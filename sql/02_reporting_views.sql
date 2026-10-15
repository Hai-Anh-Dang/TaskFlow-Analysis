/*
TaskFlow reporting layer. Source tables remain unchanged.
Analysis cutoff: 31 December 2025. All observations are synthetic.
Run against the TaskFlow database. GO separates SSMS/sqlcmd batches.

Monthly opening populations are carried forward from the preceding day.
Monthly closing populations are carried forward after month-end changes.
Date-only subscription transitions cannot establish intraday event ordering.
Higher-price exposure means a recorded renewal invoice/payment, not notice receipt.
Updated 1 October 2026: existing view contracts are retained for Power BI.
The calendar-month deletion comparison is a separate view with a new definition.
*/
USE [TaskFlow];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'taskflow_reporting') IS NULL
    EXEC(N'CREATE SCHEMA taskflow_reporting AUTHORIZATION dbo;');
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_users
AS
WITH first_pro AS (
    SELECT user_id, MIN(start_date) AS first_pro_start
    FROM dbo.Subscription_History
    WHERE tier = 'Pro'
    GROUP BY user_id
)
SELECT u.*,
       DATEFROMPARTS(YEAR(u.registration_date), MONTH(u.registration_date), 1) AS cohort_month,
       p.first_pro_start,
       CONVERT(int, CASE WHEN DATEADD(day, 90, u.registration_date) <= CONVERT(date, '20251231', 112)
                        THEN 1 ELSE 0 END) AS eligible_90d,
       CONVERT(int, CASE WHEN DATEADD(day, 90, u.registration_date) > CONVERT(date, '20251231', 112)
                        THEN NULL
                        WHEN p.first_pro_start >= u.registration_date
                         AND p.first_pro_start <= DATEADD(day, 90, u.registration_date)
                        THEN 1 ELSE 0 END) AS converted_90d,
       CONVERT(int, CASE WHEN DATEADD(day, 90, EOMONTH(u.registration_date)) <= CONVERT(date, '20251231', 112)
                        THEN 1 ELSE 0 END) AS cohort_fully_mature
FROM dbo.Users AS u
LEFT JOIN first_pro AS p ON p.user_id = u.user_id;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_activity_events
AS
SELECT a.*,
       CONVERT(date, a.[timestamp]) AS event_date,
       s.tier AS tier_at_event_time,
       COALESCE(s.tier_match_count, 0) AS tier_match_count,
       CONVERT(int, CASE WHEN a.result = 'success'
                         AND a.action IN ('task_completed', 'workflow_completed', 'first_task_completed',
                                          'report_viewed', 'reminder_set')
                        THEN 1 ELSE 0 END) AS meaningful_action,
       CONVERT(int, CASE WHEN s.tier = 'Free'
                         AND a.action IN ('allowance_reached', 'action_blocked')
                        THEN 1 ELSE 0 END) AS restriction_block,
       CONVERT(int, CASE WHEN a.action IN ('sync_completed', 'sync_failed') THEN 1 ELSE 0 END) AS sync_outcome,
       CONVERT(int, CASE WHEN a.action = 'sync_failed' THEN 1 ELSE 0 END) AS sync_failure
