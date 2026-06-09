/*======================================================================
  12_run_pipeline.sql
  Executa o pipeline de ETL completo (modo amostra sintética) e valida
  a carga. Para usar o CSV real do Kaggle, troque a 1ª chamada por:
      EXEC dbo.sp_ExtractKaggleData @CaminhoArquivo = N'/data/2019-Oct.csv';
======================================================================*/
USE EcommerceDW;
SET NOCOUNT ON;
GO

PRINT '==================================================================';
PRINT ' INICIANDO PIPELINE DE ETL';
PRINT '==================================================================';
GO

DECLARE @t0 DATETIME2 = SYSDATETIME();

EXEC dbo.sp_ExtractKaggleData;     -- E (amostra sintética: ~590k eventos)
EXEC dbo.sp_TransformEventos;      -- T
EXEC dbo.sp_LoadFatoNavegacao;     -- L

PRINT CONCAT(' Pipeline executado em ', DATEDIFF(SECOND,@t0,SYSDATETIME()), ' segundos.');
GO

PRINT '';
PRINT '=== CONTAGEM DE REGISTROS POR TABELA ===';
SELECT 'stg.EventosRaw'            AS Tabela, COUNT_BIG(*) AS Linhas FROM stg.EventosRaw
UNION ALL SELECT 'stg.EventosClean',          COUNT_BIG(*) FROM stg.EventosClean
UNION ALL SELECT 'fato.Fato_EventosNavegacao',COUNT_BIG(*) FROM fato.Fato_EventosNavegacao
UNION ALL SELECT 'fato.Fato_Pedido',          COUNT_BIG(*) FROM fato.Fato_Pedido
UNION ALL SELECT 'fato.Fato_ItemPedido',      COUNT_BIG(*) FROM fato.Fato_ItemPedido
UNION ALL SELECT 'fato.Fato_AbandonoCarrinho',COUNT_BIG(*) FROM fato.Fato_AbandonoCarrinho
UNION ALL SELECT 'fato.Fato_Pagamento',       COUNT_BIG(*) FROM fato.Fato_Pagamento
UNION ALL SELECT 'dim.Dim_Produto',           COUNT_BIG(*) FROM dim.Dim_Produto
UNION ALL SELECT 'dim.Dim_Usuario',           COUNT_BIG(*) FROM dim.Dim_Usuario
ORDER BY Linhas DESC;
GO

PRINT '';
PRINT '=== REQUISITO: Fato principal > 500.000 linhas ===';
SELECT COUNT_BIG(*) AS LinhasFatoPrincipal,
       CASE WHEN COUNT_BIG(*) > 500000 THEN 'OK (> 500k)' ELSE 'ABAIXO DO MINIMO' END AS Status
FROM fato.Fato_EventosNavegacao;
GO

PRINT '';
PRINT '=== PERGUNTA 1: Funil de conversão por categoria ===';
EXEC dbo.sp_AnaliseFunilConversao;
GO

PRINT '';
PRINT '=== PERGUNTA 2: Top horários de abandono de carrinho ===';
EXEC dbo.sp_AnaliseAbandonoHorario @TopN = 10;
GO

PRINT '';
PRINT '=== PERGUNTA 3: Receita x Visualizações por marca (Top 10) ===';
SELECT TOP (10) * FROM dbo.vw_ReceitaPorMarca ORDER BY ReceitaTotal DESC;
GO

PRINT '';
PRINT '=== Função fn_CalcularSessaoMinutos (amostra de 5 sessões que converteram) ===';
SELECT TOP (5) p.UserSession,
       dbo.fn_CalcularSessaoMinutos(p.UserSession) AS MinutosAteCompra
FROM fato.Fato_Pedido p;
GO

PRINT '';
PRINT '=== Monitoramento do ETL (auditoria) ===';
SELECT TOP (15) NomeProcesso, Etapa, DuracaoSegundos, LinhasAfetadas, Status, Mensagem
FROM dbo.vw_MonitoramentoCarga
ORDER BY AuditSK DESC;
GO

PRINT '==================================================================';
PRINT ' PIPELINE + VALIDACAO CONCLUIDOS';
PRINT '==================================================================';
GO
