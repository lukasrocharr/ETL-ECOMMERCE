-- =====================================================
-- PROJETO: E-COMMERCE | Data Warehouse Olist 2016-2018
-- Banco: Microsoft SQL Server
-- Script: Criacao inicial do banco, schemas e tabelas
-- =====================================================

USE master;
GO

-- Criacao do banco
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'EcommerceOlist')
    CREATE DATABASE EcommerceOlist;
GO

USE EcommerceOlist;
GO

-- =====================================================
-- SCHEMAS
-- =====================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');   -- dados tratados
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg');  -- area de pouso (CSVs brutos)
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctrl')
    EXEC('CREATE SCHEMA ctrl'); -- auditoria e log ETL
GO

-- =====================================================
-- DIMENSOES
-- =====================================================

CREATE TABLE dw.dim_tempo (
    tempo_id      INT          NOT NULL,  -- formato YYYYMMDD
    data_completa DATE         NOT NULL,
    ano           SMALLINT     NOT NULL,
    trimestre     TINYINT      NOT NULL,
    mes           TINYINT      NOT NULL,
    nome_mes      VARCHAR(20)  NOT NULL,
    dia_semana    TINYINT      NOT NULL,
    eh_fim_semana BIT          NOT NULL DEFAULT 0,
    eh_feriado    BIT          NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_tempo PRIMARY KEY (tempo_id)
);
GO

CREATE TABLE dw.dim_clientes (
    cliente_id        VARCHAR(50)  NOT NULL,
    cliente_unique_id VARCHAR(50)  NOT NULL,
    cep_prefixo       VARCHAR(10)  NULL,
    cidade            VARCHAR(100) NULL,
    estado            CHAR(2)      NULL,
    CONSTRAINT PK_dim_clientes PRIMARY KEY (cliente_id)
);
GO

CREATE TABLE dw.dim_vendedores (
    vendedor_id VARCHAR(50)  NOT NULL,
    cep_prefixo VARCHAR(10)  NULL,
    cidade      VARCHAR(100) NULL,
    estado      CHAR(2)      NULL,
    CONSTRAINT PK_dim_vendedores PRIMARY KEY (vendedor_id)
);
GO

CREATE TABLE dw.dim_categorias (
    categoria_id      SMALLINT     NOT NULL IDENTITY(1,1),
    nome_categoria_pt VARCHAR(100) NOT NULL,
    nome_categoria_en VARCHAR(100) NULL,
    CONSTRAINT PK_dim_categorias PRIMARY KEY (categoria_id)
);
GO

CREATE TABLE dw.dim_produtos (
    produto_id        VARCHAR(50)  NOT NULL,
    categoria_id      SMALLINT     NULL,
    nome_categoria_pt VARCHAR(100) NULL,
    peso_gramas       INT          NULL,
    comprimento_cm    DECIMAL(8,2) NULL,
    altura_cm         DECIMAL(8,2) NULL,
    largura_cm        DECIMAL(8,2) NULL,
    CONSTRAINT PK_dim_produtos   PRIMARY KEY (produto_id),
    CONSTRAINT FK_prod_categoria FOREIGN KEY (categoria_id)
        REFERENCES dw.dim_categorias (categoria_id)
);
GO

CREATE TABLE dw.dim_forma_pagamento (
    pagamento_id         TINYINT     NOT NULL IDENTITY(1,1),
    tipo_pagamento       VARCHAR(30) NOT NULL,
    descricao_pt         VARCHAR(50) NULL,
    permite_parcelamento BIT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_forma_pagamento PRIMARY KEY (pagamento_id)
);
GO

CREATE TABLE dw.dim_status_pedido (
    status_id       TINYINT     NOT NULL IDENTITY(1,1),
    codigo_status   VARCHAR(30) NOT NULL,
    descricao_pt    VARCHAR(60) NULL,
    eh_status_final BIT         NOT NULL DEFAULT 0,
    eh_cancelamento BIT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_status_pedido PRIMARY KEY (status_id)
);
GO

CREATE TABLE dw.dim_motivo_cancelamento (
    motivo_id     TINYINT      NOT NULL IDENTITY(1,1),
    codigo_motivo VARCHAR(50)  NOT NULL,
    descricao     VARCHAR(100) NULL,
    CONSTRAINT PK_dim_motivo_cancelamento PRIMARY KEY (motivo_id)
);
GO

CREATE TABLE dw.dim_geolocalizacao (
    geo_id      INT            NOT NULL IDENTITY(1,1),
    cep_prefixo VARCHAR(10)    NOT NULL,
    latitude    DECIMAL(10,6)  NULL,
    longitude   DECIMAL(10,6)  NULL,
    cidade      VARCHAR(100)   NULL,
    estado      CHAR(2)        NULL,
    regiao      VARCHAR(20)    NULL,
    CONSTRAINT PK_dim_geolocalizacao PRIMARY KEY (geo_id)
);
GO