FROM dbo.Activity_Events AS a
OUTER APPLY (
    SELECT TOP (1) h.tier, COUNT(*) OVER () AS tier_match_count
    FROM dbo.Subscription_History AS h
    WHERE h.user_id = a.user_id
      AND h.start_date <= CONVERT(date, a.[timestamp])
      AND (h.end_date IS NULL OR h.end_date >= CONVERT(date, a.[timestamp]))
    ORDER BY h.start_date DESC, h.subscription_id DESC
) AS s;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_subscription_history
AS
WITH pro_entries AS (
    SELECT subscription_id,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY start_date, subscription_id) AS pro_entry_number
    FROM dbo.Subscription_History
    WHERE tier = 'Pro'
), invoice_exposure AS (
    SELECT subscription_id, MIN(issue_date) AS first_higher_price_invoice_date
    FROM dbo.Invoices
    WHERE actual_price >= 14.99
    GROUP BY subscription_id
), payment_exposure AS (
    SELECT i.subscription_id,
           CONVERT(date, MIN(p.[timestamp])) AS first_successful_higher_price_payment_date
    FROM dbo.Invoices AS i
    INNER JOIN dbo.Payment_Transactions AS p ON p.invoice_id = i.invoice_id
    WHERE i.actual_price >= 14.99
      AND p.[status] = 'Success'
      AND p.transaction_type = 'Payment'
    GROUP BY i.subscription_id
)
SELECT h.*, e.pro_entry_number,
       i.first_higher_price_invoice_date,
       p.first_successful_higher_price_payment_date
FROM dbo.Subscription_History AS h
LEFT JOIN pro_entries AS e ON e.subscription_id = h.subscription_id
LEFT JOIN invoice_exposure AS i ON i.subscription_id = h.subscription_id
LEFT JOIN payment_exposure AS p ON p.subscription_id = h.subscription_id;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_user_month
AS
WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR(d.[date]), MONTH(d.[date]), 1) AS month_start,
                    EOMONTH(d.[date]) AS month_end
    FROM dbo.[Date] AS d
    WHERE d.[date] BETWEEN CONVERT(date, '20230101', 112) AND CONVERT(date, '20251231', 112)
), user_months AS (
    SELECT u.user_id, u.signup_platform AS platform, u.registration_date,
           u.account_deletion_date, u.cohort_month, m.month_start, m.month_end
    FROM taskflow_reporting.vw_users AS u
    INNER JOIN months AS m
        ON u.registration_date <= m.month_end
       AND (u.account_deletion_date IS NULL OR u.account_deletion_date >= m.month_start)
), activity AS (
    SELECT user_id, DATEFROMPARTS(YEAR([timestamp]), MONTH([timestamp]), 1) AS month_start,
           COUNT(*) AS event_count,
           SUM(CASE WHEN result = 'success'
                     AND action IN ('task_completed', 'workflow_completed', 'first_task_completed',
                                    'report_viewed', 'reminder_set')
                    THEN 1 ELSE 0 END) AS meaningful_action_count
    FROM dbo.Activity_Events
    GROUP BY user_id, DATEFROMPARTS(YEAR([timestamp]), MONTH([timestamp]), 1)
), subscription_months AS (
    SELECT um.user_id, um.month_start,
           MAX(CASE WHEN h.start_date < um.month_start
                     AND (h.end_date IS NULL OR h.end_date >= um.month_start)
                    THEN 1 ELSE 0 END) AS opening_pro,
           MAX(CASE WHEN h.start_date <= um.month_end
                     AND (h.end_date IS NULL OR h.end_date > um.month_end)
                    THEN 1 ELSE 0 END) AS closing_pro,
           SUM(CASE WHEN h.start_date BETWEEN um.month_start AND um.month_end
                     AND h.pro_entry_number = 1 THEN 1 ELSE 0 END) AS first_upgrades,
           SUM(CASE WHEN h.start_date BETWEEN um.month_start AND um.month_end
                     AND h.pro_entry_number > 1 THEN 1 ELSE 0 END) AS repeat_upgrades,
           SUM(CASE WHEN h.[status] = 'Cancelled'
                     AND h.cancellation_effective_date BETWEEN um.month_start AND um.month_end
                    THEN 1 ELSE 0 END) AS pro_cancellations,
           SUM(CASE WHEN h.[status] = 'Ended (account deleted)'
                     AND h.end_date BETWEEN um.month_start AND um.month_end
                    THEN 1 ELSE 0 END) AS pro_deletion_exits,
           MAX(CASE WHEN h.[status] = 'Cancelled'
                     AND h.cancellation_effective_date BETWEEN um.month_start AND um.month_end
                    THEN 1 ELSE 0 END) AS has_pro_cancellation
    FROM user_months AS um
    LEFT JOIN taskflow_reporting.vw_subscription_history AS h
        ON h.user_id = um.user_id AND h.tier = 'Pro'
    GROUP BY um.user_id, um.month_start
)
SELECT um.user_id, um.platform, um.month_start, um.month_end, um.cohort_month,
       DATEDIFF(month, um.cohort_month, um.month_start) AS cohort_age_months,
       COALESCE(a.event_count, 0) AS event_count,
       COALESCE(a.meaningful_action_count, 0) AS meaningful_action_count,
       CONVERT(int, CASE WHEN um.registration_date BETWEEN um.month_start AND um.month_end
                        THEN 1 ELSE 0 END) AS is_new_this_month,
       CONVERT(int, CASE WHEN um.registration_date < um.month_start
                         AND (um.account_deletion_date IS NULL OR um.account_deletion_date >= um.month_start)
                        THEN 1 ELSE 0 END) AS opening_accounts,
       CONVERT(int, CASE WHEN um.registration_date <= um.month_end
                         AND (um.account_deletion_date IS NULL OR um.account_deletion_date > um.month_end)
                        THEN 1 ELSE 0 END) AS closing_accounts,
       s.opening_pro, s.closing_pro, s.first_upgrades, s.repeat_upgrades,
       s.pro_cancellations, s.pro_deletion_exits,
       s.opening_pro * s.has_pro_cancellation AS opening_pro_cancellations,
       CONVERT(int, CASE WHEN um.account_deletion_date BETWEEN um.month_start AND um.month_end
                        THEN 1 ELSE 0 END) AS account_deletions,
       CONVERT(int, CASE WHEN um.account_deletion_date BETWEEN um.month_start AND um.month_end
                         AND um.registration_date < um.month_start
                        THEN 1 ELSE 0 END) AS opening_account_deletions
