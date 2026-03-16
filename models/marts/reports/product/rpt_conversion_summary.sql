with funnel_events as (
    select
        account_id,
        date_trunc('month', start_date) as start_month,
        plan_tier,
        min(case when is_trial = true then start_date end) as trial_start_date,
        min(case when is_trial = false and start_date is not null then start_date end) as paid_start_date,
        min(case when is_upgrade = true then start_date end) as upgrade_date,
        min(case when is_downgrade = true then start_date end) as downgrade_date,
        min(case when has_churned = true then start_date end) as churn_date
    from {{ref('stg_subscriptions')}}
    group by 1,2,3
),
monthly_funnel_counts as (
    select
        start_month,
        plan_tier,
        count(distinct case when trial_start_date is not null then account_id end) as trial_accounts,
        count(distinct case when paid_start_date is not null then account_id end) as paid_accounts,
        count(distinct case when upgrade_date is not null then account_id end) as upgrade_accounts,
        count(distinct case when downgrade_date is not null then account_id end) as downgrade_accounts,
        count(distinct case when churn_date is not null then account_id end) as churn_accounts
    from funnel_events
    group by 1,2
)
select 
    start_month,
    plan_tier,
    trial_accounts,
    paid_accounts,
    upgrade_accounts,
    downgrade_accounts,
    churn_accounts,
    --positive funnel
    round(100.0 * paid_accounts / trial_accounts, 2) as trial_to_paid_conversion_rate,
    round(100.0 * upgrade_accounts / trial_accounts, 2) as trial_to_upgrade_conversion_rate,
    round(100.0 * upgrade_accounts / paid_accounts, 2) as paid_to_upgrade_conversion_rate,
    --negative funnel
    round(100.0 * (paid_accounts - upgrade_accounts) / paid_accounts, 2) as paid_to_non_upgrade_conversion_rate,
    --loyalty funnel
    round(100.0 * (paid_accounts - downgrade_accounts) / paid_accounts, 2) as paid_to_non_downgrade_conversion_rate,
    round(100.0 * (paid_accounts - churn_accounts) / paid_accounts, 2) as paid_to_non_churn_conversion_rate,
    --churn funnel
    round(100.0 * downgrade_accounts / paid_accounts, 2) as paid_to_downgrade_conversion_rate,
    round(100.0 * churn_accounts / paid_accounts, 2) as paid_to_churn_conversion_rate
from monthly_funnel_counts
order by 1,2