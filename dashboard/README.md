# Dashboard Insights

Key findings from `Ecommerce_Sales_Analytics.pbix`. Figures are calculated with the same definitions as `src/views_for_bi.sql` and correspond to the dashboard with no filters applied.

**Period:** orders from 2012-03-19 to 2015-03-19. 2012 starts mid-March and 2015 covers only Q1 (to 19 March), so full-year comparisons use 2013 vs 2014.

## Summary

| KPI | Value |
|---|---:|
| Orders | 32,313 |
| Revenue before refunds | USD 1,938,509.75 |
| Refunds | USD 85,338.69 (4.4% of revenue) |
| Revenue after refunds | USD 1,853,171.06 |
| Sessions | 472,871 |
| Conversion rate | 6.83% |
| Bounce rate | 44.8% |
| Revenue per session | USD 4.10 |

## 1. Business Overview

- **Strong growth.** Revenue in 2014 reached USD 1.08M, up **174%** from USD 393K in 2013. Orders grew 126% (7,447 → 16,860), while average order value rose 21% (USD 52.81 → 63.80).
- **Growth came from both traffic and efficiency.** Conversion rate improved every year (4.14% in 2012 → 7.22% in 2014 → 8.44% in Q1 2015) and revenue per session more than doubled (USD 2.07 → 5.30).
- **Clear Q4 seasonality.** Across 2013–2014, December orders (3,361) were about 2.4× January orders (1,372). December 2014 is the best month in the dataset with USD 145K revenue and 2,314 orders.
- **Desktop drives revenue.** Desktop is 69% of sessions but earns USD 5.09 per session, compared with USD 1.87 on mobile.

## 2. Product Performance

| Product | Items sold | Revenue | Share | Gross margin | Add-on share |
|---|---:|---:|---:|---:|---:|
| The Original Mr. Fuzzy | 24,226 | USD 1,211K | 62.5% | 61.0% | 2% |
| The Forever Love Bear | 5,796 | USD 348K | 17.9% | 62.5% | 17% |
| The Birthday Sugar Panda | 4,985 | USD 229K | 11.8% | 68.5% | 38% |
| The Hudson River Mini bear | 5,018 | USD 150K | 7.8% | 68.4% | 88% |

- **Heavy dependence on one product.** Mr. Fuzzy generates 62.5% of product revenue.
- **Cross-selling changed the business.** The share of orders with more than one item rose from about 1% (Sep 2013) to 34% (Mar 2014). Items per order went from 1.02 in 2013 to 1.34 in 2014, which explains most of the AOV increase.
- **The Mini bear is an add-on product.** 88% of its units were sold as add-on items. Mr. Fuzzy + Mini bear is the most common pair (3,126 orders).
- **Newer products carry higher margins.** Sugar Panda and Mini bear have about 68% gross margin, compared with 61% for Mr. Fuzzy. Overall gross margin rose from 61.0% (2012) to 63.2% (2014).

## 3. Marketing Performance

| Source | Share of sessions | Conversion rate | Bounce rate | Revenue per session |
|---|---:|---:|---:|---:|
| gsearch | 66.8% | 6.75% | 44.4% | USD 4.04 |
| No UTM | 17.6% | 7.34% | 39.9% | USD 4.46 |
| bsearch | 13.3% | 7.19% | 47.5% | USD 4.28 |
| socialbook | 2.3% | 3.21% | 77.6% | USD 2.08 |

- **gsearch nonbrand is the main traffic engine.** It brings 60% of all sessions and USD 1.12M in revenue, so changes in its bidding or ranking would have the biggest impact on the business.
- **Brand campaigns convert better than nonbrand.** gsearch brand converts at 7.53% vs 6.66% for nonbrand; bsearch brand at 8.86% vs 6.95%.
- **The socialbook pilot is underperforming.** It has a 1.08% conversion rate and 87% bounce rate, and earned only USD 3.7K from 5,095 sessions. The `desktop_targeted` campaign does better (5.15%) but is still below the search channels.
- **Mobile is the biggest gap.** Mobile conversion is 3.09% vs 8.5% on desktop. For gsearch nonbrand, desktop conversion rose from 9.13% (2014) to 10.68% (Q1 2015), while mobile stayed flat (3.61% → 3.74%).
- **Landing page comparisons need device context.** `/lander-3` looks weak (3.39%), but it only received mobile traffic, so it converts in line with other mobile pages. `/lander-5` has the highest conversion rate (10.17%) and served only desktop traffic.
- **Repeat sessions convert better.** They are 16.6% of sessions with a 7.83% conversion rate vs 6.64% for new sessions.

## 4. Refund

| Product | Items sold | Refunded items | Refund rate | Refund amount |
|---|---:|---:|---:|---:|
| The Birthday Sugar Panda | 4,985 | 301 | 6.04% | USD 13.8K |
| The Original Mr. Fuzzy | 24,226 | 1,237 | 5.11% | USD 61.8K |
| The Forever Love Bear | 5,796 | 129 | 2.23% | USD 7.7K |
| The Hudson River Mini bear | 5,018 | 64 | 1.28% | USD 1.9K |

- **Sugar Panda has the highest refund rate** (6.04%) and has stayed around 6% every year.
- **Mr. Fuzzy accounts for 72% of refund value** because of its volume.
- **Mr. Fuzzy had a refund spike in Aug–Sep 2014.** Items sold in those months had a refund rate of 13.8% and 13.3%, compared with roughly 3–5% in other months. Refund amount by refund date peaked in September 2014 at USD 11.8K, the highest month in the dataset. The rate returned to normal from October 2014.
- **Bears sold mainly as gifts or add-ons are returned less.** Love Bear (2.23%) and Mini bear (1.28%) have the lowest refund rates.

## Recommendations

1. **Invest in mobile conversion.** Mobile is almost a third of traffic but converts at about a third of the desktop rate. Testing a new mobile landing page and checkout is likely the largest opportunity.
2. **Review the socialbook pilot.** Pause or rework it before increasing spend; keep `desktop_targeted` under watch.
3. **Keep growing cross-sell.** The Mini bear works well as a high-margin add-on; similar bundles could be tested for Love Bear and Sugar Panda.
4. **Investigate Sugar Panda quality** and the cause of the Aug–Sep 2014 Mr. Fuzzy refund spike (e.g. a supplier or batch issue) so it can be prevented.
5. **Reduce reliance on Mr. Fuzzy and gsearch nonbrand** by growing newer products and brand/direct traffic.
6. **Plan inventory and campaigns for Q4**, when demand is highest.

## Caveats

- These are descriptive results. They show associations, not the causal effect of a campaign, landing page or product change.
- Refund rate is based on the sale date of the item; refund amounts on the Refund page charts use the refund date.
- Sessions without UTM are not necessarily direct traffic: about half have an organic search referer.
- Gross margin is revenue minus COGS and does not include marketing or operating costs.
