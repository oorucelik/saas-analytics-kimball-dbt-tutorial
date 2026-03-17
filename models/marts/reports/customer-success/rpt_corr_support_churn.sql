with all_accounts as (
    select account_id from {{ref('stg_accounts')}}
),

churn_counts as (
    select 
        account_id,
        COUNT(churn_event_id) as total_churn
    from {{ref('stg_churn_events')}}
    group by 1
),

support_counts as (
    select 
        account_id,
        COUNT(ticket_id) as total_tickets
    from {{ref('stg_support_tickets')}}
    --where resolution_time_hours > (select avg(resolution_time_hours) from {{ref('stg_support_tickets')}})
    --and satisfaction_score < (select avg(satisfaction_score) from {{ref('stg_support_tickets')}})
    --and is_escalated = true
    --and priority = 'high'
    --and first_response_time_minutes > (select avg(first_response_time_minutes) from {{ref('stg_support_tickets')}})

    group by 1
),

final_metrics as (
    select
        a.account_id,
        coalesce(c.total_churn,0) as total_churn,
        coalesce(s.total_tickets,0) as total_tickets
    from all_accounts a
    left join churn_counts c
        on a.account_id = c.account_id
    left join support_counts s
        on a.account_id = s.account_id
)

select 
    --corr(total_churn, total_tickets) as churn_support_corr,
    *
from final_metrics

