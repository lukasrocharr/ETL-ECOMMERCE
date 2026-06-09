/*======================================================================
  03_carga_estrela.sql  —  ETL: raw_* -> dimensões -> fatos
  Executar após 02_modelo_estrela.sql. Transacional e reexecutável.
======================================================================*/
USE OlistDW;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

------------------------------ DIMENSÕES ------------------------------
-- dim_tempo: calendário cobrindo o período do dataset
;WITH N AS (
    SELECT TOP (DATEDIFF(DAY,'2016-01-01','2019-01-01'))
           n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
), D AS (SELECT d = DATEADD(DAY, n, CAST('2016-01-01' AS DATE)) FROM N)
INSERT INTO dim_tempo (TempoSK, data, ano, mes, nome_mes, dia, trimestre, nome_dia, eh_fim_semana)
SELECT CONVERT(INT, CONVERT(CHAR(8), d, 112)), d, YEAR(d), MONTH(d), DATENAME(MONTH,d),
       DAY(d), DATEPART(QUARTER,d), DATENAME(WEEKDAY,d),
       CASE WHEN DATEPART(WEEKDAY,d) IN (1,7) THEN 1 ELSE 0 END
FROM D;

-- dim_categoria
INSERT INTO dim_categoria (categoria_pt, categoria_en)
SELECT DISTINCT p.product_category_name,
       MAX(t.product_category_name_english)
FROM raw_products p
LEFT JOIN raw_cat_translation t ON t.product_category_name = p.product_category_name
WHERE NULLIF(LTRIM(RTRIM(p.product_category_name)),'') IS NOT NULL
GROUP BY p.product_category_name;

-- dim_produto
INSERT INTO dim_produto (product_id, CategoriaSK, peso_g)
SELECT p.product_id, c.CategoriaSK, TRY_CONVERT(INT, p.product_weight_g)
FROM raw_products p
LEFT JOIN dim_categoria c ON c.categoria_pt = p.product_category_name;

-- dim_cliente (grão = customer_unique_id)
INSERT INTO dim_cliente (customer_unique_id, cidade, uf)
SELECT customer_unique_id, MAX(customer_city), MAX(customer_state)
FROM raw_customers
GROUP BY customer_unique_id;

-- dim_vendedor
INSERT INTO dim_vendedor (seller_id, cidade, uf)
SELECT seller_id, MAX(seller_city), MAX(seller_state)
FROM raw_sellers
GROUP BY seller_id;

-- dim_status_pedido
INSERT INTO dim_status_pedido (status, eh_concluido)
SELECT DISTINCT order_status,
       CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END
FROM raw_orders WHERE NULLIF(order_status,'') IS NOT NULL;

-- dim_forma_pagamento
INSERT INTO dim_forma_pagamento (forma)
SELECT DISTINCT payment_type FROM raw_payments WHERE NULLIF(payment_type,'') IS NOT NULL;

-- dim_avaliacao (1..5)
INSERT INTO dim_avaliacao (nota, faixa)
VALUES (1,'Insatisfeito'),(2,'Insatisfeito'),(3,'Neutro'),(4,'Satisfeito'),(5,'Satisfeito');

-------------------------------- FATOS --------------------------------
-- fato_pedido (1 linha por pedido) + métricas de entrega e totais
;WITH itens AS (
    SELECT order_id,
           COUNT(*) AS qtd,
           SUM(TRY_CONVERT(DECIMAL(12,2), price))         AS val_itens,
           SUM(TRY_CONVERT(DECIMAL(12,2), freight_value)) AS val_frete
    FROM raw_order_items GROUP BY order_id
)
INSERT INTO fato_pedido (order_id, ClienteSK, StatusSK, TempoCompraSK, data_compra,
        data_entrega, dias_entrega, dias_vs_estimativa, entregue_no_prazo,
        qtd_itens, valor_itens, valor_frete)
