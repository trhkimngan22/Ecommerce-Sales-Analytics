-- Run after loading schema.sql. Read-only checks; no permanent audit table is changed.
USE E_CommerceDB;
GO
SET NOCOUNT ON;
DECLARE @checks TABLE (check_name VARCHAR(120), issue_count BIGINT);

INSERT INTO @checks
SELECT 'Orders: missing session/product or inconsistent user', COUNT_BIG(*)
FROM dbo.orders o
LEFT JOIN dbo.website_sessions s ON s.website_session_id = o.website_session_id
LEFT JOIN dbo.products p ON p.product_id = o.primary_product_id
WHERE s.website_session_id IS NULL OR p.product_id IS NULL OR o.user_id <> s.user_id;

INSERT INTO @checks
SELECT 'Items: missing order/product', COUNT_BIG(*)
FROM dbo.order_items i
LEFT JOIN dbo.orders o ON o.order_id = i.order_id
LEFT JOIN dbo.products p ON p.product_id = i.product_id
WHERE o.order_id IS NULL OR p.product_id IS NULL;

INSERT INTO @checks
SELECT 'Pageviews: missing session or pageview before session', COUNT_BIG(*)
FROM dbo.website_pageviews p
LEFT JOIN dbo.website_sessions s ON s.website_session_id = p.website_session_id
WHERE s.website_session_id IS NULL OR p.created_at < s.created_at;

INSERT INTO @checks
SELECT 'Orders: created before their session', COUNT_BIG(*)
FROM dbo.orders o JOIN dbo.website_sessions s ON s.website_session_id = o.website_session_id
WHERE o.created_at < s.created_at;

INSERT INTO @checks
SELECT 'Refunds: missing item/order, mismatched order or invalid date', COUNT_BIG(*)
FROM dbo.order_item_refunds r
LEFT JOIN dbo.order_items i ON i.order_item_id = r.order_item_id
LEFT JOIN dbo.orders o ON o.order_id = r.order_id
WHERE i.order_item_id IS NULL OR o.order_id IS NULL
   OR r.order_id <> i.order_id OR r.created_at < i.created_at;

INSERT INTO @checks
SELECT 'Items: total refund exceeds item price', COUNT_BIG(*)
FROM (
    SELECT i.order_item_id
    FROM dbo.order_items i JOIN dbo.order_item_refunds r ON r.order_item_id = i.order_item_id
    GROUP BY i.order_item_id, i.price_usd
    HAVING SUM(r.refund_amount_usd) > i.price_usd
) bad;

INSERT INTO @checks
SELECT 'Orders: item count/revenue/cost mismatch or invalid primary item', COUNT_BIG(*)
FROM dbo.orders o
LEFT JOIN (
    SELECT order_id, COUNT(*) AS item_count, SUM(price_usd) AS price_usd,
           SUM(cogs_usd) AS cogs_usd, SUM(CAST(is_primary_item AS INT)) AS primary_count,
           MAX(CASE WHEN is_primary_item = 1 THEN product_id END) AS primary_product_id
    FROM dbo.order_items GROUP BY order_id
) i ON i.order_id = o.order_id
WHERE i.order_id IS NULL OR i.item_count <> o.items_purchased
   OR i.price_usd <> o.price_usd OR i.cogs_usd <> o.cogs_usd
   OR i.primary_count <> 1 OR i.primary_product_id <> o.primary_product_id;

INSERT INTO @checks
SELECT 'Orders/items/refunds: negative amounts or invalid quantity', COUNT_BIG(*)
FROM (
    SELECT order_id AS id FROM dbo.orders WHERE price_usd < 0 OR cogs_usd < 0 OR items_purchased <= 0
    UNION ALL SELECT order_item_id FROM dbo.order_items WHERE price_usd < 0 OR cogs_usd < 0
    UNION ALL SELECT order_item_refund_id FROM dbo.order_item_refunds WHERE refund_amount_usd < 0
) bad;

INSERT INTO @checks
SELECT 'Sessions: unnormalized missing marketing fields', COUNT_BIG(*)
FROM dbo.website_sessions
WHERE utm_source IN ('', 'NULL', '\N') OR utm_campaign IN ('', 'NULL', '\N')
   OR utm_content IN ('', 'NULL', '\N') OR http_referer IN ('', 'NULL', '\N');

INSERT INTO @checks
SELECT 'Products/pageviews/sessions: empty descriptive fields', COUNT_BIG(*)
FROM (
    SELECT product_id AS id FROM dbo.products WHERE LTRIM(RTRIM(product_name)) = ''
    UNION ALL SELECT website_pageview_id FROM dbo.website_pageviews WHERE LTRIM(RTRIM(pageview_url)) = ''
    UNION ALL SELECT website_session_id FROM dbo.website_sessions WHERE LTRIM(RTRIM(device_type)) = ''
) bad;

SELECT check_name, issue_count,
       CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM @checks ORDER BY issue_count DESC, check_name;

IF EXISTS (SELECT 1 FROM @checks WHERE issue_count > 0)
    THROW 50002, 'Data quality checks failed; inspect the result set before building the dashboard.', 1;
GO

-- Snapshot totals: compare to README and Python validation output.
SELECT 'products' AS table_name, COUNT_BIG(*) AS row_count FROM dbo.products
UNION ALL SELECT 'website_sessions', COUNT_BIG(*) FROM dbo.website_sessions
UNION ALL SELECT 'orders', COUNT_BIG(*) FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT_BIG(*) FROM dbo.order_items
UNION ALL SELECT 'order_item_refunds', COUNT_BIG(*) FROM dbo.order_item_refunds
UNION ALL SELECT 'website_pageviews', COUNT_BIG(*) FROM dbo.website_pageviews;
SELECT (SELECT SUM(price_usd) FROM dbo.orders) AS order_revenue_usd,
       (SELECT SUM(price_usd) FROM dbo.order_items) AS item_revenue_usd,
       (SELECT SUM(refund_amount_usd) FROM dbo.order_item_refunds) AS refunded_usd;