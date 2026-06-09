/*======================================================================
  01_perguntas.sql  —  Respostas às 10 perguntas de negócio (Olist)
  Executar após 00_setup_e_carga.sql. Cada bloco responde 1 pergunta.
======================================================================*/
USE OlistDW;
SET NOCOUNT ON;
GO

/*----------------------------------------------------------------------
  1) Qual forma de pagamento é mais usada?
----------------------------------------------------------------------*/
PRINT '=== 1) Formas de pagamento mais usadas ===';
SELECT
    payment_type                                                       AS forma_pagamento,
    COUNT(*)                                                           AS qtd_transacoes,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))     AS pct,
    CAST(SUM(TRY_CONVERT(DECIMAL(12,2), payment_value)) AS DECIMAL(16,2)) AS valor_total
FROM raw_payments
GROUP BY payment_type
ORDER BY qtd_transacoes DESC;
GO

/*----------------------------------------------------------------------
  2) Qual a taxa de recompra dos clientes?
     (clientes únicos com mais de 1 pedido)
----------------------------------------------------------------------*/
PRINT '=== 2) Taxa de recompra ===';
WITH pedidos_por_cliente AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS qtd_pedidos
    FROM raw_orders o
    JOIN raw_customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                                          AS clientes_unicos,
    SUM(CASE WHEN qtd_pedidos > 1 THEN 1 ELSE 0 END)                  AS clientes_recompra,
    CAST(100.0 * SUM(CASE WHEN qtd_pedidos > 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS taxa_recompra_pct
FROM pedidos_por_cliente;
GO

/*----------------------------------------------------------------------
  3) Quais estados têm mais clientes ativos? (com pedidos)
----------------------------------------------------------------------*/
PRINT '=== 3) Estados com mais clientes ativos (Top 15) ===';
SELECT TOP (15)
    c.customer_state                                  AS estado,
    COUNT(DISTINCT c.customer_unique_id)              AS clientes_ativos,
    COUNT(DISTINCT o.order_id)                        AS pedidos
FROM raw_customers c
JOIN raw_orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY clientes_ativos DESC;
GO

/*----------------------------------------------------------------------
  4) Quais meses têm maior volume de vendas?
----------------------------------------------------------------------*/
PRINT '=== 4) Meses com maior volume de vendas (Top 12) ===';
WITH o AS (
    SELECT order_id, TRY_CONVERT(DATETIME2, order_purchase_timestamp) AS dt
    FROM raw_orders
)
SELECT TOP (12)
    YEAR(o.dt)                                            AS ano,
    MONTH(o.dt)                                           AS mes,
    COUNT(DISTINCT o.order_id)                            AS pedidos,
    CAST(SUM(TRY_CONVERT(DECIMAL(12,2), oi.price)) AS DECIMAL(16,2)) AS receita
FROM o
JOIN raw_order_items oi ON oi.order_id = o.order_id
WHERE o.dt IS NOT NULL
GROUP BY YEAR(o.dt), MONTH(o.dt)
ORDER BY pedidos DESC;
GO

/*----------------------------------------------------------------------
  5) Quais categorias foram mais vendidas?
----------------------------------------------------------------------*/
PRINT '=== 5) Categorias mais vendidas (Top 15) ===';
SELECT TOP (15)
    COALESCE(t.product_category_name_english, p.product_category_name, 'desconhecida') AS categoria,
    COUNT(*)                                                          AS itens_vendidos,
    CAST(SUM(TRY_CONVERT(DECIMAL(12,2), oi.price)) AS DECIMAL(16,2))  AS receita
FROM raw_order_items oi
LEFT JOIN raw_products p     ON p.product_id = oi.product_id
LEFT JOIN raw_cat_translation t ON t.product_category_name = p.product_category_name
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'desconhecida')
ORDER BY itens_vendidos DESC;
GO

/*----------------------------------------------------------------------
  6) Qual o crescimento MoM (mês a mês) de vendas?
----------------------------------------------------------------------*/
PRINT '=== 6) Crescimento MoM de receita ===';
WITH vendas AS (
    SELECT TRY_CONVERT(DATETIME2, o.order_purchase_timestamp) AS dt,
           TRY_CONVERT(DECIMAL(12,2), oi.price)               AS preco
    FROM raw_order_items oi
    JOIN raw_orders o ON o.order_id = oi.order_id
),
mensal AS (
    SELECT DATEFROMPARTS(YEAR(dt), MONTH(dt), 1) AS mes_ref,
           SUM(preco)                            AS receita
    FROM vendas
    WHERE dt IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(dt), MONTH(dt), 1)
)
SELECT
    mes_ref,
    CAST(receita AS DECIMAL(16,2))                                       AS receita,
    CAST(LAG(receita) OVER (ORDER BY mes_ref) AS DECIMAL(16,2))          AS receita_mes_anterior,
    CAST(100.0 * (receita - LAG(receita) OVER (ORDER BY mes_ref))
         / NULLIF(LAG(receita) OVER (ORDER BY mes_ref), 0) AS DECIMAL(14,2)) AS crescimento_mom_pct
