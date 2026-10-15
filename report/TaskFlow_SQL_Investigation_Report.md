# TaskFlow SQL supporting analysis - supplement to the Power BI dashboard report

Version 1, draft for review. Revised 4 October 2026. Historical coverage: 1 January 2023 to 31 December 2025. Main investigation period: 2025.

This supplement explains the calculations and evidence behind [TaskFlow Power BI dashboard report v1](TaskFlow_Power_BI_Dashboard_Report_v1.md). The primary report establishes the operational downturn before examining two leading explanations: Pro pricing/value and system design across workflows and checkout. Those explanations remain unconfirmed. This document provides their detailed populations, alternative comparisons and reproduction paths, with Free restrictions, Android reliability, deletion and acquisition retained as supporting context.

TaskFlow is a fictional productivity product and all records are synthetic. The supplement records observed results, interpretation boundaries and unresolved questions. It does not establish real customer behaviour, stakeholder approval or benefits from a product intervention. SQL validation took place on 1 October 2026 Sydney time; the preserved-source audit and read-only Power BI inspection took place on 2 October. An independent raw-CSV recomputation on 3 October added engagement-depth, subscriber-bridge and workflow-identity checks. That recomputation did not execute SQL Server or DAX or inspect Power BI. On 4 October, the live Power BI deletion measures were revised and checked using the same preceding calendar month as the supporting SQL. At the 4 October handoff, the live changes had not been saved and reopened; the current saved dashboard has not been checked by this packaging task.

## 1. Evidence coverage and recorded validation

The analysis uses separate account, event, subscription, workflow, checkout, billing and review populations. Reporting views derive consistent account-months and attempt identities while retaining source records and nulls. Combining these facts in a single detail join would multiply observations, so each measure is calculated at its relevant grain. The [SQL reporting guide](../docs/SQL_REPORTING_GUIDE.md) contains execution instructions, parameters and view contracts.

The [recorded SQL run](../docs/sql_validation_2026-10-01/sql_execution_results.json) returned 32 result sets. Its `success`, `rollback_completed` and `database_view_definitions_unchanged` flags are all true. The runner temporarily applied the reporting views inside a transaction, captured the query results and restored the original database definitions. This validates the tested SQL contracts against the imported database. The calendar-month deletion view was not permanently deployed by that run.

The [SQL acceptance record](../docs/sql_validation_2026-10-01/acceptance_checks.json) reports 740 passing field-level and integrity assertions. These are value and boundary checks, rather than separate business scenarios. The separate historical parameter-test transcript is outside this lean evidence set. QA01 records zero account and Pro movement residuals. QA02 records zero structurally invalid attempts among 17,991 workflows and 689 checkouts. QA03 records zero calendar-window violations or duplicate account-months. Their scope is limited to the definitions tested.

The retained [raw calculation record](../docs/sql_validation_2026-10-01/raw_evidence.json) contains the SHA256 hashes and row counts for all 11 exports, key/orphan and review-rating checks, and monthly movement residuals. SQL QA06 records 2,911 events with multiple date-only subscription matches. Latest-start-date and subscription-ID precedence provides a consistent reporting classification, while intraday tier order remains unknown.

The evidence crosswalk below uses retained SQL outputs, CSV calculations and raw tables. Screenshots, live Power BI session outputs and the two later report audits are outside this package. The retained evidence does not certify every visual interaction or a saved and reopened PBIX.

The historical 3 October revision audit added engagement-overlap, subscriber-bridge and workflow-grouping checks without running SQL Server or DAX. Its script and output are excluded. Engagement and pooled-cohort values can be calculated directly from the retained raw tables under section 2 definitions; subscriber-period values can be calculated from S1 Q01. Detailed alternative workflow-grouping results below remain historical assertions with their audit evidence outside this package.

SQL QA09 agrees with the preserved-source manifest:

| Source | Recorded rows | Analytical use |
|---|---:|---|
| Users | 1,500 | Registrations, original cohorts and account exits. |
| Activity_Events | 120,000 | Recorded activity, successful actions, restrictions and sync outcomes. |
| Subscription_History | 2,078 | Pro entries, cancellations and subscriber exposure. |
| Sessions | 74,834 | Session context and workflow identity. |
| Reviews | 805 | Selected ratings and investigation themes. |
| Invoices | 3,421 | Recorded renewal-invoice exposure. |
| Payment_Transactions | 3,421 | Recorded transactions and successful payment exposure. |
| Date | 1,096 | Contiguous dates from 1 January 2023 to 31 December 2025. |
| Business_Change_Register | 6 | Synthetic business-change context. |
| Plan_Versions | 4 | Recorded plan definitions. |
| Platforms | 3 | Web, iOS and Android scope. |

## 2. Metric definitions and populations

The historical cutoff is 31 December 2025. Report preparation in 2026 does not extend observation. Apply platform filters to both sides of a rate, retain counts beside percentages and distinguish a measured zero from an unavailable rate. Monthly distinct-user counts are not additive annual headcounts; opening and closing stocks are not summed across months.

