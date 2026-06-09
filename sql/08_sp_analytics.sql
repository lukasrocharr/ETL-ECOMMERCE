/*======================================================================
  08_sp_analytics.sql
  Stored Procedures Analíticas (2 obrigatórias).
  Respondem diretamente às perguntas do Plano de Análise.
======================================================================*/
USE EcommerceDW;
GO

/*---------------------------------------------------------------------
  sp_AnaliseFunilConversao  (Pergunta 1)
  Taxa de conversão Visualização -> Carrinho -> Compra por categoria.
  Parâmetro opcional para filtrar uma categoria específica.
---------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.sp_AnaliseFunilConversao
    @CategoriaNome VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Funil AS (
        SELECT
            cat.CategoriaNome,
            SUM(CASE WHEN te.EventTypeCodigo = 'view'     THEN 1 ELSE 0 END) AS Visualizacoes,
            SUM(CASE WHEN te.EventTypeCodigo = 'cart'     THEN 1 ELSE 0 END) AS Carrinhos,
            SUM(CASE WHEN te.EventTypeCodigo = 'purchase' THEN 1 ELSE 0 END) AS Compras
        FROM fato.Fato_EventosNavegacao e
        JOIN dim.Dim_TipoEvento te ON te.TipoEventoSK = e.TipoEventoSK
        JOIN dim.Dim_Produto p     ON p.ProdutoSK = e.ProdutoSK
        JOIN dim.Dim_Categoria cat ON cat.CategoriaSK = p.CategoriaSK
        WHERE (@CategoriaNome IS NULL OR cat.CategoriaNome = @CategoriaNome)
        GROUP BY cat.CategoriaNome
    )
    SELECT
        CategoriaNome,
        Visualizacoes,
        Carrinhos,
        Compras,
        CAST(100.0 * Carrinhos / NULLIF(Visualizacoes,0) AS DECIMAL(5,2)) AS TaxaView2Cart_Pct,
        CAST(100.0 * Compras   / NULLIF(Carrinhos,0)     AS DECIMAL(5,2)) AS TaxaCart2Buy_Pct,
        CAST(100.0 * Compras   / NULLIF(Visualizacoes,0) AS DECIMAL(5,2)) AS TaxaConversaoTotal_Pct
    FROM Funil
    ORDER BY TaxaConversaoTotal_Pct DESC, Visualizacoes DESC;
END;
GO

/*---------------------------------------------------------------------
  sp_AnaliseAbandonoHorario  (Pergunta 2)
  Horários de pico de abandono de carrinho, cruzando a fato derivada
  com a Dim_Tempo (dia útil x fim de semana).
  @TopN limita os horários de maior abandono retornados.
---------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.sp_AnaliseAbandonoHorario
    @TopN INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Carrinhos AS (
        -- total de carrinhos por hora (para calcular a taxa de abandono)
        SELECT e.HoraDoDia, COUNT(*) AS TotalCarrinhos
        FROM fato.Fato_EventosNavegacao e
        JOIN dim.Dim_TipoEvento te ON te.TipoEventoSK = e.TipoEventoSK
        WHERE te.EventTypeCodigo = 'cart'
        GROUP BY e.HoraDoDia
    ),
    Abandonos AS (
        SELECT
            a.HoraDoDia,
            t.EhFimDeSemana,
            COUNT(*)               AS QtdAbandonos,
            SUM(a.ValorAbandonado) AS ValorAbandonado
        FROM fato.Fato_AbandonoCarrinho a
        JOIN dim.Dim_Tempo t ON t.TempoSK = a.TempoSK
        GROUP BY a.HoraDoDia, t.EhFimDeSemana
    )
    SELECT TOP (@TopN)
        ab.HoraDoDia,
        CASE ab.EhFimDeSemana WHEN 1 THEN 'Fim de semana' ELSE 'Dia útil' END AS TipoDia,
        ab.QtdAbandonos,
        CAST(ab.ValorAbandonado AS DECIMAL(14,2)) AS ValorAbandonado,
        ca.TotalCarrinhos,
        CAST(100.0 * ab.QtdAbandonos / NULLIF(ca.TotalCarrinhos,0) AS DECIMAL(5,2)) AS TaxaAbandono_Pct
    FROM Abandonos ab
    JOIN Carrinhos ca ON ca.HoraDoDia = ab.HoraDoDia
    ORDER BY ab.QtdAbandonos DESC;
END;
GO

PRINT '>> 08_sp_analytics.sql concluído (2 procedures analíticas).';
GO
