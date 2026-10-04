-- LOAD CSV DATA INTO SQL SERVER
-- Run create_db.sql and schema.sql first to create the database and target tables.
-- Copy the CSV files to /var/opt/mssql/data/import/ on the SQL Server machine/container.
-- If the files are stored elsewhere, update the FROM paths below.

USE E_CommerceDB;
GO

-- Before loading: stop if any target table already contains data.
IF EXISTS (SELECT 1 FROM dbo.products)
   OR EXISTS (SELECT 1 FROM dbo.website_sessions)
   OR EXISTS (SELECT 1 FROM dbo.orders)
   OR EXISTS (SELECT 1 FROM dbo.order_items)
   OR EXISTS (SELECT 1 FROM dbo.order_item_refunds)
   OR EXISTS (SELECT 1 FROM dbo.website_pageviews)
BEGIN
    PRINT N'Target tables already contain data. Stopping to avoid duplicate loading.';
    RETURN;
END;

-- STEP 1: CREATE TEMPORARY TABLES FOR THE CSV DATA
-- Read columns as text first; convert them to numbers or dates during INSERT.

CREATE TABLE #raw_products (
    product_id VARCHAR(100),
    created_at VARCHAR(100),
    product_name VARCHAR(100)
);

CREATE TABLE #raw_website_sessions (
    website_session_id VARCHAR(100),
    created_at VARCHAR(100),
    user_id VARCHAR(100),
    is_repeat_session VARCHAR(100),
    utm_source VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_content VARCHAR(100),
    device_type VARCHAR(100),
    http_referer VARCHAR(2048)
);

CREATE TABLE #raw_orders (
    order_id VARCHAR(100),
    created_at VARCHAR(100),
    website_session_id VARCHAR(100),
    user_id VARCHAR(100),
    primary_product_id VARCHAR(100),
    items_purchased VARCHAR(100),
    price_usd VARCHAR(100),
    cogs_usd VARCHAR(100)
);

CREATE TABLE #raw_order_items (
    order_item_id VARCHAR(100),
    created_at VARCHAR(100),
    order_id VARCHAR(100),
    product_id VARCHAR(100),
    is_primary_item VARCHAR(100),
    price_usd VARCHAR(100),
    cogs_usd VARCHAR(100)
);

CREATE TABLE #raw_order_item_refunds (
    order_item_refund_id VARCHAR(100),
    created_at VARCHAR(100),
    order_item_id VARCHAR(100),
    order_id VARCHAR(100),
    refund_amount_usd VARCHAR(100)
);

CREATE TABLE #raw_website_pageviews (
    website_pageview_id VARCHAR(100),
    created_at VARCHAR(100),
    website_session_id VARCHAR(100),
    pageview_url VARCHAR(2048)
);

-- STEP 2: READ THE SIX CSV FILES INTO THE TEMPORARY TABLES
-- BULK INSERT: read multiple rows from a file into a table.
-- FORMAT = 'CSV': the source file uses CSV format.
-- FIRSTROW = 2: skip the header and start reading from the second row.
-- FIELDTERMINATOR = ',': columns are separated by commas.
-- The first five CSVs use CRLF (0x0d0a); website_pageviews.csv uses LF (0x0a).
-- Match the full line ending so CR is not left in the last column.
BULK INSERT #raw_products
FROM '/var/opt/mssql/data/import/products.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a'
);

BULK INSERT #raw_website_sessions
FROM '/var/opt/mssql/data/import/website_sessions.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a'
);

BULK INSERT #raw_orders
FROM '/var/opt/mssql/data/import/orders.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a'
);

BULK INSERT #raw_order_items
FROM '/var/opt/mssql/data/import/order_items.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a'
);

BULK INSERT #raw_order_item_refunds
FROM '/var/opt/mssql/data/import/order_item_refunds.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0d0a'
);

BULK INSERT #raw_website_pageviews
FROM '/var/opt/mssql/data/import/website_pageviews.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);

-- STEP 3: INSERT DATA FROM THE TEMPORARY TABLES INTO THE TARGET TABLES
-- Load parent tables before child tables so referenced keys already exist.

-- The following two statements group the INSERTs into one transaction:
-- if an INSERT encounters a data error, roll back the INSERTs in this transaction.
-- only save changes if all INSERTs succeed; otherwise roll back.
SET XACT_ABORT ON; 
BEGIN TRANSACTION;

