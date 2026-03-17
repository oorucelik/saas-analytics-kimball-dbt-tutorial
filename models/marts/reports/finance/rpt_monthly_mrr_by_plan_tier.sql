with monthly_mrr as (
    select
        date_trunc('month', start_date) as start_month,
        plan_tier,
        sum(mrr_amount) as mrr_amount
    from {{ref('stg_subscriptions')}}
    group by 1,2
),

mrr_with_totals as (
    select 
        start_month,
        plan_tier,
        mrr_amount,
        sum(mrr_amount) over (partition by start_month) as total_monthly_mrr
    from monthly_mrr
)

select
    start_month,
    plan_tier,
    mrr_amount,
    round(100.0 * mrr_amount/total_monthly_mrr, 2) as mrr_percentage
from mrr_with_totals
order by start_month, plan_tier, mrr_percentage desc