FROM mensal
ORDER BY mes_ref;
GO

/*----------------------------------------------------------------------
  7) Tempo médio de entrega?
----------------------------------------------------------------------*/
PRINT '=== 7) Tempo médio de entrega (pedidos entregues) ===';
WITH e AS (
    SELECT
        DATEDIFF(DAY, TRY_CONVERT(DATETIME2, order_purchase_timestamp),
                      TRY_CONVERT(DATETIME2, order_delivered_customer_date)) AS dias_entrega,
        DATEDIFF(DAY, TRY_CONVERT(DATETIME2, order_delivered_customer_date),
                      TRY_CONVERT(DATETIME2, order_estimated_delivery_date)) AS dias_vs_estimativa
    FROM raw_orders
    WHERE order_status = 'delivered'
      AND TRY_CONVERT(DATETIME2, order_delivered_customer_date) IS NOT NULL
)
SELECT
    COUNT(*)                                              AS pedidos_entregues,
    CAST(AVG(dias_entrega * 1.0) AS DECIMAL(6,1))         AS dias_medios_entrega,
    CAST(AVG(dias_vs_estimativa * 1.0) AS DECIMAL(6,1))   AS dias_medios_antes_do_prazo,
    CAST(100.0 * SUM(CASE WHEN dias_vs_estimativa >= 0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_no_prazo
FROM e;
GO

/*----------------------------------------------------------------------
  8) Maiores motivos de cancelamento?
     Obs.: o Olist NÃO possui um campo textual de "motivo".
     Usamos a distribuição de status (canceled/unavailable) como proxy
     e o perfil das categorias dos pedidos cancelados.
----------------------------------------------------------------------*/
PRINT '=== 8a) Distribuição de status dos pedidos ===';
SELECT
    order_status                                                   AS status,
    COUNT(*)                                                       AS qtd,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM raw_orders
GROUP BY order_status
ORDER BY qtd DESC;
GO
PRINT '=== 8b) Categorias mais frequentes em pedidos cancelados (Top 10) ===';
SELECT TOP (10)
    COALESCE(t.product_category_name_english, p.product_category_name, 'desconhecida') AS categoria,
    COUNT(*) AS itens_cancelados
FROM raw_orders o
JOIN raw_order_items oi ON oi.order_id = o.order_id
LEFT JOIN raw_products p     ON p.product_id = oi.product_id
LEFT JOIN raw_cat_translation t ON t.product_category_name = p.product_category_name
WHERE o.order_status IN ('canceled','unavailable')
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'desconhecida')
ORDER BY itens_cancelados DESC;
GO

/*----------------------------------------------------------------------
  9) Quais vendedores têm mais receita?
----------------------------------------------------------------------*/
PRINT '=== 9) Vendedores com maior receita (Top 15) ===';
SELECT TOP (15)
    oi.seller_id                                                     AS vendedor,
    s.seller_state                                                   AS estado,
    s.seller_city                                                    AS cidade,
    COUNT(*)                                                         AS itens_vendidos,
    CAST(SUM(TRY_CONVERT(DECIMAL(12,2), oi.price)) AS DECIMAL(16,2)) AS receita
FROM raw_order_items oi
LEFT JOIN raw_sellers s ON s.seller_id = oi.seller_id
GROUP BY oi.seller_id, s.seller_state, s.seller_city
ORDER BY receita DESC;
GO

/*----------------------------------------------------------------------
  10) Satisfação dos clientes?
----------------------------------------------------------------------*/
PRINT '=== 10a) Distribuição das notas de avaliação ===';
WITH r AS (SELECT TRY_CONVERT(INT, review_score) AS score FROM raw_reviews)
SELECT
    score                                                          AS nota,
    COUNT(*)                                                       AS qtd,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM r
WHERE score IS NOT NULL
GROUP BY score
ORDER BY score DESC;
GO
PRINT '=== 10b) Resumo de satisfação ===';
WITH r AS (SELECT TRY_CONVERT(INT, review_score) AS score FROM raw_reviews)
SELECT
    CAST(AVG(score * 1.0) AS DECIMAL(4,2))                                       AS nota_media,
    COUNT(*)                                                                     AS total_avaliacoes,
    CAST(100.0 * SUM(CASE WHEN score >= 4 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_satisfeitos_4e5,
    CAST(100.0 * SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_insatisfeitos_1e2
FROM r WHERE score IS NOT NULL;
GO
