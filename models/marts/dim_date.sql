SELECT
    CAST(strftime(date_day, '%Y%m%d') AS INT) AS date_key,
    CAST(date_day AS DATE) AS date_day,
    year(date_day) AS date_year,
    month(date_day) AS date_month,
    monthname(date_day) AS date_monthname,
    day(date_day) AS date_dayofmonth,
    dayofweek(date_day) AS date_dayofweek,
    week(date_day) AS date_weekofyear,
    dayofyear(date_day) AS date_dayofyear,
    CAST(CASE WHEN dayofweek(date_day) IN (0, 6) THEN 1 ELSE 0 END AS BOOLEAN) AS date_is_weekend
FROM 
    ({{ dbt_utils.date_spine(
            datepart="day",
            start_date="CAST('2023-01-01' AS TIMESTAMP)",
            end_date="CAST('2025-01-01' AS TIMESTAMP)",
            )}}
    ) AS date_series