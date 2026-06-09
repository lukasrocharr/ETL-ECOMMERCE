/*======================================================================
  00_create_database.sql
  Projeto Final - Engenharia e Análise de Dados com T-SQL
  Tema: E-commerce (Funil de Conversão e Comportamento do Consumidor)

  Cria o banco de dados EcommerceDW de forma idempotente.
  Compatível com SQL Server 2019/2022 (Windows ou contêiner Docker Linux).
======================================================================*/
SET NOCOUNT ON;
GO

IF DB_ID('EcommerceDW') IS NULL
BEGIN
    PRINT '>> Criando banco de dados EcommerceDW...';
    CREATE DATABASE EcommerceDW;
END
ELSE
    PRINT '>> Banco EcommerceDW já existe. Reutilizando.';
GO

ALTER DATABASE EcommerceDW SET RECOVERY SIMPLE;  -- reduz log durante cargas massivas
GO

USE EcommerceDW;
GO

/*---------------------------------------------------------------------
  Schemas lógicos para organização (separação de responsabilidades).
---------------------------------------------------------------------*/
IF SCHEMA_ID('stg')   IS NULL EXEC('CREATE SCHEMA stg');    -- staging / área de pouso
IF SCHEMA_ID('dim')   IS NULL EXEC('CREATE SCHEMA dim');    -- dimensões
IF SCHEMA_ID('fato')  IS NULL EXEC('CREATE SCHEMA fato');   -- fatos
IF SCHEMA_ID('analytics') IS NULL EXEC('CREATE SCHEMA analytics'); -- views/SP analíticas
GO

PRINT '>> 00_create_database.sql concluído.';
GO
