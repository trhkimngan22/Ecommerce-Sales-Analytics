# E-commerce Sales & Website Analysis

Sales and website behavior analysis built from the 6 CSV files in `data/`, using SQL Server for cleaning and data modeling and Power BI for visualization.

## Repository structure

```
Ecommerce-Sales-Analytics/
├── data/                              # 6 source CSV files
│   ├── products.csv
│   ├── website_sessions.csv
│   ├── website_pageviews.csv
│   ├── orders.csv
│   ├── order_items.csv
│   └── order_item_refunds.csv
├── src/
│   ├── create_db.sql                  # Creates the E_CommerceDB database
│   ├── schema.sql                     # Creates the 6 tables, keys, constraints and indexes
│   ├── import_data.sql                # Loads the CSVs with BULK INSERT
│   ├── data_quality_check.sql         # Data quality checks (PASS/FAIL) and reconciliation totals
│   ├── views_for_bi.sql               # Dimension/fact views for Power BI
│   └── analysis_queries.sql           # 10 analysis queries
├── dashboard/
│   ├── images/                        # Screenshots of the 4 dashboard pages
│   ├── Ecommerce_Sales_Analytics.pbix # Power BI dashboard
│   └── README.md                      # Dashboard insights
└── README.md
```

## Data and reconciliation figures

| CSV | Grain | Rows |
|---|---|---:|
| products | One product | 4 |
| website_sessions | One website session | 472,871 |
| orders | One order | 32,313 |
| order_items | One item in an order | 40,025 |
| order_item_refunds | One refund event | 1,731 |
| website_pageviews | One pageview | 1,188,124 |

- Revenue before refunds: **USD 1,938,509.75**, equal to both the sum of order `price_usd` and the sum of item `price_usd`.
- Refunds: **USD 85,338.69**. Revenue after refunds: **USD 1,853,171.06**.
- Orders span 2012-03-19 to 2015-03-19; refunds run until 2015-04-01. The first month (2012-03) and the last month (2015-03) are incomplete.
- `NULL`, `\N` and empty strings in UTM/referer fields are converted to SQL NULL. A missing UTM does not mean direct traffic.
- The dataset's source and terms of use should be added before publishing the project.

## How to run

Requires SQL Server 2017+ and Power BI Desktop. The SQL scripts use the `GO` batch separator, so run them with a SQL Server tool (SSMS, Azure Data Studio, sqlcmd, ...).

1. Run `src/create_db.sql` to create the `E_CommerceDB` database.
2. Run `src/schema.sql` to create the 6 tables. It only creates missing tables and does not migrate existing tables with the same name but a different structure.
3. Copy all 6 CSVs to `/var/opt/mssql/data/import/` on the machine/container running SQL Server, or edit the `FROM` paths in `src/import_data.sql`. This is a server-side path, not a path on the machine running your editor.
4. Run the whole of `src/import_data.sql` in a single connection. The script reads the CSVs into text staging tables → converts types and loads the main tables in one transaction → drops the staging tables. If any target table already contains data, the script stops instead of loading duplicates.
5. Run `src/data_quality_check.sql`; every check must be `PASS` and the totals must match the table above.
6. Run `src/views_for_bi.sql` (uses `CREATE OR ALTER`, safe to re-run), then `src/analysis_queries.sql`.
7. Open `dashboard/Ecommerce_Sales_Analytics.pbix`, point the data source to your SQL Server and refresh.

## Dashboard

- Power BI file: [dashboard/Ecommerce_Sales_Analytics.pbix](dashboard/Ecommerce_Sales_Analytics.pbix) (open with Power BI Desktop)
- Insights and recommendations: [dashboard/README.md](dashboard/README.md)

| Page | Main content |
|---|---|
| [Business Overview](dashboard/images/Business%20Overview.png) | Total orders, revenue before/after refunds, AOV; monthly revenue and order volume; revenue by device and by product |
| [Product Performance](dashboard/images/Product%20Performance.png) | Items sold, product revenue, gross margin, return rate; revenue ranking and trend by product; primary vs add-on items |
| [Marketing Performance](dashboard/images/Marketing%20Performance.png) | Sessions, sessions with orders, conversion rate, bounce rate; performance by traffic source, campaign and device |
| [Refund](dashboard/images/Refund.png) | Refund count and amount by refund date; refund amount and return rate by product |

## Power BI model

| View | Grain / purpose |
|---|---|
| View_Dim_Date | One continuous day, including the refund period |
| View_Dim_Product | One product |
| View_Dim_User | One user; date of the first observed session |
| View_Fact_Orders | One order; revenue, AOV and order count KPIs |
| View_Fact_Order_Items | One item; product revenue and cross-sell |
| View_Fact_Refunds | One refund event; reporting by refund date |
| View_Fact_Sessions | One session; traffic, conversion, bounce, landing page |
| View_Fact_Pageviews | One pageview; import only if pageview-level analysis is needed |

One-to-many relationships, single-direction filtering from dimensions to facts:

- Date → Orders/Order_Items on `order_date`, Sessions on `session_date`, Refunds on `refund_date`. Mark Date as the date table; sort `year_month` by `year_month_sort`.
- Product → Order_Items and Refunds on `product_id`.
- User → Orders, Order_Items, Refunds and Sessions on `user_id`.
- Fact tables are not joined to each other. Revenue from different facts is never added into one KPI.
- `Orders.primary_product_id` is only the primary product; product revenue comes from Order_Items. The Product slicer filters only the item/refund facts, not Orders/Sessions.
- UTM/device slicers on the Marketing page use the Sessions fact columns.

Key measures:

```dax
Total_Orders = COUNTROWS(View_Fact_Orders)
Gross Revenue = SUM(View_Fact_Orders[gross_revenue_usd])
Net Revenue = SUM(View_Fact_Orders[net_revenue_usd])
Average_order_value = DIVIDE([Gross Revenue], [Total_Orders])
Total sessions = COUNTROWS(View_Fact_Sessions)
Converted Sessions = SUM(View_Fact_Sessions[is_converted])
Conversion Rate = DIVIDE([Converted Sessions], [Total sessions])
Bounce Rate = DIVIDE(
    SUM(View_Fact_Sessions[is_bounce]),
    CALCULATE(COUNTROWS(View_Fact_Sessions), View_Fact_Sessions[pageview_count] > 0)
)
Product Gross Revenue = SUM(View_Fact_Order_Items[gross_revenue_usd])
Refunds by Refund Date = SUM(View_Fact_Refunds[refund_amount_usd])
```

Calculated columns used as slicer labels:

```dax
Item Type = IF(View_Fact_Order_Items[is_primary_item], "Primary", "Add-on")
Visitor Type = IF(View_Fact_Sessions[is_repeat_session], "Repeat", "New")
Traffic Source = COALESCE(View_Fact_Sessions[utm_source], "No UTM")
Campaign = COALESCE(View_Fact_Sessions[utm_campaign], "No UTM")
```

## Definitions and caveats

- Refunds in Orders/Order_Items are attributed to the original sale date; refunds in Fact_Refunds use the actual refund date. Never add the two together.
- `gross_margin_usd` = revenue − COGS. `margin_after_refunds_usd` = revenue − refunds − COGS; it assumes no COGS recovery and is not net profit, since operating/marketing costs are unavailable.
- Bounce = a session with exactly one pageview. Landing page = the pageview with the lowest ID in the session.
- Conversion rate = sessions with at least one order / total sessions, not orders / total sessions.
- A repeat session is not customer retention. Descriptive aggregates do not show the causal effect of advertising.