The primary report normally presents percentages and average monthly counts to one decimal place, and activity intensities and review ratings to two. This supplement retains exact counts and fractions, with additional decimals where useful. Round half up from the unrounded calculation: `63 / 240 * 100 = 26.25%`, presented as `26.3%`. Calculate differences and changes before rounding their components; the displayed percentages may therefore not reproduce the final rounded change exactly.

| Measure | Numerator and denominator | Period, grain and exclusions |
| --- | --- | --- |
| Registrations | Count of registered accounts. Channel share divides channel registrations by all registrations in the same scope. | Registration calendar month; one account per registration. Channel represents recorded signup composition. |
| Recorded active users | Distinct accounts with at least one recorded event. | Calendar month and signup platform. Coverage outside the export is unknown. |
| Meaningful engagement | Distinct users with a successful meaningful action; participation divides these users by recorded active users. Intensity divides successful meaningful actions by meaningfully active users. | Same calendar month and platform. Actions are `task_completed`, `workflow_completed`, `first_task_completed`, `report_viewed` and `reminder_set`, with successful results. Purchases are separate. |
| Recorded activity without meaningful use | Recorded active users minus meaningfully active users; share divides this count by recorded active users. | Same calendar month and platform. Absence of a successful meaningful action does not establish absence of benefit or exposure to friction. |
| Meaningful retention | Meaningfully active original registrants at an observed cohort age divided by the fixed original registration-cohort size. | Age zero is registration calendar month. Later deletion does not reduce the denominator. Include complete observation months; future ages remain blank. |
| Paid cancellation rate | Distinct cancelling users who were Pro at month opening divided by distinct opening Pro users. | Matching opening cohort on both sides. All cancellation events are a separate measure. Cancellation does not necessarily delete an account. |
| Closing Pro base | Opening subscribers plus first entries and repeat entries, less cancellation exits and Pro account-deletion exits. | Carried-forward stock under one boundary convention. Exit types are kept distinct to avoid double-counting. |
| 90-day first-Pro conversion | First Pro entries within the defined observable window divided by eligible original registrants. | Headline comparison requires fully mature monthly cohorts, through September 2025. Repeat Pro entries are excluded. |
| Restriction exposure | Restriction events per user with recorded event-time Free activity; affected share is exposed users with a restriction divided by all exposed users. Event frequency divides restrictions by recorded Free events. | Calendar month. Accounts with no Free events are outside the exposure denominator. Events per user are an intensity, not a percentage. |
| Resolved workflow failure | Failed valid attempts divided by completed plus failed attempts. Completion per start divides completed attempts by all valid starts. | Derived user/session/journey identity, recorded variant, platform, feature and period. Abandoned attempts are outside the resolved denominator. |
| Checkout progression | Completed purchases or cumulative completed-stage reach divided by valid starts in the same flow period. | Checkout-start date and derived user/checkout identity. Pre-change steps three and four are inapplicable and remain blank. |
| Sync failure | Failed recorded outcomes divided by completed plus failed recorded outcomes. | Calendar month and platform. Request events are counted separately because complete matching is unestablished. |
| Preceding friction | Eligible account-months with at least one blocked action, allowance-reached event, sync failure or action failure divided by eligible account-months in each outcome group. | Supporting SQL and the dated DAX definitions use the previous full calendar month; current saved-model behaviour is unverified. Registration and account-open eligibility apply equally to both groups. |
| Review rating | Total rating points divided by the number of review records. Theme share uses review records in the same scope. | Selected reviewers. A period average weights each review equally; zero-review months have no defined rating. |
| Cancellation and deletion reason mix | Count of assigned reason labels divided by all cancellation events or deletion records in the same period. | Generator-assigned simulation labels. Cancellation events, deleted accounts and opening Pro populations are separate grains; labels do not establish real customer testimony or causal explanation. |

The account identity is `opening accounts + registrations - deletions = closing accounts`. The Pro identity adds first and repeat entries separately and deducts cancellations and Pro deletion exits separately. For 2025, the Pro bridge is `145 + 160 + 10 - 160 - 11 = 144`. These reconciliations check stock arithmetic; they do not explain why a customer entered or left.

## 3. Supporting analysis for the operational baseline and two explanations

### 3.1 Engagement depth and the gap in useful activity

Meaningful engagement measures successful use under the stated action definition. A wider event-depth check helps distinguish extensive recorded activity from intensive use. The following values use retained Activity_Events records, all signup platforms, calendar-month scope. Count events by user and month; identify successful meaningful actions using section 2; then count single-event, failed and blocked flags within users without a meaningful action.

