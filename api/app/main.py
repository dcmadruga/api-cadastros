import asyncio
import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.exc import DBAPIError, OperationalError
from sqlalchemy.orm import Session

from . import models, schemas
from .crud import criar_router
from .database import SCHEMA, engine, get_db
from .estado import ESTADO
from .estrutura import TabelasDeOutroSistema, preparar_estrutura
from .versao import VERSAO

log = logging.getLogger("api")
INTERVALO_TENTATIVA = int(os.getenv("DB_RETRY_SECONDS", "30"))


def _resumo_erro(erro: Exception) -> str:
    texto = str(getattr(erro, "orig", None) or erro).strip().splitlines()
    return texto[0] if texto else type(erro).__name__


def tentar_preparar_banco() -> bool:
    destino = f"{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'api_db')} (schema {SCHEMA})"
    try:
        with engine.connect() as conn:
            versao_pg = conn.exec_driver_sql("show server_version").scalar()
        preparar_estrutura(engine, saida=log.info)
        ESTADO.update(banco="ok", detalhe=f"PostgreSQL {versao_pg} em {destino}")
        log.info("Banco pronto: %s", ESTADO["detalhe"])
        return True
    except Exception as erro:  # noqa: BLE001
        bloqueado = isinstance(erro, TabelasDeOutroSistema)
        detalhe = f"{destino}: {_resumo_erro(erro)}"
        mudou = detalhe != ESTADO.get("detalhe")
        ESTADO.update(banco="bloqueado" if bloqueado else "indisponivel", detalhe=detalhe)
        agora = time.monotonic()
        if mudou or agora - ESTADO.get("ultimo_aviso", 0) > 600:
            ESTADO["ultimo_aviso"] = agora
            log.error("Banco indisponível — %s. Nova tentativa a cada %ss; a API continua no ar.",
                      detalhe, INTERVALO_TENTATIVA)
        return False


async def _vigiar_banco():
    while not await asyncio.to_thread(tentar_preparar_banco):
        await asyncio.sleep(INTERVALO_TENTATIVA)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Prepara o banco em segundo plano: se ele estiver fora do ar, a API sobe mesmo assim
    # e fica tentando de novo, respondendo 503 com o motivo enquanto isso.
    tarefa = None
    if not await asyncio.to_thread(tentar_preparar_banco):
        tarefa = asyncio.create_task(_vigiar_banco())
    yield
    if tarefa:
        tarefa.cancel()


app = FastAPI(
    title="API de Cadastros",
    description="Clientes, produtos e fornecedores.",
    version=VERSAO,
    lifespan=lifespan,
)


def validar_produto(db: Session, valores: dict):
    fid = valores.get("fornecedor_id")
    if fid is not None and db.get(models.Fornecedor, fid) is None:
        raise HTTPException(422, f"Fornecedor {fid} não existe.")


def filtros_produto(
    fornecedor_id: int | None = Query(None, description="Filtrar por fornecedor"),
):
    return {"fornecedor_id": fornecedor_id}


app.include_router(criar_router(
    model=models.Cliente, schema_criar=schemas.ClienteCriar,
    schema_atualizar=schemas.ClienteAtualizar, schema_saida=schemas.ClienteSaida,
    prefixo="/clientes", nome="cliente",
))

fornecedores_router = criar_router(
    model=models.Fornecedor, schema_criar=schemas.FornecedorCriar,
    schema_atualizar=schemas.FornecedorAtualizar, schema_saida=schemas.FornecedorSaida,
    prefixo="/fornecedores", nome="fornecedor",
)


@fornecedores_router.get(
    "/{item_id}/produtos", response_model=list[schemas.ProdutoSaida],
    summary="Listar produtos de um fornecedor",
)
def produtos_do_fornecedor(item_id: int, db: Session = Depends(get_db)):
    if db.get(models.Fornecedor, item_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Fornecedor {item_id} não encontrado.")
    return db.scalars(
        select(models.Produto).where(models.Produto.fornecedor_id == item_id).order_by(models.Produto.id)
    ).all()


app.include_router(fornecedores_router)

app.include_router(criar_router(
    model=models.Produto, schema_criar=schemas.ProdutoCriar,
    schema_atualizar=schemas.ProdutoAtualizar, schema_saida=schemas.ProdutoSaida,
    prefixo="/produtos", nome="produto",
    filtros_extras=filtros_produto, validar=validar_produto,
))


@app.exception_handler(OperationalError)
@app.exception_handler(DBAPIError)
async def banco_fora_do_ar(request: Request, erro: Exception):
    codigo = getattr(getattr(erro, "orig", None), "sqlstate", None) or ""
    if isinstance(erro, OperationalError) or codigo.startswith("08") or codigo == "42P01":
        return JSONResponse(status_code=503, content={
            "detail": f"Banco de dados indisponível: {_resumo_erro(erro)}"})
    raise erro


@app.get("/", tags=["Status"], summary="Verificar se a API está no ar e o estado do banco")
def status_api():
    return {"status": "ok", "versao": VERSAO, "banco": ESTADO["banco"],
            "banco_detalhe": ESTADO["detalhe"], "documentacao": "/docs"}
