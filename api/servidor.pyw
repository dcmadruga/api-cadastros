"""Processo da API executado pelo serviço do Windows "API de Cadastros" (via WinSW).

Também pode ser rodado à mão para testes. O registro de funcionamento fica em logs\\api.log.
"""
import os
import socket
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
os.chdir(BASE)
sys.path.insert(0, str(BASE))

(BASE / "logs").mkdir(exist_ok=True)
# pythonw.exe não tem console: manda toda a saída para o arquivo de log
log = open(BASE / "logs" / "api.log", "a", encoding="utf-8", buffering=1)
sys.stdout = sys.stderr = log

from dotenv import load_dotenv  # noqa: E402

load_dotenv(BASE / ".env")
HOST = os.getenv("API_HOST", "127.0.0.1")
PORTA = int(os.getenv("API_PORT", "8000"))

# Se a API já estiver rodando, não abre uma segunda cópia
with socket.socket() as s:
    s.settimeout(1)
    if s.connect_ex(("127.0.0.1" if HOST in ("0.0.0.0", "") else HOST, PORTA)) == 0:
        # código 1 = falha: o serviço tenta de novo em alguns segundos (porta pode liberar)
        print(f"A porta {PORTA} já está em uso por outro programa; nova tentativa em instantes.")
        sys.exit(1)

(BASE / "logs" / "api.pid").write_text(str(os.getpid()))

import uvicorn  # noqa: E402

try:
    print(f"Iniciando API em http://{HOST}:{PORTA}")
    uvicorn.run("app.main:app", host=HOST, port=PORTA, log_config=None, use_colors=False)
finally:
    (BASE / "logs" / "api.pid").unlink(missing_ok=True)
