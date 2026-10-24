"""Leitura do arquivo .env.

O instalador do Windows pode gravar o .env na codificação do Windows (cp1252);
editores como o Bloco de Notas podem gravar em UTF-8 (com ou sem BOM).
Aqui aceitamos os dois, para que acentos (inclusive na senha) nunca quebrem a API.
"""
import io
from pathlib import Path

from dotenv import load_dotenv


def ler_texto(caminho: Path) -> str:
    dados = caminho.read_bytes()
    for codificacao in ("utf-8-sig", "cp1252"):
        try:
            return dados.decode(codificacao)
        except UnicodeDecodeError:
            continue
    return dados.decode("latin-1")


def carregar_env(caminho: Path | str | None = None, sobrescrever: bool = False) -> bool:
    caminho = Path(caminho) if caminho else Path(__file__).resolve().parent.parent / ".env"
    if not caminho.exists():
        return False
    return load_dotenv(stream=io.StringIO(ler_texto(caminho)), override=sobrescrever)
