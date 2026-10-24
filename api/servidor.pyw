"""Processo da API executado pelo serviço do Windows "API de Cadastros" (via WinSW).

Também pode ser rodado à mão para testes.
Registro de funcionamento: logs\\api.log (com data/hora; erros repetidos são resumidos).
"""
import logging
import os
import socket
import sys
import traceback
from datetime import datetime
from pathlib import Path

BASE = Path(__file__).resolve().parent
os.chdir(BASE)
sys.path.insert(0, str(BASE))

LOGS = BASE / "logs"
LOGS.mkdir(exist_ok=True)
ARQ_LOG = LOGS / "api.log"
ARQ_ULTIMO_ERRO = LOGS / "ultimo_erro.txt"

# Mantém o registro em tamanho razoável (guarda o anterior como api.log.1)
if ARQ_LOG.exists() and ARQ_LOG.stat().st_size > 5 * 1024 * 1024:
    ARQ_LOG.replace(LOGS / "api.log.1")

# pythonw.exe / serviço não têm console: toda a saída vai para o arquivo
log = open(ARQ_LOG, "a", encoding="utf-8", buffering=1)
sys.stdout = sys.stderr = log
logging.basicConfig(
    stream=log, level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(name)s: %(message)s", datefmt="%Y-%m-%d %H:%M:%S",
)


def registrar(mensagem: str) -> None:
    log.write(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {mensagem}\n")


def registrar_erro(resumo: str, detalhe: str) -> None:
    """Grava o erro. Se for igual ao anterior, grava só uma linha curta (evita encher o arquivo)."""
    assinatura = resumo.strip()
    anterior = ARQ_ULTIMO_ERRO.read_text(encoding="utf-8") if ARQ_ULTIMO_ERRO.exists() else ""
    if anterior.startswith(assinatura + "\n"):
        vezes = int(anterior.split("\n", 2)[1] or 1) + 1
        registrar(f"ERRO (repetido, {vezes}ª vez): {resumo}")
    else:
        vezes = 1
        registrar(f"ERRO: {resumo}")
        if detalhe.strip():
            log.write(detalhe.rstrip() + "\n")
    ARQ_ULTIMO_ERRO.write_text(f"{assinatura}\n{vezes}\n", encoding="utf-8")


try:
    from app.config import carregar_env
    from app.versao import VERSAO

    carregar_env(BASE / ".env")
    HOST = os.getenv("API_HOST", "127.0.0.1")
    PORTA = int(os.getenv("API_PORT", "8000"))
    registrar(f"Iniciando API de Cadastros {VERSAO} em http://{HOST}:{PORTA}")

    # Se a porta já estiver ocupada, sai com erro: o serviço tenta de novo em instantes
    with socket.socket() as s:
        s.settimeout(1)
        if s.connect_ex(("127.0.0.1" if HOST in ("0.0.0.0", "") else HOST, PORTA)) == 0:
            registrar_erro(
                f"A porta {PORTA} já está em uso por outro programa (feche-o ou troque API_PORT no .env).",
                "",
            )
            sys.exit(1)

    (LOGS / "api.pid").write_text(str(os.getpid()))
    ARQ_ULTIMO_ERRO.unlink(missing_ok=True)

    import uvicorn

    try:
        uvicorn.run("app.main:app", host=HOST, port=PORTA, log_config=None, use_colors=False)
    finally:
        (LOGS / "api.pid").unlink(missing_ok=True)
        registrar("API encerrada")
except SystemExit:
    raise
except BaseException as erro:  # qualquer falha na partida vira uma linha clara no registro
    registrar_erro(f"{type(erro).__name__}: {erro}", traceback.format_exc())
    sys.exit(1)
