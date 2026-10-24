-- Versão 1.2.0: unidade de medida do produto (UN, KG, L, CX...).
-- Produtos já cadastrados recebem 'UN'. Idempotente.
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS unidade VARCHAR(10) NOT NULL DEFAULT 'UN';
