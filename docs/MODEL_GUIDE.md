# TaskFlow Semantic Model Guide

This guide describes the historical TaskFlow semantic-model design and provides calculation-authoring guidance for the two dashboards. All observations are synthetic and cover 1 January 2023 to 31 December 2025. The detailed table, relationship, layout and metadata counts below refer to the September preparation state; they have not been rechecked against a current saved model for this package.

The package contains three DAX references: [reusable time functions](../power%20bi/dax_functions.dax) from September, the [annual KPI authoring pack](../power%20bi/TaskFlow_Yearly_KPIs.dax) prepared on 2 October, and [calendar and engagement measures](../power%20bi/Calendar_and_engagement_measures_2026-10-04.dax) from 4 October. These are authored definitions, not a self-contained current Power BI project. Apply them to a compatible model and validate the result.

September save-and-reopen checks predate the October report edits. October live-calculation records and screenshots are outside this package; the historical handoff described unsaved Power BI changes. Current persistence and publication remain unverified. See the [validation summary](VALIDATION_SUMMARY.md) for the available evidence and its limits.

## 1. Model structure and filtering

The specification contains 30 active, single-direction relationships. Dimensions filter facts; facts do not filter other facts. This preserves the separate grains of activity, subscriptions, billing, workflows, checkouts, reviews, and monthly account populations.

- `Platforms[platform_name]` filters `Users[signup_platform]`. `Users[user_id]` then filters the twelve connected fact tables. This route is appropriate for the supplied data because each user has one recorded platform, and event, session, and review platforms agree with that user's platform.
- `Cohort[Cohort Month]` filters `Users[cohort_month]`. Cohort membership remains based on original registration, including users who later delete their accounts.
- `Date[date]` filters the relevant date in each time-varying fact. There is no active registration-date relationship from Date to Users. The `New Users` measure applies the selected dates to registration explicitly, preventing a registration filter from accidentally excluding established users from activity measures.
- `Cohort Age[Age Months]` filters `User Month[cohort_age_months]` for the retention matrix.
- `Event Tier[Tier]` filters **Activity Events only**. It affects recorded activity, meaningful activity, restrictions, and sync outcomes. It does not redefine registrations, cohort sizes, account movements, paid cancellation populations, reviews, workflows, or checkouts.
- `Checkout Period[Period]` filters both checkout facts. `Checkout Stage[Stage Order]` filters Checkout Progression only, so its denominator can remain all eligible checkout starts.

Use the supplied dimensions for slicers and shared axes. A platform column selected directly from one fact will filter that fact only. Do not present Event Tier as a universal Free/Pro page filter.

### Navigating the model

The model is a multi-fact dimensional model with shared dimensions and a small snowflake branch: Platforms and Cohort filter Users, which filters the facts. It contains 12 facts, eight dimensions, two disconnected references, and one measures table. Separate facts preserve each business process's grain.

Use the Model-view tabs for different tasks:

| Layout | Purpose |
|---|---|
| Overview | Read the main user, platform, cohort and date relationships with four principal facts. This is an orientation view, not the complete relationship inventory. |
| Operational | Prepare registrations, engagement, retention, reviews and account/subscription movement. Includes Cohort Age and User Month. |
| Diagnostic | Inspect restrictions, subscription cancellations, workflows, checkout progression, deletion comparisons and the fixed sync follow-up population. |
| All tables | Inspect all 23 tables, including billing facts and disconnected references. |

The layouts are different views of the same model. They do not create separate datasets or change filter behaviour. Dimensions are positioned above facts, and key relationship fields are pinned to the top of each card. Zoom and pan remain available for detailed inspection.

In this design, five semantic tables use spaces: Activity Events, Subscription History, Payment Transactions, Business Change Register and Plan Versions. Physical SQL table names, reporting views, source queries and original CSV names are unchanged.

Shared slicers and axes should come from the dimension tables. Use `_Measures` for values. Eighty-five additional implementation columns are hidden from normal report authoring, including duplicated platform fields, population flags, raw attempt counters, and the misleading `price_notice_date` marker. Hidden fields are retained for calculations, relationships and investigation; no records or columns were deleted.

Measure folders retain the business topics in `00` through `09`. Folder `10 Time Comparisons` contains MoM/YoY values and icons. The 22 colour measures are under `90 Advanced\Conditional Formatting`, grouped by KPI, for use with formatting by field value. Six validation measures in `99 QA` are hidden from normal browsing but remain queryable. Supporting record fields are grouped under `Detail\Dates`, `Detail\Exposure` and `Detail\Billing` where applicable.

