import os

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

load_dotenv()


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


engine = create_engine(montar_url(), pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    """Abre uma sessão com o banco por requisição e fecha ao final."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
