/*======================================================================
  13_demo_triggers_seguranca.sql
  Demonstração dos Triggers (DTL) e do controle de acesso (DCL).
  Executar depois do pipeline (12_run_pipeline.sql).
======================================================================*/
USE EcommerceDW;
SET NOCOUNT ON;
GO

PRINT '=== TRIGGER trg_AtualizacaoPreco: alterando preço de 1 produto ===';
DECLARE @prod INT = (SELECT MIN(ProdutoSK) FROM dim.Dim_Produto);
UPDATE dim.Dim_Produto SET PrecoAtual = PrecoAtual + 10.00 WHERE ProdutoSK = @prod;

SELECT TOP (5) * FROM dim.Hist_PrecoProduto ORDER BY HistSK DESC;
GO

PRINT '';
PRINT '=== TRIGGER trg_AuditoriaPedidos: registrando um UPDATE em Fato_Pedido ===';
-- UPDATE inócuo (ValorTotal recebe o próprio valor): não altera o dado,
-- mas dispara o trigger, que grava o registro de auditoria. Em autocommit
-- o log PERSISTE (um ROLLBACK desfaria também o INSERT feito pelo trigger,
-- pois o SQL Server não possui transações autônomas).
UPDATE TOP (3) fato.Fato_Pedido SET ValorTotal = ValorTotal;

SELECT TOP (3) NomeProcesso, Etapa, LinhasAfetadas, Mensagem
FROM fato.Audit_CargaETL
WHERE NomeProcesso = 'trg_AuditoriaPedidos'
ORDER BY AuditSK DESC;
GO

PRINT '';
PRINT '=== DCL: Analista_BI consegue ler a View (esperado: SUCESSO) ===';
EXECUTE AS USER = 'usr_bi';
    SELECT TOP (3) MarcaNome, ReceitaTotal FROM dbo.vw_ReceitaPorMarca ORDER BY ReceitaTotal DESC;
REVERT;
GO

PRINT '';
PRINT '=== DCL: Analista_BI tenta ler tabela transacional (esperado: ERRO de permissão) ===';
EXECUTE AS USER = 'usr_bi';
    BEGIN TRY
        SELECT TOP (1) * FROM fato.Fato_Pedido;
        PRINT 'FALHA DE SEGURANCA: o acesso deveria ter sido negado!';
    END TRY
    BEGIN CATCH
        PRINT CONCAT('OK - acesso negado conforme esperado: ', ERROR_MESSAGE());
    END CATCH
REVERT;
GO

PRINT '=== Demonstração de triggers e segurança concluída. ===';
GO