### Date roles

| Fact | Date relationship |
|---|---|
| Activity Events | Event date |
| Sessions | Session date |
| Reviews | Review date |
| Invoices | Invoice issue date |
| Payment Transactions | Payment date |
| Subscription History | Cancellation effective date |
| User Month | Month start |
| Workflow Attempts | Attempt start date |
| Checkout Attempts and Checkout Progression | Checkout start date |
| Deletion Comparison | Comparison month start |
| Sync Follow-up | No Date relationship; fixed exposure and outcome windows |

Use `Date[Year Month]`, sorted by `Date[Month Sort]`, for monthly trends. `Date[Month Start]` also provides a chronological month axis. Use the main Date table rather than automatic date hierarchies. Cohort dates describe registration groups and are independent of the activity-date selection.

`Plan Versions` and `Business Change Register` remain reference tables without active relationships. Effective-date ranges, affected plans, and rollout descriptions do not form valid equality keys to facts. Use them for context, not automatic attribution. The Measures table stores explicit measures and does not need a relationship.

## 2. Facts and aggregation rules

| Table | Grain and intended use |
|---|---|
| Users | One registered account; cohort size, acquisition composition, and first-Pro conversion eligibility. |
| Activity Events | One recorded action; observed activity, successful meaningful actions, event-time tier, restrictions, and sync outcomes. |
| User Month | One user-month from registration through deletion month; activity summaries, opening and closing populations, and movement categories. |
| Subscription History | One plan period; cancellation details and invoice-derived or payment-derived price exposure. |
| Workflow Attempts | One user/session/journey combination; validated start, terminal outcome, platform, feature, and interface variant. |
| Checkout Attempts | One user/checkout combination; start, flow version, completed steps, purchase, and payment outcome. |
| Checkout Progression | One valid checkout per reached stage; cumulative funnel counts. |
| Invoices and Payment Transactions | Separate renewal invoice and transaction grains; billed and successfully paid amounts remain distinct. |
| Sessions and Reviews | Separate session and submitted-review grains. |
| Sync Follow-up | One eligible Android user in the fixed exploratory comparison. |
| Deletion Comparison | One eligible opening account per comparison month; retained users can appear in multiple months. |

Use explicit measures rather than summing identifiers or flags directly in visuals. Distinct active users across several months are not the sum of monthly active users. Opening and closing populations use the first and last boundaries of the selected complete months; they are not additive stocks.

Monthly movement measures require complete, contiguous months. Paid cancellation and account deletion rates require one complete month. Undefined rates, unavailable comparisons, immature conversion cohorts, and future retention cells must remain blank. A measured zero with an eligible denominator remains zero.

The Pro ledger follows:

**Opening Pro + first upgrades + repeat upgrades − cancellations − Pro account deletions = closing Pro.**

Closing populations are carried forward after changes on the closing date. Cancellation events and account deletion exits are separate movements. `All Pro Cancellation Events` counts all cancellation rows; `Paid Cancellation Rate` uses only users who were Pro at the opening of the month.

## 3. Reusable time-comparison functions

The September function reference defines eight reusable DAX functions. Compatible comparison measures can wrap these functions for the main KPIs; confirm the available measure names in the target model.

| Function | Example and purpose |
|---|---|
| `Month_Value` | `Month_Value([New Users], -1)` evaluates the previous complete month. Offset `0` is the selected month; `-12` is the same month last year. |
| `Relative_Change` | `Relative_Change(CurrentAmount, PriorAmount)` calculates relative change. Missing values or a zero prior value return blank. |
| `Change_Icon` | `Change_Icon([New Users MoM %])` returns an up, down, or unchanged glyph. Missing comparisons remain blank. |
| `Change_Color` | `Change_Color([New Users MoM %], 1)` returns a colour for a higher-is-better metric. Use `-1` for cancellation, deletion, or failure increases. |
| `MoM_Perc` | `MoM_Perc([New Users])` calculates month-over-month relative change. |
| `YoY_Perc` | `YoY_Perc([New Users])` compares the selected month with the same calendar month last year. |
| `MoM_Icon` | `MoM_Icon([New Users])` returns the MoM direction glyph. |
| `YoY_Icon` | `YoY_Icon([New Users])` returns the YoY direction glyph. |

The metric parameters use `SCALAR EXPR`, allowing the function to evaluate the measure after changing the date context. Do not replace these parameters with eagerly evaluated scalar values when extending the functions.

