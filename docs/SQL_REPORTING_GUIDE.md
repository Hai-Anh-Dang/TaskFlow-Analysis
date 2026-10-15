# TaskFlow SQL reporting guide

Prepared 1 October 2026. Analysis cutoff: 31 December 2025. All records describe a fictional product and are synthetic.

This guide explains how to reproduce the investigation, interpret its SQL outputs, and apply the reporting definitions without changing raw data. The stakeholder findings are in the [dashboard report](../report/TaskFlow_Power_BI_Dashboard_Report_v1.md); the [SQL supplement](../report/TaskFlow_SQL_Investigation_Report.md) provides the detailed evidence.

## 1. Files and responsibilities

| File | Purpose |
|---|---|
| [02_reporting_views.sql](../sql/02_reporting_views.sql) | Creates or updates the derived reporting views. Preserves the source tables and the existing Power BI view contracts. |
| [03_dashboard_queries.sql](../sql/03_dashboard_queries.sql) | Produces the operational, diagnostic, and quality-check result sets used in the investigation. |
| [validate_reporting.ps1](../sql/validate_reporting.ps1) | Executes the view definitions and reporting queries inside one SQL transaction, records their results, and rolls back the changes. |
| [SQL supplement](../report/TaskFlow_SQL_Investigation_Report.md) | Documents calculations, populations and evidence supporting the dashboard report. |
| [Validation evidence](sql_validation_2026-10-01/sql_execution_results.json) | Records SQL execution status, input script hashes, result sets, and rollback status. |
| [Raw evidence](sql_validation_2026-10-01/raw_evidence.json) | Independently calculates selected findings from the preserved CSVs and records their hashes and date coverage. |
| [Raw audit script](sql_validation_2026-10-01/audit_raw_evidence.py) | Reproduces the CSV calculation path without SQL Server or Power BI changes. |

Import all 11 source CSV tables before using these scripts. This package contains reporting definitions and a transactional validation runner; the import prerequisites are in [reproducibility guidance](REPRODUCIBILITY.md).

## 2. Validation and deployment are different operations

The validation runner uses Windows authentication to connect to the local SQL Express `TaskFlow` database. It records the definitions of the existing reporting views, begins a transaction, runs `02_reporting_views.sql` followed by `03_dashboard_queries.sql`, captures every result set, and rolls the transaction back. It then compares the restored view definitions with the originals.

Read the evidence file before accepting the run. A successful record must contain `success: true`, `rollback_completed: true`, and `database_view_definitions_unchanged: true`. A captured result set alone is insufficient if execution or rollback later failed.

This process validates the updated SQL against the imported database while leaving the deployed view definitions as they were. It does not install the new calendar-month deletion view permanently, refresh Power BI, change DAX, or validate dashboard visuals.

The separate raw-data audit provides an independent calculation path from the CSV exports. Its findings should agree with the SQL result sets for the same population and dates. The [validation summary](VALIDATION_SUMMARY.md) distinguishes this recorded SQL run from historical model checks and current saved-dashboard verification.

The recorded successful SQL run began at `2026-09-30T16:27:03.8962001Z` and finished at `2026-09-30T16:28:55.1130140Z`, corresponding to 1 October 2026 in Sydney. It returned 32 result sets and recorded all three success/restoration flags as true. Source counts in QA09 agree with the 11-file CSV manifest. QA01 has zero monthly account/Pro residuals; QA02 has zero structurally invalid journeys/checkouts; QA03 has zero calendar-window violations or duplicate account-months. These checks establish their stated contracts. They do not establish complete tracking or a causal design.

The run checked 17,991 workflow attempts and 689 checkout attempts across the historical export. All 4,217 abandoned workflow attempts contain one event. The checkout validity flag verifies start, platform, timestamps, contiguous completed-step sets and terminal consistency; it does not prove every viewed/completed step occurred in chronological order. Keep this narrower scope visible when interpreting "valid".

The independent comparison passed all **740 field-level and integrity assertions**, including source counts, operational metrics, revised deletion rates, restrictions, sync rates, conversion eligibility, and file hashes. These are individual value and boundary checks, not 740 separate business scenarios. SQL decimal rounding is compared with an absolute tolerance of 0.000001. See [acceptance results](sql_validation_2026-10-01/acceptance_checks.json) and the [comparison script](sql_validation_2026-10-01/check_results.py).