-- 3.1. Products
INSERT INTO dbo.products (
    product_id,
    created_at,
    product_name
)
SELECT 
    CAST(product_id AS INT),
    CAST(created_at AS DATETIME2(0)),
    product_name
FROM #raw_products;

-- 3.2. Website sessions
-- CASE: store SQL NULL when the CSV contains NULL, \N, or an empty string.
INSERT INTO dbo.website_sessions (
    website_session_id,
    created_at,
    user_id,
    is_repeat_session,
    utm_source,
    utm_campaign,
    utm_content,
    device_type,
    http_referer
)
SELECT
    CAST(website_session_id AS INT),
    CAST(created_at AS DATETIME2(0)),
    CAST(user_id AS INT),
    CAST(is_repeat_session AS BIT),
    CASE WHEN utm_source IN ('NULL', '\N', '') THEN NULL ELSE utm_source END,
    CASE WHEN utm_campaign IN ('NULL', '\N', '') THEN NULL ELSE utm_campaign END,
    CASE WHEN utm_content IN ('NULL', '\N', '') THEN NULL ELSE utm_content END,
    device_type,
    CASE WHEN http_referer IN ('NULL', '\N', '') THEN NULL ELSE http_referer END
FROM #raw_website_sessions;

-- 3.3. Orders
INSERT INTO dbo.orders (
    order_id,
    created_at,
    website_session_id,
    user_id,
    primary_product_id,
    items_purchased,
    price_usd,
    cogs_usd
)
SELECT
    CAST(order_id AS INT),
    CAST(created_at AS DATETIME2(0)),
    CAST(website_session_id AS INT),
    CAST(user_id AS INT),
    CAST(primary_product_id AS INT),
    CAST(items_purchased AS INT),
    CAST(price_usd AS DECIMAL(12,2)),
    CAST(cogs_usd AS DECIMAL(12,2))
FROM #raw_orders;

-- 3.4. Order items
INSERT INTO dbo.order_items (
    order_item_id,
    created_at,
    order_id,
    product_id,
    is_primary_item,
    price_usd,
    cogs_usd
)
SELECT
    CAST(order_item_id AS INT),
    CAST(created_at AS DATETIME2(0)),
    CAST(order_id AS INT),
    CAST(product_id AS INT),
    CAST(is_primary_item AS BIT),
    CAST(price_usd AS DECIMAL(12,2)),
    CAST(cogs_usd AS DECIMAL(12,2))
FROM #raw_order_items;

-- 3.5. Refunds
INSERT INTO dbo.order_item_refunds (
    order_item_refund_id,
    created_at,
    order_item_id,
    order_id,
    refund_amount_usd
)
SELECT
    CAST(order_item_refund_id AS INT),
    CAST(created_at AS DATETIME2(0)),
    CAST(order_item_id AS INT),
    CAST(order_id AS INT),
    CAST(refund_amount_usd AS DECIMAL(12,2))
FROM #raw_order_item_refunds;

-- 3.6. Website pageviews
INSERT INTO dbo.website_pageviews (
    website_pageview_id,
    created_at,
    website_session_id,
    pageview_url
)
SELECT
    CAST(website_pageview_id AS INT),
    CAST(created_at AS DATETIME2(0)),
    CAST(website_session_id AS INT),
    pageview_url
FROM #raw_website_pageviews;

-- Save all changes when every INSERT succeeds.
COMMIT TRANSACTION;

-- STEP 4: DROP THE TEMPORARY TABLES AFTER LOADING
DROP TABLE #raw_products;
DROP TABLE #raw_website_sessions;
DROP TABLE #raw_orders;
DROP TABLE #raw_order_items;
DROP TABLE #raw_order_item_refunds;
DROP TABLE #raw_website_pageviews;

-- STEP 5: CHECK THE NUMBER OF LOADED ROWS
SELECT COUNT(*) AS products_row_count FROM dbo.products;
SELECT COUNT(*) AS website_sessions_row_count FROM dbo.website_sessions;
SELECT COUNT(*) AS orders_row_count FROM dbo.orders;
SELECT COUNT(*) AS order_items_row_count FROM dbo.order_items;
SELECT COUNT(*) AS order_item_refunds_row_count FROM dbo.order_item_refunds;
SELECT COUNT(*) AS website_pageviews_row_count FROM dbo.website_pageviews;