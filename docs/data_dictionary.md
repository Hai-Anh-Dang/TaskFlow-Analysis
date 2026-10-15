# TaskFlow synthetic dataset — data dictionary

Generated dataset for a portfolio case study (Power BI analyst investigation into a
declining SaaS product). All data is synthetic, produced by `generate_taskflow_dataset.py`
with a fixed random seed (42) for reproducibility. It is not real user data.

Scale: 1,500 users, ~120,000 activity events, three full years (2023–2025). Year 1–2 show
growth; year 3 shows a sharp, deliberately "alarming" decline driven by a documented
sequence of scenario changes (see `Business_Change_Register.csv`). These generation assumptions do not establish real-world causality.

## Scenario change timeline

| Date | Change |
|---|---|
| 2025-02-01 | Free plan allowance cut (10→3 projects, 200→50 tasks) |
| 2025-03-01 | Pro price increased $9.99 → $14.99, one minor feature added |
| 2025-04-10 | Web interface redesign goes live |
| 2025-05-10 | Mobile (iOS/Android) interface redesign goes live |
| 2025-06-01 | Checkout flow gets extra steps |
| 2025-07-01 | Android app v7.0 release — sync reliability regresses (Android only) |

## Tables

### Date.csv
One row per calendar day, 2023-01-01 to 2025-12-31.
`date, year, quarter, month, week, weekday`

### Platforms.csv
`platform_id, platform_name (Web/iOS/Android), platform_type (Web/Mobile)`

### Plan_Versions.csv
Historical versions of each commercial tier.
`plan_version_id, tier (Free/Pro), effective_start, effective_end (blank = current),
price, billing_frequency, project_allowance, task_allowance, features`

### Users.csv — one row per registered account (1,500 rows)
`user_id, registration_date, acquisition_channel, signup_platform, country,
declared_purpose, account_deletion_date (blank if still active), deletion_reason`

Each user has one `signup_platform`, used as their platform throughout (no
cross-platform switching modeled — see "Scope decisions" below).

### Subscription_History.csv — one row per unbroken plan period (~2,080 rows)
`subscription_id, user_id, tier, start_date, end_date (blank = still open),
actual_price, status (Active/Cancelled/Upgraded to Pro/Ended (account deleted)),
price_notice_date, cancellation_request_date, cancellation_effective_date,
cancellation_reason`

A user's Free→Pro upgrade closes one row and opens another; a Pro cancellation
reverts them to a new open Free row. Date-only transitions can match more than one subscription row on a boundary date. Reporting uses latest-start-date and subscription-ID precedence; intraday ordering remains unknown.

### Sessions.csv — one row per user-per-active-day (~75,000 rows)
`session_id, user_id, platform, platform_version, interface_variant (Old/New),
date, start_ts, end_ts, n_events, end_reason (Normal/Timeout/Error)`

Session boundary is deliberately simple: all of a user's events on a given
calendar day are grouped into one session (see "Scope decisions").

### Activity_Events.csv — one row per recorded action (120,000 rows)
`event_id, user_id, session_id, timestamp, action, feature, result
(success/blocked/failed), platform, platform_version, interface_variant,
journey_id (groups one workflow attempt), checkout_id (groups one checkout
attempt), error_code`

Action families: initial-value (`project_created`, `task_created`,
`first_task_completed`), repeat usage (`task_completed`, `reminder_set`,
`report_viewed`), free-tier restriction (`feature_attempted`,
`allowance_reached`, `action_blocked`, `upgrade_page_viewed`), interface
friction (`workflow_started`, `navigation_step`, `workflow_completed`,
`action_failed`), checkout (`checkout_started`, `step_viewed`,
`step_completed`, `payment_submitted`, `purchase_completed`), and
reliability (`sync_requested`, `sync_completed`, `sync_failed`).

### Invoices.csv / Payment_Transactions.csv (~3,400 rows each)
Monthly Pro renewal billing. `Invoices`: `invoice_id, user_id, subscription_id,
billing_period_start/end, issue_date, due_date, actual_price, discount,
amount_due, currency, invoice_status`. `Payment_Transactions`:
`transaction_id, invoice_id, timestamp, transaction_type, amount, status,
payment_method, failure_reason, original_transaction_ref`.

Only covers recurring renewals, not the very first payment at signup — that
first conversion is only visible as a `purchase_completed` event in
Activity_Events, not as a formal invoice row. A deliberate scope cut, noted
here rather than silently left out.

### Reviews.csv (805 rows)
`review_id, user_id, review_date, platform, rating (1–5), review_text,
issue_category (Restriction/Price/Navigation/Sync/Checkout/Positive-other)`

Each review is generated from something that actually happened to that user
(hit an allowance block, lived through the redesign, was on Android after the
sync regression, cancelled for a price reason, abandoned checkout, or — for
the baseline — just a normal happy user). Ratings and themes are not random;
they follow the affected population and time window.

### Business_Change_Register.csv (6 rows)
`change_id, description, intended_benefit, announcement_date, rollout_start,
rollout_end, affected_plans, affected_platforms, affected_versions,
rollout_group`

## Scope decisions (what's deliberately not here)

- **No API request log, maintenance/incident register, or tracking-coverage
  table.** The reliability/API category is evidenced only through
  `sync_failed` events (Android, post-2025-07-01) and the "Sync" review
  theme. This is intentional — treat it in the investigation as a flagged
  thread that would need infrastructure telemetry to fully confirm, not as a
  fully-evidenced category.
- **One platform per user.** Users don't switch between Web/iOS/Android.
  Platform comparisons are done across users, not within a user's own
  history.
- **First Pro payment isn't a formal invoice.** See Invoices note above.
- **Session boundaries are same-day grouping**, not gap-based session
  detection.
