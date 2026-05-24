-- ============================================================
-- 06_IMPORT_REVIEWS_LIMPO.sql
-- Importa o CSV de reviews tratado pelo script Python
--
-- IMPORTANTE: Antes de rodar este script:
-- 1. Execute o script Python: python3 scripts/limpar_reviews.py
-- 2. Copie o arquivo gerado para o container:
--    docker cp data/reviews_limpo.csv sqlserver-etl:/var/opt/mssql/dados/
--    docker exec -u root sqlserver-etl chown mssql:mssql /var/opt/mssql/dados/reviews_limpo.csv
-- ============================================================

USE ecommerce_etl;
GO

-- Recria a tabela
IF OBJECT_ID('raw.reviews_limpo', 'U') IS NOT NULL 
    DROP TABLE raw.reviews_limpo;

CREATE TABLE raw.reviews_limpo (
    review_id NVARCHAR(100),
    order_id NVARCHAR(100),
    review_score INT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

-- Importa
BULK INSERT raw.reviews_limpo
FROM '/var/opt/mssql/dados/reviews_limpo.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    MAXERRORS = 1000,
    TABLOCK
);

PRINT 'Reviews importados!';
SELECT COUNT(*) AS total_reviews FROM raw.reviews_limpo;
-- RESULTADO ESPERADO: 99.224 reviews
