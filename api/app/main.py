from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import models, schemas
from .crud import criar_router
from .database import Base, engine, get_db
from .versao import VERSAO


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Cria as tabelas no PostgreSQL caso ainda não existam
    Base.metadata.create_all(bind=engine)
    yield


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


@app.get("/", tags=["Status"], summary="Verificar se a API está no ar")
def status_api():
    return {"status": "ok", "documentacao": "/docs"}