FROM user_months AS um
LEFT JOIN activity AS a ON a.user_id = um.user_id AND a.month_start = um.month_start
INNER JOIN subscription_months AS s ON s.user_id = um.user_id AND s.month_start = um.month_start;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_fact_journey
AS
WITH attempts AS (
    SELECT user_id, session_id, journey_id,
           MIN([timestamp]) AS first_event_ts, MAX([timestamp]) AS last_event_ts,
           MIN(CASE WHEN action = 'workflow_started' THEN [timestamp] END) AS start_ts,
           MAX(CASE WHEN action IN ('workflow_completed', 'action_failed') THEN [timestamp] END) AS terminal_ts,
           MIN(feature) AS feature, MIN(platform) AS platform, MIN(interface_variant) AS interface_variant,
           COUNT(*) AS event_count, COUNT(DISTINCT [timestamp]) AS distinct_timestamps,
           COUNT(DISTINCT feature) AS feature_count,
           COUNT(DISTINCT platform) AS platform_count,
           COUNT(DISTINCT interface_variant) AS interface_variant_count,
           SUM(CASE WHEN action = 'workflow_started' THEN 1 ELSE 0 END) AS start_count,
           SUM(CASE WHEN action = 'workflow_completed' THEN 1 ELSE 0 END) AS completed_count,
           SUM(CASE WHEN action = 'action_failed' THEN 1 ELSE 0 END) AS failed_count
    FROM dbo.Activity_Events
    WHERE journey_id IS NOT NULL AND journey_id <> ''
    GROUP BY user_id, session_id, journey_id
), checked AS (
    SELECT *, completed_count + failed_count AS terminal_count,
           CONVERT(int, CASE WHEN start_count = 1
                             AND completed_count + failed_count <= 1
                             AND first_event_ts = start_ts
                             AND (terminal_ts IS NULL OR terminal_ts = last_event_ts)
                             AND event_count = distinct_timestamps
                             AND feature_count = 1 AND platform_count = 1 AND interface_variant_count = 1
                            THEN 1 ELSE 0 END) AS is_valid_attempt
    FROM attempts
)
SELECT CONCAT(CONVERT(varchar(20), user_id), '|', session_id, '|', journey_id) AS attempt_key,
       user_id, session_id, journey_id,
       CONVERT(date, COALESCE(start_ts, first_event_ts)) AS start_date,
       start_ts, first_event_ts, last_event_ts, terminal_ts,
       feature, platform, interface_variant,
       event_count, start_count, terminal_count, completed_count, failed_count,
       event_count - distinct_timestamps AS timestamp_tie_count,
       feature_count, platform_count, interface_variant_count, is_valid_attempt,
       CASE WHEN is_valid_attempt = 0 THEN 'Invalid'
            WHEN completed_count = 1 THEN 'Completed'
            WHEN failed_count = 1 THEN 'Failed'
            ELSE 'Abandoned' END AS outcome
