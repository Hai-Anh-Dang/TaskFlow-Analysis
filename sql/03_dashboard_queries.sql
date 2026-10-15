/*
TaskFlow SQL investigation query pack | Updated 1 October 2026.
Run after 02_reporting_views.sql against the synthetic TaskFlow database.
This file only reads data. It does not load sources or create/alter database objects.

Every result set includes a query_id for the report evidence crosswalk.
Q01-Q07 establish operational performance; Q08-Q18 investigate possible explanations.
QA01-QA09 check reconciliation, coverage, and analytical populations.
Rates are fractions (0.10 = 10%); *_pp fields are percentage points (1.0 = 1 pp).
Count zero means no record in the covered source period. Undefined rates remain NULL.
Stocks, distinct users, cohort denominators and rates must not be summed across months.
@Platform filters users by signup platform; this synthetic dataset has no switching.
Workflow-specific filters use the actual platform/feature recorded on the attempt.
No hypothesis verdict or causal inference is implied by the returned comparisons.
*/
USE [TaskFlow];
GO
SET NOCOUNT ON;

/* Edit these inputs. Dates for monthly rates must cover complete calendar months.
   The observed source period is fixed at 2023-01-01 through 2025-12-31.
   Keep declarations and queries in one batch: do not insert GO below this line. */
DECLARE @AnalysisStart date = '20230101';
DECLARE @AnalysisEnd date = '20251231';
DECLARE @StartDate date = '20250101';
DECLARE @EndDate date = '20251231';
DECLARE @KpiMonth date = '20251201';
DECLARE @Platform nvarchar(20) = NULL;       -- NULL = all signup platforms.
DECLARE @WorkflowPlatform nvarchar(20) = NULL; -- Set 'Web' for the documented scoped panel.
DECLARE @WorkflowFeature nvarchar(100) = NULL; -- Set 'Tasks' with Web for that panel.
DECLARE @CheckoutStart date = '20230101';    -- Canonical whole-history flow comparison.
DECLARE @CheckoutEnd date = '20251231';

IF @AnalysisStart IS NULL OR @AnalysisEnd IS NULL
   OR @AnalysisStart <> CONVERT(date, '20230101', 112)
   OR @AnalysisEnd <> CONVERT(date, '20251231', 112)
   OR @StartDate IS NULL OR @EndDate IS NULL OR @KpiMonth IS NULL
   OR @CheckoutStart IS NULL OR @CheckoutEnd IS NULL
   OR @StartDate < @AnalysisStart OR @EndDate > @AnalysisEnd
   OR @StartDate > @EndDate
   OR DAY(@StartDate) <> 1 OR @EndDate <> EOMONTH(@EndDate)
   OR @KpiMonth < @AnalysisStart OR @KpiMonth > @AnalysisEnd OR DAY(@KpiMonth) <> 1
   OR @CheckoutStart < @AnalysisStart OR @CheckoutEnd > @AnalysisEnd
   OR @CheckoutStart > @CheckoutEnd
BEGIN
    ;THROW 50001, 'Keep fixed source coverage 2023-01-01 to 2025-12-31. Required dates cannot be NULL; use ordered covered dates and full monthly boundaries.', 1;
END;

IF @WorkflowPlatform IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.Activity_Events WHERE platform = @WorkflowPlatform AND journey_id IS NOT NULL
)
BEGIN
    ;THROW 50003, 'Unknown recorded workflow platform. Use NULL or a recorded platform.', 1;
END;
IF @WorkflowFeature IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.Activity_Events WHERE feature = @WorkflowFeature AND journey_id IS NOT NULL
)
BEGIN
    ;THROW 50004, 'Unknown recorded workflow feature. Use NULL or a recorded feature.', 1;
END;
IF @Platform IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Users WHERE signup_platform = @Platform)
BEGIN
    ;THROW 50002, 'Unknown signup platform. Use NULL, Web, iOS, or Android.', 1;
END;

/* Q01 | Monthly operational baseline.
   Grain: calendar month. Population: registered accounts open at any point that month.
   Active users have any recorded event. Meaningful actions exclude purchase completion.
   Cancellation risk uses DISTINCT opening Pro users, not all cancellation event rows.
   LAG operates over the full history before the requested display period is filtered. */