MoM and YoY functions require one complete selected month and a comparison month inside the loaded historical calendar. Multiple months, partial months, and unavailable earlier periods return blank. The cutoff comes from the loaded dates, not the current computer date. YoY here means the same month last year, not an annual-total comparison.

Prepared count and intensity comparisons use names such as `New Users MoM %`, `New Users MoM Icon`, and `New Users MoM Color`. Rate comparisons use **percentage points**, such as `Paid Cancellation Rate MoM pp`. A change from 10% to 12% is +2 percentage points. Do not label that measure as a +2% relative change.

Apply the corresponding Color measure through conditional formatting by field value. Direction and business interpretation remain separate: an upward cancellation icon represents an increase, while its colour indicates deterioration. Retain text or icons alongside colour for accessibility.

## 4. Dashboard 1 field guide

Use the operational page to establish what changed before introducing possible explanations. Show the selected period, `Data Through`, and the synthetic-data label. Use `Period Selection Note` and `Tier Filter Scope` where they help readers understand the controls.

| Planned output | Fields and measures |
|---|---|
| KPI strip | `New Users`, `New Users MoM %`, `New Users MoM Icon`, `Active Users`, `Meaningfully Active Users`; add `Actions per Meaningfully Active User` where space permits. Use a full month for KPI comparisons. |
| Registrations trend | Axis `Date[Year Month]`; value `New Users`; comparison tooltips can use the prepared MoM and YoY measures. |
| Engagement split | Axis `Date[Year Month]`; values `New Active Users` and `Returning Active Users`. Add meaningful activity and usage intensity as supporting measures. |
| Ratings | Axis `Date[Year Month]`; values `Average Rating` and `Review Count`. Keep review volume visible beside average rating. |
| Cohort retention | Rows `Cohort[Cohort Month]`; columns `Cohort Age[Age Months]`; value `Cohort Retention %`; tooltip `Cohort Size`. Retention deliberately ignores the activity-date selection and leaves future cells and matrix totals blank. |
| Account movement | Axis `Date[Year Month]`; values `New Users`, `Account Deletions`, and `Net Account Movement`; opening and closing account measures provide the reconciliation. |
| Cancellations trend | Axis `Date[Year Month]`; value `All Pro Cancellation Events`. The opening-cohort rate belongs in the diagnostic pricing analysis. |
| Pro ledger | Rows `Date[Year Month]`; values `Opening Pro Subscribers`, `First Pro Upgrades`, `Repeat Pro Upgrades`, `Pro Cancellation Movements`, `Pro Account Deletion Exits`, and `Closing Pro Subscribers`. |

Keep `Pro Ledger Residual` and `Account Ledger Residual` in a technical QA view, not the stakeholder narrative. For accepted complete-month selections, both should equal zero.

## 5. Dashboard 2 field guide

Show the comparison population and observation period for each diagnostic panel. Do not silently synchronize operational filters that would remove a diagnostic comparison group or truncate a fixed observation window.

| Investigation | Fields and measures |
|---|---|
| H1: Free restrictions | Monthly `Blocks per Free Exposed User`, with `Free Exposed Users`, `Restriction Events`, and `Free Users Affected %`. Event intensity and affected-user share answer different questions. |
| H1 supporting conversion | Axis `Cohort[Cohort Month]`; `90-day Conversion Rate`, `90-day Eligible Users`, and `90-day Converted Users`. Headline measures include only fully mature monthly cohorts. Use `Cohort Maturity %` and `Eligible Users Including Partial Cohorts` for supporting eligibility detail. |
| H2: Pricing and cancellation | Monthly `Paid Cancellation Rate`; reason breakdown using `Subscription History[cancellation_reason]`, `All Pro Cancellation Events`, and `Cancellation Reason Share`. `Price-related Cancellation Share` groups the recorded price/value categories. Inspect the derived first higher-price invoice and successful-payment dates as supporting subscription detail. |
| Cross-cutting deletion | Monthly `Account Deletion Rate`; categories `Users[deletion_reason]` with `Deletion Reason Share`. For prior friction, use `Deletion Comparison[outcome]`, `Prior Friction Share`, and `Deletion Comparison Observations`; the denominator is account-month observations. |
| H3: Interface workflows | Compare `Workflow Attempts[interface_variant]` within `feature` and platform. Show `Workflow Completion Rate`, `Workflow Outcome Share`, and `Valid Workflow Attempts`; outcome values are Completed, Failed, and Abandoned. Inspect transition months separately. |
| H4: Checkout progression | Use two funnel visuals, one filtered by `Checkout Period[Period]` to Pre-redesign and one to Post-redesign. Category `Checkout Stage[Stage]`, sorted by Stage Order; value `Checkouts Reaching Stage`. Add `Checkout Stage Reach %`, `Checkout Step Drop-off %`, `Checkout Completion Rate`, and `Checkout Payment Failures` as supporting measures. Pre-redesign has two steps; post-redesign has four. |
| H5: Sync reliability | Monthly `Sync Failure Rate` and `Recorded Sync Outcomes`, compared by platform. For later activity, use `Sync Follow-up[exposure_group]`, `Sync Later Activity Rate`, `Sync Follow-up Eligible Users`, and `Sync Comparison Note`. The fixed comparison ignores the Date slicer. |
| H6: Registration decline | Stacked monthly columns of `New Users` by `Date[Year Month]` and `Users[acquisition_channel]`. Default Volume view; optional Channel mix bookmark. Tooltip: count, monthly channel share and existing MoM/YoY measures. Channel composition cannot explain acquisition efficiency without visitors, campaign exposure, or spend. |


