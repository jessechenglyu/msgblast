-- Proposed metric: elapsed-day submission retention for recent consent cohorts.
-- Installation IDs intentionally count installations; person profiles are disabled.
SELECT
    target_day AS day,
    countIf(dateDiff('second', cohort_start, now()) >= (target_day + 1) * 86400) AS eligible_installations,
    countIf(dateDiff('second', cohort_start, now()) >= (target_day + 1) * 86400
        AND has(engaged_days, target_day)) AS retained_installations,
    round(100.0 * retained_installations / nullIf(eligible_installations, 0), 1) AS retention_percent
FROM (
    SELECT distinct_id,
        min(toDateTime(properties.cohortStartedAt)) AS cohort_start,
        groupUniqArrayIf(toInt(properties.cohortDay), event = 'app_engaged') AS engaged_days
    FROM events
    WHERE timestamp >= now() - INTERVAL 90 DAY
        AND timestamp <= now()
        AND properties.cohortStartedAt IS NOT NULL
        AND toDateTime(properties.cohortStartedAt) >= now() - INTERVAL 90 DAY
        AND (properties.buildChannel IS NULL OR properties.buildChannel != 'development')
        AND (properties.fixture IS NULL OR properties.fixture = false)
    GROUP BY distinct_id
)
ARRAY JOIN [1, 7, 14, 30] AS target_day
GROUP BY target_day
ORDER BY target_day
