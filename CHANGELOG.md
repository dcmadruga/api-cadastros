# Histórico de versões

Formato: cada versão lista o que mudou. A versão oficial fica em `api/app/versao.py`.

## [1.2.0] - 2026-10-24
- Produto ganhou o campo **unidade** (unidade de medida: UN, KG, L, CX...). Padrão "UN", gravado em maiúsculas, até 10 caracteres.
- Atualização automática do banco (migração 002): produtos já cadastrados recebem "UN".
- Enviar um campo obrigatório como nulo numa edição agora responde 422 com mensagem clara (antes era 400).

## [1.1.0] - 2026-10-24
- API instalada como serviço do Windows (WinSW): inicia com o computador e reinicia sozinha em caso de falha.
- Instalador em `C:\Program Files\ApiCadastros`, com atalhos para reiniciar, parar e configurar.
- Migrações automáticas do banco ao instalar ou atualizar (tabela `_migracoes`).
- Senha do `.env` protegida (só administradores e o serviço podem ler).

## [1.0.0] - 2026-10-24
- Cadastro de clientes, produtos e fornecedores (criar, listar, buscar, editar, excluir).
- Campo IE: mesmo CPF/CNPJ permitido com IE diferente.
- Erros do banco identificados por código SQLSTATE (funciona com PostgreSQL em português e na versão 18).
- Testado no PostgreSQL 18 do computador argo-madruga (6 de 6 testes).