Parameter validation is defined in the retained query script. The separate historical parameter-test transcript is outside this lean evidence set, so this package does not make a separately evidenced nine-test pass claim. A future run must check the intended inputs and rejection cases.

## 3. Reproduce the SQL checks

Run the following from the project folder in PowerShell, substituting a new evidence-folder name for a later run:

```powershell
& '.\sql\validate_reporting.ps1' `
    -Server 'localhost\SQLEXPRESS' `
    -Database 'TaskFlow' `
    -ProjectRoot (Get-Location).Path `
    -EvidenceDirectory '.\docs\sql_validation_new_run'
```

The account running the command needs permission to read the source tables and create or alter reporting views. The runner splits the scripts at `GO` batch separators. It waits for each command to complete and saves results as JSON rather than relying on copied console values.

For a new validation run, use a new evidence directory so the recorded run used by the report remains intact. Check the script hashes in the evidence against the files being reviewed. A later file change requires a new run.

The raw audit uses Python's standard library. Reproduce it separately with an explicit source and output directory:

```powershell
python '.\docs\sql_validation_2026-10-01\audit_raw_evidence.py' `
    --raw-dir '.\data\raw' `
    --out-dir '.\docs\raw_validation_new_run'
```

The script writes `raw_evidence.json` and `RAW_EVIDENCE_FINDINGS.md`. It reads source CSVs without rewriting them. Its output is a separate evidence record; SQL-only workflow and checkout results require the SQL path. An independent calculation using the same synthetic source is an implementation cross-check, not independent real-world corroboration.

For persistent deployment, execute the complete `02_reporting_views.sql` script in SSMS against `TaskFlow`, then run `03_dashboard_queries.sql` with the intended parameters. Running the views script directly persists its definitions. Use the transactional runner when the purpose is validation only. Inspect the reconciliation and attempt-validity outputs before refreshing any dependent model.

### Query parameters and result catalogue

The reporting-query declarations and queries form one batch. Keep them together and do not add `GO` after the declarations. Date checks reject reversed or uncovered periods and require full calendar boundaries for the monthly trend period.

| Parameter | Recorded default | Effect |
|---|---|---|
| `@AnalysisStart`, `@AnalysisEnd` | 1 January 2023; 31 December 2025 | Fixed loaded-data history and maturity cutoff. |
| `@StartDate`, `@EndDate` | 1 January; 31 December 2025 | Operational and diagnostic display/outcome period. |
| `@KpiMonth` | 1 December 2025 | Q02 KPI month, independent of trend display. |
| `@Platform` | `NULL` | All signup platforms; Web, iOS or Android filters matching populations. |
| `@WorkflowPlatform`, `@WorkflowFeature` | `NULL`, `NULL` | Q12/Q13 recorded workflow scope; report's worked example selects Web and Tasks from the returned rows. |
| `@CheckoutStart`, `@CheckoutEnd` | 1 January 2023; 31 December 2025 | Q14 whole-history flow context, independent of the 2025 trend defaults. |

Q15 deliberately uses fixed March–May, June–August and June–December 2025 windows while retaining the platform filter. Q07 deliberately uses the full 2024 monthly baseline. Q03 can observe selected registration cohorts through the historical cutoff. Do not assume every output inherits the same period.

| Result IDs | Question or control | Output grain |
|---|---|---|
| Q01, Q02 | Monthly performance and four KPI cards | Month; selected KPI month. |
| Q03, Q11 | Meaningful retention and 90-day first-Pro conversion | Registration cohort/age; registration cohort. |
| Q04, Q05 | Ratings and review theme mix | Month; theme in selected period. |
| Q06, Q07 | Registration channels and 2024 benchmark | Month/channel; month. |
| Q08 | Free restriction exposure, intensity and affected share | Month. |
| Q09, Q10 | Prior higher-price invoice exposure and cancellation reasons | Month/exposure group; month/reason. |
| Q12, Q13 | Workflow outcomes by actual variant | Platform/feature/variant; month plus those fields. |
| Q14, Q15 | Checkout stages and nearby windows | Flow/stage; comparison window. |
| Q16, Q16P, Q16R | Calendar-month deletion/friction, pooled observations and exit reasons | Outcome month/group; group; reason. |
| Q17, Q17E | Recorded sync failures and engagement context | Month/platform. |
| Q18 | Recorded scenario changes | Change record. |
| QA01–QA09 | Stocks, attempt structure, eligibility, missing activity, ambiguity, maturity, billing-row uniqueness and source counts | Control-specific. |