Evidence-strength assessments, hypothesis statuses, recommendations and next decisions belong in the written summary report, not in a Power BI evidence table or tooltip. The field guide describes intended report behaviour. Report screenshots are outside this package. The authored field guide does not establish that every proposed interaction exists in a saved report.

Only reached checkout stages have fact rows. If a visual displays stages with no rows, distinguish zero reach in an applicable stage from a stage that does not exist in that flow. Do not display Step 3 or Step 4 as pre-redesign failures.

## 6. Interpretation and QA boundaries

- Workflow IDs are not globally unique. The model preserves raw identifiers and uses user, session, and journey together; invalid attempts remain identifiable rather than being silently discarded.
- Event-time tier uses the latest subscription start date when dates overlap. The retained raw audit records 2,911 events on ambiguous transition dates. This convention does not establish precise intraday exposure.
- `price_notice_date` is a global scenario date, not a verified notice or higher-price renewal date. Use the derived invoice and payment exposure fields. A subscription's eventual exposure label is not, by itself, a time-specific population at risk.
- Renewal invoice and payment totals exclude the first upgrade payment. They are not complete product revenue.
- Meaningful activity requires a successful designated product action. Commercial purchase completion is excluded from product engagement.
- The generator omits activity in deletion months. Missing events mean no recorded activity; they do not prove complete tracking or absence of friction.
- Conversion uses a fixed cutoff of 31 December 2025. October has only one eligible user out of 17; November and December have none. Headline conversion comparisons stop at fully mature monthly cohorts.
- The fixed sync follow-up has only four eligible users: one in the high-failure group and three in the low-failure group. All four have recorded meaningful activity in September–December. Report the group sizes and avoid claiming a demonstrated engagement consequence.
- Review themes are selected synthetic sentiment observations. They do not estimate issue prevalence among all users or establish independent corroboration of causality.

Use the QA measures to inspect invalid workflow and checkout attempts, unmapped or ambiguous tier rows, and ledger residuals. Validate source-to-model counts, rate denominators, zero-versus-blank behaviour, platform filters, cohort maturity, and time comparisons. Final completion additionally requires checking the saved artifact and reopening it; consult the [validation summary](VALIDATION_SUMMARY.md) for recorded checks and remaining limitations.


## 7. Annual KPI authoring and interpretation

Prepared 2 October 2026. The data is synthetic and covers the complete historical years 2023–2025.

The [DAX authoring pack](../power%20bi/TaskFlow_Yearly_KPIs.dax) defines one disconnected year table and eleven measures. Create the calculated table first, then paste each measure separately through Modeling > New measure. The file is not a single DAX query or an automatically importable report. Existing monthly measures remain unchanged.

### What to create

1. Create the `KPI Year` calculated table using the first expression in the pack. Leave it disconnected: do not create relationships from it.
2. Create `KPI Selected Year`, then the annual values and cancellation helpers, then the four annual comparisons. Store measures in `_Measures`.
3. Add a dropdown slicer using `KPI Year[Year]`. Enable single selection and select 2025.
4. Build the annual cards using the pairings below. Duplicate the visual style of the monthly cards, then replace their value and comparison measures.

