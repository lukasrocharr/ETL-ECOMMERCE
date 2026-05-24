-- ============================================================
-- 04_CREATE_STAGING.sql
-- Cria a camada STAGING com dados limpos e prontos para análise
-- ============================================================

USE ecommerce_etl;
GO

-- Limpa tabelas staging se já existirem (idempotente)
IF OBJECT_ID('staging.orders_clientes', 'U') IS NOT NULL 
    DROP TABLE staging.orders_clientes;
IF OBJECT_ID('staging.products_categoria', 'U') IS NOT NULL 
    DROP TABLE staging.products_categoria;
GO

-- ============================================================
-- 1. ORDERS + CUSTOMERS
-- Junta pedidos com os dados de cliente (unique_id, estado, cidade)
-- e calcula campo derivado dias_entrega
-- ============================================================
SELECT 
    o.order_id,
    c.customer_unique_id AS cliente_id,
    c.customer_state AS estado,
    c.customer_city AS cidade,
    o.order_status AS status,
    o.order_purchase_timestamp AS data_compra,
    o.order_delivered_customer_date AS data_entrega,
    o.order_estimated_delivery_date AS data_estimada,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS dias_entrega
INTO staging.orders_clientes
FROM raw.orders o
INNER JOIN raw.customers c ON o.customer_id = c.customer_id
WHERE o.order_purchase_timestamp IS NOT NULL;

PRINT 'staging.orders_clientes criada';

-- ============================================================
-- 2. PRODUCTS + CATEGORIA traduzida
-- Junta produtos com a tradução de categoria (pt -> en)
-- ============================================================
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'sem_categoria') AS categoria
INTO staging.products_categoria
FROM raw.products p
LEFT JOIN raw.category_translation t ON p.product_category_name = t.product_category_name;

PRINT 'staging.products_categoria criada';

-- Confere
SELECT 'orders_clientes' AS tabela, COUNT(*) AS total FROM staging.orders_clientes
UNION ALL
SELECT 'products_categoria', COUNT(*) FROM staging.products_categoria;
