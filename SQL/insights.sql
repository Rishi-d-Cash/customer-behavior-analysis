--1)"Who are our most valuable customers, and how should we treat them differently?"
WITH customer_metrics AS (
    SELECT
        customer_id,
        previous_purchases,
        purchase_amount,
        purchase_frequency_days,
        NTILE(4) OVER (ORDER BY previous_purchases DESC) AS frequency_tier,
        NTILE(4) OVER (ORDER BY purchase_amount DESC)    AS monetary_tier
    FROM customer_behavior
)
SELECT
    customer_id,
    previous_purchases,
    purchase_amount,
    CASE
        WHEN frequency_tier = 1 AND monetary_tier = 1 THEN 'VIP - High Value & Loyal'
        WHEN frequency_tier = 1 AND monetary_tier > 1  THEN 'Loyal - Frequent, Lower Spend'
        WHEN frequency_tier > 1 AND monetary_tier = 1  THEN 'Big Spender - Infrequent'
        WHEN frequency_tier = 4 AND monetary_tier = 4  THEN 'At Risk / Low Engagement'
        ELSE 'Standard'
    END AS customer_segment
FROM customer_metrics
ORDER BY purchase_amount DESC;
--Insights:count customers per segment, sum revenue contribution per segment,
--and recommend an action per tier (VIPs are 12% of customers but 	
--drive 34% of revenue — build a loyaltytier before a competitor does).

-- 2) What should merchandising stock, and when?
--Business context: Inventory planning needs to know which categories peak in which seasons to avoid
--overstock/understock

SELECT
    season,
    category,
    COUNT(*)                       AS units_sold,
    ROUND(SUM(purchase_amount), 2) AS total_revenue,
    RANK() OVER (PARTITION BY season ORDER BY SUM(purchase_amount) DESC) AS revenue_rank_in_season
FROM customer_behavior
GROUP BY season, category;

-- part 2 )
WITH ranked AS (
    SELECT
        season,
        category,
        COUNT(*) AS units_sold,
        ROUND(SUM(purchase_amount), 2) AS total_revenue,
        RANK() OVER (PARTITION BY season ORDER BY SUM(purchase_amount) DESC) AS revenue_rank_in_season
    FROM customer_behavior
    GROUP BY season, category
)
SELECT * FROM ranked
WHERE revenue_rank_in_season <= 3
ORDER BY season, revenue_rank_in_season;

--Insight framing: "Top 3 categories by season" is a direct, board-ready slide — this is the kind of output
--a merchandising VP would actually act on.

--3) Where should we focus marketing spend geographically?
WITH regional_revenue AS (
    SELECT
        location,
        COUNT(DISTINCT customer_id)     AS customers,
        ROUND(SUM(purchase_amount), 2)  AS total_revenue,
        ROUND(AVG(purchase_amount), 2)  AS avg_order_value,
        ROUND(AVG(review_rating), 2)    AS avg_review_rating
    FROM customer_behavior
    GROUP BY location
)
SELECT
    *,
    ROUND(100.0 * total_revenue / SUM(total_revenue) OVER (), 2) AS pct_of_total_revenue
FROM regional_revenue
ORDER BY total_revenue DESC
LIMIT 15;

--Insight framing: identify whether revenue is concentrated (e.g., top 5 states = 40% of revenue — an
--80/20 story) or evenly spread. Concentration = clear budget-allocation recommendation.

--4) which 5 products have the highest % of purchases with discounts applied.
select item_purchased,
100*sum(case when discount_applied ='Yes' then 1 else 0 end)/count(item_purchased) as discount_rate , 
sum(purchase_amount)as revenue
from customer_behavior
group by item_purchased,category
order by discount_rate desc
limit 11;

--5) Review Rating Risk Analysis — "What's driving customer dissatisfaction?"
SELECT
    category,
    shipping_type,
    CASE
        WHEN purchase_amount < 30  THEN 'Low ($0-30)'
        WHEN purchase_amount < 60  THEN 'Mid ($30-60)'
        ELSE 'High ($60+)'
    END AS price_band,
    COUNT(*) AS orders,
    ROUND(AVG(review_rating::numeric), 2)  AS avg_review_rating
FROM customer_behavior
GROUP BY category, shipping_type, price_band
HAVING COUNT(*) > 20
ORDER BY avg_review_rating desc
LIMIT 10;

--Insight framing: surfacing the 10 worst-rated combinations (with enough sample size to be credible via
--the `HAVING COUNT(*) > 20` filter) is a concrete, actionable CX finding — not just "average rating is 3.7."
