-- ============================================================
-- Sample Analytics Queries — RavenStack SaaS Dimensional Model
-- Run with: dbt show --inline "query" --profiles-dir .
-- ============================================================

-- Q1: MRR Trend by Plan Tier (Monthly)
-- "What is our revenue trend per plan tier?"
SELECT
    date_trunc('month', start_date) AS month,
    plan_tier,
    SUM(mrr_amount) AS total_mrr,
    COUNT(*) AS subscriptions
FROM {{ ref('fct_subscriptions') }}
GROUP BY 1, 2
ORDER BY 1, MIN(plan_tier_rank) DESC;

--Q1.1: MRR Trend by Plan Tier (Monthly) with percentage
--"What is our revenue trend per plan tier as a percentage of total revenue?"
with monthly_mrr as (
    select
        date_trunc('month', start_date) as start_month,
        plan_tier,
        sum(mrr_amount) as mrr_amount
    from {{ref('fct_subscriptions')}}
    group by 1,2
)

select
    start_month as Month,
    plan_tier as Plan,
    mrr_amount as MRR,
    round(
        100.0 * mrr_amount/
        sum(mrr_amount) over (partition by start_month)
        ,1) as MRR_Percent
from monthly_mrr
order by start_month desc, plan_tier_rank desc
limit 9; -- 3 months * 3 plans

-- Q2: Top 5 Most Adopted Features
-- "Which features drive the most engagement?"
SELECT
    feature_name as Feature,
    COUNT(DISTINCT account_key) AS Accounts,
    SUM(usage_count) AS Usage_Count,
    ROUND(AVG(usage_duration_mins), 1) AS Avg_Duration_Minutes
FROM {{ ref('fct_feature_usage') }}
GROUP BY feature_name
ORDER BY Usage_Count DESC
LIMIT 5;


-- Q3: Top Churn Reasons
-- "Why are customers leaving?"
SELECT
    COALESCE(feedback_text,'N/A') as Feedback,
    COUNT(*) AS Total_Churns,
    SUM(CASE WHEN had_preceding_downgrade THEN 1 ELSE 0 END) AS Preceded_by_Downgrade,
    CAST(SUM(refund_amount_usd) AS INT) as Total_Refund,
    ROUND(AVG(refund_amount_usd), 1) AS Avg_Refund
FROM {{ ref('fct_churn') }}
GROUP BY 1
ORDER BY 2 DESC, 4 DESC;


-- Q4: Support Volume vs Churn Correlation
-- "Do accounts with more support tickets churn more?"
SELECT
    a.account_name as Account,
    --a.current_plan_tier,
    a.lifetime_tickets as Total_Tickets,
    a.lifetime_churn_events as Total_Churn,
    ROUND(a.avg_satisfaction_score,1) as Avg_Satisfaction,
    a.has_churned as Churned
FROM {{ ref('dim_account') }} a
WHERE a.lifetime_tickets > 0
ORDER BY a.lifetime_tickets DESC
LIMIT 10;


-- Q5: Trial-to-Paid Conversion Funnel
-- "How well do we convert trials to paying customers?"
WITH subscription_events AS (
    SELECT
        s.account_key,
        p.plan_tier,
        s.start_date,
        s.is_trial,
        -- Identify the first trial date for the cohort bucket
        MIN(CASE WHEN s.is_trial THEN s.start_date END) OVER (PARTITION BY s.account_key) AS first_trial_date,
        -- Flag if this user EVER became a paid customer (Boolean logic in one pass)
        MAX(CASE WHEN NOT s.is_trial THEN 1 ELSE 0 END) OVER (PARTITION BY s.account_key) AS has_ever_converted,
        -- Get the plan tier of their VERY FIRST trial
        FIRST_VALUE(p.plan_tier) OVER (
            PARTITION BY s.account_key 
            ORDER BY CASE WHEN s.is_trial THEN 0 ELSE 1 END, s.start_date ASC
        ) AS cohort_plan_tier
    FROM {{ref('fct_subscriptions')}} s
    JOIN {{ref('dim_plan')}} p ON s.plan_key = p.plan_key
),

-- Step 2: Collapse to one row per account
unique_cohort_members AS (
    SELECT
        account_key,
        DATE_TRUNC('month', first_trial_date) AS cohort_month,
        cohort_plan_tier,
        has_ever_converted
    FROM subscription_events
    WHERE first_trial_date IS NOT NULL  -- Only include users who actually trialed
    GROUP BY 1, 2, 3, 4
)
-- Step 3: Final Aggregation
SELECT
    cohort_month AS Month,
    cohort_plan_tier AS Plan,
    COUNT(*) AS Total_Subscriptions,
    SUM(CASE WHEN is_trial THEN 1 ELSE 0 END) AS Trials,
    SUM(CASE WHEN NOT is_trial THEN 1 ELSE 0 END) AS Paid,
    SUM(CASE WHEN is_upgrade THEN 1 ELSE 0 END) AS Upgrades,
    SUM(CASE WHEN has_churned THEN 1 ELSE 0 END) AS Churned,
    ROUND(100.0 * SUM(CASE WHEN NOT is_trial THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN is_trial THEN 1 ELSE 0 END), 0), 1) AS Trial_to_Paid_Pct
FROM unique_cohort_members
GROUP BY 1,2
ORDER BY 1,2