| Measure | January 2025 | December 2025 |
| --- | ---: | ---: |
| All recorded events | 6,065 | 3,568 |
| Recorded active users | 1,074 | 1,155 |
| Events per recorded active user | 6,065/1,074 = 5.6471 | 3,568/1,155 = 3.0892 |
| Single-event active users | 27/1,074 = 2.51% | 284/1,155 = 24.59% |
| Active without a successful meaningful action | 54/1,074 = 5.03% | 345/1,155 = 29.87% |
| Single-event users within that group | 11/54 = 20.37% | 161/345 = 46.67% |
| Users with any failed result within that group | 0/54 = 0.00% | 91/345 = 26.38% |
| Users with any blocked result within that group | 17/54 = 31.48% | 109/345 = 31.59% |

The last three rows share a denominator and overlap. Their shares cannot be added to attribute the absence of meaningful activity. Failed and blocked flags use all event results, not workflow failures alone. A single-event user can belong to either flag, while users without flags can still have unrecorded difficulties or receive value through actions outside the meaningful definition.

For December's 345 users, the mutually exclusive partition is: neither a single event nor a failed/blocked result, 54; multiple events and blocked only, 49; multiple events and failed only, 68; multiple events with both failed and blocked results, 13; a single event with neither flag, 104; a single blocked event, 47; a single failed event, ten; a single event with both flags, zero. These counts reconcile to 345. They check overlapping classification and do not estimate a causal contribution from lighter use or friction.

### 3.2 Subscriber movement and the price/value explanation

The annual Pro bridge is nearly flat, but its component flows changed. Sum the first entries, repeat entries and separate exits in retained S1 Q01 for each period, then divide by three or six months. These rows use the carried-forward stock convention defined by the SQL reporting views.

| Pro movement | March to May 2025: total | Monthly mean | July to December 2025: total | Monthly mean |
| --- | ---: | ---: | ---: | ---: |
| First entries | 64 | 21.3333 | 54 | 9.0000 |
| Repeat entries | 6 | 2.0000 | 3 | 0.5000 |
| All entries | 70 | 23.3333 | 57 | 9.5000 |
| Cancellation exits | 55 | 18.3333 | 79 | 13.1667 |
| Pro account-deletion exits | 4 | 1.3333 | 7 | 1.1667 |
| Net movement | +11 | +3.6667 | -29 | -4.8333 |

The periods differ in duration, so the comparison uses monthly means: `1 - (57/6)/(70/3) = 59.2857%` fewer Pro entries. March opens at 176 and May closes at 187. July opens at 173 and December closes at 144. June records five first entries, one repeat entry, 20 cancellations and no Pro deletion exits: `187 + 5 + 1 - 20 = 173`.

Cancellation counts fell between these periods while entry fell more. The March-to-May unweighted mean opening-cohort cancellation rate is 10.32%, versus 8.40% in July to December. Comparing either period with the 2024 baseline answers a different question from whether cancellation counts kept rising later in 2025. The bridge supports examining weaker subscription entry alongside retention and prevents a pricing-only account of late contraction.

The scenario's monthly price increased from AUD 9.99 to AUD 14.99: `(14.99 - 9.99)/9.99 * 100 = 50.0501%`, or 50.1%. Opening-cohort cancellation increased from February's 5/160 to March's 20/176. The full comparison is 3.59% mean monthly cancellation in 2024 versus 9.21% in March to December 2025. The 100/160 price/value reason share is 62.5%, using cancellation events as its population. Reasons were assigned by the generator according to calendar/tier rules and randomness; they do not independently measure subscriber motivations or reactions to an invoice.

Q09 and QA08 distinguish higher-price invoices from successful payments. The global `price_notice_date` is not a customer's first higher-price renewal and cannot establish notice receipt. Exposure classification, customer-value evidence and billing feasibility are required before comparing the current price with a limited price or packaging intervention. First-upgrade billing remains incomplete, limiting complete revenue and profitability analysis.

### 3.3 Workflow and checkout evidence for the system-design explanation

Two processes are examined separately: useful work inside TaskFlow and subscription entry. The 2025 canonical workflow totals are Old 2,889 starts, 2,156 completed, 42 failed and 691 start-only; New 5,876 starts, 2,916 completed, 992 failed and 1,968 start-only. Resolved failure rates are `42/(2,156+42) = 1.9108%` and `992/(2,916+992) = 25.3838%`. Failure per valid start is a different measure: 1.4538% and 16.8822%. Completion per valid start is 74.6279% and 49.6256%. The denominator must accompany a chart or quoted rate.

The historical 3 October audit, whose detailed output is outside this package, compared the validated `user_id|session_id|journey_id` identity with alternative groupings. Adding user identity prevents unrelated accounts sharing a random raw journey ID from becoming one attempt. Within 2025, `user_id|journey_id` gives the same Old/New totals as the canonical identity. Grouping by raw journey alone yields 2,886 Old groups and 5,873 New groups, including one and five invalid groups respectively. After validation it leaves Old 2,885 valid starts, 2,152 completions and 42 failures, and New 5,868 valid starts, 2,914 completions and 992 failures. Raw-journey aggregation can therefore distort denominators and validity even when the broad comparison direction survives.

