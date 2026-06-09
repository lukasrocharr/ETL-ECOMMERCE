/*======================================================================
  02_ddl_dimensions.sql
  14 Tabelas de Dimensão (modelo estrela/floco-de-neve).
  Convenções:
    *SK  = Surrogate Key (IDENTITY) -> chave primária da dimensão
    *BK  = Business/Natural Key      -> chave de origem (UNIQUE)
  Todas as tabelas usam DROP IF EXISTS para idempotência.
  A ordem de DROP respeita as FKs (dependentes primeiro).
======================================================================*/
USE EcommerceDW;
GO

----------------------------------------------------------------------
-- DROP em ordem reversa de dependência (caso já existam)
----------------------------------------------------------------------
DROP TABLE IF EXISTS dim.Dim_Produto;       -- depende de Categoria/Subcategoria/Marca/FaixaPreco
DROP TABLE IF EXISTS dim.Dim_Subcategoria;  -- depende de Categoria
DROP TABLE IF EXISTS dim.Dim_Categoria;
DROP TABLE IF EXISTS dim.Dim_Marca;
DROP TABLE IF EXISTS dim.Dim_FaixaPreco;
DROP TABLE IF EXISTS dim.Dim_Usuario;
DROP TABLE IF EXISTS dim.Dim_Tempo;
DROP TABLE IF EXISTS dim.Dim_TipoEvento;
DROP TABLE IF EXISTS dim.Dim_OrigemTrafego;
DROP TABLE IF EXISTS dim.Dim_Geografia;
DROP TABLE IF EXISTS dim.Dim_MetodoPagamento;
DROP TABLE IF EXISTS dim.Dim_StatusTransacao;
DROP TABLE IF EXISTS dim.Dim_Dispositivo;
DROP TABLE IF EXISTS dim.Dim_CampanhaPromo;
GO

----------------------------------------------------------------------
-- 1) Dim_Categoria
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Categoria
(
    CategoriaSK   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Categoria PRIMARY KEY,
    CategoriaNome VARCHAR(100) NOT NULL CONSTRAINT UQ_Dim_Categoria UNIQUE,
    DataCarga     DATETIME2(0) NOT NULL CONSTRAINT DF_Categoria_DataCarga DEFAULT (SYSDATETIME())
);
GO

----------------------------------------------------------------------
-- 2) Dim_Subcategoria (floco-de-neve a partir de Categoria)
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Subcategoria
(
    SubcategoriaSK   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Subcategoria PRIMARY KEY,
    CategoriaSK      INT NOT NULL,
    SubcategoriaNome VARCHAR(100) NOT NULL,
    DataCarga        DATETIME2(0) NOT NULL CONSTRAINT DF_Subcat_DataCarga DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Subcat_Categoria FOREIGN KEY (CategoriaSK) REFERENCES dim.Dim_Categoria(CategoriaSK),
    CONSTRAINT UQ_Dim_Subcategoria UNIQUE (CategoriaSK, SubcategoriaNome)
);
GO

----------------------------------------------------------------------
-- 3) Dim_Marca
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Marca
(
    MarcaSK   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Marca PRIMARY KEY,
    MarcaNome VARCHAR(100) NOT NULL CONSTRAINT UQ_Dim_Marca UNIQUE,
    DataCarga DATETIME2(0) NOT NULL CONSTRAINT DF_Marca_DataCarga DEFAULT (SYSDATETIME())
);
GO

----------------------------------------------------------------------
-- 4) Dim_FaixaPreco (faixas de ticket para clusterização)
----------------------------------------------------------------------
CREATE TABLE dim.Dim_FaixaPreco
(
    FaixaPrecoSK  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_FaixaPreco PRIMARY KEY,
    FaixaNome     VARCHAR(20)   NOT NULL CONSTRAINT UQ_Dim_FaixaPreco UNIQUE,
    ValorMinimo   DECIMAL(12,2) NOT NULL,
    ValorMaximo   DECIMAL(12,2) NOT NULL,
    CONSTRAINT CK_FaixaPreco_Intervalo CHECK (ValorMaximo > ValorMinimo)
);
GO

----------------------------------------------------------------------
-- 5) Dim_Produto (depende de Categoria, Subcategoria, Marca, FaixaPreco)
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Produto
(
    ProdutoSK     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Produto PRIMARY KEY,
    ProductID     BIGINT NOT NULL CONSTRAINT UQ_Dim_Produto UNIQUE,  -- chave natural Kaggle
    CategoriaSK   INT NULL,
    SubcategoriaSK INT NULL,
    MarcaSK       INT NOT NULL,
    FaixaPrecoSK  INT NOT NULL,
    PrecoAtual    DECIMAL(12,2) NOT NULL CONSTRAINT CK_Produto_Preco CHECK (PrecoAtual >= 0),
    DataCarga     DATETIME2(0) NOT NULL CONSTRAINT DF_Produto_DataCarga DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Produto_Categoria    FOREIGN KEY (CategoriaSK)    REFERENCES dim.Dim_Categoria(CategoriaSK),
    CONSTRAINT FK_Produto_Subcategoria FOREIGN KEY (SubcategoriaSK) REFERENCES dim.Dim_Subcategoria(SubcategoriaSK),
    CONSTRAINT FK_Produto_Marca        FOREIGN KEY (MarcaSK)        REFERENCES dim.Dim_Marca(MarcaSK),
    CONSTRAINT FK_Produto_FaixaPreco   FOREIGN KEY (FaixaPrecoSK)   REFERENCES dim.Dim_FaixaPreco(FaixaPrecoSK)
);
GO

