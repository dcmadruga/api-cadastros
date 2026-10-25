"""Criação e atualização da estrutura do banco (schema, tabelas e migrações), com trava de segurança.

A trava impede que a API altere tabelas de OUTRO sistema que tenham, por acaso, os mesmos
nomes (clientes, produtos, fornecedores) no schema configurado.
"""
from pathlib import Path

from sqlalchemy import inspect, text

from . import models  # noqa: F401  (registra as tabelas no Base)
from .database import SCHEMA, Base, garantir_schema

PASTA_MIGRACOES = Path(__file__).resolve().parent.parent / "migracoes"

# Colunas que identificam uma tabela criada por esta API
ASSINATURA = {
    "clientes": {"id", "nome", "cpf_cnpj", "criado_em", "atualizado_em"},
    "fornecedores": {"id", "nome", "cnpj", "criado_em", "atualizado_em"},
    "produtos": {"id", "nome", "codigo", "preco", "estoque", "fornecedor_id", "criado_em", "atualizado_em"},
}


class TabelasDeOutroSistema(RuntimeError):
    pass


def verificar_tabelas(engine) -> None:
    """Levanta TabelasDeOutroSistema se houver tabelas com nossos nomes que não são da API."""
    insp = inspect(engine)
    existentes = set(insp.get_table_names(schema=SCHEMA))
    alheias = []
    for tabela, colunas in ASSINATURA.items():
        if tabela in existentes:
            tem = {c["name"] for c in insp.get_columns(tabela, schema=SCHEMA)}
            if not colunas <= tem:
                alheias.append(tabela)
    if alheias:
        raise TabelasDeOutroSistema(
            f"O schema '{SCHEMA}' já tem as tabelas {', '.join(alheias)} de outro sistema. "
            f"A API não vai alterá-las. Use outro schema (DB_SCHEMA, ex.: api_cadastros) ou outro banco."
        )


def aplicar_migracoes(engine, saida=print) -> int:
    """Executa, em ordem, os arquivos migracoes/NNN_*.sql ainda não aplicados neste schema.

    O controle fica na tabela _migracoes. Cada arquivo deve ser idempotente.
    """
    with engine.connect() as conn:
        conn = conn.execution_options(isolation_level="AUTOCOMMIT")
        conn.exec_driver_sql(
            "CREATE TABLE IF NOT EXISTS _migracoes ("
            " nome varchar(200) PRIMARY KEY, aplicada_em timestamp NOT NULL DEFAULT now())"
        )
        feitas = {r[0] for r in conn.exec_driver_sql("SELECT nome FROM _migracoes")}
        pendentes = [a for a in sorted(PASTA_MIGRACOES.glob("*.sql")) if a.name not in feitas]
        for arquivo in pendentes:
            saida(f"Aplicando migração {arquivo.name}...")
            conn.exec_driver_sql(arquivo.read_text(encoding="utf-8"))
            conn.execute(text("INSERT INTO _migracoes (nome) VALUES (:n)"), {"n": arquivo.name})
        saida(f"Migrações: {len(pendentes)} aplicada(s), {len(feitas)} já existente(s).")
        return len(pendentes)


def preparar_estrutura(engine, saida=print) -> None:
    garantir_schema(engine)
    verificar_tabelas(engine)
    Base.metadata.create_all(engine)
    saida(f"Tabelas conferidas no schema '{SCHEMA}'.")
    aplicar_migracoes(engine, saida)