FROM checked;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_fact_checkout
AS
WITH attempts AS (
    SELECT user_id, checkout_id,
           MIN([timestamp]) AS first_event_ts, MAX([timestamp]) AS last_event_ts,
           MIN(CASE WHEN action = 'checkout_started' THEN [timestamp] END) AS start_ts,
           MIN(platform) AS platform,
           COUNT(DISTINCT platform) AS platform_count,
           COUNT(*) AS event_count, COUNT(DISTINCT [timestamp]) AS distinct_timestamps,
           SUM(CASE WHEN action = 'checkout_started' THEN 1 ELSE 0 END) AS start_count,
           SUM(CASE WHEN action = 'purchase_completed' AND result = 'success' THEN 1 ELSE 0 END) AS purchase_count,
           SUM(CASE WHEN action = 'payment_submitted' AND result = 'success' THEN 1 ELSE 0 END) AS payment_success_count,
           SUM(CASE WHEN action = 'payment_submitted' AND result = 'failed' THEN 1 ELSE 0 END) AS payment_failure_count,
           SUM(CASE WHEN action = 'step_completed' THEN 1 ELSE 0 END) AS completed_step_events,
           COUNT(DISTINCT CASE WHEN action = 'step_completed'
                               THEN TRY_CONVERT(int, REPLACE(feature, 'Checkout step ', '')) END) AS distinct_completed_steps,
           MIN(CASE WHEN action = 'step_completed'
                    THEN TRY_CONVERT(int, REPLACE(feature, 'Checkout step ', '')) END) AS min_step_completed,
           COALESCE(MAX(CASE WHEN action = 'step_completed'
                             THEN TRY_CONVERT(int, REPLACE(feature, 'Checkout step ', '')) END), 0) AS max_step_completed
    FROM dbo.Activity_Events
    WHERE checkout_id IS NOT NULL AND checkout_id <> ''
    GROUP BY user_id, checkout_id
), flows AS (
    SELECT *, CASE WHEN COALESCE(start_ts, first_event_ts) < CONVERT(date, '20250601', 112)
                   THEN 'Pre-redesign' ELSE 'Post-redesign' END AS period,
              CASE WHEN COALESCE(start_ts, first_event_ts) < CONVERT(date, '20250601', 112)
                   THEN 2 ELSE 4 END AS n_steps
    FROM attempts
), checked AS (
    SELECT *, CONVERT(int, CASE WHEN start_count = 1 AND first_event_ts = start_ts
                                AND platform_count = 1 AND event_count = distinct_timestamps
                                AND purchase_count <= 1
                                AND payment_success_count + payment_failure_count <= 1
                                AND max_step_completed BETWEEN 0 AND n_steps
                                AND completed_step_events = distinct_completed_steps
                                AND distinct_completed_steps = max_step_completed
                                AND (max_step_completed = 0 OR min_step_completed = 1)
                                AND (purchase_count = 0 OR (max_step_completed = n_steps AND payment_success_count = 1))
                                AND (payment_success_count + payment_failure_count = 0 OR max_step_completed = n_steps)
                               THEN 1 ELSE 0 END) AS is_valid_attempt
    FROM flows
)
SELECT CONCAT(CONVERT(varchar(20), user_id), '|', checkout_id) AS attempt_key,
       user_id, checkout_id, platform,
       CONVERT(date, COALESCE(start_ts, first_event_ts)) AS start_date,
       start_ts, first_event_ts, last_event_ts, period, n_steps,
       event_count, start_count, purchase_count, payment_success_count, payment_failure_count,
       max_step_completed, completed_step_events, is_valid_attempt,
       CASE WHEN is_valid_attempt = 0 THEN 'Invalid'
            WHEN purchase_count = 1 THEN 'Completed'
            WHEN payment_failure_count = 1 THEN 'Payment failed'
            ELSE 'Abandoned' END AS outcome,
       CASE WHEN payment_failure_count > 0 THEN 'Failed'
            WHEN payment_success_count > 0 THEN 'Success'
            ELSE 'Not submitted' END AS payment_outcome