The order of grouping and filtering also matters with a colliding key. Grouping all history by raw journey before selecting 2025 leaves New 5,864 valid starts, 2,912 completions and 991 failures. The canonical key retains New 5,876/2,916/992 in either calculation order. The excluded historical audit held the collision examples and component identities; the retained SQL outputs independently record the canonical attempt counts, but do not reproduce these alternative-grouping checks. The report uses canonical values; alternatives are sensitivity checks, not a repair to the source records.

For iOS Projects under New, the canonical 2025 population is 455 starts, 214 completions, 87 failures and 154 start-only attempts. Its resolved failure rate is `87/301 = 28.9037%`; failed per valid start is `87/455 = 19.1209%`. Grouping all history by raw journey first loses a valid completion in this example and illustrates why a different chart count requires inspection of identity and scope.

Checkout completion is 305/449 before June and 63/240 afterward. Cumulative completed-stage reach is 370 and 317 before June, versus 181, 130, 98 and 64 afterward, using each period's valid starts as the common denominator. Recorded payment failures are 12/317 submissions and 1/64. Q15's nearby equal-duration windows, 70/111 in March to May and 21/102 in June to August, retain the direction of the full-history comparison.

These process results support a design inquiry without quantifying attributable cancellations, lost upgrades or recoverable revenue. Old/New exposure is unequal, concurrent changes overlap, and the generator constructs start-only workflows and checkout continuation. Confirm task needs and checkout step purposes before specifying a controlled design test. Acquisition causality and the technical mechanism of Android sync failure remain separate unresolved questions.

### 3.4 Alternative periods and sensitivity checks

The checks below show how aggregation and comparison choices affect interpretation. They retain the same preserved sources. Agreement across calculation paths checks implementation consistency; it does not create independent customer evidence.

| Comparison choice | Recorded result | Interpretation boundary |
|---|---|---|
| Registration benchmark | December 2025 is 87.6% below January 2025, 71.6% below the 2024 monthly mean of 45.83, and 72.9% below December 2024's 48. | January's 105 is unusually high and has no listed explanation. The primary report uses the prior-year mean and comparable December context. |
| Mean monthly cancellation versus pooled observations | Unweighted monthly means are 3.59% in 2024 and 9.21% in March to December 2025. Pooled rates are 42/1,180, or 3.56%, and 154/1,662, or 9.27%. | Both show deterioration. Pooled denominators contain recurring opening Pro account-months, not distinct people across the period. |
| Free restrictions across broader periods | Pooled 2023 to 2024 versus February to December 2025: 0.489 versus 0.253 events per exposed Free user-month; affected shares 37.32% versus 21.85%; 8.245 versus 7.919 restrictions per 100 Free events. | These period summaries differ from the immediate January/February comparison. A February event-share increase does not establish a sustained increase across every denominator. |
| Simple monthly means for the same Free periods | Events per exposed user: 0.508 versus 0.253; affected share: 38.69% versus 21.92%; events per 100 Free events: 8.045 versus 7.851. | Unequal monthly populations give pooled rates and simple means different weights. Retain one convention within a reported period comparison. |
| Retention pooled by signup year versus individual monthly cohorts | At age three, eligible retention pooled by signup year is 97.1% for 2023, 95.8% for 2024 and 78.0% for 2025. January 2025 records 81.0%, while July records 92.3%. | The pooled deterioration coexists with individual variation. At age six, 2025 uses January to June and a denominator of 387; age three uses January to September and 455. |
| Mature conversion cohort variation | January records 19/105, April 4/48 and March 15/75. June to September rates range from 4.3% to 7.7% across cohorts of 19 to 30. | March interrupts a monotonic decline. Small later groups and differing observation periods limit customer-quality or change-effect claims. |
| Checkout periods | Full-history pre-June completion is 305/449, or 67.9%, versus 63/240, or 26.3%, afterward. March to May records 70/111, or 63.1%, versus June to August's 21/102, or 20.6%. | The nearby equal-length comparison retains the direction, while overlapping changes prevent attribution to the June flow alone. |
| Workflow scope | The primary comparison uses all valid 2025 platform/feature groups. A worked Web/Tasks comparison is Old 3/207, or 1.45%, versus New 102/445, or 22.92%, among resolved attempts. | An all-history Old baseline, a specific feature and an Android/Reports comparison answer different questions. Scope must accompany the rate. |
| Deletion monthly versus pooled scope | Pooled 2025 calendar comparison: 25.81% deleted versus 25.28% retained. December alone, using November activity: 1/12, or 8.33%, versus 341/1,323, or 25.77%. | Monthly direction can differ from the pooled result. Retained observations repeat and some users later enter the deleted group. |

Cancellation sensitivity uses unweighted means of the selected monthly rates in S2 `operational_monthly`. Free-restriction period rates use summed matching numerators and denominators in S2 `free_restrictions_monthly`, with monthly means shown separately. Pooled retention and weighted review summaries use S4 raw records under section 2 definitions. Nearby checkout windows have recorded S1 Q15 outputs. The excluded later audits are not required inputs for these calculations.