;WITH calendar AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] BETWEEN @AnalysisStart AND @AnalysisEnd
), monthly AS (
    SELECT month_start,
           SUM(is_new_this_month) AS registrations,
           SUM(CASE WHEN event_count > 0 THEN 1 ELSE 0 END) AS observed_active_users,
           SUM(CASE WHEN event_count > 0 AND is_new_this_month = 1 THEN 1 ELSE 0 END) AS new_active_users,
           SUM(CASE WHEN event_count > 0 AND is_new_this_month = 0 THEN 1 ELSE 0 END) AS returning_active_users,
           SUM(CASE WHEN meaningful_action_count > 0 THEN 1 ELSE 0 END) AS meaningfully_active_users,
           SUM(meaningful_action_count) AS meaningful_actions,
           SUM(opening_accounts) AS opening_accounts,
           SUM(account_deletions) AS account_deletions,
           SUM(opening_account_deletions) AS opening_account_deletions,
           SUM(closing_accounts) AS closing_accounts,
           SUM(opening_pro) AS opening_pro, SUM(first_upgrades) AS first_upgrades,
           SUM(repeat_upgrades) AS repeat_upgrades,
           SUM(pro_cancellations) AS cancellation_events,
           SUM(pro_deletion_exits) AS pro_deletion_exits,
           SUM(closing_pro) AS closing_pro,
           SUM(opening_pro_cancellations) AS opening_pro_cancellers
    FROM taskflow_reporting.vw_user_month
    WHERE @Platform IS NULL OR platform = @Platform
    GROUP BY month_start
), rates AS (
    SELECT c.month_start, COALESCE(m.registrations, 0) AS registrations,
           COALESCE(m.observed_active_users, 0) AS observed_active_users,
           COALESCE(m.new_active_users, 0) AS new_active_users,
           COALESCE(m.returning_active_users, 0) AS returning_active_users,
           COALESCE(m.meaningfully_active_users, 0) AS meaningfully_active_users,
           COALESCE(m.meaningful_actions, 0) AS meaningful_actions,
           COALESCE(m.opening_accounts, 0) AS opening_accounts,
           COALESCE(m.account_deletions, 0) AS account_deletions,
           COALESCE(m.opening_account_deletions, 0) AS opening_account_deletions,
           COALESCE(m.closing_accounts, 0) AS closing_accounts,
           COALESCE(m.opening_pro, 0) AS opening_pro,
           COALESCE(m.first_upgrades, 0) AS first_upgrades,
           COALESCE(m.repeat_upgrades, 0) AS repeat_upgrades,
           COALESCE(m.cancellation_events, 0) AS cancellation_events,
           COALESCE(m.pro_deletion_exits, 0) AS pro_deletion_exits,
           COALESCE(m.closing_pro, 0) AS closing_pro,
           COALESCE(m.opening_pro_cancellers, 0) AS opening_pro_cancellers,
           1.0 * m.meaningfully_active_users / NULLIF(m.observed_active_users, 0) AS meaningful_share_of_active,
           1.0 * m.meaningful_actions / NULLIF(m.meaningfully_active_users, 0) AS actions_per_meaningfully_active_user,
           1.0 * m.opening_pro_cancellers / NULLIF(m.opening_pro, 0) AS paid_cancellation_rate,
           1.0 * m.opening_account_deletions / NULLIF(m.opening_accounts, 0) AS account_deletion_rate
    FROM calendar AS c LEFT JOIN monthly AS m ON m.month_start = c.month_start
), compared AS (
    SELECT *,
           LAG(registrations, 1) OVER (ORDER BY month_start) AS prior_registrations,
           LAG(registrations, 12) OVER (ORDER BY month_start) AS prior_year_registrations,
           LAG(observed_active_users, 1) OVER (ORDER BY month_start) AS prior_active_users,
           LAG(observed_active_users, 12) OVER (ORDER BY month_start) AS prior_year_active_users,
           LAG(closing_pro, 1) OVER (ORDER BY month_start) AS prior_closing_pro,
           LAG(closing_pro, 12) OVER (ORDER BY month_start) AS prior_year_closing_pro,
           LAG(paid_cancellation_rate, 1) OVER (ORDER BY month_start) AS prior_paid_cancellation_rate,
           LAG(paid_cancellation_rate, 12) OVER (ORDER BY month_start) AS prior_year_paid_cancellation_rate
    FROM rates
)
SELECT 'Q01' AS query_id, COALESCE(@Platform, 'All') AS platform_scope, *,
       registrations - account_deletions AS net_account_change,
       1.0 * (registrations - prior_registrations) / NULLIF(prior_registrations, 0) AS registrations_mom,
       1.0 * (registrations - prior_year_registrations) / NULLIF(prior_year_registrations, 0) AS registrations_yoy,
       1.0 * (observed_active_users - prior_active_users) / NULLIF(prior_active_users, 0) AS active_users_mom,
       1.0 * (observed_active_users - prior_year_active_users) / NULLIF(prior_year_active_users, 0) AS active_users_yoy,
       1.0 * (closing_pro - prior_closing_pro) / NULLIF(prior_closing_pro, 0) AS closing_pro_mom,
       1.0 * (closing_pro - prior_year_closing_pro) / NULLIF(prior_year_closing_pro, 0) AS closing_pro_yoy,
       100.0 * (paid_cancellation_rate - prior_paid_cancellation_rate) AS cancellation_mom_pp,
       100.0 * (paid_cancellation_rate - prior_year_paid_cancellation_rate) AS cancellation_yoy_pp
FROM compared
WHERE month_start BETWEEN @StartDate AND @EndDate
ORDER BY month_start;

/* Q02 | Four KPI cards at @KpiMonth, independent of the displayed trend period.
   Counts/stocks use relative MoM/YoY. Cancellation-rate changes use pp, not relative percent. */
;WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] BETWEEN @AnalysisStart AND @AnalysisEnd
), monthly AS (
    SELECT month_start, SUM(is_new_this_month) AS new_users,
           SUM(CASE WHEN event_count > 0 THEN 1 ELSE 0 END) AS active_users,
           SUM(closing_pro) AS closing_pro,
           1.0 * SUM(opening_pro_cancellations) / NULLIF(SUM(opening_pro), 0) AS paid_cancellation_rate
    FROM taskflow_reporting.vw_user_month
    WHERE @Platform IS NULL OR platform = @Platform
    GROUP BY month_start
), aligned AS (
    SELECT d.month_start, COALESCE(m.new_users, 0) AS new_users,
           COALESCE(m.active_users, 0) AS active_users, COALESCE(m.closing_pro, 0) AS closing_pro,
           m.paid_cancellation_rate
    FROM months AS d LEFT JOIN monthly AS m ON m.month_start = d.month_start
)
SELECT 'Q02' AS query_id, c.month_start AS kpi_month, COALESCE(@Platform, 'All') AS platform_scope,
       c.new_users, c.active_users, c.closing_pro, c.paid_cancellation_rate,
       p.new_users AS prior_new_users, y.new_users AS prior_year_new_users,
       p.active_users AS prior_active_users, y.active_users AS prior_year_active_users,
       p.closing_pro AS prior_closing_pro, y.closing_pro AS prior_year_closing_pro,
       p.paid_cancellation_rate AS prior_paid_cancellation_rate,
       y.paid_cancellation_rate AS prior_year_paid_cancellation_rate,
       1.0 * (c.new_users - p.new_users) / NULLIF(p.new_users, 0) AS new_users_mom,
       1.0 * (c.new_users - y.new_users) / NULLIF(y.new_users, 0) AS new_users_yoy,
       1.0 * (c.active_users - p.active_users) / NULLIF(p.active_users, 0) AS active_users_mom,
       1.0 * (c.active_users - y.active_users) / NULLIF(y.active_users, 0) AS active_users_yoy,
       1.0 * (c.closing_pro - p.closing_pro) / NULLIF(p.closing_pro, 0) AS closing_pro_mom,
       1.0 * (c.closing_pro - y.closing_pro) / NULLIF(y.closing_pro, 0) AS closing_pro_yoy,
       100.0 * (c.paid_cancellation_rate - p.paid_cancellation_rate) AS cancellation_mom_pp,
       100.0 * (c.paid_cancellation_rate - y.paid_cancellation_rate) AS cancellation_yoy_pp
