/*======================================================================
  11_dcl_security.sql
  Governança e Segurança (DCL) - princípio do menor privilégio.
  3 Roles obrigatórias:
    - DBA_Admin    : controle total (DDL/DCL).
    - Eng_Dados    : EXECUTE nas SP de ETL + DML nas staging.
    - Analista_BI  : SELECT apenas nas Views + EXECUTE nas SP analíticas.
                     NÃO enxerga as tabelas transacionais de origem.
  Idempotente. Cria usuários de exemplo (sem login) para teste com
  EXECUTE AS USER.
======================================================================*/
USE EcommerceDW;
GO

----------------------------------------------------------------------
-- Roles
----------------------------------------------------------------------
IF DATABASE_PRINCIPAL_ID('DBA_Admin')   IS NULL CREATE ROLE DBA_Admin;
IF DATABASE_PRINCIPAL_ID('Eng_Dados')   IS NULL CREATE ROLE Eng_Dados;
IF DATABASE_PRINCIPAL_ID('Analista_BI') IS NULL CREATE ROLE Analista_BI;
GO

----------------------------------------------------------------------
-- DBA_Admin : controle total no banco.
----------------------------------------------------------------------
ALTER ROLE db_owner ADD MEMBER DBA_Admin;
GO

----------------------------------------------------------------------
-- Eng_Dados : opera o pipeline de ETL.
--   - EXECUTE nas procedures de ETL
--   - DML (INSERT/UPDATE/DELETE/SELECT) nas tabelas de staging
--   - SELECT/INSERT no log de auditoria
----------------------------------------------------------------------
GRANT EXECUTE ON dbo.sp_GenerateSyntheticData TO Eng_Dados;
GRANT EXECUTE ON dbo.sp_ExtractKaggleData     TO Eng_Dados;
GRANT EXECUTE ON dbo.sp_TransformEventos       TO Eng_Dados;
GRANT EXECUTE ON dbo.sp_LoadFatoNavegacao      TO Eng_Dados;

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::stg TO Eng_Dados;  -- staging
GRANT SELECT, INSERT ON fato.Audit_CargaETL TO Eng_Dados;          -- log
-- Acesso de leitura às dimensões/fatos para validar a carga (sem DROP/ALTER).
GRANT SELECT ON SCHEMA::dim  TO Eng_Dados;
GRANT SELECT ON SCHEMA::fato TO Eng_Dados;
GO

----------------------------------------------------------------------
-- Analista_BI : consumo analítico apenas.
--   - SELECT somente nas Views (camada semântica)
--   - EXECUTE nas SP analíticas
--   - EXECUTE nas Functions de apoio
--   - DENY explícito de leitura nas tabelas transacionais de origem
----------------------------------------------------------------------
GRANT SELECT ON dbo.vw_CatalogoCompleto    TO Analista_BI;
GRANT SELECT ON dbo.vw_ReceitaPorMarca      TO Analista_BI;
GRANT SELECT ON dbo.vw_EngajamentoUsuario   TO Analista_BI;
GRANT SELECT ON dbo.vw_ResumoDiarioEventos  TO Analista_BI;
GRANT SELECT ON dbo.vw_MonitoramentoCarga   TO Analista_BI;

GRANT EXECUTE ON dbo.sp_AnaliseFunilConversao  TO Analista_BI;
GRANT EXECUTE ON dbo.sp_AnaliseAbandonoHorario TO Analista_BI;
GRANT EXECUTE ON dbo.fn_ClassificarTicket      TO Analista_BI;
GRANT EXECUTE ON dbo.fn_CalcularSessaoMinutos  TO Analista_BI;

-- Bloqueia leitura direta das tabelas brutas/transacionais.
DENY SELECT ON SCHEMA::stg  TO Analista_BI;
DENY SELECT ON fato.Fato_Pedido        TO Analista_BI;
DENY SELECT ON fato.Fato_ItemPedido    TO Analista_BI;
DENY SELECT ON fato.Fato_Pagamento     TO Analista_BI;
GO

----------------------------------------------------------------------
-- Usuários de exemplo (sem login) para demonstrar as permissões.
----------------------------------------------------------------------
IF DATABASE_PRINCIPAL_ID('usr_eng') IS NULL
    CREATE USER usr_eng WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_bi') IS NULL
    CREATE USER usr_bi WITHOUT LOGIN;
GO
ALTER ROLE Eng_Dados   ADD MEMBER usr_eng;
ALTER ROLE Analista_BI ADD MEMBER usr_bi;
GO

PRINT '>> 11_dcl_security.sql concluído (3 roles).';
GO