## 4. Calculation and dashboard visibility differences

### Deletion observation windows

The Power BI model inspected on 2 October used the imported `vw_deletion_comparison` records. Their lookback was the 30 days strictly before an index date: deletion date for deleted accounts, month end for retained accounts. Registration eligibility followed that index. The generator omits activity throughout deletion months, so the two groups could have different observable portions of their lookbacks. The legacy 30-day definition is discussed here to explain its difference from the retained calendar-month SQL and later DAX; the earlier session captures are outside this package.

The supporting SQL uses `vw_deletion_comparison_calendar_month`. Both groups use the same full preceding calendar month and must have registered by that month's first day and remained open at the outcome month's start. For December outcomes, observation is 1 to 30 November. January 2023 outcomes are unavailable because December 2022 activity is absent. Five of the 129 recorded 2025 deletions fail this registration eligibility rule; the pooled comparison therefore uses 124 deleted observations.

The historical 4 October handoff described a live revision of three deletion measures to the same full preceding calendar month as the SQL. The dated calendar DAX file retains those definitions. Its preview and applied-model verification outputs are excluded, so no live test-suite or current saved-model pass is claimed here. S1 Q16P independently records B23's pooled SQL values: deleted 32/124 and retained 3,652/14,445. Incomplete tracking and repeated observations remain limits. The earlier SQL run rolled back the calendar view, and a DAX revision does not deploy a database view. The historical handoff left Power BI unsaved.

### Cohort maturity

Q11 exposes individual 90-day eligibility as well as a fully mature monthly headline rate. October has 17 registrants, one individually eligible user and one first-Pro conversion. Its eligible-only rate is 1/1, but its `fully_mature` flag is zero and its `headline_mature_conversion_rate` is null. November and December are also immature.

The historical dashboard definition requires both individual eligibility and whole-cohort maturity. It excludes October to December from its eligible and converted headline populations, leaving their rate blank. Both the SQL headline and dashboard headline therefore exclude these cohorts. The single-user October SQL result is a supporting eligibility check and cannot be reported as an October cohort conversion finding.

### Calculation scopes and Power BI status

Retained SQL and CSV records establish the calculation scopes cited in Appendix B. The report's engagement, subscriber and cancellation trends use all platforms and calendar months in 2025. Workflow results use 2025 valid attempts by recorded interface, platform and feature. Checkout uses fixed January 2023 to May 2025 and June to December 2025 periods; the nearby windows are separate comparisons.

October screenshots, bookmark records and live-measure outputs are excluded. The historical handoff described unsaved Power BI edits. This package supports reviewing analytical definitions and recorded results, while current visual interactions, bookmark recall and saved-model persistence require a separate Power BI check.

## 5. Limits and their consequences

| Limitation | Consequence for interpretation |
|---|---|
| Synthetic construction and shared generation rules | The report is a portfolio investigation. Cancellation and deletion reasons are assigned by the generator. Cross-checks confirm calculation consistency; coinciding changes, events, reasons and reviews cannot establish independent customer or causal evidence. |
| Incomplete activity coverage | All 150 historically deleted accounts lack deletion-month events. Absence of recorded activity or friction does not establish absence of actual use or problems. |
| One signup platform per account | Platform comparisons describe different user populations. They cannot compare the same person's experience across devices or control for platform selection. |
| Date-only subscriptions and overlapping exposure | Event-time tier follows documented precedence for 2,911 ambiguous rows. Notice receipt and within-day changes remain unknown. |
| Billing coverage | Renewals are recorded, while first-upgrade billing is incomplete. Complete revenue, profitability, price elasticity and the financial return of an option cannot be estimated. |
| Workflow and checkout validity scope | Derived identities repair raw journey collisions. All 4,217 abandoned workflows are start-only. Checkout checks cover starts, platforms, timestamps, contiguous completed-step sets and terminal consistency; they do not certify every step-view/completion ordering. |
| Small or unequal groups | Later conversion cohorts, pricing exposure groups and the four-user sync follow-up limit effect estimates. Broader population summaries cannot resolve these limits. |
| Selected reviews and unavailable acquisition/technical evidence | Review themes do not measure prevalence. Missing visitors, attempts and spend leave acquisition mechanism unresolved; missing service tracing leaves sync mechanism unresolved. |
| Observational and repeated account-months | Retained deletion-comparison users repeat and can later be deleted. Pooled rates are descriptive observations without individual matching or an independent causal control. |
| Verification and authority scope | Earlier read-only inspections and live checks are historical; their detailed outputs are outside this package. Retained SQL and CSV records do not verify every Power BI interaction or a saved/reopened artifact. Product implementation, business approval and achieved benefits remain unrecorded. |

## Appendix A. SQL query and reproduction crosswalk

