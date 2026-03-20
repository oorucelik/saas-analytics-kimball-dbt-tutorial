select 
    round(corr(lifetime_churn_events, lifetime_tickets), 4) as Churn_Ticket_Correlation, 
    count(*) as Total_Accounts, 
    count(case when lifetime_tickets > 0 and lifetime_churn_events > 0 then 1 end) as Accounts_With_Both, 
    round(avg(lifetime_tickets),1) as Avg_Tickets, 
    round(avg(lifetime_churn_events),1) as Avg_Churns 
from {{ref('dim_account')}}