SELECT
    o.order_id,
    cli.ClienteSK,
    st.StatusSK,
    CONVERT(INT, CONVERT(CHAR(8), TRY_CONVERT(DATETIME2, o.order_purchase_timestamp), 112)),
    TRY_CONVERT(DATETIME2, o.order_purchase_timestamp),
    TRY_CONVERT(DATETIME2, o.order_delivered_customer_date),
    DATEDIFF(DAY, TRY_CONVERT(DATETIME2,o.order_purchase_timestamp), TRY_CONVERT(DATETIME2,o.order_delivered_customer_date)),
    DATEDIFF(DAY, TRY_CONVERT(DATETIME2,o.order_delivered_customer_date), TRY_CONVERT(DATETIME2,o.order_estimated_delivery_date)),
    CASE WHEN TRY_CONVERT(DATETIME2,o.order_delivered_customer_date) IS NULL THEN NULL
         WHEN TRY_CONVERT(DATETIME2,o.order_delivered_customer_date) <= TRY_CONVERT(DATETIME2,o.order_estimated_delivery_date) THEN 1
         ELSE 0 END,
    it.qtd, it.val_itens, it.val_frete
FROM raw_orders o
LEFT JOIN raw_customers rc ON rc.customer_id = o.customer_id
LEFT JOIN dim_cliente cli   ON cli.customer_unique_id = rc.customer_unique_id
LEFT JOIN dim_status_pedido st ON st.status = o.order_status
LEFT JOIN itens it ON it.order_id = o.order_id;

-- fato_item_pedido (1 linha por item)
INSERT INTO fato_item_pedido (order_id, PedidoSK, ProdutoSK, VendedorSK, ClienteSK, CategoriaSK, TempoSK, price, freight_value)
SELECT
    oi.order_id, fp.PedidoSK, pr.ProdutoSK, ve.VendedorSK, fp.ClienteSK,
    pr.CategoriaSK, fp.TempoCompraSK,
    TRY_CONVERT(DECIMAL(12,2), oi.price), TRY_CONVERT(DECIMAL(12,2), oi.freight_value)
FROM raw_order_items oi
LEFT JOIN fato_pedido fp ON fp.order_id = oi.order_id
LEFT JOIN dim_produto pr ON pr.product_id = oi.product_id
LEFT JOIN dim_vendedor ve ON ve.seller_id = oi.seller_id;

-- fato_pagamento (1 linha por pagamento)
INSERT INTO fato_pagamento (order_id, PedidoSK, FormaPagtoSK, ClienteSK, TempoSK, parcelas, valor)
SELECT
    pg.order_id, fp.PedidoSK, fpag.FormaPagtoSK, fp.ClienteSK, fp.TempoCompraSK,
    TRY_CONVERT(INT, pg.payment_installments), TRY_CONVERT(DECIMAL(12,2), pg.payment_value)
FROM raw_payments pg
LEFT JOIN fato_pedido fp ON fp.order_id = pg.order_id
LEFT JOIN dim_forma_pagamento fpag ON fpag.forma = pg.payment_type;

-- fato_avaliacao (1 linha por avaliação)
INSERT INTO fato_avaliacao (review_id, order_id, PedidoSK, ClienteSK, AvaliacaoSK, TempoSK, nota)
SELECT
    rv.review_id, rv.order_id, fp.PedidoSK, fp.ClienteSK, da.AvaliacaoSK,
    fp.TempoCompraSK, TRY_CONVERT(TINYINT, rv.review_score)
FROM raw_reviews rv
LEFT JOIN fato_pedido fp ON fp.order_id = rv.order_id
LEFT JOIN dim_avaliacao da ON da.nota = TRY_CONVERT(TINYINT, rv.review_score);

COMMIT TRANSACTION;
GO

PRINT '=== Contagem do modelo estrela ===';
SELECT 'dim_tempo' t, COUNT(*) n FROM dim_tempo
UNION ALL SELECT 'dim_cliente', COUNT(*) FROM dim_cliente
UNION ALL SELECT 'dim_produto', COUNT(*) FROM dim_produto
UNION ALL SELECT 'dim_categoria', COUNT(*) FROM dim_categoria
UNION ALL SELECT 'dim_vendedor', COUNT(*) FROM dim_vendedor
UNION ALL SELECT 'dim_status_pedido', COUNT(*) FROM dim_status_pedido
UNION ALL SELECT 'dim_forma_pagamento', COUNT(*) FROM dim_forma_pagamento
UNION ALL SELECT 'dim_avaliacao', COUNT(*) FROM dim_avaliacao
UNION ALL SELECT 'fato_pedido', COUNT(*) FROM fato_pedido
UNION ALL SELECT 'fato_item_pedido', COUNT(*) FROM fato_item_pedido
UNION ALL SELECT 'fato_pagamento', COUNT(*) FROM fato_pagamento
UNION ALL SELECT 'fato_avaliacao', COUNT(*) FROM fato_avaliacao
ORDER BY n DESC;
GO