FROM aligned AS c
LEFT JOIN aligned AS p ON p.month_start = DATEADD(month, -1, c.month_start)
LEFT JOIN aligned AS y ON y.month_start = DATEADD(year, -1, c.month_start)
WHERE c.month_start = @KpiMonth;

/* Q03 | Meaningful-activity cohort retention, original registered cohort denominator.
   Cohorts follow @StartDate/@EndDate; observation can continue to the analysis cutoff.
   Future ages are NULL. Deleted users remain in the original cohort denominator. */
;WITH cohorts AS (
    SELECT cohort_month, COUNT(*) AS original_cohort_users
    FROM taskflow_reporting.vw_users
    WHERE cohort_month BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR signup_platform = @Platform)
    GROUP BY cohort_month
), ages AS (
    SELECT DISTINCT DATEDIFF(month, @AnalysisStart,
               DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)) AS cohort_age_months
    FROM dbo.[Date] WHERE [date] BETWEEN @AnalysisStart AND @AnalysisEnd
), active AS (
    SELECT cohort_month, cohort_age_months,
           SUM(CASE WHEN meaningful_action_count > 0 THEN 1 ELSE 0 END) AS meaningfully_active_users
    FROM taskflow_reporting.vw_user_month
    WHERE @Platform IS NULL OR platform = @Platform
    GROUP BY cohort_month, cohort_age_months
)
SELECT 'Q03' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       c.cohort_month, a.cohort_age_months,
       DATEADD(month, a.cohort_age_months, c.cohort_month) AS observation_month,
       c.original_cohort_users,
       CASE WHEN DATEADD(month, a.cohort_age_months, c.cohort_month) > @AnalysisEnd
            THEN NULL ELSE COALESCE(v.meaningfully_active_users, 0) END AS meaningfully_active_users,
       CASE WHEN DATEADD(month, a.cohort_age_months, c.cohort_month) > @AnalysisEnd
            THEN NULL ELSE 1.0 * COALESCE(v.meaningfully_active_users, 0) / NULLIF(c.original_cohort_users, 0)
            END AS retention_rate
FROM cohorts AS c CROSS JOIN ages AS a
LEFT JOIN active AS v ON v.cohort_month = c.cohort_month AND v.cohort_age_months = a.cohort_age_months
WHERE a.cohort_age_months IN (0, 3, 6, 9, 12)
ORDER BY c.cohort_month, a.cohort_age_months;

/* Q04 | Monthly ratings and review volume. Reviews are selected sentiment records.
   A month without reviews has review_count=0 and average_rating=NULL. */
;WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] BETWEEN @StartDate AND @EndDate
), reviews AS (
    SELECT DATEFROMPARTS(YEAR(r.review_date), MONTH(r.review_date), 1) AS month_start,
           COUNT(*) AS review_count, AVG(CONVERT(decimal(19,6), r.rating)) AS average_rating
    FROM dbo.Reviews AS r INNER JOIN dbo.Users AS u ON u.user_id = r.user_id
    WHERE r.review_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
    GROUP BY DATEFROMPARTS(YEAR(r.review_date), MONTH(r.review_date), 1)
)
SELECT 'Q04' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       m.month_start, COALESCE(r.review_count, 0) AS review_count, r.average_rating
FROM months AS m LEFT JOIN reviews AS r ON r.month_start = m.month_start
ORDER BY m.month_start;

/* Q05 | Review theme mix. Denominator is selected reviews, not all users. */
;WITH themes AS (
    SELECT r.issue_category, COUNT(*) AS review_count,
           AVG(CONVERT(decimal(19,6), r.rating)) AS average_rating
    FROM dbo.Reviews AS r INNER JOIN dbo.Users AS u ON u.user_id = r.user_id
    WHERE r.review_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
    GROUP BY r.issue_category
)
SELECT 'Q05' AS query_id, @StartDate AS period_start, @EndDate AS period_end,
       COALESCE(@Platform, 'All') AS platform_scope, issue_category, review_count, average_rating,
       1.0 * review_count / NULLIF(SUM(review_count) OVER (), 0) AS share_of_reviews
FROM themes ORDER BY review_count DESC, issue_category;

/* Q06 | Registered accounts by recorded acquisition channel: volume and mix.
   This is signup composition; no visitor denominator, campaign attribution, or spend exists. */
;WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] BETWEEN @StartDate AND @EndDate
), channels AS (
    SELECT DISTINCT acquisition_channel FROM dbo.Users
), registrations AS (
    SELECT DATEFROMPARTS(YEAR(registration_date), MONTH(registration_date), 1) AS month_start,
           acquisition_channel, COUNT(*) AS registrations
    FROM dbo.Users
    WHERE registration_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR signup_platform = @Platform)
    GROUP BY DATEFROMPARTS(YEAR(registration_date), MONTH(registration_date), 1), acquisition_channel
), aligned AS (
    SELECT m.month_start, c.acquisition_channel, COALESCE(r.registrations, 0) AS registrations
    FROM months AS m CROSS JOIN channels AS c
    LEFT JOIN registrations AS r ON r.month_start = m.month_start AND r.acquisition_channel = c.acquisition_channel
)
SELECT 'Q06' AS query_id, COALESCE(@Platform, 'All') AS platform_scope, *,
       1.0 * registrations / NULLIF(SUM(registrations) OVER (PARTITION BY month_start), 0) AS share_of_registrations
FROM aligned ORDER BY month_start, acquisition_channel;

/* Q07 | Registration benchmark against the FULL 2024 monthly average.
   The baseline always includes 12 covered months, including any zero signup month. */
