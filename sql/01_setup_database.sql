-- ============================================================
-- 01_SETUP_DATABASE.sql
-- Cria o banco de dados e os 3 schemas do ETL (RAW, STAGING, MART)
-- ============================================================

-- Cria o banco
CREATE DATABASE ecommerce_etl;
GO

USE ecommerce_etl;
GO

-- Cria os 3 schemas (camadas do ETL)
CREATE SCHEMA raw;      -- dados brutos
GO
CREATE SCHEMA staging;  -- dados limpos
GO
CREATE SCHEMA mart;     -- dados prontos para análise
GO

PRINT 'Banco e schemas criados com sucesso!';
