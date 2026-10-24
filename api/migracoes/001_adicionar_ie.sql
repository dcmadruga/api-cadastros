-- Atualização: adiciona Inscrição Estadual (IE) e permite CPF/CNPJ repetido com IE diferente.
-- Rode UMA vez, apenas se as tabelas já existiam antes desta versão:
--   psql -U seu_usuario -d seu_banco -f migracoes/001_adicionar_ie.sql

BEGIN;

-- Clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS ie VARCHAR(20);
ALTER TABLE clientes DROP CONSTRAINT IF EXISTS clientes_cpf_cnpj_key;
CREATE INDEX IF NOT EXISTS ix_clientes_cpf_cnpj ON clientes (cpf_cnpj);
CREATE UNIQUE INDEX IF NOT EXISTS uq_clientes_cpf_cnpj_ie ON clientes (cpf_cnpj, coalesce(ie, ''));

-- Fornecedores
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS ie VARCHAR(20);
ALTER TABLE fornecedores DROP CONSTRAINT IF EXISTS fornecedores_cnpj_key;
CREATE INDEX IF NOT EXISTS ix_fornecedores_cnpj ON fornecedores (cnpj);
CREATE UNIQUE INDEX IF NOT EXISTS uq_fornecedores_cnpj_ie ON fornecedores (cnpj, coalesce(ie, ''));

COMMIT;
