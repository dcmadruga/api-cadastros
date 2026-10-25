"""Testes da API.

ATENÇÃO: as tabelas do banco de teste são APAGADAS e recriadas a cada teste.
Por segurança, o banco usado é DB_TEST_NAME (padrão: api_test) e o nome
precisa terminar com "_test"; caso contrário os testes nem começam.
"""
import os

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.config import carregar_env  # noqa: E402

carregar_env()
NOME_BANCO_TESTE = os.getenv("DB_TEST_NAME", "api_test")
if not NOME_BANCO_TESTE.endswith("_test"):
    raise SystemExit(f"Recusado: o banco de teste '{NOME_BANCO_TESTE}' precisa terminar com '_test'.")
os.environ.pop("DATABASE_URL", None)
os.environ["DB_NAME"] = NOME_BANCO_TESTE

import pytest
from fastapi.testclient import TestClient

from app.database import Base, engine, garantir_schema
from app.main import app


@pytest.fixture(autouse=True)
def banco_limpo():
    garantir_schema(engine)
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_status(client):
    assert client.get("/").json()["status"] == "ok"


def test_crud_cliente(client):
    r = client.post("/clientes", json={"nome": "Maria Silva", "cpf_cnpj": "123.456.789-00", "email": "maria@ex.com"})
    assert r.status_code == 201, r.text
    cid = r.json()["id"]

    assert client.get(f"/clientes/{cid}").json()["nome"] == "Maria Silva"

    r = client.patch(f"/clientes/{cid}", json={"telefone": "(65) 99999-0000"})
    assert r.json()["telefone"] == "(65) 99999-0000"
    assert r.json()["nome"] == "Maria Silva"  # campos não enviados ficam como estavam

    client.post("/clientes", json={"nome": "João Souza"})
    r = client.get("/clientes", params={"q": "maria"})
    assert [c["nome"] for c in r.json()] == ["Maria Silva"]
    assert client.get("/clientes").headers["X-Total-Count"] == "2"

    assert client.delete(f"/clientes/{cid}").status_code == 204
    assert client.get(f"/clientes/{cid}").status_code == 404


def test_cpf_cnpj_com_ie(client):
    cnpj = "12.345.678/0001-90"
    # mesmo CNPJ com IEs diferentes: permitido
    a = client.post("/clientes", json={"nome": "Loja Matriz", "cpf_cnpj": cnpj, "ie": "13.111.111-1"})
    b = client.post("/clientes", json={"nome": "Loja Filial", "cpf_cnpj": cnpj, "ie": "13.222.222-2"})
    assert a.status_code == 201 and b.status_code == 201, b.text
    # um terceiro sem IE também é permitido (só pode haver um sem IE)
    assert client.post("/clientes", json={"nome": "Sem IE", "cpf_cnpj": cnpj}).status_code == 201
    # repetições: bloqueadas
    assert client.post("/clientes", json={"nome": "X", "cpf_cnpj": cnpj, "ie": "13.111.111-1"}).status_code == 409
    assert client.post("/clientes", json={"nome": "Y", "cpf_cnpj": cnpj}).status_code == 409
    # editar a filial para a IE da matriz: bloqueado
    assert client.patch(f"/clientes/{b.json()['id']}", json={"ie": "13.111.111-1"}).status_code == 409
    # mesma IE com CPF/CNPJ diferente: permitido
    assert client.post("/clientes", json={"nome": "Z", "cpf_cnpj": "999", "ie": "13.111.111-1"}).status_code == 201

    # fornecedores seguem a mesma regra
    assert client.post("/fornecedores", json={"nome": "F1", "cnpj": cnpj, "ie": "1"}).status_code == 201
    assert client.post("/fornecedores", json={"nome": "F2", "cnpj": cnpj, "ie": "2"}).status_code == 201
    assert client.post("/fornecedores", json={"nome": "F3", "cnpj": cnpj, "ie": "2"}).status_code == 409


def test_validacoes_cliente(client):
    assert client.post("/clientes", json={"nome": "C", "email": "nao-e-email"}).status_code == 422
    assert client.post("/clientes", json={"nome": ""}).status_code == 422


def test_produto_com_fornecedor(client):
    f = client.post("/fornecedores", json={"nome": "Distribuidora Centro-Oeste", "cnpj": "12.345.678/0001-90"}).json()
    r = client.post("/produtos", json={"nome": "Café 500g", "codigo": "CAF500", "preco": "18.90", "estoque": 40, "fornecedor_id": f["id"]})
    assert r.status_code == 201, r.text
    p = r.json()
    assert p["preco"] == "18.90"

    client.post("/produtos", json={"nome": "Açúcar 1kg", "preco": 5})
    assert len(client.get("/produtos", params={"fornecedor_id": f["id"]}).json()) == 1
    assert [x["nome"] for x in client.get(f"/fornecedores/{f['id']}/produtos").json()] == ["Café 500g"]

    # fornecedor inexistente
    assert client.post("/produtos", json={"nome": "X", "fornecedor_id": 999}).status_code == 422
    # preço e estoque negativos
    assert client.post("/produtos", json={"nome": "X", "preco": -1}).status_code == 422
    assert client.patch(f"/produtos/{p['id']}", json={"estoque": -5}).status_code == 422
    # código duplicado
    assert client.post("/produtos", json={"nome": "Y", "codigo": "CAF500"}).status_code == 409

    # não pode excluir fornecedor com produtos
    assert client.delete(f"/fornecedores/{f['id']}").status_code == 409
    assert client.get(f"/produtos/{p['id']}").json()["fornecedor_id"] == f["id"]

    client.delete(f"/produtos/{p['id']}")
    assert client.delete(f"/fornecedores/{f['id']}").status_code == 204


def test_paginacao(client):
    for i in range(5):
        client.post("/fornecedores", json={"nome": f"Fornecedor {i}"})
    r = client.get("/fornecedores", params={"skip": 2, "limit": 2})
    assert [x["nome"] for x in r.json()] == ["Fornecedor 2", "Fornecedor 3"]
    assert r.headers["X-Total-Count"] == "5"


def test_unidade_produto(client):
    # padrão UN quando não informada
    p = client.post("/produtos", json={"nome": "Parafuso"}).json()
    assert p["unidade"] == "UN"
    # aceita e padroniza em maiúsculas
    r = client.post("/produtos", json={"nome": "Arroz", "unidade": " kg "})
    assert r.status_code == 201 and r.json()["unidade"] == "KG"
    # edição
    r = client.patch(f"/produtos/{p['id']}", json={"unidade": "cx"})
    assert r.json()["unidade"] == "CX"
    # inválidas: vazia, longa demais, nula
    assert client.post("/produtos", json={"nome": "X", "unidade": "  "}).status_code == 422
    assert client.post("/produtos", json={"nome": "X", "unidade": "UNIDADE-GRANDE"}).status_code == 422
    assert client.patch(f"/produtos/{p['id']}", json={"unidade": None}).status_code == 422
    assert client.get(f"/produtos/{p['id']}").json()["unidade"] == "CX"


def test_campo_obrigatorio_nulo_na_edicao(client):
    c = client.post("/clientes", json={"nome": "Fulano"}).json()
    assert client.patch(f"/clientes/{c['id']}", json={"nome": None}).status_code == 422


def test_env_em_cp1252_e_utf8(tmp_path):
    from app.config import ler_texto
    texto = "# Configuração\nDB_PASSWORD='ção@1'\n"
    for cod in ("cp1252", "utf-8", "utf-8-sig"):
        arq = tmp_path / f"env_{cod}"
        arq.write_bytes(texto.encode(cod))
        assert ler_texto(arq) == texto
