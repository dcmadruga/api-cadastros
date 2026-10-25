import os
import re

from sqlalchemy import URL, create_engine, event, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import carregar_env  # noqa: E402

carregar_env()


def montar_url(nome_banco: str | None = None):
    """Usa DATABASE_URL se existir; senão monta a conexão a partir de DB_HOST, DB_USER etc.

    Montar pelas partes evita problemas com senhas que têm caracteres especiais (@, :, /).
    """
    if os.getenv("DATABASE_URL") and nome_banco is None:
        return os.environ["DATABASE_URL"]
    return URL.create(
        "postgresql+psycopg",
        username=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD") or None,
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        database=nome_banco or os.getenv("DB_NAME", "api_db"),
    )


def nome_schema() -> str:
    """Schema (área separada dentro do banco) onde ficam as tabelas da API.

    Usar um schema próprio (ex.: api_cadastros) garante que a API nunca mexa em tabelas
    de outros sistemas que existam no mesmo banco, mesmo que tenham nomes iguais.
    """
    schema = (os.getenv("DB_SCHEMA") or "public").strip().lower()
    if not re.fullmatch(r"[a-z_][a-z0-9_]{0,62}", schema):
        raise ValueError(f"DB_SCHEMA inválido: {schema!r} (use letras minúsculas, números e _)")
    return schema


SCHEMA = nome_schema()


def criar_engine(url, **kwargs):
    kwargs.setdefault("connect_args", {}).setdefault("connect_timeout", 5)
    eng = create_engine(url, pool_pre_ping=True, **kwargs)

    @event.listens_for(eng, "connect")
    def _usar_schema(dbapi_conn, _record):
        # todas as conexões da API enxergam só o schema da API (e o catálogo do sistema)
        with dbapi_conn.cursor() as cur:
            cur.execute(f'SET search_path TO "{SCHEMA}"')
        dbapi_conn.commit()

    return eng


def garantir_schema(eng) -> None:
    if SCHEMA != "public":
        with eng.begin() as conn:
            conn.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{SCHEMA}"'))


engine = criar_engine(montar_url())
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    """Abre uma sessão com o banco por requisição e fecha ao final.

    Enquanto o banco não estiver pronto, responde 503 com o motivo (a API segue no ar).
    """
    from fastapi import HTTPException

    from .estado import ESTADO

    if ESTADO["banco"] != "ok":
        raise HTTPException(503, f"Banco de dados indisponível ({ESTADO['banco']}): {ESTADO['detalhe']}")
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
