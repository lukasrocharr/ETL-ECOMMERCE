-- ============================================================
-- 05_ANALISE_PERGUNTAS.sql
-- Responde as 10 perguntas estratégicas de negócio
--
-- Execute cada bloco separadamente para ver os resultados
-- ============================================================

USE ecommerce_etl;
GO

-- ============================================================
-- PERGUNTA 1: Qual forma de pagamento é mais usada?
-- ============================================================
SELECT 
    payment_type AS tipo_pagamento,
    COUNT(*) AS qtd_transacoes,
    SUM(payment_value) AS valor_total,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percentual
FROM raw.payments
GROUP BY payment_type
ORDER BY qtd_transacoes DESC;
-- RESULTADO ESPERADO:
-- credit_card: 76795 (73,92%)
-- boleto: 19784 (19,04%)
-- voucher: 5775 (5,56%)
-- debit_card: 1529 (1,47%)


-- ============================================================
-- PERGUNTA 2: Qual a taxa de recompra dos clientes?
-- ============================================================
WITH pedidos_por_cliente AS (
    SELECT 
        cliente_id,
        COUNT(DISTINCT order_id) AS qtd_pedidos
    FROM staging.orders_clientes
    GROUP BY cliente_id
)
SELECT 
    COUNT(*) AS total_clientes,
    SUM(CASE WHEN qtd_pedidos = 1 THEN 1 ELSE 0 END) AS clientes_unico_pedido,
    SUM(CASE WHEN qtd_pedidos > 1 THEN 1 ELSE 0 END) AS clientes_recompraram,
    CAST(SUM(CASE WHEN qtd_pedidos > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS taxa_recompra_pct
FROM pedidos_por_cliente;
-- RESULTADO: Taxa de recompra de apenas 3,12% (muito baixa)


-- ============================================================
-- PERGUNTA 3: Quais estados têm mais clientes ativos?
-- ============================================================
SELECT TOP 10
    estado,
    COUNT(DISTINCT cliente_id) AS qtd_clientes,
    COUNT(DISTINCT order_id) AS qtd_pedidos,
    CAST(COUNT(DISTINCT cliente_id) * 100.0 / SUM(COUNT(DISTINCT cliente_id)) OVER () AS DECIMAL(5,2)) AS percentual
FROM staging.orders_clientes
WHERE status NOT IN ('canceled', 'unavailable')
GROUP BY estado
ORDER BY qtd_clientes DESC;
-- RESULTADO: SP 41,83% | RJ 12,88% | MG 11,72%


-- ============================================================
-- PERGUNTA 4: Quais meses têm maior volume de vendas?
-- ============================================================
SELECT TOP 15
    FORMAT(data_compra, 'yyyy-MM') AS ano_mes,
    COUNT(DISTINCT order_id) AS qtd_pedidos,
    DATENAME(MONTH, data_compra) + '/' + CAST(YEAR(data_compra) AS VARCHAR) AS mes_extenso
FROM staging.orders_clientes
WHERE data_compra IS NOT NULL
GROUP BY FORMAT(data_compra, 'yyyy-MM'), DATENAME(MONTH, data_compra), YEAR(data_compra)
ORDER BY qtd_pedidos DESC;
-- RESULTADO: Novembro/2017 com 7.544 pedidos (Black Friday)


-- ============================================================
-- PERGUNTA 5: Quais categorias foram mais vendidas?
-- ============================================================
SELECT TOP 10
    pc.categoria,
    COUNT(*) AS qtd_vendida,
    SUM(oi.price) AS receita_total,
    AVG(oi.price) AS preco_medio,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percentual
FROM raw.order_items oi
INNER JOIN staging.products_categoria pc ON oi.product_id = pc.product_id
INNER JOIN staging.orders_clientes o ON oi.order_id = o.order_id
WHERE o.status = 'delivered'
GROUP BY pc.categoria
ORDER BY qtd_vendida DESC;
-- RESULTADO: bed_bath_table (9,94%) lidera em quantidade
-- health_beauty lidera em receita (R$ 1,23M)


-- ============================================================
-- PERGUNTA 6: Qual o crescimento MoM (Month-over-Month) de vendas?
-- ============================================================
WITH vendas_mensais AS (
    SELECT 
        FORMAT(data_compra, 'yyyy-MM') AS ano_mes,
        COUNT(DISTINCT order_id) AS pedidos
    FROM staging.orders_clientes
    WHERE data_compra IS NOT NULL
      AND YEAR(data_compra) BETWEEN 2017 AND 2018
    GROUP BY FORMAT(data_compra, 'yyyy-MM')
)
SELECT 
    ano_mes,
    pedidos,
    LAG(pedidos) OVER (ORDER BY ano_mes) AS pedidos_mes_anterior,
    pedidos - LAG(pedidos) OVER (ORDER BY ano_mes) AS variacao_absoluta,
    CAST(
        (pedidos - LAG(pedidos) OVER (ORDER BY ano_mes)) * 100.0 
        / NULLIF(LAG(pedidos) OVER (ORDER BY ano_mes), 0) 
    AS DECIMAL(6,2)) AS crescimento_mom_pct
FROM vendas_mensais
ORDER BY ano_mes;
-- RESULTADO: Pico de +122% em Fev/2017 | +62% em Nov/2017 (BF)
-- ATENÇÃO: Set/Out 2018 devem ser desconsiderados (dados incompletos)


-- ============================================================
-- PERGUNTA 7: Tempo médio de entrega por estado
-- ============================================================
SELECT 
    estado,
    COUNT(*) AS qtd_pedidos_entregues,
    CAST(AVG(CAST(dias_entrega AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS media_dias_entrega,
    MIN(dias_entrega) AS minimo_dias,
    MAX(dias_entrega) AS maximo_dias
FROM staging.orders_clientes
WHERE status = 'delivered' 
  AND dias_entrega IS NOT NULL
  AND dias_entrega > 0
GROUP BY estado
ORDER BY media_dias_entrega DESC;
-- RESULTADO: SP 8,7 dias (mais rápido) | RR 29,3 dias (mais lento)


-- ============================================================
-- PERGUNTA 8: Maiores motivos de cancelamento (status dos pedidos)
-- ============================================================
SELECT 
    status,
    COUNT(*) AS qtd,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percentual
FROM staging.orders_clientes
GROUP BY status
ORDER BY qtd DESC;
-- RESULTADO: 97,02% delivered | 0,63% canceled | 0,61% unavailable


-- ============================================================
-- PERGUNTA 9: Quais vendedores têm mais receita?
-- ============================================================
SELECT TOP 10
    oi.seller_id,
    s.seller_state AS estado_vendedor,
    s.seller_city AS cidade_vendedor,
    COUNT(DISTINCT oi.order_id) AS qtd_pedidos,
    COUNT(*) AS qtd_itens_vendidos,
    CAST(SUM(oi.price) AS DECIMAL(15,2)) AS receita_total,
    CAST(AVG(oi.price) AS DECIMAL(10,2)) AS ticket_medio
FROM raw.order_items oi
INNER JOIN raw.sellers s ON oi.seller_id = s.seller_id
GROUP BY oi.seller_id, s.seller_state, s.seller_city
ORDER BY receita_total DESC;
-- RESULTADO: 9 dos top 10 vendedores são de SP


-- ============================================================
-- PERGUNTA 10: Satisfação dos clientes
-- ============================================================
-- 10A) Distribuição das notas
SELECT 
    review_score AS nota,
    COUNT(*) AS qtd_avaliacoes,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percentual
FROM raw.reviews_limpo
GROUP BY review_score
ORDER BY review_score DESC;

-- 10B) Resumo geral (NPS-like)
SELECT 
    COUNT(*) AS total_avaliacoes,
    CAST(AVG(CAST(review_score AS DECIMAL(5,2))) AS DECIMAL(5,2)) AS nota_media,
    SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) AS satisfeitos,
    SUM(CASE WHEN review_score = 3 THEN 1 ELSE 0 END) AS neutros,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS insatisfeitos,
    CAST(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pct_satisfeitos,
    CAST(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pct_insatisfeitos
FROM raw.reviews_limpo;
-- RESULTADO: Nota média 4,09 | 77% satisfeitos | 15% insatisfeitos