Each JSON result set contains `columns`, `row_count` and `rows`; each row identifies its query. Additional QA05A/B and QA07A/B result IDs explain why nine numbered control groups produce eleven control result sets. Treat decimal rate `0.083916` as 8.3916%, while a field ending `_pp` is already expressed in percentage points.

## 4. Reporting view contracts

| View | Grain | Main purpose |
|---|---|---|
| `vw_users` | One registered account | Registration cohort, first Pro start, and 90-day conversion eligibility. |
| `vw_activity_events` | One recorded event | Event-date activity, meaningful actions, event-time tier, restriction events, and sync outcomes. |
| `vw_subscription_history` | One subscription period | First versus repeat Pro entry and invoice/payment exposure dates. |
| `vw_user_month` | One account-month | Opening and closing account/Pro populations, movements, activity, and cohort age. |
| `vw_fact_journey` | One user/session/journey attempt | Validated workflow identity, sequence, recorded variant, and outcome. |
| `vw_fact_checkout` | One user/checkout attempt | Validated start, flow period, reached steps, purchase, and payment outcome. |
| `vw_checkout_stages` | One reached stage per valid checkout | Cumulative progression with all starts as the denominator. |
| `vw_sync_followup` | One eligible Android user | Preserved exploratory July-August exposure and September-December outcome comparison. |
| `vw_deletion_comparison` | One eligible account-month | Preserved 30-day comparison used by the existing Power BI model. |
| `vw_deletion_comparison_calendar_month` | One eligible account-month | New aligned previous-calendar-month friction comparison. |
| `vw_payments` | One recorded transaction | Renewal payment detail with the invoice-derived account key. |

The payment view belongs in the view-definition script. The reporting-query script reads the views and does not create them. Raw identifiers and source nulls remain available.

Do not combine event, journey, checkout, subscription, invoice, payment, and review facts into a single wide join. Their different grains would multiply counts. Aggregate the required population at its own grain, then join compatible summaries through account or calendar keys.

## 5. Date, population, and aggregation rules

The historical calendar ends on 31 December 2025. Use this loaded-data cutoff for maturity and period comparisons. The current computer date does not extend observation coverage.

| Topic | Required rule |
|---|---|
| Platform | Filter the numerator and denominator to the same recorded platform. Users have one signup platform in this synthetic dataset. |
| Monthly counts | Count distinct users within each month. Summing monthly active users across a year gives user-month observations, not unique annual users. |
| Opening and closing stocks | Opening is the carried-forward population at the start of the month; closing is after that month's changes. Stocks are not additive across months. |
| Paid cancellation | Divide distinct cancelling users who were Pro at month opening by distinct opening Pro users. All cancellation events are a separate count. |
| Meaningful activity | Count successful `task_completed`, `workflow_completed`, `first_task_completed`, `report_viewed`, and `reminder_set` events. Purchases are commercial activity. |
| Retention | Divide meaningful users at a cohort age by the cohort's original registration size. Later deletion does not remove users from the denominator. Future ages remain unavailable. |
| Conversion | Use users whose full 90-day period is observable. A fully mature monthly cohort requires every registration date in that month to have an observable window. |
| Rate comparison | Subtract decimal rates and multiply by 100 to obtain percentage points. Relative change uses the prior value as its denominator. |
| Missing values | Undefined rates, immature cohorts, unavailable previous periods, and inapplicable checkout stages remain null. A measured count of zero with eligible coverage is zero. |

The account movement identity is:

`Opening accounts + registrations - account deletions = closing accounts`

The Pro movement identity is:

`Opening Pro + first upgrades + repeat upgrades - cancellations - Pro account deletions = closing Pro`

Cancellations and account-deletion exits are separate movements. The ledger includes repeat Pro entries so a subscriber who returns to Pro is not lost from the reconciliation.

## 6. Diagnostic definitions

### Free restrictions

Use tier at the event date. On date-only subscription transitions, the latest subscription start takes precedence. The source cannot establish intraday ordering, so overlapping transition-date exposure remains a disclosed convention.

Report three different quantities: restriction events per exposed Free user; restriction events per 100 recorded Free events; and the proportion of exposed Free users with at least one restriction event. The first two describe event intensity. The third describes how widely recorded restrictions are distributed. None estimates restrictions among Free accounts with no recorded events.

