-- ============================================================
-- 03_BULK_INSERT_CSVS.sql
-- Importa os 8 CSVs principais para a camada RAW
--
-- IMPORTANTE: Antes de rodar este script, os CSVs devem estar
-- copiados para /var/opt/mssql/dados/ DENTRO do container Docker.
--
-- Comandos prévios (no terminal):
--   docker exec sqlserver-etl mkdir -p /var/opt/mssql/dados
--   docker cp ./data/. sqlserver-etl:/var/opt/mssql/dados/
--   docker exec -u root sqlserver-etl chown -R mssql:mssql /var/opt/mssql/dados/
-- ============================================================

USE ecommerce_etl;
GO

-- 1. Customers
BULK INSERT raw.customers
FROM '/var/opt/mssql/dados/olist_customers_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Customers importado';

-- 2. Orders
BULK INSERT raw.orders
FROM '/var/opt/mssql/dados/olist_orders_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Orders importado';

-- 3. Order Items
BULK INSERT raw.order_items
FROM '/var/opt/mssql/dados/olist_order_items_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Order Items importado';

-- 4. Payments
BULK INSERT raw.payments
FROM '/var/opt/mssql/dados/olist_order_payments_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Payments importado';

-- 5. Products
BULK INSERT raw.products
FROM '/var/opt/mssql/dados/olist_products_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Products importado';

-- 6. Sellers
BULK INSERT raw.sellers
FROM '/var/opt/mssql/dados/olist_sellers_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Sellers importado';

-- 7. Geolocation
BULK INSERT raw.geolocation
FROM '/var/opt/mssql/dados/olist_geolocation_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Geolocation importado';

-- 8. Category Translation
BULK INSERT raw.category_translation
FROM '/var/opt/mssql/dados/product_category_name_translation.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
PRINT 'Category Translation importado';

PRINT '=== TODAS AS 8 IMPORTACOES PRINCIPAIS CONCLUIDAS ===';

-- Confere quantidades
SELECT 'customers' AS tabela, COUNT(*) AS total FROM raw.customers
UNION ALL SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM raw.payments
UNION ALL SELECT 'products', COUNT(*) FROM raw.products
UNION ALL SELECT 'sellers', COUNT(*) FROM raw.sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'category_translation', COUNT(*) FROM raw.category_translation;
