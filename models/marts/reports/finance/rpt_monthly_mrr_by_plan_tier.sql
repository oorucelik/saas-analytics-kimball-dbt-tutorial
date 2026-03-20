with monthly_mrr as (
    select
        date_trunc('month', start_date) as start_month,
        plan_tier,
        plan_tier_rank,
        sum(mrr_amount) as mrr_amount
    from {{ref('fct_subscriptions')}}
    group by 1,2,3
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
order by start_month, plan_tier_rank DESC