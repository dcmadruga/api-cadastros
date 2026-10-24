"""Prepara o PostgreSQL para a API.

Uso:
  python preparar_bancos.py              -> modo interativo (testar.bat): pede a senha se faltar,
                                            cria os bancos da API e de teste
  python preparar_bancos.py --instalador -> modo do instalador: não pergunta nada, cria só o banco
                                            da API e as tabelas, e devolve um código de saída

Códigos de saída: 0 = ok, 2 = senha recusada, 3 = servidor não encontrado, 1 = outro erro.
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

def aplicar_migracoes(engine):
    """Executa, em ordem, os arquivos migracoes/NNN_*.sql que ainda não foram aplicados neste banco.

    O controle fica na tabela _migracoes. Cada arquivo deve ser idempotente
    (usar IF NOT EXISTS etc.), pois numa instalação nova as tabelas já nascem atualizadas.
    """
    pasta = BASE / "migracoes"
    with engine.connect() as conn:
        conn.exec_driver_sql(
            "CREATE TABLE IF NOT EXISTS _migracoes ("
            " nome varchar(200) PRIMARY KEY, aplicada_em timestamp NOT NULL DEFAULT now())"
        )
        feitas = {r[0] for r in conn.exec_driver_sql("SELECT nome FROM _migracoes")}
        pendentes = [a for a in sorted(pasta.glob("*.sql")) if a.name not in feitas]
        for arquivo in pendentes:
            print(f"Aplicando migração {arquivo.name}...")
            conn.exec_driver_sql(arquivo.read_text(encoding="utf-8"))
            conn.execute(text("INSERT INTO _migracoes (nome) VALUES (:n)"), {"n": arquivo.name})
        print(f"Migrações: {len(pendentes)} aplicada(s), {len(feitas)} já existente(s).")


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
    # Tabelas novas + migrações pendentes no banco da API (nunca apaga dados)
    from app import models  # noqa: F401  (registra as tabelas)
    from app.database import Base
    engine_api = create_engine(montar_url(nome_api))
    Base.metadata.create_all(engine_api)
    print(f"Tabelas conferidas no banco '{nome_api}'.")
    aplicar_migracoes(create_engine(montar_url(nome_api), isolation_level="AUTOCOMMIT"))
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
