"""Gera as rotas de CRUD (criar, listar, buscar, editar, excluir) para um recurso.

Assim clientes, produtos e fornecedores seguem exatamente o mesmo padrão
sem repetir código.
"""
from typing import Callable

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .database import get_db


def traduzir_erro_integridade(erro: IntegrityError) -> HTTPException:
    # Usa o código SQLSTATE do PostgreSQL, que é o mesmo em qualquer idioma do servidor
    # (as mensagens de texto mudam conforme o idioma: inglês, português...).
    codigo = getattr(erro.orig, "sqlstate", None)
    if codigo == "23505":  # unique_violation
        return HTTPException(status.HTTP_409_CONFLICT, "Já existe um registro com esses dados (mesmo CPF/CNPJ com a mesma IE, ou código de produto repetido).")
    # 23503 = foreign_key_violation; 23001 = restrict_violation (PostgreSQL 18 usa este
    # ao tentar excluir um registro protegido por ON DELETE RESTRICT)
    if codigo in ("23503", "23001"):
        return HTTPException(status.HTTP_409_CONFLICT, "Operação viola um vínculo entre registros (ex.: fornecedor inexistente ou com produtos vinculados).")
    if codigo == "23514":  # check_violation
        return HTTPException(422, "Valor fora do permitido (ex.: preço ou estoque negativo).")
    return HTTPException(status.HTTP_400_BAD_REQUEST, "Dados inválidos para o banco de dados.")


def criar_router(
    *,
    model,
    schema_criar,
    schema_atualizar,
    schema_saida,
    prefixo: str,
    nome: str,
    filtros_extras: Callable | None = None,
    validar: Callable | None = None,
) -> APIRouter:
    router = APIRouter(prefix=prefixo, tags=[nome.capitalize() + "s"])

    def buscar_ou_404(db: Session, item_id: int):
        obj = db.get(model, item_id)
        if obj is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, f"{nome.capitalize()} {item_id} não encontrado.")
        return obj

    def salvar(db: Session, obj):
        try:
            db.commit()
        except IntegrityError as e:
            db.rollback()
            raise traduzir_erro_integridade(e)
        db.refresh(obj)
        return obj

    @router.get("", response_model=list[schema_saida], summary=f"Listar {nome}s")
    def listar(
        response: Response,
        q: str | None = Query(None, description="Busca por parte do nome"),
        skip: int = Query(0, ge=0),
        limit: int = Query(50, ge=1, le=500),
        db: Session = Depends(get_db),
        extras: dict = Depends(filtros_extras) if filtros_extras else Depends(lambda: {}),
    ):
        stmt = select(model)
        if q:
            stmt = stmt.where(model.nome.ilike(f"%{q}%"))
        for coluna, valor in extras.items():
            if valor is not None:
                stmt = stmt.where(getattr(model, coluna) == valor)
        total = db.scalar(select(func.count()).select_from(stmt.subquery()))
        response.headers["X-Total-Count"] = str(total)
        return db.scalars(stmt.order_by(model.id).offset(skip).limit(limit)).all()

    @router.get("/{item_id}", response_model=schema_saida, summary=f"Buscar {nome} por ID")
    def obter(item_id: int, db: Session = Depends(get_db)):
        return buscar_ou_404(db, item_id)

    @router.post("", response_model=schema_saida, status_code=status.HTTP_201_CREATED, summary=f"Cadastrar {nome}")
    def criar(dados: schema_criar, db: Session = Depends(get_db)):
        valores = dados.model_dump()
        if validar:
            validar(db, valores)
        obj = model(**valores)
        db.add(obj)
        return salvar(db, obj)

    @router.patch("/{item_id}", response_model=schema_saida, summary=f"Atualizar {nome}")
    def atualizar(item_id: int, dados: schema_atualizar, db: Session = Depends(get_db)):
        obj = buscar_ou_404(db, item_id)
        valores = dados.model_dump(exclude_unset=True)
        if validar:
            validar(db, valores)
        for campo, valor in valores.items():
            setattr(obj, campo, valor)
        return salvar(db, obj)

    @router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary=f"Excluir {nome}")
    def excluir(item_id: int, db: Session = Depends(get_db)):
        obj = buscar_ou_404(db, item_id)
        db.delete(obj)
        try:
            db.commit()
        except IntegrityError as e:
            db.rollback()
            raise traduzir_erro_integridade(e)

    return router
