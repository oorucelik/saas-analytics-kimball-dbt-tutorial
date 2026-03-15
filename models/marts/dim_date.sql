SELECT
    CAST(range AS DATE) AS date_day,
    year(range) AS date_year,
    month(range) AS date_month,
    monthname(range) AS date_monthname,
    day(range) AS date_dayofmonth,
    dayofweek(range) AS date_dayofweek,
    week(range) AS date_weekofyear,
    dayofyear(range) AS date_dayofyear,
    CAST(CASE WHEN dayofweek(range) IN (0, 6) THEN 1 ELSE 0 END AS BOOLEAN) AS date_is_weekend
FROM 
    (
        {{ dbt_utils.date_spine(
            datepart="day",
            start_date="2023-01-01",
            end_date="2025-01-01"
            )
        }}
    ) AS date_series