;WITH baseline_months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] >= '20240101' AND [date] < '20250101'
), registrations AS (
    SELECT DATEFROMPARTS(YEAR(registration_date), MONTH(registration_date), 1) AS month_start,
           COUNT(*) AS registrations
    FROM dbo.Users WHERE @Platform IS NULL OR signup_platform = @Platform
    GROUP BY DATEFROMPARTS(YEAR(registration_date), MONTH(registration_date), 1)
), baseline AS (
    SELECT AVG(CONVERT(decimal(19,6), COALESCE(r.registrations, 0))) AS average_monthly_registrations_2024
    FROM baseline_months AS m LEFT JOIN registrations AS r ON r.month_start = m.month_start
), output_months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] BETWEEN @StartDate AND @EndDate
)
SELECT 'Q07' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       m.month_start, COALESCE(r.registrations, 0) AS registrations,
       b.average_monthly_registrations_2024,
       (COALESCE(r.registrations, 0) - b.average_monthly_registrations_2024)
           / NULLIF(b.average_monthly_registrations_2024, 0) AS difference_from_2024_average
FROM output_months AS m CROSS JOIN baseline AS b
LEFT JOIN registrations AS r ON r.month_start = m.month_start ORDER BY m.month_start;

/* Q08 | H1: restriction intensity and exposure-normalised frequency.
   Population: users/events assigned Free at event time using latest-start precedence.
   blocks_per_exposed_user can exceed one. blocks_per_100_free_events is an event share.
   Neither denominator includes Free users with no recorded events. */
;WITH free_events AS (
    SELECT a.*, DATEFROMPARTS(YEAR(a.event_date), MONTH(a.event_date), 1) AS month_start
    FROM taskflow_reporting.vw_activity_events AS a
    INNER JOIN dbo.Users AS u ON u.user_id = a.user_id
    WHERE a.tier_at_event_time = 'Free' AND a.event_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
)
SELECT 'Q08' AS query_id, COALESCE(@Platform, 'All') AS platform_scope, month_start,
       COUNT(*) AS free_events, COUNT(DISTINCT user_id) AS free_exposed_users,
       SUM(restriction_block) AS restriction_events,
       COUNT(DISTINCT CASE WHEN restriction_block = 1 THEN user_id END) AS users_with_restrictions,
       1.0 * SUM(restriction_block) / NULLIF(COUNT(DISTINCT user_id), 0) AS blocks_per_exposed_user,
       100.0 * SUM(restriction_block) / NULLIF(COUNT(*), 0) AS blocks_per_100_free_events,
       1.0 * COUNT(DISTINCT CASE WHEN restriction_block = 1 THEN user_id END)
           / NULLIF(COUNT(DISTINCT user_id), 0) AS share_of_exposed_users_with_restrictions,
       SUM(CASE WHEN tier_match_count > 1 THEN 1 ELSE 0 END) AS events_with_date_only_tier_ambiguity
FROM free_events GROUP BY month_start ORDER BY month_start;

/* Q09 | H2: opening Pro cancellation by recorded higher-price invoice exposure.
   Exposure must PRECEDE outcome-month start. Same-month invoices are not used to classify risk.
   Select the Pro subscription carried into the opening day. Compare descriptive groups only.
   NULL invoice exposure means no recorded qualifying invoice, not proven non-exposure to a notice. */
;WITH opening AS (
    SELECT um.user_id, um.month_start, um.opening_pro_cancellations,
           h.subscription_id, h.first_higher_price_invoice_date,
           h.first_successful_higher_price_payment_date
    FROM taskflow_reporting.vw_user_month AS um
    OUTER APPLY (
        SELECT TOP (1) s.subscription_id, s.first_higher_price_invoice_date,
               s.first_successful_higher_price_payment_date
        FROM taskflow_reporting.vw_subscription_history AS s
        WHERE s.user_id = um.user_id AND s.tier = 'Pro' AND s.start_date < um.month_start
          AND (s.end_date IS NULL OR s.end_date >= um.month_start)
        ORDER BY s.start_date DESC, s.subscription_id DESC
    ) AS h
    WHERE um.opening_pro = 1 AND um.month_start BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR um.platform = @Platform)
), groups AS (
    SELECT *, CASE WHEN first_higher_price_invoice_date < month_start
                   THEN 'Higher-price invoice recorded before month'
                   ELSE 'No higher-price invoice recorded before month' END AS invoice_exposure_group
    FROM opening
)
SELECT 'Q09' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       month_start, invoice_exposure_group, COUNT(*) AS opening_pro_users,
       SUM(opening_pro_cancellations) AS opening_pro_cancellers,
       1.0 * SUM(opening_pro_cancellations) / NULLIF(COUNT(*), 0) AS paid_cancellation_rate,
       SUM(CASE WHEN first_successful_higher_price_payment_date < month_start THEN 1 ELSE 0 END)
           AS users_with_successful_higher_price_payment_before_month
FROM groups GROUP BY month_start, invoice_exposure_group ORDER BY month_start, invoice_exposure_group;

/* Q10 | H2: cancellation reasons among cancelled Pro SUBSCRIPTION ROWS.
   This denominator differs from Q01/Q02 opening-cohort cancellation risk. */
;WITH reasons AS (
    SELECT DATEFROMPARTS(YEAR(h.cancellation_effective_date), MONTH(h.cancellation_effective_date), 1) AS month_start,
           COALESCE(NULLIF(h.cancellation_reason, ''), 'Not recorded') AS cancellation_reason,
           COUNT(*) AS cancellation_events, COUNT(DISTINCT h.user_id) AS cancelled_users
    FROM dbo.Subscription_History AS h INNER JOIN dbo.Users AS u ON u.user_id = h.user_id
    WHERE h.tier = 'Pro' AND h.[status] = 'Cancelled'
      AND h.cancellation_effective_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
    GROUP BY DATEFROMPARTS(YEAR(h.cancellation_effective_date), MONTH(h.cancellation_effective_date), 1),
             COALESCE(NULLIF(h.cancellation_reason, ''), 'Not recorded')
)
SELECT 'Q10' AS query_id, COALESCE(@Platform, 'All') AS platform_scope, *,
       1.0 * cancellation_events / NULLIF(SUM(cancellation_events) OVER (PARTITION BY month_start), 0)
           AS share_of_cancellation_events
FROM reasons ORDER BY month_start, cancellation_reason;