CREATE TABLE dw.dim_meios_pagamento_bcb (
    bcb_id              INT           NOT NULL IDENTITY(1,1),
    ano_referencia      SMALLINT      NOT NULL,
    mes_referencia      TINYINT       NOT NULL,
    meio_pagamento      VARCHAR(50)   NOT NULL,
    qtd_transacoes      BIGINT        NULL,
    valor_total_bilhoes DECIMAL(18,4) NULL,
    participacao_pct    DECIMAL(5,2)  NULL,
    CONSTRAINT PK_dim_bcb PRIMARY KEY (bcb_id)
);
GO

-- =====================================================
-- FATOS
-- =====================================================

CREATE TABLE dw.fato_pedidos (
    fato_id          BIGINT        NOT NULL IDENTITY(1,1),
    order_id         VARCHAR(50)   NOT NULL,
    order_item_seq   TINYINT       NOT NULL DEFAULT 1,
    cliente_id       VARCHAR(50)   NULL,
    vendedor_id      VARCHAR(50)   NULL,
    produto_id       VARCHAR(50)   NULL,
    pagamento_id     TINYINT       NULL,
    status_id        TINYINT       NULL,
    tempo_compra_id  INT           NULL,
    tempo_entrega_id INT           NULL,
    motivo_cancel_id TINYINT       NULL,
    vlr_produto      DECIMAL(10,2) NULL,
    vlr_frete        DECIMAL(10,2) NULL,
    vlr_total        DECIMAL(10,2) NULL,
    dias_para_entrega INT          NULL,
    atraso_dias      INT           NULL,
    fl_cancelado     BIT           NOT NULL DEFAULT 0,
    fl_entregue      BIT           NOT NULL DEFAULT 0,
    fl_atraso        BIT           NOT NULL DEFAULT 0,
    fl_avaliado      BIT           NOT NULL DEFAULT 0,
    dt_carga         DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_fato_pedidos     PRIMARY KEY (fato_id),
    CONSTRAINT FK_fp_cliente       FOREIGN KEY (cliente_id)       REFERENCES dw.dim_clientes           (cliente_id),
    CONSTRAINT FK_fp_vendedor      FOREIGN KEY (vendedor_id)      REFERENCES dw.dim_vendedores          (vendedor_id),
    CONSTRAINT FK_fp_produto       FOREIGN KEY (produto_id)       REFERENCES dw.dim_produtos            (produto_id),
    CONSTRAINT FK_fp_pagamento     FOREIGN KEY (pagamento_id)     REFERENCES dw.dim_forma_pagamento     (pagamento_id),
    CONSTRAINT FK_fp_status        FOREIGN KEY (status_id)        REFERENCES dw.dim_status_pedido       (status_id),
    CONSTRAINT FK_fp_tempo_compra  FOREIGN KEY (tempo_compra_id)  REFERENCES dw.dim_tempo               (tempo_id),
    CONSTRAINT FK_fp_tempo_entrega FOREIGN KEY (tempo_entrega_id) REFERENCES dw.dim_tempo               (tempo_id),
    CONSTRAINT FK_fp_motivo        FOREIGN KEY (motivo_cancel_id) REFERENCES dw.dim_motivo_cancelamento (motivo_id)
);
GO

CREATE TABLE dw.fato_itens_pedido (
    item_id           BIGINT        NOT NULL IDENTITY(1,1),
    order_id          VARCHAR(50)   NOT NULL,
    order_item_seq    TINYINT       NOT NULL DEFAULT 1,
    produto_id        VARCHAR(50)   NULL,
    vendedor_id       VARCHAR(50)   NULL,
    tempo_compra_id   INT           NULL,
    preco             DECIMAL(10,2) NULL,
    frete_valor       DECIMAL(10,2) NULL,
    data_limite_envio DATE          NULL,
    CONSTRAINT PK_fato_itens   PRIMARY KEY (item_id),
    CONSTRAINT FK_fi_produto   FOREIGN KEY (produto_id)     REFERENCES dw.dim_produtos   (produto_id),
    CONSTRAINT FK_fi_vendedor  FOREIGN KEY (vendedor_id)    REFERENCES dw.dim_vendedores  (vendedor_id),
    CONSTRAINT FK_fi_tempo     FOREIGN KEY (tempo_compra_id) REFERENCES dw.dim_tempo      (tempo_id)
);
GO

CREATE TABLE dw.fato_pagamentos (
    pgto_seq_id   BIGINT        NOT NULL IDENTITY(1,1),
    order_id      VARCHAR(50)   NOT NULL,
    pagamento_seq TINYINT       NOT NULL DEFAULT 1,
    pagamento_id  TINYINT       NULL,
    parcelas      TINYINT       NULL,
    valor         DECIMAL(10,2) NULL,
    CONSTRAINT PK_fato_pagamentos PRIMARY KEY (pgto_seq_id),
    CONSTRAINT FK_pag_forma       FOREIGN KEY (pagamento_id) REFERENCES dw.dim_forma_pagamento (pagamento_id)
);
GO