FROM checked;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_checkout_stages
AS
-- Reached stages only. Fixed ordering permits a shared stage dimension across both flows.
SELECT c.attempt_key, c.user_id, c.checkout_id, c.platform, c.start_date,
       c.period, c.n_steps, stages.stage_order, stages.stage
FROM taskflow_reporting.vw_fact_checkout AS c
CROSS APPLY (VALUES
    (0, CONVERT(varchar(30), 'Started')),
    (1, CONVERT(varchar(30), 'Step 1')),
    (2, CONVERT(varchar(30), 'Step 2')),
    (3, CONVERT(varchar(30), 'Step 3')),
    (4, CONVERT(varchar(30), 'Step 4')),
    (5, CONVERT(varchar(30), 'Purchase completed'))
) AS stages(stage_order, stage)
WHERE c.is_valid_attempt = 1
  AND (stages.stage_order = 0
       OR (stages.stage_order BETWEEN 1 AND c.n_steps AND stages.stage_order <= c.max_step_completed)
       OR (stages.stage_order = 5 AND c.purchase_count = 1));
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_sync_followup
AS
-- Fixed exploratory comparison from archived v7. Threshold is an analytical choice.
-- Current export has only four eligible users; group sizes must accompany rates.
WITH exposure AS (
    SELECT user_id, COUNT(*) AS attempts,
           SUM(CASE WHEN action = 'sync_failed' THEN 1 ELSE 0 END) AS failures
    FROM dbo.Activity_Events
    WHERE platform = 'Android' AND action IN ('sync_completed', 'sync_failed')
      AND [timestamp] >= CONVERT(date, '20250701', 112)
      AND [timestamp] < CONVERT(date, '20250901', 112)
    GROUP BY user_id
    HAVING COUNT(*) >= 3
), later AS (
    SELECT DISTINCT user_id
    FROM dbo.Activity_Events
    WHERE [timestamp] >= CONVERT(date, '20250901', 112)
      AND [timestamp] < CONVERT(date, '20260101', 112)
      AND result = 'success'
      AND action IN ('task_completed', 'workflow_completed', 'first_task_completed', 'report_viewed', 'reminder_set')
)
SELECT e.user_id, CONVERT(varchar(10), 'Android') AS platform,
       e.attempts, e.failures,
       CONVERT(decimal(19,6), 1.0 * e.failures / NULLIF(e.attempts, 0)) AS exposure_failure_rate,
       CASE WHEN 1.0 * e.failures / NULLIF(e.attempts, 0) >= 0.2
            THEN 'High failure rate' ELSE 'Low failure rate' END AS exposure_group,
       CONVERT(int, CASE WHEN l.user_id IS NOT NULL THEN 1 ELSE 0 END) AS meaningfully_active_later,
       CONVERT(date, '20250701', 112) AS exposure_start,
       CONVERT(date, '20250901', 112) AS exposure_end_exclusive,
       CONVERT(date, '20250901', 112) AS outcome_start,
       CONVERT(date, '20260101', 112) AS outcome_end_exclusive,
       CONVERT(int, 3) AS minimum_sync_outcomes,
       CONVERT(decimal(4,2), 0.20) AS high_failure_threshold