/* Q11 | 90-day first-Pro conversion by registration cohort.
   fully_mature=1 is required for headline cohort comparisons. Partially mature cohorts
   are returned for coverage review; their rates describe eligible users only. */
SELECT 'Q11' AS query_id, COALESCE(@Platform, 'All') AS platform_scope, cohort_month,
       COUNT(*) AS registered_users, SUM(eligible_90d) AS eligible_90d_users,
       SUM(CASE WHEN eligible_90d = 1 THEN converted_90d ELSE 0 END) AS converted_90d_users,
       MIN(cohort_fully_mature) AS fully_mature,
       1.0 * SUM(CASE WHEN eligible_90d = 1 THEN converted_90d ELSE 0 END)
           / NULLIF(SUM(eligible_90d), 0) AS conversion_rate_among_eligible,
       CASE WHEN MIN(cohort_fully_mature) = 1
            THEN 1.0 * SUM(converted_90d) / NULLIF(COUNT(*), 0) ELSE NULL END AS headline_mature_conversion_rate,
       @AnalysisEnd AS observation_cutoff
FROM taskflow_reporting.vw_users
WHERE cohort_month BETWEEN @StartDate AND @EndDate
  AND (@Platform IS NULL OR signup_platform = @Platform)
GROUP BY cohort_month ORDER BY cohort_month;

/* Q12 | H3: valid workflow outcomes by actual platform, feature and interface variant.
   Scope is explicit: @StartDate/@EndDate, @WorkflowPlatform/@WorkflowFeature and @Platform.
   Failure among resolved = Failed/(Completed+Failed). Abandoned attempts are excluded
   from that rate, so it answers a conditional question. Generator-created start-only
   abandonment is retained in counts and must be qualified in the written report. */