CREATE TABLE dw.fato_avaliacoes (
    review_id         VARCHAR(50)  NOT NULL,
    order_id          VARCHAR(50)  NOT NULL,
    nota              TINYINT      NOT NULL CHECK (nota BETWEEN 1 AND 5),
    titulo_review     VARCHAR(100) NULL,
    comentario        VARCHAR(MAX) NULL,
    tempo_compra_id   INT          NULL,
    dt_envio_pesquisa DATETIME     NULL,
    fl_nota_negativa  BIT          NOT NULL DEFAULT 0,
    CONSTRAINT PK_fato_avaliacoes PRIMARY KEY (review_id),
    CONSTRAINT FK_av_tempo        FOREIGN KEY (tempo_compra_id) REFERENCES dw.dim_tempo (tempo_id)
);
GO

-- =====================================================
-- STAGING + CONTROLE
-- =====================================================

CREATE TABLE stg.stg_orders_raw (
    stg_id               BIGINT       NOT NULL IDENTITY(1,1),
    order_id             VARCHAR(100) NULL,
    customer_id          VARCHAR(100) NULL,
    order_status         VARCHAR(50)  NULL,
    order_purchase_ts    VARCHAR(50)  NULL,
    order_approved_at    VARCHAR(50)  NULL,
    order_delivered_ts   VARCHAR(50)  NULL,
    order_estimated_ts   VARCHAR(50)  NULL,
    order_item_id        VARCHAR(20)  NULL,
    product_id           VARCHAR(100) NULL,
    seller_id            VARCHAR(100) NULL,
    price                VARCHAR(20)  NULL,
    freight_value        VARCHAR(20)  NULL,
    shipping_limit_date  VARCHAR(50)  NULL,
    payment_type         VARCHAR(50)  NULL,
    payment_installments VARCHAR(10)  NULL,
    payment_value        VARCHAR(20)  NULL,
    dt_carga             DATETIME     NOT NULL DEFAULT GETDATE(),
    fl_processado        BIT          NOT NULL DEFAULT 0,
    fl_erro              BIT          NOT NULL DEFAULT 0,
    msg_erro             VARCHAR(500) NULL,
    CONSTRAINT PK_stg_orders_raw PRIMARY KEY (stg_id)
);
GO

CREATE TABLE ctrl.log_etl (
    log_id         INT          NOT NULL IDENTITY(1,1),
    tabela_destino VARCHAR(100) NOT NULL,
    sp_executada   VARCHAR(100) NOT NULL,
    dt_inicio      DATETIME     NOT NULL DEFAULT GETDATE(),
    dt_fim         DATETIME     NULL,
    qtd_inseridos  INT          NULL DEFAULT 0,
    usuario        VARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    status         VARCHAR(20)  NOT NULL DEFAULT 'INICIADO',
    mensagem_erro  VARCHAR(MAX) NULL,
    CONSTRAINT PK_log_etl    PRIMARY KEY (log_id),
    CONSTRAINT CK_log_status CHECK (status IN ('INICIADO', 'SUCESSO', 'ERRO'))
);
GO

-- =====================================================
-- DADOS INICIAIS DE DOMINIO
-- =====================================================

INSERT INTO dw.dim_forma_pagamento (tipo_pagamento, descricao_pt, permite_parcelamento) VALUES
    ('credit_card', 'Cartao de Credito', 1),
    ('boleto',      'Boleto Bancario',   0),
    ('voucher',     'Voucher',           0),
    ('debit_card',  'Cartao de Debito',  0),
    ('pix',         'PIX',               0),
    ('not_defined', 'Nao Identificado',  0);
GO

INSERT INTO dw.dim_status_pedido (codigo_status, descricao_pt, eh_status_final, eh_cancelamento) VALUES
    ('delivered',   'Entregue',          1, 0),
    ('canceled',    'Cancelado',         1, 1),
    ('shipped',     'Em Transporte',     0, 0),
    ('processing',  'Em Processamento',  0, 0),
    ('approved',    'Aprovado',          0, 0),
    ('invoiced',    'Faturado',          0, 0),
    ('unavailable', 'Indisponivel',      1, 1),
    ('created',     'Criado',            0, 0);
GO

INSERT INTO dw.dim_motivo_cancelamento (codigo_motivo, descricao) VALUES
    ('sem_pagamento',        'Pagamento nao confirmado dentro do prazo'),
    ('cancelamento_cliente', 'Cancelamento solicitado pelo cliente'),
    ('produto_indisponivel', 'Produto sem estoque ou indisponivel'),
    ('fraude_suspeita',      'Suspeita de fraude identificada'),
    ('endereco_invalido',    'Endereco de entrega invalido'),
    ('outros',               'Outros motivos'),
    ('nao_identificado',     'Motivo nao identificado nos dados');
GO

PRINT 'Setup inicial concluido.';
PRINT 'Tabelas criadas: 16 | Registros de dominio inseridos.';
GO
