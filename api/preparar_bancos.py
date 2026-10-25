"""Prepara o PostgreSQL para a API.

Uso:
  python preparar_bancos.py              -> modo interativo (testar.bat): pede a senha se faltar,
                                            cria os bancos da API e de teste
  python preparar_bancos.py --instalador -> modo do instalador: não pergunta nada, cria só o banco
                                            da API e as tabelas, e devolve um código de saída

Códigos de saída: 0 = ok, 2 = senha recusada, 3 = servidor não encontrado,
4 = tabelas de outro sistema no schema (nada foi alterado), 1 = outro erro.
Não altera nenhum outro banco.
"""
import getpass
import os
import sys
from pathlib import Path

from dotenv import set_key

from app.config import carregar_env

BASE = Path(__file__).resolve().parent
os.chdir(BASE)
sys.path.insert(0, str(BASE))
INSTALADOR = "--instalador" in sys.argv

ENV = BASE / ".env"
if not ENV.exists():
    ENV.write_text((BASE / ".env.example").read_text(encoding="utf-8"), encoding="utf-8")
carregar_env(ENV)

if not os.getenv("DB_PASSWORD") and not INSTALADOR:
    from app.config import ler_texto
    ENV.write_text(ler_texto(ENV), encoding="utf-8")  # set_key exige UTF-8
    print(f"Conectando no PostgreSQL em {os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')} "
          f"com o usuário '{os.getenv('DB_USER', 'postgres')}'.")
    senha = getpass.getpass("Digite a senha do PostgreSQL (não aparece enquanto digita) e tecle Enter: ")
    os.environ["DB_PASSWORD"] = senha
    set_key(str(ENV), "DB_PASSWORD", senha, quote_mode="always")

from sqlalchemy import create_engine, text  # noqa: E402

from app.database import montar_url  # noqa: E402

nome_api = os.getenv("DB_NAME", "api_db")
nome_teste = os.getenv("DB_TEST_NAME", "api_test")
if not nome_teste.endswith("_test"):
    sys.exit(f"Recusado: o banco de teste '{nome_teste}' precisa terminar com '_test'.")
bancos = (nome_api,) if INSTALADOR else (nome_api, nome_teste)

try:
    engine = create_engine(montar_url("postgres"), isolation_level="AUTOCOMMIT")
    with engine.connect() as conn:
        print("Conectado:", conn.scalar(text("select version()")))
        for nome in bancos:
            if conn.scalar(text("select 1 from pg_database where datname = :n"), {"n": nome}):
                print(f"Banco '{nome}' já existe.")
            else:
                conn.execute(text(f'CREATE DATABASE "{nome}"'))
                print(f"Banco '{nome}' criado.")
    # Schema próprio + tabelas novas + migrações pendentes no banco da API (nunca apaga dados)
    from app.database import SCHEMA, criar_engine
    from app.estrutura import TabelasDeOutroSistema, preparar_estrutura
    print(f"Usando o schema '{SCHEMA}' no banco '{nome_api}'.")
    try:
        preparar_estrutura(criar_engine(montar_url(nome_api)))
    except TabelasDeOutroSistema as bloqueio:
        print("RECUSADO:", bloqueio)
        sys.exit(4)
except SystemExit:
    raise
except Exception as e:
    # SQLSTATE independe do idioma do servidor (28P01/28000 = autenticação recusada)
    codigo = getattr(getattr(e, "orig", None), "sqlstate", None) or getattr(e, "sqlstate", None)
    texto = str(e).lower()
    print("ERRO ao conectar no PostgreSQL. Confira servidor, porta, usuário e senha.")
    print("Detalhe:", str(e).splitlines()[0])
    if codigo in ("28P01", "28000") or "password" in texto or "senha" in texto:
        if not INSTALADOR:
            set_key(str(ENV), "DB_PASSWORD", "", quote_mode="never")
            print("A senha foi apagada do .env; rode o testar.bat de novo para digitá-la.")
        sys.exit(2)
    if "connection refused" in texto or "recus" in texto or "could not translate" in texto or "timeout" in texto:
        sys.exit(3)
    sys.exit(1)