;WITH scoped AS (
    SELECT j.*
    FROM taskflow_reporting.vw_fact_journey AS j INNER JOIN dbo.Users AS u ON u.user_id = j.user_id
    WHERE j.is_valid_attempt = 1 AND j.start_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
      AND (@WorkflowPlatform IS NULL OR j.platform = @WorkflowPlatform)
      AND (@WorkflowFeature IS NULL OR j.feature = @WorkflowFeature)
)
SELECT 'Q12' AS query_id, @StartDate AS period_start, @EndDate AS period_end,
       COALESCE(@Platform, 'All') AS signup_platform_scope,
       platform AS recorded_platform, feature, interface_variant,
       COUNT(*) AS valid_attempts, COUNT(DISTINCT user_id) AS users_with_attempts,
       SUM(CASE WHEN outcome = 'Completed' THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN outcome = 'Failed' THEN 1 ELSE 0 END) AS failed,
       SUM(CASE WHEN outcome = 'Abandoned' THEN 1 ELSE 0 END) AS abandoned,
       SUM(CASE WHEN outcome IN ('Completed', 'Failed') THEN 1 ELSE 0 END) AS resolved,
       1.0 * SUM(CASE WHEN outcome = 'Completed' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS completion_rate,
       1.0 * SUM(CASE WHEN outcome = 'Failed' THEN 1 ELSE 0 END)
           / NULLIF(SUM(CASE WHEN outcome IN ('Completed', 'Failed') THEN 1 ELSE 0 END), 0) AS failure_among_resolved,
       SUM(CASE WHEN outcome = 'Abandoned' AND event_count = 1 THEN 1 ELSE 0 END) AS abandoned_with_one_event
FROM scoped GROUP BY platform, feature, interface_variant ORDER BY platform, feature, interface_variant;

/* Q13 | H3 supplementary: monthly workflow outcomes for the same explicit scope.
   Inspect transition months; raw variants are not a randomized exposure. */
SELECT 'Q13' AS query_id, DATEFROMPARTS(YEAR(j.start_date), MONTH(j.start_date), 1) AS month_start,
       j.platform AS recorded_platform, j.feature, j.interface_variant,
       COUNT(*) AS attempts,
       SUM(CASE WHEN j.outcome = 'Completed' THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN j.outcome = 'Failed' THEN 1 ELSE 0 END) AS failed,
       SUM(CASE WHEN j.outcome = 'Abandoned' THEN 1 ELSE 0 END) AS abandoned,
       1.0 * SUM(CASE WHEN j.outcome = 'Failed' THEN 1 ELSE 0 END)
           / NULLIF(SUM(CASE WHEN j.outcome IN ('Completed', 'Failed') THEN 1 ELSE 0 END), 0) AS failure_among_resolved
FROM taskflow_reporting.vw_fact_journey AS j INNER JOIN dbo.Users AS u ON u.user_id = j.user_id
WHERE j.is_valid_attempt = 1 AND j.start_date BETWEEN @StartDate AND @EndDate
  AND (@Platform IS NULL OR u.signup_platform = @Platform)
  AND (@WorkflowPlatform IS NULL OR j.platform = @WorkflowPlatform)
  AND (@WorkflowFeature IS NULL OR j.feature = @WorkflowFeature)
GROUP BY DATEFROMPARTS(YEAR(j.start_date), MONTH(j.start_date), 1), j.platform, j.feature, j.interface_variant
ORDER BY month_start, recorded_platform, j.feature, j.interface_variant;

/* Q14 | H4 canonical checkout: separate two-step and four-step funnels.
   Whole-history defaults reproduce 2023-Jan through 2025-May versus 2025-Jun through Dec.
   Each flow begins at 100%; step positions do not have recorded business purposes.
   Retain actual counts and unequal period lengths beside normalized stage reach. */
;WITH selected AS (
    SELECT c.* FROM taskflow_reporting.vw_fact_checkout AS c
    INNER JOIN dbo.Users AS u ON u.user_id = c.user_id
    WHERE c.is_valid_attempt = 1 AND c.start_date BETWEEN @CheckoutStart AND @CheckoutEnd
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
), flows AS (
    SELECT period, n_steps, COUNT(*) AS valid_started,
           SUM(purchase_count) AS completed_purchases,
           SUM(payment_success_count) AS successful_payment_submissions,
           SUM(payment_failure_count) AS failed_payment_submissions,
           MIN(start_date) AS first_recorded_start, MAX(start_date) AS last_recorded_start
    FROM selected GROUP BY period, n_steps
), stage_counts AS (
    SELECT s.period, s.stage_order, COUNT(*) AS reached
    FROM taskflow_reporting.vw_checkout_stages AS s
    INNER JOIN selected AS c ON c.attempt_key = s.attempt_key
    GROUP BY s.period, s.stage_order
)
SELECT 'Q14' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       @CheckoutStart AS requested_start, @CheckoutEnd AS requested_end,
       f.period, f.first_recorded_start, f.last_recorded_start, f.n_steps,
       v.stage_order, v.stage, COALESCE(s.reached, 0) AS reached,
       f.valid_started, 1.0 * COALESCE(s.reached, 0) / NULLIF(f.valid_started, 0) AS reach_from_start,
       f.completed_purchases, 1.0 * f.completed_purchases / NULLIF(f.valid_started, 0) AS checkout_completion_rate,
       f.successful_payment_submissions, f.failed_payment_submissions,
       1.0 * f.failed_payment_submissions
           / NULLIF(f.successful_payment_submissions + f.failed_payment_submissions, 0) AS failure_among_payment_submissions
FROM flows AS f
CROSS APPLY (VALUES (0, 'Started'), (1, 'Step 1'), (2, 'Step 2'),
                    (3, 'Step 3'), (4, 'Step 4'), (5, 'Purchase completed')) AS v(stage_order, stage)
LEFT JOIN stage_counts AS s ON s.period = f.period AND s.stage_order = v.stage_order
WHERE v.stage_order = 0 OR v.stage_order BETWEEN 1 AND f.n_steps OR v.stage_order = 5
ORDER BY CASE f.period WHEN 'Pre-redesign' THEN 0 ELSE 1 END, v.stage_order;

/* Q15 | H4 sensitivity: equal-length nearby windows plus the full post period.
   Fixed windows ignore the displayed trend period deliberately; @Platform still applies.
   March-May already includes the price change. Concurrent changes and cohort differences
   prevent a causal checkout attribution even when nearby-window rates differ. */
;WITH windows AS (
    SELECT * FROM (VALUES
        ('Nearer pre: March-May 2025', CONVERT(date, '20250301', 112), CONVERT(date, '20250601', 112)),
        ('Nearer post: June-August 2025', CONVERT(date, '20250601', 112), CONVERT(date, '20250901', 112)),
        ('Full post: June-December 2025', CONVERT(date, '20250601', 112), CONVERT(date, '20260101', 112))
    ) AS v(comparison_window, window_start, window_end_exclusive)
), selected AS (
    SELECT c.* FROM taskflow_reporting.vw_fact_checkout AS c
    INNER JOIN dbo.Users AS u ON u.user_id = c.user_id
    WHERE c.is_valid_attempt = 1 AND (@Platform IS NULL OR u.signup_platform = @Platform)
)
SELECT 'Q15' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       w.comparison_window, w.window_start, w.window_end_exclusive,
       COUNT(c.attempt_key) AS valid_started, COALESCE(SUM(c.purchase_count), 0) AS completed_purchases,
       1.0 * SUM(c.purchase_count) / NULLIF(COUNT(c.attempt_key), 0) AS completion_rate
FROM windows AS w LEFT JOIN selected AS c
    ON c.start_date >= w.window_start AND c.start_date < w.window_end_exclusive
GROUP BY w.comparison_window, w.window_start, w.window_end_exclusive ORDER BY w.window_start, w.window_end_exclusive;

/* Q16 | Revised deletion comparison for a chart-specific Comparison month dropdown.
   Group by outcome month and retain that month in the chart's filter context.
   Both groups use the PREVIOUS full calendar month. No friction lookback runs into
   deletion month. Denominator is eligible accounts; registrations after observation
   start are excluded from both groups. This is descriptive, not matched risk evidence. */
SELECT 'Q16' AS query_id, COALESCE(@Platform, 'All') AS platform_scope,
       month_start AS outcome_month, observation_start, observation_end_exclusive,
       observation_days, outcome, COUNT(*) AS eligible_account_observations,
       SUM(had_recorded_activity) AS accounts_with_recorded_activity,
       SUM(had_prior_friction) AS accounts_with_prior_friction,
       SUM(friction_event_count) AS friction_events,
       1.0 * SUM(had_prior_friction) / NULLIF(COUNT(*), 0) AS prior_friction_share
FROM taskflow_reporting.vw_deletion_comparison_calendar_month
WHERE month_start BETWEEN @StartDate AND @EndDate
  AND (@Platform IS NULL OR platform = @Platform)
GROUP BY month_start, observation_start, observation_end_exclusive, observation_days, outcome
ORDER BY outcome_month, outcome;

/* Q16P | Pooled deletion comparison across the requested outcome months.
   Grain remains ACCOUNT-MONTH. Retained people can appear in several months.
   This is a ratio of pooled counts, not an average of monthly percentages. */
SELECT 'Q16P' AS query_id, @StartDate AS requested_outcome_start, @EndDate AS requested_outcome_end,
       MIN(month_start) AS first_covered_outcome_month, MAX(month_start) AS last_covered_outcome_month,
       COALESCE(@Platform, 'All') AS platform_scope, outcome,
       COUNT(*) AS eligible_account_months, COUNT(DISTINCT user_id) AS distinct_users,
       SUM(had_prior_friction) AS account_months_with_prior_friction,
       1.0 * SUM(had_prior_friction) / NULLIF(COUNT(*), 0) AS prior_friction_share
FROM taskflow_reporting.vw_deletion_comparison_calendar_month
WHERE month_start BETWEEN @StartDate AND @EndDate
  AND (@Platform IS NULL OR platform = @Platform)
GROUP BY outcome ORDER BY outcome;

/* Q16R | Account-deletion reason mix. Counts all account deletion records in period,
   including users excluded from the full prior-month friction population. */
;WITH reasons AS (
    SELECT COALESCE(NULLIF(deletion_reason, ''), 'Not recorded') AS deletion_reason, COUNT(*) AS deleted_accounts
    FROM dbo.Users
    WHERE account_deletion_date BETWEEN @StartDate AND @EndDate
      AND (@Platform IS NULL OR signup_platform = @Platform)
    GROUP BY COALESCE(NULLIF(deletion_reason, ''), 'Not recorded')
)
SELECT 'Q16R' AS query_id, @StartDate AS period_start, @EndDate AS period_end,
       COALESCE(@Platform, 'All') AS platform_scope, *,
       1.0 * deleted_accounts / NULLIF(SUM(deleted_accounts) OVER (), 0) AS share_of_deleted_accounts
FROM reasons ORDER BY deleted_accounts DESC, deletion_reason;

/* Q17 | H5: recorded sync failures by calendar month and actual event platform.
   Denominator: terminal sync_completed/sync_failed events; requests are separate.
   No matched request/terminal assumption or infrastructure root-cause claim is made. */
;WITH months AS (
    SELECT DISTINCT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS month_start
    FROM dbo.[Date] WHERE [date] BETWEEN @StartDate AND @EndDate
), platforms AS (
    SELECT DISTINCT signup_platform AS platform FROM dbo.Users
    WHERE @Platform IS NULL OR signup_platform = @Platform
), sync AS (
    SELECT DATEFROMPARTS(YEAR(a.[timestamp]), MONTH(a.[timestamp]), 1) AS month_start,
           a.platform, COUNT(*) AS recorded_requests_and_outcomes,
           SUM(CASE WHEN a.action = 'sync_requested' THEN 1 ELSE 0 END) AS recorded_requests,
           SUM(CASE WHEN a.action IN ('sync_completed', 'sync_failed') THEN 1 ELSE 0 END) AS recorded_outcomes,
           SUM(CASE WHEN a.action = 'sync_failed' THEN 1 ELSE 0 END) AS recorded_failures,
           COUNT(DISTINCT CASE WHEN a.action IN ('sync_completed', 'sync_failed') THEN a.user_id END)
               AS users_with_sync_outcomes
    FROM dbo.Activity_Events AS a INNER JOIN dbo.Users AS u ON u.user_id = a.user_id
    WHERE a.[timestamp] >= @StartDate AND a.[timestamp] < DATEADD(day, 1, @EndDate)
      AND a.action IN ('sync_requested', 'sync_completed', 'sync_failed')
      AND (@Platform IS NULL OR u.signup_platform = @Platform)
    GROUP BY DATEFROMPARTS(YEAR(a.[timestamp]), MONTH(a.[timestamp]), 1), a.platform
)
SELECT 'Q17' AS query_id, m.month_start, p.platform AS recorded_platform,
       COALESCE(s.recorded_requests, 0) AS recorded_requests,
       COALESCE(s.recorded_outcomes, 0) AS recorded_outcomes,
       COALESCE(s.recorded_failures, 0) AS recorded_failures,
       COALESCE(s.users_with_sync_outcomes, 0) AS users_with_sync_outcomes,
       1.0 * s.recorded_failures / NULLIF(s.recorded_outcomes, 0) AS failure_rate
FROM months AS m CROSS JOIN platforms AS p
LEFT JOIN sync AS s ON s.month_start = m.month_start AND s.platform = p.platform
ORDER BY m.month_start, p.platform;

/* Q17E | H5 supporting engagement trend by platform. Counts and participation shares
   support context only; they do not link an individual's sync exposure to later usage. */
SELECT 'Q17E' AS query_id, month_start, platform,
       SUM(CASE WHEN event_count > 0 THEN 1 ELSE 0 END) AS observed_active_users,
       SUM(CASE WHEN meaningful_action_count > 0 THEN 1 ELSE 0 END) AS meaningfully_active_users,
       1.0 * SUM(CASE WHEN meaningful_action_count > 0 THEN 1 ELSE 0 END)
           / NULLIF(SUM(CASE WHEN event_count > 0 THEN 1 ELSE 0 END), 0) AS meaningful_share_of_active
FROM taskflow_reporting.vw_user_month
WHERE month_start BETWEEN @StartDate AND @EndDate AND (@Platform IS NULL OR platform = @Platform)
GROUP BY month_start, platform ORDER BY month_start, platform;

/* Q18 | Recorded scenario changes for report context. Descriptions are scenario inputs. */
SELECT 'Q18' AS query_id, change_id, description, intended_benefit, announcement_date,
       rollout_start, rollout_end, affected_plans, affected_platforms, affected_versions, rollout_group
FROM dbo.Business_Change_Register
WHERE rollout_start <= @EndDate AND rollout_end >= @StartDate
ORDER BY rollout_start, change_id;

/* QA01 | Account and Pro movement reconciliation. Expected: zero residuals per month. */
SELECT 'QA01' AS query_id, month_start,
       SUM(opening_pro + first_upgrades + repeat_upgrades - pro_cancellations - pro_deletion_exits - closing_pro)
           AS pro_residual,
       SUM(opening_accounts + is_new_this_month - account_deletions - closing_accounts) AS account_residual
FROM taskflow_reporting.vw_user_month
WHERE @Platform IS NULL OR platform = @Platform
GROUP BY month_start ORDER BY month_start;

/* QA02 | Validated attempt keys and terminal structure. Expected: zero invalid attempts.
   The retained legacy checkout view checks stage-set completeness, not full event-by-event
   chronological ordering; any complete chronology test belongs in supporting validation. */
SELECT 'QA02' AS query_id, 'Journey' AS attempt_type, COUNT(*) AS attempts,
       SUM(CASE WHEN is_valid_attempt = 0 THEN 1 ELSE 0 END) AS invalid_attempts
FROM taskflow_reporting.vw_fact_journey
UNION ALL
SELECT 'QA02', 'Checkout', COUNT(*), SUM(CASE WHEN is_valid_attempt = 0 THEN 1 ELSE 0 END)
FROM taskflow_reporting.vw_fact_checkout;

/* QA03 | New deletion-view eligibility and aligned observation windows. Expected: zero violations. */
SELECT 'QA03' AS query_id, COUNT(*) AS eligible_account_months,
       SUM(CASE WHEN registration_date > observation_start
                 OR observation_end_exclusive <> month_start
                 OR observation_start <> DATEADD(month, -1, month_start)
                 OR month_start < '20230201'
                 OR (account_deletion_date IS NOT NULL AND account_deletion_date < month_start)
                THEN 1 ELSE 0 END) AS eligibility_or_window_violations,
       COUNT(*) - COUNT(DISTINCT CONCAT(CONVERT(varchar(20), user_id), '|', CONVERT(char(8), month_start, 112)))
           AS duplicate_account_months
FROM taskflow_reporting.vw_deletion_comparison_calendar_month;

/* QA04 | Dataset coverage limitation: deletion-month events. Expected is a recorded count,
   not a completeness assertion. Zero events confirms the known generator omission. */
;WITH deletion_coverage AS (
    SELECT u.user_id, CASE WHEN EXISTS (
           SELECT 1 FROM dbo.Activity_Events AS a WHERE a.user_id = u.user_id
             AND a.[timestamp] >= DATEFROMPARTS(YEAR(u.account_deletion_date), MONTH(u.account_deletion_date), 1)
             AND a.[timestamp] < DATEADD(day, 1, EOMONTH(u.account_deletion_date))
       ) THEN 1 ELSE 0 END AS has_deletion_month_events
    FROM dbo.Users AS u WHERE u.account_deletion_date IS NOT NULL
)
SELECT 'QA04' AS query_id, COUNT(*) AS deleted_users,
       SUM(has_deletion_month_events) AS deleted_users_with_deletion_month_events
FROM deletion_coverage;

/* QA05 | Abandonment interpretation and the legacy fixed follow-up inset.
   This follow-up is retained for transparency, not a dashboard finding or powered analysis.
   Historical four-user count is observed here, not hard-coded as an acceptance target. */
SELECT 'QA05A' AS query_id, outcome, COUNT(*) AS attempts,
       SUM(CASE WHEN event_count = 1 THEN 1 ELSE 0 END) AS attempts_with_one_event
FROM taskflow_reporting.vw_fact_journey WHERE is_valid_attempt = 1 GROUP BY outcome ORDER BY outcome;
SELECT 'QA05B' AS query_id, exposure_group, COUNT(*) AS eligible_users,
       SUM(meaningfully_active_later) AS users_with_later_meaningful_activity,
       1.0 * SUM(meaningfully_active_later) / NULLIF(COUNT(*), 0) AS later_activity_rate
FROM taskflow_reporting.vw_sync_followup GROUP BY exposure_group ORDER BY exposure_group;

/* QA06 | Event-time tier ambiguity. Latest-start assignment remains explicit. */
SELECT 'QA06' AS query_id, COUNT(*) AS activity_events,
       SUM(CASE WHEN tier_match_count = 0 THEN 1 ELSE 0 END) AS events_without_subscription_match,
       SUM(CASE WHEN tier_match_count > 1 THEN 1 ELSE 0 END) AS events_with_multiple_date_matches
FROM taskflow_reporting.vw_activity_events;

/* QA07 | Cohort maturity and date coverage; source dates must cover every day in scope. */
SELECT 'QA07A' AS query_id, MIN([date]) AS first_date, MAX([date]) AS last_date,
       COUNT(*) AS date_rows, COUNT(DISTINCT [date]) AS distinct_days,
       DATEDIFF(day, MIN([date]), MAX([date])) + 1 AS expected_contiguous_days
FROM dbo.[Date];
SELECT 'QA07B' AS query_id, SUM(eligible_90d) AS eligible_90d_users,
       SUM(CASE WHEN eligible_90d = 1 THEN converted_90d ELSE 0 END) AS converted_90d_users,
       SUM(CASE WHEN eligible_90d = 0 AND converted_90d IS NOT NULL THEN 1 ELSE 0 END)
           AS ineligible_users_with_defined_conversion
FROM taskflow_reporting.vw_users;

/* QA08 | Opening Pro rows selected by the billing-exposure query must be unique.
   Expected: zero opener user-months with missing or multiple qualifying Pro rows. */
;WITH matches AS (
    SELECT um.user_id, um.month_start, COUNT(h.subscription_id) AS pro_row_matches
    FROM taskflow_reporting.vw_user_month AS um
    LEFT JOIN dbo.Subscription_History AS h ON h.user_id = um.user_id AND h.tier = 'Pro'
      AND h.start_date < um.month_start AND (h.end_date IS NULL OR h.end_date >= um.month_start)
    WHERE um.opening_pro = 1 GROUP BY um.user_id, um.month_start
)
SELECT 'QA08' AS query_id, COUNT(*) AS opening_pro_account_months,
       SUM(CASE WHEN pro_row_matches = 0 THEN 1 ELSE 0 END) AS missing_pro_row_matches,
       SUM(CASE WHEN pro_row_matches > 1 THEN 1 ELSE 0 END) AS multiple_pro_row_matches
FROM matches;

/* QA09 | Imported source row counts. Compare with the preserved CSV manifest. */
SELECT 'QA09' AS query_id, 'Users' AS source_table, COUNT_BIG(*) AS source_rows FROM dbo.Users
UNION ALL SELECT 'QA09', 'Subscription_History', COUNT_BIG(*) FROM dbo.Subscription_History
UNION ALL SELECT 'QA09', 'Sessions', COUNT_BIG(*) FROM dbo.Sessions
UNION ALL SELECT 'QA09', 'Activity_Events', COUNT_BIG(*) FROM dbo.Activity_Events
UNION ALL SELECT 'QA09', 'Invoices', COUNT_BIG(*) FROM dbo.Invoices
UNION ALL SELECT 'QA09', 'Payment_Transactions', COUNT_BIG(*) FROM dbo.Payment_Transactions
UNION ALL SELECT 'QA09', 'Reviews', COUNT_BIG(*) FROM dbo.Reviews
UNION ALL SELECT 'QA09', 'Business_Change_Register', COUNT_BIG(*) FROM dbo.Business_Change_Register
UNION ALL SELECT 'QA09', 'Plan_Versions', COUNT_BIG(*) FROM dbo.Plan_Versions
UNION ALL SELECT 'QA09', 'Platforms', COUNT_BIG(*) FROM dbo.Platforms
UNION ALL SELECT 'QA09', 'Date', COUNT_BIG(*) FROM dbo.[Date]
ORDER BY source_table;
