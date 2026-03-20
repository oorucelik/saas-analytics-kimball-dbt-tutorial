WITH subscription_events AS (
    SELECT
        account_key,
        plan_tier,
        start_date,
        is_trial,
        -- Identify the first trial date for the cohort bucket
        MIN(CASE WHEN is_trial THEN start_date END) OVER (PARTITION BY account_key) AS first_trial_date,
        -- Flag if this user EVER became a paid customer (Boolean logic in one pass)
        MAX(CASE WHEN NOT is_trial THEN 1 ELSE 0 END) OVER (PARTITION BY account_key) AS has_ever_converted,
        -- Get the plan tier of their VERY FIRST trial
        FIRST_VALUE(plan_tier) OVER (
            PARTITION BY account_key 
            ORDER BY CASE WHEN is_trial THEN 0 ELSE 1 END, start_date ASC
        ) AS cohort_plan_tier
    FROM {{ref('fct_subscriptions')}}
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
    SUM(has_ever_converted) AS Paid_Subscriptions,
    ROUND(100.0 * SUM(has_ever_converted) / NULLIF(COUNT(*), 0), 2) AS Conversion_Rate
FROM unique_cohort_members
GROUP BY 1, 2
ORDER BY 1, 2