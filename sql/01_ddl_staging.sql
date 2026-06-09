/*======================================================================
  01_ddl_staging.sql
  Área de Staging (landing zone).
  - stg.EventosRaw : espelha exatamente o CSV do Kaggle
      ("eCommerce behavior data from multi category store").
  - stg.EventosClean : dados já tipados/limpos pela transformação.
  Idempotente: pode ser executado várias vezes.
======================================================================*/
USE EcommerceDW;
GO

/*---------------------------------------------------------------------
  RAW: todas as colunas como texto para tolerar sujeira do arquivo
  bruto (datas em string, nulos, aspas). Colunas do dataset Kaggle:
  event_time, event_type, product_id, category_id, category_code,
  brand, price, user_id, user_session
---------------------------------------------------------------------*/
DROP TABLE IF EXISTS stg.EventosRaw;
GO
CREATE TABLE stg.EventosRaw
(
    event_time     NVARCHAR(40)   NULL,
    event_type     NVARCHAR(20)   NULL,
    product_id     NVARCHAR(30)   NULL,
    category_id    NVARCHAR(30)   NULL,
    category_code  NVARCHAR(200)  NULL,
    brand          NVARCHAR(100)  NULL,
    price          NVARCHAR(30)   NULL,
    user_id        NVARCHAR(30)   NULL,
    user_session   NVARCHAR(80)   NULL
);
GO

/*---------------------------------------------------------------------
  CLEAN: dados tipados e enriquecidos (resultado de sp_TransformEventos).
  Atributos inferidos (dispositivo/origem/geografia) são derivados de
  forma determinística a partir do user_session na transformação.
---------------------------------------------------------------------*/
DROP TABLE IF EXISTS stg.EventosClean;
GO
CREATE TABLE stg.EventosClean
(
    EventoBK        BIGINT IDENTITY(1,1) PRIMARY KEY, -- chave de negócio da linha de evento
    EventTime       DATETIME2(0)   NOT NULL,
    EventType       VARCHAR(20)    NOT NULL,
    ProductID       BIGINT         NOT NULL,
    CategoryID      BIGINT         NULL,
    CategoryCode    VARCHAR(200)   NULL,
    CategoriaNome   VARCHAR(100)   NOT NULL,   -- 1º nível do category_code
    SubcategoriaNome VARCHAR(100)  NOT NULL,   -- 2º+ nível do category_code
    Marca           VARCHAR(100)   NOT NULL,   -- 'UNKNOWN' quando nulo
    Preco           DECIMAL(12,2)  NOT NULL,
    UserID          BIGINT         NOT NULL,
    UserSession     VARCHAR(80)    NOT NULL,
    DataEvento      DATE           NOT NULL,
    HoraDoDia       TINYINT        NOT NULL,
    -- atributos inferidos
    Dispositivo     VARCHAR(20)    NOT NULL,
    OrigemTrafego   VARCHAR(20)    NOT NULL,
    GeoPais         VARCHAR(40)    NOT NULL,
    GeoRegiao       VARCHAR(40)    NOT NULL
);
GO

CREATE INDEX IX_EventosClean_Session ON stg.EventosClean(UserSession, EventTime);
CREATE INDEX IX_EventosClean_Tipo    ON stg.EventosClean(EventType);
GO

PRINT '>> 01_ddl_staging.sql concluído.';
GO
