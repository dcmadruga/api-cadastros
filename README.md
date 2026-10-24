# API de Cadastros

API REST (Python/FastAPI + PostgreSQL) para **clientes, produtos e fornecedores**, com instalador para Windows que registra a API como **serviço do Windows**.

## Organização do repositório

```
api/                  código da API
  app/                aplicação (rotas, tabelas, validações)
  app/versao.py       VERSÃO OFICIAL (API e instalador usam este número)
  migracoes/          mudanças de estrutura do banco (NNN_descricao.sql)
  tests/              testes automatizados
  testar.bat          roda os testes num Windows de desenvolvimento
instalador/           script do instalador (NSIS) e configuração do serviço (WinSW)
scripts/              geração do instalador e notas de versão
.github/workflows/    automação: testes + instalador a cada mudança
CHANGELOG.md          histórico de versões
```

## Como uma modificação vira uma nova versão

1. Altera-se o código em `api/` (e, se a estrutura do banco mudar, cria-se `api/migracoes/NNN_*.sql`).
2. Os testes em `api/tests/` são ajustados/ampliados.
3. A versão sobe em `api/app/versao.py` e a mudança é descrita no `CHANGELOG.md`.
4. Envio para o GitHub (branch `main`): a automação roda os testes num PostgreSQL 18 e gera o instalador.
5. Se o número da versão for novo, a automação publica sozinha a Release `vX.Y.Z` com o instalador, pronto para baixar em **Releases**.

Para atualizar um computador, basta rodar o instalador novo por cima: ele para o serviço, troca os arquivos,
aplica as migrações pendentes no banco (sem apagar dados) e liga o serviço de novo.

### Regras para migrações
- Nome: `NNN_descricao.sql` (ex.: `002_adicionar_unidade_produto.sql`), aplicadas em ordem, uma única vez por banco.
- Devem ser **idempotentes** (`ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`...), porque numa instalação nova as tabelas já nascem na versão atual.
- Nunca apagar dados sem decisão explícita.

## Usando a API instalada

- Documentação interativa: **http://localhost:8000/docs**
- Serviço: "API de Cadastros" (services.msc). Atalhos no Menu Iniciar → API de Cadastros.
- Configuração: `C:\Program Files\ApiCadastros\.env` (atalho "Configurar conexão"; depois "Reiniciar API").
- Registro de funcionamento: `C:\Program Files\ApiCadastros\logs\api.log`.

### Endpoints

| Método | Rota | O que faz |
|---|---|---|
| GET | `/clientes` | Lista (`?q=` busca por nome, `?skip=`/`?limit=` paginam; total no cabeçalho `X-Total-Count`) |
| POST | `/clientes` | Cadastra |
| GET / PATCH / DELETE | `/clientes/{id}` | Busca / atualiza só os campos enviados / exclui |
| (mesmo padrão) | `/fornecedores`, `/produtos` | Produtos aceitam `?fornecedor_id=` |
| GET | `/fornecedores/{id}/produtos` | Produtos de um fornecedor |

### Regras
- **CPF/CNPJ + IE**: o mesmo CPF/CNPJ pode repetir com IE diferente; a mesma combinação não (409).
- Código de produto único (409). Excluir fornecedor com produtos: bloqueado (409).
- E-mail inválido, preço/estoque negativo, fornecedor inexistente: 422.

## Desenvolvimento

```bash
cd api
python -m venv .venv && .venv/bin/pip install -r requirements.txt -r requirements-dev.txt   # Windows: .venv\Scripts\pip
cp .env.example .env        # preencha DB_PASSWORD
python preparar_bancos.py   # cria api_db / api_test e aplica migrações
pytest
```
Os testes apagam e recriam as tabelas de `DB_TEST_NAME` (precisa terminar com `_test`; nunca tocam no banco de produção).

Gerar o instalador (Linux): `sudo apt install nsis && ./scripts/build_instalador.sh` → `dist/`.

## Componentes de terceiros
- [WinSW 2.12](https://github.com/winsw/winsw) (licença MIT) — registra a API como serviço do Windows.
