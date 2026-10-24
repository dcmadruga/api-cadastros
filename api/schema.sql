-- Estrutura das tabelas (opcional: a API cria as tabelas sozinha ao iniciar).
-- Para criar manualmente: psql -U seu_usuario -d seu_banco -f schema.sql

CREATE TABLE public.clientes (
    id integer NOT NULL,
    nome character varying(150) NOT NULL,
    cpf_cnpj character varying(18),
    ie character varying(20),
    email character varying(150),
    telefone character varying(20),
    endereco character varying(255),
    criado_em timestamp without time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp without time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE public.clientes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.clientes_id_seq OWNED BY public.clientes.id;

CREATE TABLE public.fornecedores (
    id integer NOT NULL,
    nome character varying(150) NOT NULL,
    cnpj character varying(18),
    ie character varying(20),
    email character varying(150),
    telefone character varying(20),
    endereco character varying(255),
    criado_em timestamp without time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp without time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE public.fornecedores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.fornecedores_id_seq OWNED BY public.fornecedores.id;

CREATE TABLE public.produtos (
    id integer NOT NULL,
    nome character varying(150) NOT NULL,
    codigo character varying(50),
    descricao text,
    preco numeric(12,2) NOT NULL,
    estoque integer NOT NULL,
    fornecedor_id integer,
    criado_em timestamp without time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_produtos_estoque CHECK ((estoque >= 0)),
    CONSTRAINT ck_produtos_preco CHECK ((preco >= (0)::numeric))
);

CREATE SEQUENCE public.produtos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.produtos_id_seq OWNED BY public.produtos.id;

ALTER TABLE ONLY public.clientes ALTER COLUMN id SET DEFAULT nextval('public.clientes_id_seq'::regclass);

ALTER TABLE ONLY public.fornecedores ALTER COLUMN id SET DEFAULT nextval('public.fornecedores_id_seq'::regclass);

ALTER TABLE ONLY public.produtos ALTER COLUMN id SET DEFAULT nextval('public.produtos_id_seq'::regclass);

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_codigo_key UNIQUE (codigo);

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_pkey PRIMARY KEY (id);

CREATE INDEX ix_clientes_cpf_cnpj ON public.clientes USING btree (cpf_cnpj);

CREATE INDEX ix_clientes_nome ON public.clientes USING btree (nome);

CREATE INDEX ix_fornecedores_cnpj ON public.fornecedores USING btree (cnpj);

CREATE INDEX ix_fornecedores_nome ON public.fornecedores USING btree (nome);

CREATE INDEX ix_produtos_fornecedor_id ON public.produtos USING btree (fornecedor_id);

CREATE INDEX ix_produtos_nome ON public.produtos USING btree (nome);

CREATE UNIQUE INDEX uq_clientes_cpf_cnpj_ie ON public.clientes USING btree (cpf_cnpj, COALESCE(ie, ''::character varying));

CREATE UNIQUE INDEX uq_fornecedores_cnpj_ie ON public.fornecedores USING btree (cnpj, COALESCE(ie, ''::character varying));

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id) ON DELETE RESTRICT;

