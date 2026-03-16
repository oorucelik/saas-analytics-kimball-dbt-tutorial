with feature_usage as (
    select 
        usage_key,
        feature_name,
        usage_count
    from {{ref('fct_feature_usage')}}
)

select
    feature_name,
    SUM(usage_count) as total_usage
from feature_usage
group by feature_name
order by total_usage asc
