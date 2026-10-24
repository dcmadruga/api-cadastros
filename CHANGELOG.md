# Histórico de versões

Formato: cada versão lista o que mudou. A versão oficial fica em `api/app/versao.py`.

## [1.2.1] - 2026-10-24
- **Correção:** o instalador gravava o `.env` na codificação do Windows (cp1252) e a API o lia como UTF-8, o que quebrava a preparação do banco e a partida do serviço (`UnicodeDecodeError`). Agora a API aceita as duas codificações e o instalador grava o `.env` sem acentos.
- **Registro da instalação:** cada passo, a saída de cada comando e os erros são gravados em `C:\ProgramData\ApiCadastros\instalacao.txt` (a senha nunca é registrada). Em caso de falha, o arquivo é aberto automaticamente. Cópia em `C:\Program Files\ApiCadastros\logs\instalacao.txt` e atalho "Ver registro da instalação" no Menu Iniciar.
- O registro inclui versão do Windows, .NET Framework, Python encontrado e status final do serviço.

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
