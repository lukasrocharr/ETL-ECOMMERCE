-- ============================================================
-- 02_CREATE_RAW_TABLES.sql
-- Cria as 9 tabelas da camada RAW (espelho dos CSVs)
-- ============================================================

USE ecommerce_etl;
GO

-- Clientes
CREATE TABLE raw.customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

-- Pedidos
CREATE TABLE raw.orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

-- Itens do pedido
CREATE TABLE raw.order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);

-- Pagamentos
CREATE TABLE raw.payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);

-- Produtos
CREATE TABLE raw.products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- Vendedores
CREATE TABLE raw.sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(5)
);

-- Geolocalização
CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(15,10),
    geolocation_lng DECIMAL(15,10),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5)
);

-- Tradução de categorias
CREATE TABLE raw.category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

PRINT 'Todas as 8 tabelas RAW criadas com sucesso!';
PRINT 'A tabela reviews_limpo será criada após o tratamento Python (script 06).';
