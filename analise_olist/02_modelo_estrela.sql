/*======================================================================
  02_modelo_estrela.sql  —  Modelo dimensional (estrela) do Olist
  Total do modelo = 20 tabelas:
     8 staging (raw_*)  +  8 dimensões  +  4 fatos
  As dimensões/fatos são derivadas das tabelas brutas (raw_*) carregadas
  em 00_setup_e_carga.sql. Idempotente (DROP IF EXISTS + CREATE).
======================================================================*/
USE OlistDW;
GO
SET NOCOUNT ON;
GO

-- DROP em ordem de dependência (fatos -> dimensões)
DROP TABLE IF EXISTS fato_avaliacao;
DROP TABLE IF EXISTS fato_pagamento;
DROP TABLE IF EXISTS fato_item_pedido;
DROP TABLE IF EXISTS fato_pedido;
DROP TABLE IF EXISTS dim_avaliacao;
DROP TABLE IF EXISTS dim_forma_pagamento;
DROP TABLE IF EXISTS dim_status_pedido;
DROP TABLE IF EXISTS dim_vendedor;
DROP TABLE IF EXISTS dim_produto;
DROP TABLE IF EXISTS dim_categoria;
DROP TABLE IF EXISTS dim_cliente;
DROP TABLE IF EXISTS dim_tempo;
GO

----------------------------- DIMENSÕES (8) ---------------------------
CREATE TABLE dim_tempo (
    TempoSK      INT          NOT NULL CONSTRAINT PK_dim_tempo PRIMARY KEY, -- AAAAMMDD
    data         DATE         NOT NULL CONSTRAINT UQ_dim_tempo UNIQUE,
    ano          SMALLINT     NOT NULL,
    mes          TINYINT      NOT NULL,
    nome_mes     VARCHAR(15)  NOT NULL,
    dia          TINYINT      NOT NULL,
    trimestre    TINYINT      NOT NULL,
    nome_dia     VARCHAR(15)  NOT NULL,
    eh_fim_semana BIT         NOT NULL);

CREATE TABLE dim_cliente (
    ClienteSK    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_cliente PRIMARY KEY,
    customer_unique_id NVARCHAR(40) NOT NULL CONSTRAINT UQ_dim_cliente UNIQUE,
    cidade       NVARCHAR(60) NULL,
    uf           NVARCHAR(5)  NULL);

CREATE TABLE dim_categoria (
    CategoriaSK  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_categoria PRIMARY KEY,
    categoria_pt NVARCHAR(100) NOT NULL CONSTRAINT UQ_dim_categoria UNIQUE,
    categoria_en NVARCHAR(100) NULL);

CREATE TABLE dim_produto (
    ProdutoSK    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_produto PRIMARY KEY,
    product_id   NVARCHAR(40) NOT NULL CONSTRAINT UQ_dim_produto UNIQUE,
    CategoriaSK  INT NULL,
    peso_g       INT NULL,
    CONSTRAINT FK_produto_categoria FOREIGN KEY (CategoriaSK) REFERENCES dim_categoria(CategoriaSK));

CREATE TABLE dim_vendedor (
    VendedorSK   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_vendedor PRIMARY KEY,
    seller_id    NVARCHAR(40) NOT NULL CONSTRAINT UQ_dim_vendedor UNIQUE,
    cidade       NVARCHAR(60) NULL,
    uf           NVARCHAR(5)  NULL);

CREATE TABLE dim_status_pedido (
    StatusSK     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_status PRIMARY KEY,
    status       NVARCHAR(20) NOT NULL CONSTRAINT UQ_dim_status UNIQUE,
    eh_concluido BIT NOT NULL);

CREATE TABLE dim_forma_pagamento (
    FormaPagtoSK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_formapagto PRIMARY KEY,
    forma        NVARCHAR(30) NOT NULL CONSTRAINT UQ_dim_formapagto UNIQUE);

CREATE TABLE dim_avaliacao (
    AvaliacaoSK  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_avaliacao PRIMARY KEY,
    nota         TINYINT NOT NULL CONSTRAINT UQ_dim_avaliacao UNIQUE,
    faixa        VARCHAR(15) NOT NULL,
    CONSTRAINT CK_dim_avaliacao CHECK (nota BETWEEN 1 AND 5));
GO

