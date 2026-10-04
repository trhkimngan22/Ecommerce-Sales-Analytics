-- Run schema.sql and load data first. All views can be redeployed safely.
USE E_CommerceDB;
GO
CREATE OR ALTER VIEW dbo.View_Dim_Product AS
SELECT product_id, product_name, created_at AS product_created_at
FROM dbo.products;
GO
CREATE OR ALTER VIEW dbo.View_Dim_User AS
SELECT user_id, MIN(created_at) AS first_observed_session_at
FROM dbo.website_sessions
GROUP BY user_id;
GO
-- Continuous calendar includes refunds after the final order date.
CREATE OR ALTER VIEW dbo.View_Dim_Date AS
WITH digits AS (
    SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) d(n)
), bounds AS (
    SELECT CAST(MIN(created_at) AS DATE) AS first_date,
           CAST(MAX(created_at) AS DATE) AS last_date
    FROM (
        SELECT MIN(created_at) AS created_at FROM dbo.website_sessions
        UNION ALL SELECT MAX(created_at) FROM dbo.website_sessions
        UNION ALL SELECT MIN(created_at) FROM dbo.orders
        UNION ALL SELECT MAX(created_at) FROM dbo.orders
        UNION ALL SELECT MIN(created_at) FROM dbo.order_item_refunds
        UNION ALL SELECT MAX(created_at) FROM dbo.order_item_refunds
        UNION ALL SELECT MIN(created_at) FROM dbo.website_pageviews
        UNION ALL SELECT MAX(created_at) FROM dbo.website_pageviews
    ) dates
), calendar AS (
    SELECT DATEADD(DAY, a.n + 10*b.n + 100*c.n + 1000*d.n + 10000*e.n, first_date) AS calendar_date
    FROM bounds CROSS JOIN digits a CROSS JOIN digits b CROSS JOIN digits c
    CROSS JOIN digits d CROSS JOIN digits e
    WHERE a.n + 10*b.n + 100*c.n + 1000*d.n + 10000*e.n <= DATEDIFF(DAY, first_date, last_date)
)
SELECT calendar_date, YEAR(calendar_date) AS calendar_year,
       MONTH(calendar_date) AS month_number,
       DATEPART(QUARTER, calendar_date) AS quarter_number,
       CONVERT(CHAR(7), calendar_date, 126) AS year_month,
       YEAR(calendar_date)*100 + MONTH(calendar_date) AS year_month_sort
FROM calendar;
GO
-- Grain: one order. Refunds attributed to the ORIGINAL order date.
CREATE OR ALTER VIEW dbo.View_Fact_Orders AS
WITH refunds AS (
    SELECT order_id, SUM(refund_amount_usd) AS refund_amount_usd
    FROM dbo.order_item_refunds GROUP BY order_id
)
SELECT o.order_id, o.created_at, CAST(o.created_at AS DATE) AS order_date,
       o.website_session_id, o.user_id, o.primary_product_id, o.items_purchased,
       o.price_usd AS gross_revenue_usd, o.cogs_usd,
       COALESCE(r.refund_amount_usd, 0) AS refund_amount_usd,
       o.price_usd - COALESCE(r.refund_amount_usd, 0) AS net_revenue_usd,
       o.price_usd - o.cogs_usd AS gross_margin_usd,
       o.price_usd - COALESCE(r.refund_amount_usd, 0) - o.cogs_usd AS margin_after_refunds_usd,
       s.device_type, s.utm_source, s.utm_campaign, s.utm_content, s.http_referer,
       s.is_repeat_session
FROM dbo.orders o
JOIN dbo.website_sessions s ON s.website_session_id = o.website_session_id
LEFT JOIN refunds r ON r.order_id = o.order_id;
GO
-- Grain: one item. Use this fact for product revenue, including cross-sell items.
CREATE OR ALTER VIEW dbo.View_Fact_Order_Items AS
WITH refunds AS (
    SELECT order_item_id, SUM(refund_amount_usd) AS refund_amount_usd,
           COUNT(*) AS refund_event_count
    FROM dbo.order_item_refunds GROUP BY order_item_id
)
SELECT i.order_item_id, i.order_id, i.product_id, i.is_primary_item,
       i.created_at, CAST(o.created_at AS DATE) AS order_date,
       o.user_id, o.website_session_id,
       i.price_usd AS gross_revenue_usd, i.cogs_usd,
       COALESCE(r.refund_amount_usd, 0) AS refund_amount_usd,
       COALESCE(r.refund_event_count, 0) AS refund_event_count,
       CASE WHEN r.order_item_id IS NULL THEN 0 ELSE 1 END AS is_refunded,
       i.price_usd - COALESCE(r.refund_amount_usd, 0) AS net_revenue_usd,
       i.price_usd - i.cogs_usd AS gross_margin_usd,
       i.price_usd - COALESCE(r.refund_amount_usd, 0) - i.cogs_usd AS margin_after_refunds_usd
FROM dbo.order_items i
JOIN dbo.orders o ON o.order_id = i.order_id
LEFT JOIN refunds r ON r.order_item_id = i.order_item_id;
GO
-- Grain: one refund event. Use refund_date for refund-period reporting.
CREATE OR ALTER VIEW dbo.View_Fact_Refunds AS
SELECT r.order_item_refund_id, r.order_item_id, r.order_id, i.product_id,
       o.user_id, r.created_at, CAST(r.created_at AS DATE) AS refund_date,
       CAST(o.created_at AS DATE) AS order_date, r.refund_amount_usd
FROM dbo.order_item_refunds r
JOIN dbo.order_items i ON i.order_item_id = r.order_item_id
JOIN dbo.orders o ON o.order_id = r.order_id;
GO
-- Grain: one session, including sessions with no orders or pageviews.
-- Orders and pageviews are aggregated independently before joining.
CREATE OR ALTER VIEW dbo.View_Fact_Sessions AS
WITH pageviews AS (
    SELECT website_session_id, COUNT_BIG(*) AS pageview_count,
           MIN(website_pageview_id) AS first_pageview_id
    FROM dbo.website_pageviews GROUP BY website_session_id
), orders AS (
    SELECT website_session_id, COUNT(*) AS order_count, SUM(price_usd) AS gross_revenue_usd
    FROM dbo.orders GROUP BY website_session_id
)
SELECT s.website_session_id, s.created_at, CAST(s.created_at AS DATE) AS session_date,
       s.user_id, s.is_repeat_session, s.utm_source, s.utm_campaign, s.utm_content,
       s.device_type, s.http_referer,
       landing.pageview_url AS landing_page,
       COALESCE(p.pageview_count, 0) AS pageview_count,
       CASE WHEN p.pageview_count = 1 THEN 1 ELSE 0 END AS is_bounce,
       COALESCE(o.order_count, 0) AS order_count,
       CASE WHEN o.order_count > 0 THEN 1 ELSE 0 END AS is_converted,
       COALESCE(o.gross_revenue_usd, 0) AS gross_revenue_usd
FROM dbo.website_sessions s
LEFT JOIN pageviews p ON p.website_session_id = s.website_session_id
LEFT JOIN dbo.website_pageviews landing ON landing.website_pageview_id = p.first_pageview_id
LEFT JOIN orders o ON o.website_session_id = s.website_session_id;
GO
CREATE OR ALTER VIEW dbo.View_Fact_Pageviews AS
SELECT website_pageview_id, website_session_id, created_at,
       CAST(created_at AS DATE) AS pageview_date, pageview_url
FROM dbo.website_pageviews;
GO