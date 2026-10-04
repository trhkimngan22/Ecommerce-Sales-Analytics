-- Run views_for_bi.sql first. Monetary amounts are USD.
USE E_CommerceDB;
GO
-- 1. Sales KPIs; margin is not net profit (marketing/operating costs unavailable).
SELECT COUNT(*) AS orders, COUNT(DISTINCT user_id) AS purchasing_users,
       SUM(items_purchased) AS units, SUM(gross_revenue_usd) AS gross_revenue_usd,
       SUM(refund_amount_usd) AS refunds_usd, SUM(net_revenue_usd) AS net_revenue_usd,
       AVG(gross_revenue_usd) AS average_order_value_usd,
       SUM(margin_after_refunds_usd) AS margin_after_refunds_usd
FROM dbo.View_Fact_Orders;

-- 2. Monthly sales and growth. First and last months may be incomplete.
WITH monthly AS (
    SELECT DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month_start,
           COUNT(*) AS orders, SUM(gross_revenue_usd) AS revenue_usd
    FROM dbo.View_Fact_Orders
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
), growth AS (
    SELECT *, LAG(revenue_usd) OVER (ORDER BY month_start) AS previous_month_revenue
    FROM monthly
)
SELECT *, 100.0 * (revenue_usd - previous_month_revenue)
          / NULLIF(previous_month_revenue, 0) AS revenue_growth_pct
FROM growth ORDER BY month_start;

-- 3. Product performance; aggregate item revenue, not the whole order price.
SELECT p.product_name, COUNT(*) AS units, COUNT(DISTINCT i.order_id) AS orders,
       SUM(i.gross_revenue_usd) AS gross_revenue_usd,
       SUM(i.net_revenue_usd) AS net_revenue_usd,
       SUM(i.margin_after_refunds_usd) AS margin_after_refunds_usd,
       100.0 * SUM(i.is_refunded) / NULLIF(COUNT(*), 0) AS refunded_item_pct
FROM dbo.View_Fact_Order_Items i
JOIN dbo.View_Dim_Product p ON p.product_id = i.product_id
GROUP BY p.product_name ORDER BY gross_revenue_usd DESC;

-- 4. Session conversion by traffic source/campaign/device.
-- Missing UTM alone does not prove direct traffic: preserve referer separately.
SELECT utm_source, utm_campaign, device_type, COUNT(*) AS sessions,
       SUM(is_converted) AS converted_sessions, SUM(order_count) AS orders,
       100.0 * SUM(is_converted) / NULLIF(COUNT(*), 0) AS session_conversion_pct,
       SUM(gross_revenue_usd) / NULLIF(COUNT(*), 0) AS revenue_per_session_usd
FROM dbo.View_Fact_Sessions
GROUP BY utm_source, utm_campaign, device_type
ORDER BY sessions DESC;

-- 5. Landing-page performance (observational; not a controlled experiment).
SELECT landing_page, device_type, COUNT(*) AS sessions,
       100.0 * SUM(is_bounce) / NULLIF(COUNT(*), 0) AS bounce_pct,
       100.0 * SUM(is_converted) / NULLIF(COUNT(*), 0) AS conversion_pct
FROM dbo.View_Fact_Sessions
WHERE pageview_count > 0
GROUP BY landing_page, device_type ORDER BY sessions DESC;

-- 6. Repeat vs new sessions; not a customer retention rate.
SELECT is_repeat_session, COUNT(*) AS sessions,
       SUM(is_converted) AS converted_sessions,
       100.0 * SUM(is_converted) / NULLIF(COUNT(*), 0) AS conversion_pct
FROM dbo.View_Fact_Sessions GROUP BY is_repeat_session;

-- 7. Cross-sell pairs and their order counts.
SELECT primary_product.product_name AS primary_product,
       secondary_product.product_name AS cross_sell_product,
       COUNT(DISTINCT secondary_item.order_id) AS orders_with_pair
FROM dbo.order_items primary_item
JOIN dbo.order_items secondary_item ON secondary_item.order_id = primary_item.order_id
    AND secondary_item.is_primary_item = 0
JOIN dbo.products primary_product ON primary_product.product_id = primary_item.product_id
JOIN dbo.products secondary_product ON secondary_product.product_id = secondary_item.product_id
WHERE primary_item.is_primary_item = 1
GROUP BY primary_product.product_name, secondary_product.product_name
ORDER BY orders_with_pair DESC;

-- 8. Refunds by refund month, not original order month.
SELECT CONVERT(CHAR(7), refund_date, 126) AS refund_month,
       COUNT(*) AS refund_events, COUNT(DISTINCT order_id) AS refunded_orders,
       SUM(refund_amount_usd) AS refunds_usd
FROM dbo.View_Fact_Refunds
GROUP BY CONVERT(CHAR(7), refund_date, 126) ORDER BY refund_month;

-- 9. Most viewed pages: unique visitors are session-based here.
SELECT pageview_url, COUNT_BIG(*) AS pageviews,
       COUNT(DISTINCT website_session_id) AS sessions
FROM dbo.website_pageviews GROUP BY pageview_url ORDER BY pageviews DESC;

-- 10. Top 10 users by observed net revenue; this is not predicted lifetime value.
SELECT TOP (10) user_id, COUNT(*) AS orders, SUM(net_revenue_usd) AS net_revenue_usd
FROM dbo.View_Fact_Orders GROUP BY user_id
ORDER BY net_revenue_usd DESC, user_id;