----------------------------------------------------------------------
-- 6) Dim_Usuario
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Usuario
(
    UsuarioSK      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Usuario PRIMARY KEY,
    UserID         BIGINT NOT NULL CONSTRAINT UQ_Dim_Usuario UNIQUE,
    PrimeiroEvento DATETIME2(0) NULL,
    UltimoEvento   DATETIME2(0) NULL,
    DataCarga      DATETIME2(0) NOT NULL CONSTRAINT DF_Usuario_DataCarga DEFAULT (SYSDATETIME())
);
GO

----------------------------------------------------------------------
-- 7) Dim_Tempo (calendário, grão = dia). HoraDoDia fica na fato.
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Tempo
(
    TempoSK     INT NOT NULL CONSTRAINT PK_Dim_Tempo PRIMARY KEY, -- formato AAAAMMDD
    DataCompleta DATE NOT NULL CONSTRAINT UQ_Dim_Tempo UNIQUE,
    Ano         SMALLINT NOT NULL,
    Mes         TINYINT  NOT NULL,
    NomeMes     VARCHAR(15) NOT NULL,
    Dia         TINYINT  NOT NULL,
    Trimestre   TINYINT  NOT NULL,
    DiaSemana   TINYINT  NOT NULL,      -- 1=domingo ... 7=sábado
    NomeDiaSemana VARCHAR(15) NOT NULL,
    EhDiaUtil   BIT NOT NULL,
    EhFimDeSemana BIT NOT NULL
);
GO

----------------------------------------------------------------------
-- 8) Dim_TipoEvento (dicionário: view/cart/purchase)
----------------------------------------------------------------------
CREATE TABLE dim.Dim_TipoEvento
(
    TipoEventoSK   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_TipoEvento PRIMARY KEY,
    EventTypeCodigo VARCHAR(20) NOT NULL CONSTRAINT UQ_Dim_TipoEvento UNIQUE,
    Descricao      VARCHAR(50) NOT NULL,
    OrdemFunil     TINYINT NOT NULL  -- 1=view, 2=cart, 3=purchase
);
GO

----------------------------------------------------------------------
-- 9) Dim_OrigemTrafego
----------------------------------------------------------------------
CREATE TABLE dim.Dim_OrigemTrafego
(
    OrigemTrafegoSK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_OrigemTrafego PRIMARY KEY,
    Canal           VARCHAR(20) NOT NULL CONSTRAINT UQ_Dim_OrigemTrafego UNIQUE,
    Descricao       VARCHAR(60) NOT NULL
);
GO

----------------------------------------------------------------------
-- 10) Dim_Geografia
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Geografia
(
    GeografiaSK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Geografia PRIMARY KEY,
    Pais        VARCHAR(40) NOT NULL,
    Regiao      VARCHAR(40) NOT NULL,
    CONSTRAINT UQ_Dim_Geografia UNIQUE (Pais, Regiao)
);
GO

----------------------------------------------------------------------
-- 11) Dim_MetodoPagamento
----------------------------------------------------------------------
CREATE TABLE dim.Dim_MetodoPagamento
(
    MetodoPagamentoSK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_MetodoPagamento PRIMARY KEY,
    Metodo            VARCHAR(30) NOT NULL CONSTRAINT UQ_Dim_MetodoPagamento UNIQUE,
    PermiteParcelamento BIT NOT NULL
);
GO

----------------------------------------------------------------------
-- 12) Dim_StatusTransacao
----------------------------------------------------------------------
CREATE TABLE dim.Dim_StatusTransacao
(
    StatusTransacaoSK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_StatusTransacao PRIMARY KEY,
    Status            VARCHAR(20) NOT NULL CONSTRAINT UQ_Dim_StatusTransacao UNIQUE,
    EhConcluido       BIT NOT NULL
);
GO

----------------------------------------------------------------------
-- 13) Dim_Dispositivo
----------------------------------------------------------------------
CREATE TABLE dim.Dim_Dispositivo
(
    DispositivoSK INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Dispositivo PRIMARY KEY,
    Plataforma    VARCHAR(20) NOT NULL CONSTRAINT UQ_Dim_Dispositivo UNIQUE
);
GO

----------------------------------------------------------------------
-- 14) Dim_CampanhaPromo (datas festivas / ações de marketing)
----------------------------------------------------------------------
CREATE TABLE dim.Dim_CampanhaPromo
(
    CampanhaSK   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_CampanhaPromo PRIMARY KEY,
    NomeCampanha VARCHAR(60) NOT NULL CONSTRAINT UQ_Dim_CampanhaPromo UNIQUE,
    DataInicio   DATE NOT NULL,
    DataFim      DATE NOT NULL,
    CONSTRAINT CK_Campanha_Periodo CHECK (DataFim >= DataInicio)
);
GO

PRINT '>> 02_ddl_dimensions.sql concluído (14 dimensões).';
GO