Use [03_dashboard_queries.sql](../sql/03_dashboard_queries.sql) to locate query IDs in the [recorded execution results](../docs/sql_validation_2026-10-01/sql_execution_results.json). Each result set records columns, row count and rows; the row's `query_id` is the locator. The [view definitions](../sql/02_reporting_views.sql), [raw audit](../docs/sql_validation_2026-10-01/audit_raw_evidence.py) and [SQL reporting guide](../docs/SQL_REPORTING_GUIDE.md) provide the calculation and execution paths. Preserve the recorded run and use a new evidence directory for any later execution.

| Evidence topic | Query/control IDs | Output population and matching evidence |
|---|---|---|
| Monthly baseline, KPI changes and movements | Q01, Q02; QA01 | Monthly account and subscriber stocks/movements; S2 `operational_monthly`. |
| Retention and first-Pro conversion | Q03, Q11; QA07A, QA07B | Original cohorts and observable windows; S4 raw-table pooled retention under section 2 definitions; S2 `conversion_90d_by_cohort`. |
| Reviews | Q04, Q05 | Review month/theme; S2 `reviews_monthly`; S2 monthly review counts and ratings; S4 individual-review-weighted period ratings. |
| Registration composition and benchmark | Q06, Q07 | Month/channel and full 2024 monthly baseline; S2 `registrations_by_month_channel`. |
| Free restrictions | Q08; QA06 | Event-time Free exposure; S2 monthly measures; aggregate matching S2 numerators and denominators for alternative periods. |
| Pricing and value | Q09, Q10; QA08 | Opening Pro invoice/payment exposure and cancellation-event reasons, kept separate. |
| Workflows | Q12, Q13; QA02, QA05A | Valid attempts by recorded platform, feature and variant. |
| Checkout | Q14, Q15; QA02 | Valid starts, cumulative stages and fixed nearby periods. |
| Deletion | Q16, Q16P, Q16R; QA03, QA04 | Prior-calendar-month eligible observations; all deletion reasons separately. Dated calendar DAX is an authoring reference; current saved-model execution is unverified. |
| Sync and engagement context | Q17, Q17E; QA05B | Recorded outcomes, monthly meaningful users and the exploratory follow-up, kept separate. |
| Changes and source coverage | Q18; QA06 to QA09 | Scenario records, date/tier/billing controls and imported source counts. |

Recorded defaults are All platforms, January to December 2025 trends/outcomes and December KPI month, with 2023 to 2025 checkout context. Q07 uses the full 2024 benchmark. Q15 uses fixed March to May, June to August and June to December 2025 windows. Each output's period must be read independently. Decimal rates require multiplication by 100 for percentages; fields ending `_pp` already express percentage points. No new execution is claimed by reproducing this crosswalk in version 1.

## Appendix B. Number-to-source trace and dashboard evidence

The B-series IDs link the primary report's rounded values to calculation detail. S1 to S4 identify the retained records and raw tables. H1 marks historical detail whose later audit output is excluded. Dashboard panel references locate the analytical question; they do not certify current visual behaviour.

| Source ID | Evidence record | Scope and recorded status |
|---|---|---|
| S1 | [SQL execution](../docs/sql_validation_2026-10-01/sql_execution_results.json) | Recorded 1 October Sydney time; 32 result sets; transaction rolled back and prior view definitions restored. |
| S2 | [CSV calculations](../docs/sql_validation_2026-10-01/raw_evidence.json) | Preserved-export metrics, source hashes and selected comparisons accompanying the recorded SQL run. |
| S3 | [SQL reporting guide](../docs/SQL_REPORTING_GUIDE.md) and [reporting views](../sql/02_reporting_views.sql) | Definition and reproduction sources; authored code alone is not execution evidence. |
| S4 | [Users](../data/raw/Users.csv), [Activity_Events](../data/raw/Activity_Events.csv) and [Reviews](../data/raw/Reviews.csv) | Source rows for engagement depth/overlap, pooled cohort retention and individual-review-weighted period ratings. Apply section 2 definitions and the stated periods; the raw tables are not precomputed summary outputs. |
| H1 | Historical 3 October workflow-grouping audit, excluded from this package | Alternative raw-journey collision counts and examples remain historical assertions. S1 Q12 retains canonical counts, which are distinct from those sensitivity checks. |