### Pricing and value

Keep the opening-cohort cancellation rate separate from cancellation reason share. A reason share answers what cancellers reported, not the probability that an opening subscriber will cancel.

Derive higher-price invoice exposure from invoices with a recorded price of at least 14.99. Successful higher-price payment exposure requires a successful payment transaction attached to such an invoice. Preserve `price_notice_date`, but do not treat it as evidence of actual individual notice receipt or renewal. First-upgrade billing is incomplete; renewal amounts are not complete product revenue.

### Workflows

Group by user, session, and raw journey ID. Raw journey ID alone has collisions. Use the recorded interface variant for each validated attempt and retain platform, feature, and period filters.

`Failed / (completed + failed)` is the failure rate among resolved attempts. Report completed, failed, and abandoned counts beside it. Abandoned attempts are excluded from that particular denominator. Their start-only construction limits behavioural interpretation, and excluding them also makes the resolved rate conditional on an observed terminal outcome.

### Checkout

Count valid starts by checkout-start date. Pre-redesign and post-redesign flows have different numbers of steps. Compare each stage with its own flow's starts, retaining counts and completion percentage. Stage reach is derived from completed steps, not step-view events. Step position does not establish the purpose of a step.

The all-history pre-period provides context, while the nearer March-May 2025 period provides a more relevant pre-June comparison. Neither is a randomized control. Price and product changes overlap these windows.

### Sync reliability

Divide failed recorded sync outcomes by completed plus failed recorded sync outcomes. This is an outcome-based rate, not a confirmed failure rate for all requests. Compare Android with Web and iOS under the same calendar window.

The preserved fixed follow-up view has only four eligible users in the current export. Its 20% threshold and minimum three outcomes are analytical choices. The investigation report does not use it as persuasive evidence of an engagement effect.

### Account deletion

The new calendar comparison selects the deletion outcome month. For December 2025, both deleted and retained groups use activity from 1 November through 30 November. Eligible users registered by 1 November and remained open at the start of December. Deleted users leave during December; retained users remain open through its end.

Friction means at least one recorded `action_blocked`, `allowance_reached`, `sync_failed`, or `action_failed` event in the observation month. January 2023 outcomes are excluded because December 2022 activity is unavailable.

A pooled comparison counts account-month observations. A retained person can appear in several months. Do not call this the number of unique retained people or an individually matched causal study.

## 7. Power BI handoff

The existing `vw_deletion_comparison` retains its 30-day definition and column contract. The new `vw_deletion_comparison_calendar_month` is an additional view. Updating SQL files alone does not switch the existing Power BI table or measures to the new definition.

After permanent deployment, author the calendar comparison as a separate query or deliberately change the existing deletion table's source and its dependent measures. A comparison-month dropdown can then filter that chart only. Validate both groups, observation dates, counts, and rates for the selected month. Label the outcome month and preceding friction month in the subtitle or tooltip.

Keep the page's trend-period slicer distinct from the KPI-month control. Use a common platform dimension for measures that share a platform population. Event Tier is an event-only filter, not a universal plan filter for cohorts, cancellations, or account movement.

For cancellation changes, a positive percentage-point value represents an increase. An adverse increase can be red while retaining a plus sign. Colour expresses business interpretation; the sign expresses mathematical direction.

This SQL delivery does not save, close, refresh, or certify the current Power BI report. A separate dashboard check must reproduce cited values with the intended filter state.

## 8. Evidence and reproducibility

The stakeholder report includes a source/query crosswalk. Preserve the SQL result evidence and raw audit together with their input hashes. Reproduce a cited figure using its exact period, platform, workflow feature, eligibility rule, and numerator/denominator.

For report screenshots, record the KPI month and trend range separately. Create bookmarks only when the corresponding report state has actually been saved and checked. The investigation report's crosswalk identifies evidence queries; it does not assert that screenshots or final bookmark states exist.

Earlier scenario-oriented interpretation should not override the exact recorded calculations. In particular, the current January–December 2025 audit finds lower restrictions per recorded Free user, despite slightly higher restrictions per 100 Free events. The report preserves that mixed evidence. Likewise, the recorded October account decline is followed by small positive November and December movements. Reconcile older prose to the exact numerator, denominator and period before reusing it.

Recommendations in the stakeholder report are proposed investigations, controlled tests, or feasibility assessments. They do not represent approved product changes, completed delivery, or measured benefits.