------------------------------- FATOS (4) -----------------------------
CREATE TABLE fato_pedido (
    PedidoSK     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_fato_pedido PRIMARY KEY,
    order_id     NVARCHAR(40) NOT NULL CONSTRAINT UQ_fato_pedido UNIQUE,
    ClienteSK    INT NULL,
    StatusSK     INT NULL,
    TempoCompraSK INT NULL,
    data_compra  DATETIME2(0) NULL,
    data_entrega DATETIME2(0) NULL,
    dias_entrega INT NULL,
    dias_vs_estimativa INT NULL,
    entregue_no_prazo BIT NULL,
    qtd_itens    INT NULL,
    valor_itens  DECIMAL(12,2) NULL,
    valor_frete  DECIMAL(12,2) NULL,
    CONSTRAINT FK_pedido_cliente FOREIGN KEY (ClienteSK)     REFERENCES dim_cliente(ClienteSK),
    CONSTRAINT FK_pedido_status  FOREIGN KEY (StatusSK)      REFERENCES dim_status_pedido(StatusSK),
    CONSTRAINT FK_pedido_tempo   FOREIGN KEY (TempoCompraSK) REFERENCES dim_tempo(TempoSK));

CREATE TABLE fato_item_pedido (
    ItemSK       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_fato_item PRIMARY KEY,
    order_id     NVARCHAR(40) NOT NULL,
    PedidoSK     INT NULL,
    ProdutoSK    INT NULL,
    VendedorSK   INT NULL,
    ClienteSK    INT NULL,
    CategoriaSK  INT NULL,
    TempoSK      INT NULL,
    price        DECIMAL(12,2) NULL,
    freight_value DECIMAL(12,2) NULL,
    CONSTRAINT FK_item_pedido    FOREIGN KEY (PedidoSK)    REFERENCES fato_pedido(PedidoSK),
    CONSTRAINT FK_item_produto   FOREIGN KEY (ProdutoSK)   REFERENCES dim_produto(ProdutoSK),
    CONSTRAINT FK_item_vendedor  FOREIGN KEY (VendedorSK)  REFERENCES dim_vendedor(VendedorSK),
    CONSTRAINT FK_item_cliente   FOREIGN KEY (ClienteSK)   REFERENCES dim_cliente(ClienteSK),
    CONSTRAINT FK_item_categoria FOREIGN KEY (CategoriaSK) REFERENCES dim_categoria(CategoriaSK),
    CONSTRAINT FK_item_tempo     FOREIGN KEY (TempoSK)     REFERENCES dim_tempo(TempoSK));

CREATE TABLE fato_pagamento (
    PagtoSK      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_fato_pagto PRIMARY KEY,
    order_id     NVARCHAR(40) NOT NULL,
    PedidoSK     INT NULL,
    FormaPagtoSK INT NULL,
    ClienteSK    INT NULL,
    TempoSK      INT NULL,
    parcelas     INT NULL,
    valor        DECIMAL(12,2) NULL,
    CONSTRAINT FK_pagto_pedido FOREIGN KEY (PedidoSK)     REFERENCES fato_pedido(PedidoSK),
    CONSTRAINT FK_pagto_forma  FOREIGN KEY (FormaPagtoSK) REFERENCES dim_forma_pagamento(FormaPagtoSK),
    CONSTRAINT FK_pagto_cliente FOREIGN KEY (ClienteSK)   REFERENCES dim_cliente(ClienteSK),
    CONSTRAINT FK_pagto_tempo  FOREIGN KEY (TempoSK)      REFERENCES dim_tempo(TempoSK));

CREATE TABLE fato_avaliacao (
    AvalSK       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_fato_aval PRIMARY KEY,
    review_id    NVARCHAR(40) NULL,
    order_id     NVARCHAR(40) NOT NULL,
    PedidoSK     INT NULL,
    ClienteSK    INT NULL,
    AvaliacaoSK  INT NULL,
    TempoSK      INT NULL,
    nota         TINYINT NULL,
    CONSTRAINT FK_aval_pedido FOREIGN KEY (PedidoSK)    REFERENCES fato_pedido(PedidoSK),
    CONSTRAINT FK_aval_cliente FOREIGN KEY (ClienteSK)  REFERENCES dim_cliente(ClienteSK),
    CONSTRAINT FK_aval_dim    FOREIGN KEY (AvaliacaoSK) REFERENCES dim_avaliacao(AvaliacaoSK),
    CONSTRAINT FK_aval_tempo  FOREIGN KEY (TempoSK)     REFERENCES dim_tempo(TempoSK));
GO

PRINT '>> 02_modelo_estrela.sql: 8 dimensoes + 4 fatos criadas (modelo de 20 tabelas).';
GO
