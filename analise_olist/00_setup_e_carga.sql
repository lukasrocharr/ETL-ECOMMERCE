/*======================================================================
  00_setup_e_carga.sql  —  Projeto Olist (Brazilian E-Commerce)
  Cria o banco OlistDW, as tabelas brutas e carrega os CSVs via
  BULK INSERT (FORMAT='CSV' para tratar campos entre aspas).
  Os CSVs devem estar montados em /data dentro do contêiner.
  Idempotente: DROP IF EXISTS + recarga.
======================================================================*/
SET NOCOUNT ON;
GO
IF DB_ID('OlistDW') IS NULL CREATE DATABASE OlistDW;
GO
USE OlistDW;
GO

-- Todas as colunas como texto (NVARCHAR) para tolerar o dado bruto;
-- a conversão de tipos é feita nas consultas com TRY_CONVERT.
DROP TABLE IF EXISTS raw_orders;
DROP TABLE IF EXISTS raw_order_items;
DROP TABLE IF EXISTS raw_payments;
DROP TABLE IF EXISTS raw_reviews;
DROP TABLE IF EXISTS raw_products;
DROP TABLE IF EXISTS raw_customers;
DROP TABLE IF EXISTS raw_sellers;
DROP TABLE IF EXISTS raw_cat_translation;
GO

CREATE TABLE raw_orders (
    order_id NVARCHAR(40), customer_id NVARCHAR(40), order_status NVARCHAR(20),
    order_purchase_timestamp NVARCHAR(30), order_approved_at NVARCHAR(30),
    order_delivered_carrier_date NVARCHAR(30), order_delivered_customer_date NVARCHAR(30),
    order_estimated_delivery_date NVARCHAR(30));

CREATE TABLE raw_order_items (
    order_id NVARCHAR(40), order_item_id NVARCHAR(10), product_id NVARCHAR(40),
    seller_id NVARCHAR(40), shipping_limit_date NVARCHAR(30),
    price NVARCHAR(20), freight_value NVARCHAR(20));

CREATE TABLE raw_payments (
    order_id NVARCHAR(40), payment_sequential NVARCHAR(10), payment_type NVARCHAR(30),
    payment_installments NVARCHAR(10), payment_value NVARCHAR(20));

CREATE TABLE raw_reviews (
    review_id NVARCHAR(40), order_id NVARCHAR(40), review_score NVARCHAR(5),
    review_creation_date NVARCHAR(30), review_answer_timestamp NVARCHAR(30));

CREATE TABLE raw_products (
    product_id NVARCHAR(40), product_category_name NVARCHAR(100),
    product_name_lenght NVARCHAR(10), product_description_lenght NVARCHAR(10),
    product_photos_qty NVARCHAR(10), product_weight_g NVARCHAR(10),
    product_length_cm NVARCHAR(10), product_height_cm NVARCHAR(10), product_width_cm NVARCHAR(10));

CREATE TABLE raw_customers (
    customer_id NVARCHAR(40), customer_unique_id NVARCHAR(40),
    customer_zip_code_prefix NVARCHAR(10), customer_city NVARCHAR(60), customer_state NVARCHAR(5));

CREATE TABLE raw_sellers (
    seller_id NVARCHAR(40), seller_zip_code_prefix NVARCHAR(10),
    seller_city NVARCHAR(60), seller_state NVARCHAR(5));

CREATE TABLE raw_cat_translation (
    product_category_name NVARCHAR(100), product_category_name_english NVARCHAR(100));
GO

-- Obs.: CODEPAGE não é suportado pelo SQL Server no Linux; os campos
-- usados nas análises são ASCII (estados, payment_type, notas, etc.).
DECLARE @opt NVARCHAR(400) =
    N'WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', TABLOCK)';

EXEC('BULK INSERT raw_orders          FROM ''/data/olist_orders_dataset.csv''            ' + @opt);
EXEC('BULK INSERT raw_order_items     FROM ''/data/olist_order_items_dataset.csv''        ' + @opt);
EXEC('BULK INSERT raw_payments        FROM ''/data/olist_order_payments_dataset.csv''     ' + @opt);
EXEC('BULK INSERT raw_reviews         FROM ''/data/reviews_limpo.csv''                    ' + @opt);
EXEC('BULK INSERT raw_products        FROM ''/data/olist_products_dataset.csv''           ' + @opt);
EXEC('BULK INSERT raw_customers       FROM ''/data/olist_customers_dataset.csv''          ' + @opt);
EXEC('BULK INSERT raw_sellers         FROM ''/data/olist_sellers_dataset.csv''            ' + @opt);
EXEC('BULK INSERT raw_cat_translation FROM ''/data/product_category_name_translation.csv'' ' + @opt);
GO

PRINT '=== Linhas carregadas ===';
SELECT 'raw_orders' t, COUNT(*) n FROM raw_orders
UNION ALL SELECT 'raw_order_items', COUNT(*) FROM raw_order_items
UNION ALL SELECT 'raw_payments', COUNT(*) FROM raw_payments
UNION ALL SELECT 'raw_reviews', COUNT(*) FROM raw_reviews
UNION ALL SELECT 'raw_products', COUNT(*) FROM raw_products
UNION ALL SELECT 'raw_customers', COUNT(*) FROM raw_customers
UNION ALL SELECT 'raw_sellers', COUNT(*) FROM raw_sellers
UNION ALL SELECT 'raw_cat_translation', COUNT(*) FROM raw_cat_translation;
GO
