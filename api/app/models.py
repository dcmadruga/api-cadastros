from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Index, Numeric, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class Timestamps:
    criado_em: Mapped[datetime] = mapped_column(server_default=func.now())
    atualizado_em: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now()
    )


class Fornecedor(Timestamps, Base):
    __tablename__ = "fornecedores"
    # CNPJ pode repetir desde que a IE seja diferente.
    # coalesce: dois cadastros com o mesmo CNPJ e ambos sem IE também conflitam.
    __table_args__ = (
        Index("uq_fornecedores_cnpj_ie", "cnpj", func.coalesce(text("ie"), ""), unique=True),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(150), index=True)
    cnpj: Mapped[str | None] = mapped_column(String(18), index=True)
    ie: Mapped[str | None] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(150))
    telefone: Mapped[str | None] = mapped_column(String(20))
    endereco: Mapped[str | None] = mapped_column(String(255))

    # passive_deletes="all": deixa o próprio PostgreSQL bloquear a exclusão
    produtos: Mapped[list["Produto"]] = relationship(
        back_populates="fornecedor", passive_deletes="all"
    )


class Cliente(Timestamps, Base):
    __tablename__ = "clientes"
    # CPF/CNPJ pode repetir desde que a IE seja diferente.
    __table_args__ = (
        Index("uq_clientes_cpf_cnpj_ie", "cpf_cnpj", func.coalesce(text("ie"), ""), unique=True),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(150), index=True)
    cpf_cnpj: Mapped[str | None] = mapped_column(String(18), index=True)
    ie: Mapped[str | None] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(150))
    telefone: Mapped[str | None] = mapped_column(String(20))
    endereco: Mapped[str | None] = mapped_column(String(255))


class Produto(Timestamps, Base):
    __tablename__ = "produtos"
    __table_args__ = (
        CheckConstraint("preco >= 0", name="ck_produtos_preco"),
        CheckConstraint("estoque >= 0", name="ck_produtos_estoque"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(150), index=True)
    codigo: Mapped[str | None] = mapped_column(String(50), unique=True)
    unidade: Mapped[str] = mapped_column(String(10), default="UN", server_default="UN")
    descricao: Mapped[str | None] = mapped_column(Text)
    preco: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    estoque: Mapped[int] = mapped_column(default=0)
    # RESTRICT: não deixa excluir um fornecedor que ainda tem produtos
    fornecedor_id: Mapped[int | None] = mapped_column(
        ForeignKey("fornecedores.id", ondelete="RESTRICT"), index=True
    )

    fornecedor: Mapped[Fornecedor | None] = relationship(back_populates="produtos")