| ID | Reported values | Panel reference | Calculation period and population | Supporting source |
|---|---|---|---|---|
| B01 | Registrations: 48 in December 2024; 105 in January, 37 in May and 13 in December 2025; 2024 monthly mean 45.83; December 71.6% below that mean. | D1-1 | Registration month, all platforms; full 2024 benchmark. | S1 Q01/Q02/Q07; S2 `operational_monthly`, `headline_comparisons`. |
| B02 | January/December: active 1,074/1,155; meaningful 1,020/810; participation 95.0%/70.1%; actions 2,636/1,316; intensity 2.58/1.62. | D1-2 | Selected 2025 months, all signup platforms. | S1 Q01; S2 `operational_monthly`. |
| B03 | March meaningful users 1,074; December 2024 intensity 2.52. | D1-2 | Respective calendar months, all platforms. | S1 Q01 for March; S2 `operational_monthly`. |
| B04 | Age three: 2023 437/450, 97.1%; 2024 527/550, 95.8%; 2025 January to September 355/455, 78.0%. Age six: 414/450, 92.0%; 480/550, 87.3%; 2025 January to June 278/387, 71.8%. January 2025 age three 85/105, 81.0%; July 24/26, 92.3%. | D1-4 | Original cohort sizes; complete calendar observation months. | S4 Users registration month and successful meaningful Activity_Events at cohort age three/six; pool eligible original cohort sizes and active users by signup year. S1 Q03 supplies worked 2025 examples. |
| B05 | 90-day first conversion: January 19/105, 18.1%; April 4/48, 8.3%; March 15/75, 20.0%; June to September 4.3% to 7.7%, with 19 to 30 registrants. | D2-3 | January to September 2025 mature monthly cohorts, all platforms. | S1 Q11/QA07; S2 `conversion_90d_by_cohort`. Both headline paths exclude October to December. |
| B06 | Closing Pro: December 2024 145; May 2025 187; November 143; December 144; May to December down 23.0%; December month-on-month up 0.7%. | D1-3 | Carried-forward monthly stock, all platforms. | S1 Q01/Q02; S2 `headline_comparisons`. |
| B07 | Annual Pro bridge: 145 + 160 first + 10 repeat - 160 cancelled - 11 deletion exits = 144. | D1-3 | 2025 movements; distinct entry and exit types. | S1 Q01/QA01; S2 `operational_monthly`. |
| B08 | Mean monthly cancellation 3.59% in 2024 and 9.21% March to December 2025, about 2.6 times; November 11/145, 7.59%; December 12/143, 8.39%; +0.81 percentage points; one December event about 0.7 points. | D1-6 / D2-2 | Opening Pro each month; unweighted period means. | S1 Q01/Q02; S2 `operational_monthly`; take unweighted means of the selected S2 monthly rates. |
| B09 | December KPIs: new 13, -13.3%; active 1,155, -2.6%; Pro 144, +0.7%; cancellation 8.39%, +0.81 percentage points. | KPI cards | December versus November 2025, all platforms. | S1 Q02; S2 `operational_monthly`. |
| B10 | Accounts opening 979 / closing 1,350; 500 registrations - 129 deletions = +371; October 17/19; November net +2; December net +1; historical deletions 150. | D1-5 | 2025 account movement; historical deletion count separately. | S1 Q01/QA01; S2 `operational_monthly`, `headline_comparisons`. |
| B11 | Ratings: January 10/4.60; February 33/2.67; December 93/2.24. Period averages: 292 points/67 reviews, 4.36 in 2023 to 2024; 1,758/728, 2.41 in February to December 2025. Eleven of 19 review months had fewer than five; five calendar months had none. | D1-7 | Selected reviews; each individual review receives equal weight. | S1 Q04; S2 `reviews_monthly`; S4 review records: sum ratings and divide by review count in each stated period. |
| B12 | December themes: restrictions, navigation, sync, price and checkout. | D1-7 | Selected December reviews. | S2 `reviews_monthly`. |
| B13 | Restrictions/user: 389/921, 0.422 to 222/1,019, 0.218; affected share 295/921, 32.0% to 194/1,019, 19.0%. | D2-1 | January/December 2025 event-time Free exposure. | S1 Q08; S2 `free_restrictions_monthly`. |
| B14 | Restrictions per 100 Free events: January 7.60, February 9.05, December 7.80; January/December Free events 5,121/2,846. | D2-1 | Monthly event-time Free events and documented tier convention. | S1 Q08; S2 `free_restrictions_monthly`. |
| B15 | February cancellation 5/160, 3.13%; March 20/176, 11.36%; April to December 6.36% to 10.70%; 2025 price/value reasons 100/160, 62.5%; December 10/12, 83.3%. | D2-2 | Opening Pro monthly cohorts; cancellation reason events separately. | S1 Q01/Q10; S2 `operational_monthly`. |
| B16 | Workflow failures: Old 42/2,198 resolved, 1.91%; New 992/3,908, 25.38%; starts 2,889/5,876. | D2-5 | 2025 valid attempts, all recorded platforms/features. | S1 Q12 aggregate counts. |
| B17 | New examples: Android Projects 69/216, 31.94%; Android Tasks 55/190, 28.95%; iOS Projects 87/301, 28.90%. | D2-5 | 2025 resolved attempts by platform, feature and New variant. | S1 Q12. |
| B18 | Checkout: January 2023 to May 2025 305/449, 67.9%; June to December 63/240, 26.3%; March to May 70/111, 63.1%; June to August 21/102, 20.6%. | D2-7 | Valid starts, all platforms; whole-history and nearby periods separate. | S1 Q14/Q15. |
| B19 | Stages: before 370,317 of 449; after 181,130,98,64 of 240; failed payments 12/317, 3.79%, versus 1/64, 1.56%. | D2-7 | Completed stages/valid starts; payment failures/submissions. | S1 Q14; payment outcomes remain a separate denominator. |
| B20 | Android sync: June 0/26; July 26/76, 34.2%; December 29/88, 33.0%; Web/iOS failures zero in selected comparison windows. | D2-6 | Recorded completed plus failed outcomes by month/platform. | S1 Q17; S2 `sync_monthly`. |
| B21 | Fixed follow-up: one higher-failure and three lower-failure users; all with later meaningful activity. | D2-6 | Preserved July to August exposure and September to December follow-up. | S1 QA05B; S3 `vw_sync_followup` definition. |
| B22 | June/December meaningful users: Android 207/181, -12.6%; Web+iOS 677/629, -7.1%. | D1-2 / D2-6 | Signup-platform monthly users. | S1 Q17E; S2 `meaningful_active_by_signup_platform`. |
| B23 | Prior-calendar friction: deleted 32/124, 25.81%; retained 3,652/14,445, 25.28%; +0.52 percentage points; retained 1,441 distinct users; five 2025 deletions ineligible. | D2-4 | 2025 outcome account-months; same full previous calendar month and eligibility in supporting SQL and the dated DAX definitions. | S1 Q16P/QA03/QA04; S2 `deletion_prior_calendar_month_pooled_2025`. The dated calendar DAX specifies the matching window, but current saved-model execution is unverified. The former 30-day definition differs. |
| B24 | January/December registrations: Organic 36/2, Referral 22/4, Paid Ads 16/5, Social 16/1, App Store 15/1; Paid share 15.2%/38.5%. | D2-8 | Registered accounts by recorded channel, all platforms. | S1 Q06/Q07; S2 `registrations_by_month_channel`. |
| B25 | Allowance February; AUD 9.99 to 14.99 March; interface April/May; checkout June; Android July. | Change context | Scenario records; individual recorded exposure takes precedence. | S1 Q18; [Business_Change_Register](../data/raw/Business_Change_Register.csv) CHG001 to CHG006; [Plan_Versions](../data/raw/Plan_Versions.csv). |
| B26 | Deletion reasons: restrictions 47/129, 36.4%; no longer needed 42; switched tools 35; other four; complexity one, total 129 in 2025. All 150 historical deletions lack deletion-month events. | D2-4 | All 2025 deletions for generator-assigned reasons; historical accounts for activity omission. | S1 Q16R/QA04; S2 `headline_comparisons`. |
| B27 | 1,500 accounts, 120,000 events; coverage 2023 to 2025. | Overall scope | Preserved source tables and recorded date coverage. | S1 QA09; S2 `source_manifest`. |
| B28 | January/December recorded events 6,065/3,568; events per active user 5.65/3.09; single-event users 27/1,074, 2.5%, versus 284/1,155, 24.6%. | D1-2 | All platforms; monthly recorded activity and user depth. | S4 Activity_Events grouped by user and calendar month under section 3.1. |
| B29 | January/December active without meaningful use 54/345. Within December's 345: single event 161, 46.7%; any failure 91, 26.4%; any blocked result 109, 31.6%. | D1-2 | Same-month non-meaningful active population; subgroup flags overlap. | S4 Activity_Events: count monthly user events and meaningful actions, then failed/blocked flags within users without a meaningful action; section 3.1 explains overlap. |
| B30 | March to May versus July to December means: all entries 23.3/9.5, down 59.3%; cancellations 18.3/13.2; net movement +3.7/-4.8. Totals are 70/57 entries, 55/79 cancellations, 4/7 deletion exits and +11/-29 net. June is 187 + 5 first + 1 repeat - 20 cancelled = 173. | D1-3 | Three-month and six-month periods; compare monthly means and retain reconciled stocks. | S1 Q01 first/repeat entries and separate exits, summed for the selected three/six-month periods; divide by month count for means. QA01 checks the monthly bridge. |
| B31 | Price AUD 9.99 to 14.99: +50.0501%, displayed 50.1%. | D2-2 context | Scenario Pro monthly price; individual higher-price billing exposure remains separate. | B25 source records; arithmetic from the two listed prices. |
| B32 | Canonical workflow counts and collision sensitivity; Old/New resolved failure 42/2,198 and 992/3,908, versus failure per start 42/2,889 and 992/5,876. iOS Projects New is 455 starts, 214 complete and 87 failed. | D2-5 | 2025 validated user/session/journey identity; alternative raw-journey groupings are supplementary checks. | B16/B17 S1 Q12 for canonical totals; H1 for alternative grouping/collision details, whose execution record is excluded. |

Exact engagement values, cohort retention and weighted review ratings can be calculated from the retained raw tables. Subscriber-period means use retained monthly SQL rows. Canonical workflow counts, nearby checkout windows and payment outcomes have recorded SQL locators above. Alternative raw-journey collision checks remain historical detail outside the retained evidence.

Cancellation-event counts and opening-cohort cancellation rates use different populations. Retained calculation records do not establish complete visual-interaction coverage or saved-artifact reopening.