FROM exposure AS e
LEFT JOIN later AS l ON l.user_id = e.user_id;
GO

-- Legacy 30-day comparison. Retained unchanged for existing Power BI imports.
-- Use vw_deletion_comparison_calendar_month for the revised report comparison.
CREATE OR ALTER VIEW taskflow_reporting.vw_deletion_comparison
AS
/*
One eligible opening account per month. Retained users may appear in multiple months.
The denominator is eligible account-month observations, not unique people over all months.
Index date is deletion date or month end. Lookback is [index - 30 days, index).
The generator omits deletion-month activity; apparent absence of friction is not complete observation.
Comparisons are descriptive, not causal or independently matched case-control evidence.
*/
WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR(d.[date]), MONTH(d.[date]), 1) AS month_start,
                    EOMONTH(d.[date]) AS month_end
    FROM dbo.[Date] AS d
    WHERE d.[date] BETWEEN CONVERT(date, '20230101', 112) AND CONVERT(date, '20251231', 112)
), candidates AS (
    SELECT u.user_id, u.signup_platform AS platform, u.registration_date,
           m.month_start, m.month_end,
           CASE WHEN u.account_deletion_date BETWEEN m.month_start AND m.month_end
                THEN u.account_deletion_date ELSE m.month_end END AS index_date,
           CASE WHEN u.account_deletion_date BETWEEN m.month_start AND m.month_end
                THEN 'Deleted this month' ELSE 'Retained through month end' END AS outcome
    FROM dbo.Users AS u
    INNER JOIN months AS m
        ON u.registration_date < m.month_start
       AND (u.account_deletion_date IS NULL OR u.account_deletion_date >= m.month_start)
), eligible AS (
    SELECT *, DATEADD(day, -30, index_date) AS lookback_start
    FROM candidates
    WHERE registration_date <= DATEADD(day, -30, index_date)
), friction_daily AS (
    SELECT user_id, CONVERT(date, [timestamp]) AS event_date, COUNT(*) AS friction_event_count
    FROM dbo.Activity_Events
    WHERE action IN ('action_blocked', 'allowance_reached', 'sync_failed', 'action_failed')
    GROUP BY user_id, CONVERT(date, [timestamp])
), compared AS (
    SELECT e.user_id, e.platform, e.month_start, e.month_end, e.index_date, e.lookback_start, e.outcome,
           COALESCE(SUM(f.friction_event_count), 0) AS friction_event_count
    FROM eligible AS e
    LEFT JOIN friction_daily AS f
        ON f.user_id = e.user_id AND f.event_date >= e.lookback_start AND f.event_date < e.index_date
    GROUP BY e.user_id, e.platform, e.month_start, e.month_end, e.index_date, e.lookback_start, e.outcome
)
SELECT c.*, CONVERT(int, CASE WHEN c.friction_event_count > 0 THEN 1 ELSE 0 END) AS had_prior_friction,
       CONVERT(int, 30) AS lookback_days,
       h.tier AS tier_at_index
