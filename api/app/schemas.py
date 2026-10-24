"""Formato dos dados que entram e saem da API (validação automática)."""
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class SaidaBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    criado_em: datetime
    atualizado_em: datetime


# ---------- Fornecedores ----------
class FornecedorCriar(BaseModel):
    nome: str = Field(min_length=1, max_length=150)
    cnpj: str | None = Field(default=None, max_length=18)
    ie: str | None = Field(default=None, max_length=20, description="Inscrição Estadual")
    email: EmailStr | None = None
    telefone: str | None = Field(default=None, max_length=20)
    endereco: str | None = Field(default=None, max_length=255)


class FornecedorAtualizar(BaseModel):
    nome: str | None = Field(default=None, min_length=1, max_length=150)
    cnpj: str | None = Field(default=None, max_length=18)
    ie: str | None = Field(default=None, max_length=20, description="Inscrição Estadual")
    email: EmailStr | None = None
    telefone: str | None = Field(default=None, max_length=20)
    endereco: str | None = Field(default=None, max_length=255)


class FornecedorSaida(SaidaBase, FornecedorCriar):
    email: str | None = None


# ---------- Clientes ----------
class ClienteCriar(BaseModel):
    nome: str = Field(min_length=1, max_length=150)
    cpf_cnpj: str | None = Field(default=None, max_length=18)
    ie: str | None = Field(default=None, max_length=20, description="Inscrição Estadual")
    email: EmailStr | None = None
    telefone: str | None = Field(default=None, max_length=20)
    endereco: str | None = Field(default=None, max_length=255)


class ClienteAtualizar(BaseModel):
    nome: str | None = Field(default=None, min_length=1, max_length=150)
    cpf_cnpj: str | None = Field(default=None, max_length=18)
    ie: str | None = Field(default=None, max_length=20, description="Inscrição Estadual")
    email: EmailStr | None = None
    telefone: str | None = Field(default=None, max_length=20)
    endereco: str | None = Field(default=None, max_length=255)


class ClienteSaida(SaidaBase, ClienteCriar):
    email: str | None = None


# ---------- Produtos ----------
class ProdutoCriar(BaseModel):
    nome: str = Field(min_length=1, max_length=150)
    codigo: str | None = Field(default=None, max_length=50)
    unidade: str = Field(default="UN", min_length=1, max_length=10, description="Unidade de medida (ex.: UN, KG, L, CX, PCT)")
    descricao: str | None = None
    preco: Decimal = Field(default=Decimal("0"), ge=0, max_digits=12, decimal_places=2)
    estoque: int = Field(default=0, ge=0)
    fornecedor_id: int | None = None

    @field_validator("unidade", mode="before")
    @classmethod
    def _maiuscula(cls, v):
        return v.strip().upper() if isinstance(v, str) else v


class ProdutoAtualizar(BaseModel):
    nome: str | None = Field(default=None, min_length=1, max_length=150)
    codigo: str | None = Field(default=None, max_length=50)
    unidade: str | None = Field(default=None, min_length=1, max_length=10, description="Unidade de medida (ex.: UN, KG, L, CX, PCT)")
    descricao: str | None = None
    preco: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    estoque: int | None = Field(default=None, ge=0)
    fornecedor_id: int | None = None

    @field_validator("unidade", mode="before")
    @classmethod
    def _maiuscula(cls, v):
        return v.strip().upper() if isinstance(v, str) else v


class ProdutoSaida(SaidaBase, ProdutoCriar):
    pass
