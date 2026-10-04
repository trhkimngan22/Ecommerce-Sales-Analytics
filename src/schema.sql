-- Canonical schema for the six source CSVs. Legacy shopping-trends tables are untouched.
USE E_CommerceDB;
GO

IF OBJECT_ID('dbo.products', 'U') IS NULL
BEGIN
CREATE TABLE dbo.products (
    product_id INT NOT NULL PRIMARY KEY,
    created_at DATETIME2(0) NOT NULL,
    product_name VARCHAR(100) NOT NULL
);
END;
GO

IF OBJECT_ID('dbo.website_sessions', 'U') IS NULL
BEGIN
CREATE TABLE dbo.website_sessions (
    website_session_id INT NOT NULL PRIMARY KEY,
    created_at DATETIME2(0) NOT NULL,
    user_id INT NOT NULL,
    is_repeat_session BIT NOT NULL,
    utm_source VARCHAR(100) NULL,
    utm_campaign VARCHAR(100) NULL,
    utm_content VARCHAR(100) NULL,
    device_type VARCHAR(20) NOT NULL,
    http_referer VARCHAR(2048) NULL
);
END;
GO

IF OBJECT_ID('dbo.orders', 'U') IS NULL
BEGIN
CREATE TABLE dbo.orders (
    order_id INT NOT NULL PRIMARY KEY,
    created_at DATETIME2(0) NOT NULL,
    website_session_id INT NOT NULL,
    user_id INT NOT NULL,
    primary_product_id INT NOT NULL,
    items_purchased INT NOT NULL CHECK (items_purchased > 0),
    price_usd DECIMAL(12,2) NOT NULL CHECK (price_usd >= 0),
    cogs_usd DECIMAL(12,2) NOT NULL CHECK (cogs_usd >= 0),
    FOREIGN KEY (website_session_id) REFERENCES dbo.website_sessions(website_session_id),
    FOREIGN KEY (primary_product_id) REFERENCES dbo.products(product_id)
);
END;
GO

IF OBJECT_ID('dbo.order_items', 'U') IS NULL
BEGIN
CREATE TABLE dbo.order_items (
    order_item_id INT NOT NULL PRIMARY KEY,
    created_at DATETIME2(0) NOT NULL,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    is_primary_item BIT NOT NULL,
    price_usd DECIMAL(12,2) NOT NULL CHECK (price_usd >= 0),
    cogs_usd DECIMAL(12,2) NOT NULL CHECK (cogs_usd >= 0),
    FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
    FOREIGN KEY (product_id) REFERENCES dbo.products(product_id)
);
END;
GO

IF OBJECT_ID('dbo.order_item_refunds', 'U') IS NULL
BEGIN
CREATE TABLE dbo.order_item_refunds (
    order_item_refund_id INT NOT NULL PRIMARY KEY,
    created_at DATETIME2(0) NOT NULL,
    order_item_id INT NOT NULL,
    order_id INT NOT NULL,
    refund_amount_usd DECIMAL(12,2) NOT NULL CHECK (refund_amount_usd >= 0),
    FOREIGN KEY (order_item_id) REFERENCES dbo.order_items(order_item_id),
    FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id)
);
END;
GO

IF OBJECT_ID('dbo.website_pageviews', 'U') IS NULL
BEGIN
CREATE TABLE dbo.website_pageviews (
    website_pageview_id INT NOT NULL PRIMARY KEY,
    created_at DATETIME2(0) NOT NULL,
    website_session_id INT NOT NULL,
    pageview_url VARCHAR(2048) NOT NULL,
    FOREIGN KEY (website_session_id) REFERENCES dbo.website_sessions(website_session_id)
);
END;
GO