FROM compared AS c
OUTER APPLY (
    SELECT TOP (1) s.tier
    FROM dbo.Subscription_History AS s
    WHERE s.user_id = c.user_id AND s.start_date <= c.index_date
      AND (s.end_date IS NULL OR s.end_date >= c.index_date)
    ORDER BY s.start_date DESC, s.subscription_id DESC
) AS h;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_deletion_comparison_calendar_month
AS
/*
Grain: one eligible account per outcome month, February 2023 to December 2025.
Groups: deleted during that month versus retained through its month end.
Observation: the preceding full calendar month for both groups, [start, end).
Eligibility: registered by observation start and still open at outcome-month start.
January 2023 is excluded because December 2022 observation is unavailable.
Pooled results count account-month observations; retained people can repeat.
No recorded friction is a zero in these files, not proof of complete tracking.
This descriptive comparison does not establish a causal effect of friction.
*/
WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR(d.[date]), MONTH(d.[date]), 1) AS month_start,
                    EOMONTH(d.[date]) AS month_end
    FROM dbo.[Date] AS d
    WHERE d.[date] BETWEEN CONVERT(date, '20230201', 112) AND CONVERT(date, '20251231', 112)
), eligible AS (
    SELECT u.user_id, u.signup_platform AS platform,
           u.registration_date, u.account_deletion_date,
           m.month_start, m.month_end,
           DATEADD(month, -1, m.month_start) AS observation_start,
           m.month_start AS observation_end_exclusive,
           CASE WHEN u.account_deletion_date BETWEEN m.month_start AND m.month_end
                THEN 'Deleted this month' ELSE 'Retained through month end' END AS outcome
    FROM dbo.Users AS u
    INNER JOIN months AS m
        ON u.registration_date <= DATEADD(month, -1, m.month_start)
       AND (u.account_deletion_date IS NULL OR u.account_deletion_date >= m.month_start)
), activity_month AS (
    SELECT user_id,
           DATEFROMPARTS(YEAR([timestamp]), MONTH([timestamp]), 1) AS observation_start,
           COUNT(*) AS recorded_event_count,
           SUM(CASE WHEN action IN ('action_blocked', 'allowance_reached', 'sync_failed', 'action_failed')
                    THEN 1 ELSE 0 END) AS friction_event_count
    FROM dbo.Activity_Events
    WHERE [timestamp] >= CONVERT(date, '20230101', 112)
      AND [timestamp] < CONVERT(date, '20260101', 112)
    GROUP BY user_id, DATEFROMPARTS(YEAR([timestamp]), MONTH([timestamp]), 1)
)
SELECT e.user_id, e.platform, e.month_start, e.month_end,
       e.observation_start, e.observation_end_exclusive,
       DATEDIFF(day, e.observation_start, e.observation_end_exclusive) AS observation_days,
       e.outcome, e.registration_date, e.account_deletion_date,
       COALESCE(a.recorded_event_count, 0) AS recorded_event_count,
       COALESCE(a.friction_event_count, 0) AS friction_event_count,
       CONVERT(int, CASE WHEN COALESCE(a.recorded_event_count, 0) > 0 THEN 1 ELSE 0 END)
           AS had_recorded_activity,
       CONVERT(int, CASE WHEN COALESCE(a.friction_event_count, 0) > 0 THEN 1 ELSE 0 END)
           AS had_prior_friction
FROM eligible AS e
LEFT JOIN activity_month AS a
    ON a.user_id = e.user_id AND a.observation_start = e.observation_start;
GO

CREATE OR ALTER VIEW taskflow_reporting.vw_payments
AS
-- Existing payment view moved from 03_dashboard_queries.sql without changing its contract.
-- Amounts represent recorded renewal transactions; first-upgrade billing is incomplete.
SELECT p.transaction_id, p.invoice_id, p.[timestamp], p.transaction_type,
       CONVERT(decimal(10,2), p.amount) AS amount, p.[status], p.payment_method,
       p.failure_reason, p.original_transaction_ref,
       i.user_id, CONVERT(date, p.[timestamp]) AS payment_date
FROM dbo.Payment_Transactions AS p
LEFT JOIN dbo.Invoices AS i ON i.invoice_id = p.invoice_id;
GO