| Card title | Value measure | Comparison measure |
|---|---|---|
| New users | `Yearly New Users` | `Yearly New Users YoY %` |
| Active users | `Yearly Active Users` | `Yearly Active Users YoY %` |
| Closing Pro subscribers | `Yearly Closing Pro Subscribers` | `Yearly Closing Pro Subscribers YoY %` |
| Opening-year Pro cancellation rate | `Yearly Paid Cancellation Rate` | `Yearly Paid Cancellation Rate YoY pp` |

### Definitions and filtering

New users counts registrations during the year. Active users counts distinct users with any recorded event during the year, so a person active in several months counts once. Closing Pro subscribers uses the carried-forward December closing balance, not the sum of monthly balances.

Annual cancellation uses a fixed opening-year population. The denominator is Pro subscribers carried into 1 January. The numerator is members of that population with at least one paid cancellation during the selected year. Repeated cancellations count once. An opening subscriber who returns to Pro and cancels again still counts once. Users who first join Pro during the year are excluded, and an account-deletion exit alone is not a paid cancellation. This is not an average monthly rate or a year-end churn measure.

The annual measures remove filters from the shared `Date` table and reconstruct the full year from the disconnected year selection. A hidden monthly slicer based on `Date` therefore cannot narrow the annual values. Existing Platform and other user-population filters remain in force. Direct filters on fact dates or fact population flags can still alter the result; do not place those filters on these cards.

The year helper requires one supported year and a complete daily calendar. The supported range is deliberately fixed to the known complete export, 2023–2025. Calendar coverage alone does not prove source completeness. If future data is loaded, review its completeness before changing the supported range. Unselected or multiple years return blank. An unavailable prior year, or a zero prior count baseline, produces a blank relative comparison.

### Formatting

Use whole numbers (`#,0`) for counts, `0.00%` for the cancellation rate, and `+0.0%;-0.0%;0.0%` for the three count/stock comparison measures. The cancellation change is already expressed in percentage points: use `+0.00" pp";-0.00" pp";0.00" pp"`, not a percentage format.

For conditional formatting, increases in users/subscribers can use the existing favourable colour and decreases the adverse colour. Reverse that interpretation for cancellation-rate changes. Blank comparisons should receive a neutral colour. Annual comparisons change the disconnected year selection; the existing monthly `YoY_Perc` function must not be substituted for them.

### Monthly and yearly modes

Keep the existing monthly cards and Year–Month slicer as one visual group. Put the annual cards and `KPI Year[Year]` slicer in another group. Monthly and Yearly buttons can show the corresponding group through bookmarks. For bookmarks intended only to change visibility, disable Data capture and capture the relevant display state so switching modes does not reset the user's period selections.

Set the year slicer's Filter interaction on the annual cards. The shared date slicer can remain responsible for monthly cards and charts. Set the year slicer's interactions with unrelated charts to None. A hidden monthly slicer's Date selection is explicitly ignored by the annual measures; hiding a slicer alone is not the mechanism that protects the annual calculations.

### Expected results: Platform = All

The source annual-KPI guide recorded these reference values as CSV recomputations. Its separate expected-value JSON is outside this lean package; this table preserves authoring expectations, not fresh validation or proof that the DAX has executed in a current PBIX.

| Year | New users | Annual distinct active users | Closing Pro | Opening Pro | Opening users who cancelled | Annual cancellation rate |
|---|---:|---:|---:|---:|---:|---:|
| 2023 | 450 | 448 | 70 | 0 | 0 | Blank |
| 2024 | 550 | 994 | 145 | 70 | 23 | 32.86% |
| 2025 | 500 | 1,474 | 144 | 145 | 94 | 64.83% |

For 2025, expected annual comparisons are new users −9.09%, active users +48.29%, closing Pro −0.69%, and annual cancellation +31.97 pp. The high annual cancellation value describes at least one cancellation over twelve months in the opening cohort. It is not directly comparable with December's monthly rate.

After adding the measures, check that changing the monthly Date selection leaves the annual values unchanged, changing the selected year changes the annual cards, Platform filters still apply, and 2023 comparisons remain blank. December monthly closing Pro and annual closing Pro for the same year should agree. Verify annual cancellation's numerator is no greater than its opening cohort.

### Validation status

The source authoring guide described a 2 October design review and CSV reference calculation. The detailed model export and annual reference JSON are outside this lean evidence set. Treat the pack as a historical authoring reference and confirm matching table names, field names, calendar coverage and results in the target model. This package does not execute its DAX or certify a saved report.
