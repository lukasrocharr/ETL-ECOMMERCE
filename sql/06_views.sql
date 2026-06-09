/*======================================================================
  06_views.sql
  5 Views exigidas pelo SRS. Camada semântica para o BI e para o
  perfil Analista_BI (que NÃO acessa as tabelas transacionais).
======================================================================*/
USE EcommerceDW;
GO

----------------------------------------------------------------------
-- vw_CatalogoCompleto : visão desnormalizada do catálogo de produtos.
----------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_CatalogoCompleto
AS
SELECT
    p.ProdutoSK,
    p.ProductID,
    c.CategoriaNome,
    sc.SubcategoriaNome,
    m.MarcaNome,
    p.PrecoAtual,
    fp.FaixaNome                          AS FaixaPreco,
    dbo.fn_ClassificarTicket(p.PrecoAtual) AS FaixaCalculada
FROM dim.Dim_Produto p
JOIN dim.Dim_Marca m         ON m.MarcaSK = p.MarcaSK
JOIN dim.Dim_FaixaPreco fp   ON fp.FaixaPrecoSK = p.FaixaPrecoSK
LEFT JOIN dim.Dim_Categoria c    ON c.CategoriaSK = p.CategoriaSK
LEFT JOIN dim.Dim_Subcategoria sc ON sc.SubcategoriaSK = p.SubcategoriaSK;
GO

----------------------------------------------------------------------
-- vw_ReceitaPorMarca : faturamento, ticket médio e visualizações por
-- marca (insumo da pergunta de negócio 3 - marcas vistas x compradas).
----------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_ReceitaPorMarca
AS
WITH Vendas AS (
    SELECT pr.MarcaSK,
           SUM(ip.Subtotal)        AS ReceitaTotal,
           COUNT(DISTINCT ip.PedidoSK) AS QtdPedidos,
           SUM(ip.Quantidade)      AS UnidadesVendidas
    FROM fato.Fato_ItemPedido ip
    JOIN dim.Dim_Produto pr ON pr.ProdutoSK = ip.ProdutoSK
    GROUP BY pr.MarcaSK
),
Visualizacoes AS (
    SELECT pr.MarcaSK,
           COUNT(*) AS TotalVisualizacoes
    FROM fato.Fato_EventosNavegacao e
    JOIN dim.Dim_Produto pr   ON pr.ProdutoSK = e.ProdutoSK
    JOIN dim.Dim_TipoEvento te ON te.TipoEventoSK = e.TipoEventoSK
    WHERE te.EventTypeCodigo = 'view'
    GROUP BY pr.MarcaSK
)
SELECT
    m.MarcaNome,
    ISNULL(vi.TotalVisualizacoes, 0)                       AS TotalVisualizacoes,
    ISNULL(v.QtdPedidos, 0)                                AS QtdPedidos,
    ISNULL(v.UnidadesVendidas, 0)                          AS UnidadesVendidas,
    ISNULL(v.ReceitaTotal, 0)                              AS ReceitaTotal,
    CAST(ISNULL(v.ReceitaTotal,0) / NULLIF(v.QtdPedidos,0) AS DECIMAL(14,2)) AS TicketMedio
FROM dim.Dim_Marca m
LEFT JOIN Vendas v        ON v.MarcaSK = m.MarcaSK
LEFT JOIN Visualizacoes vi ON vi.MarcaSK = m.MarcaSK;
GO

----------------------------------------------------------------------
-- vw_EngajamentoUsuario : LTV e funil individual por usuário.
----------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_EngajamentoUsuario
AS
SELECT
    u.UsuarioSK,
    u.UserID,
    COUNT(*)                                                          AS TotalEventos,
    SUM(CASE WHEN te.EventTypeCodigo = 'view'     THEN 1 ELSE 0 END)  AS Visualizacoes,
    SUM(CASE WHEN te.EventTypeCodigo = 'cart'     THEN 1 ELSE 0 END)  AS AdicoesCarrinho,
    SUM(CASE WHEN te.EventTypeCodigo = 'purchase' THEN 1 ELSE 0 END)  AS Compras,
    SUM(CASE WHEN te.EventTypeCodigo = 'purchase' THEN e.Preco ELSE 0 END) AS LTV,
    MIN(e.EventTime) AS PrimeiraAtividade,
    MAX(e.EventTime) AS UltimaAtividade
FROM fato.Fato_EventosNavegacao e
JOIN dim.Dim_Usuario u     ON u.UsuarioSK = e.UsuarioSK
JOIN dim.Dim_TipoEvento te ON te.TipoEventoSK = e.TipoEventoSK
GROUP BY u.UsuarioSK, u.UserID;
GO

----------------------------------------------------------------------
-- vw_ResumoDiarioEventos : agregação diária por tipo de evento.
----------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_ResumoDiarioEventos
AS
SELECT
    t.DataCompleta,
    t.NomeDiaSemana,
    t.EhFimDeSemana,
    SUM(CASE WHEN te.EventTypeCodigo = 'view'     THEN 1 ELSE 0 END) AS Visualizacoes,
    SUM(CASE WHEN te.EventTypeCodigo = 'cart'     THEN 1 ELSE 0 END) AS Carrinhos,
    SUM(CASE WHEN te.EventTypeCodigo = 'purchase' THEN 1 ELSE 0 END) AS Compras,
    COUNT(*) AS TotalEventos
FROM fato.Fato_EventosNavegacao e
JOIN dim.Dim_Tempo t       ON t.TempoSK = e.TempoSK
JOIN dim.Dim_TipoEvento te ON te.TipoEventoSK = e.TipoEventoSK
GROUP BY t.DataCompleta, t.NomeDiaSemana, t.EhFimDeSemana;
GO

----------------------------------------------------------------------
-- vw_MonitoramentoCarga : status do pipeline de ETL (Audit_CargaETL).
----------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_MonitoramentoCarga
AS
SELECT
    AuditSK,
    NomeProcesso,
    Etapa,
    InicioExec,
    FimExec,
    DATEDIFF(SECOND, InicioExec, FimExec) AS DuracaoSegundos,
    LinhasAfetadas,
    Status,
    Mensagem,
    Usuario
FROM fato.Audit_CargaETL;
GO

PRINT '>> 06_views.sql concluído (5 views).';
GO
