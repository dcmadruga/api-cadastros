"""Imprime a seção do CHANGELOG.md de uma versão (usado nas notas da Release)."""
import re
import sys
from pathlib import Path

versao = sys.argv[1]
texto = Path(__file__).resolve().parent.parent.joinpath("CHANGELOG.md").read_text(encoding="utf-8")
m = re.search(rf"^## \[?{re.escape(versao)}\]?.*?$(.*?)(?=^## |\Z)", texto, re.M | re.S)
print(m.group(1).strip() if m else f"Versão {versao}")
