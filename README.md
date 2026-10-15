# TaskFlow: investigating engagement and subscription decline

TaskFlow is a fictional productivity product with Free and Pro plans on Web, iOS and Android. This portfolio report uses synthetic data to explain where performance weakened and which investigations or tests management should consider. Observation ends on 31 December 2025.

Recorded activity remained widespread while successful product use weakened. Registrations slowed, and the Pro subscriber base contracted after May as new and returning Pro subscriptions weakened while exits continued. Pricing, perceived value, workflow design and checkout warrant investigation. The causes of decline and the benefits of any intervention remain unproven.

**Interactive dashboard:** [View interactive dashboard](https://app.powerbi.com/view?r=eyJrIjoiZTdjZTU2MGItOTg5Yy00M2ViLWIzOGItZmFlN2QyNmQyZTZmIiwidCI6Ijc1ZGIzZDY4LTExMGYtNDI1NS05MTE5LWFhNjMxOGMyMDY2YyJ9&pageName=dc71aa5d5ce7497809ea)

## Business scenario

TaskFlow’s manager viewed the product’s first two years, 2023 and 2024, as successful and wanted to scale the business. Setbacks in the third year, 2025, prompted the manager to reassess whether the product was ready for further growth.

In this simulated assignment, my role is to assess TaskFlow’s operational situation and understand the risks and opportunities affecting the product. I examine user engagement, retention, and Free-to-Pro conversion to evaluate its current performance. The analysis separates observed changes from possible explanations that need further evidence.

The findings should help the manager decide whether to expand now or address the issues first. Product data can inform that decision, while a full investment assessment would also require costs and other commercial information.

## Data dictionary and dashboard measures

The 11 preserved CSVs cover 2023 to 2025, including 1,500 accounts and 120,000 activity events. SQL prepares reporting views; Power BI presents operational trends and diagnostic comparisons. The [detailed dictionary](docs/data_dictionary.md) defines the fields.

| Source | What one row means | Use in SQL and Power BI |
|---|---|---|
| [Users](data/raw/Users.csv) | One registered account. | Registrations, account deletions, original cohorts and account eligibility. |
| [Subscription_History](data/raw/Subscription_History.csv) | One uninterrupted Free or Pro period. | New and returning Pro subscriptions, cancellations, subscriber counts and plan at event time. |
| [Activity_Events](data/raw/Activity_Events.csv) | One recorded action and its result. | Meaningful use, restrictions, sync outcomes, workflow attempts and checkout progression. |
| [Sessions](data/raw/Sessions.csv) | One account's activity on one active calendar day. | Platform, interface and session context; distinguishing workflow attempts. |
| [Invoices](data/raw/Invoices.csv) | One monthly Pro renewal invoice. | Invoiced prices and higher-price renewal exposure; first-upgrade billing is incomplete. |
| [Payment_Transactions](data/raw/Payment_Transactions.csv) | One transaction against a renewal invoice. | Successful payment exposure and payment failures; amounts cover recurring billing. |
| [Reviews](data/raw/Reviews.csv) | One selected synthetic review. | Ratings and themes within stated periods; reviews do not represent all users. |
| [Date](data/raw/Date.csv) | One calendar day. | Consistent date filters, monthly comparisons and time calculations. |
| [Platforms](data/raw/Platforms.csv) | One supported platform. | Shared Web, iOS and Android filters. |
| [Plan_Versions](data/raw/Plan_Versions.csv) | One historical plan version. | Prices, allowances and effective periods. |
| [Business_Change_Register](data/raw/Business_Change_Register.csv) | One scenario change. | Intended benefit and rollout context; individual exposure requires separate evidence. |

The measures distinguish activity, successful use and subscription movements:

- Recorded active users have at least one event. Meaningfully active users have at least one successful product action, such as completing a task or workflow. Their share of active users and successful product actions per meaningfully active user describe participation and depth. Purchases are assessed separately.
- Closing Pro counts subscribers at month end, reconciling new and returning subscriptions, cancellations and account-deletion exits. Cancellation and account deletion are distinct.
- Paid cancellation rate is the share of the month's opening Pro subscribers who cancel during that month.
- Workflow failure is failed attempts divided by completed plus failed valid attempts. Start-only attempts are separate.
- Checkout completion is completed purchases divided by valid starts, with consistent period and platform scope.

Account, subscription, event, workflow, checkout and billing records remain at separate levels of detail to avoid multiplying observations when combined.

## Findings and business implications

Findings cover all platforms in 2025, except the longer checkout comparison stated below.

| Finding | Observed result | Business implication |
|---|---|---|
| New registrations weakened. | December had 13 registrations, 71.6% below the 2024 monthly average of 45.8. | Fewer incoming accounts reduce future engagement and upgrade opportunities. The acquisition cause remains unresolved. |
| Recorded activity concealed weaker useful engagement. | From January to December, active users rose from 1,074 to 1,155, while meaningfully active users fell from 1,020 to 810. Their share fell from 95.0% to 70.1%; successful product actions per meaningfully active user fell from 2.58 to 1.62. | Monitor successful use and depth alongside the active-user headline. |
| The paid base contracted. | Closing Pro fell from 187 in May to 144 in December, down 23.0%. Monthly new and returning Pro subscriptions averaged 23.3 in March to May and 9.5 in July to December. Cancellations also fell, from 18.3 to 13.2 monthly. | Continuing exits exceeded weaker entries. Both subscription entry and retention need attention. |
| Workflow failures differed by interface. | Across 2025 resolved attempts, New failed in 992/3,908 cases (25.4%), versus Old's 42/2,198 (1.9%). | Diagnose affected workflows, retaining platform, feature and exposure differences. |
| Checkout completion fell. | Completion was 305/449 valid starts (67.9%) in January 2023 to May 2025 (29 months), versus 63/240 (26.3%) in June to December 2025 (seven months). | Examine stage progression before selecting a test. Unequal periods and overlapping changes limit attribution. |

## Explanation and questions to investigate

The scenario Pro price rose from AUD 9.99 to AUD 14.99 in March 2025, an increase of 50.1%. Investigate whether users experienced sufficient value at the higher price and whether pricing affected subscription entry or retention. First check who was billed the higher price, who paid it and who received notice. Assigned cancellation reasons and selected reviews share simulation rules, limiting independent evidence of customer motivation.

Workflow and checkout comparisons identify processes to examine. They are observational and do not establish how many subscriptions were lost because of the design. Confirm checkout step purposes and required controls before proposing a shorter flow.

## Proposed management actions

Management should agree scope, responsible functions, resources, review windows and acceptance criteria. Sequence the inquiries using affected users, severity, feasibility, reversibility and trade-offs.

- Assess Pro value and billing exposure. Confirm billing can support a test, then compare retaining current pricing with a limited price or packaging test if the evidence justifies it. Monitor opening-cohort cancellation, new and returning Pro subscriptions, meaningful use and subscriber movements.
- Diagnose workflow failures and checkout progression. Compare continued observation with a focused design test. Monitor failure among resolved attempts, workflow completion per valid start, checkout purchases per valid start and stage progression. Preserve payment and required-control checks.
- Add measurement from visitors through registration to investigate acquisition. Investigate Android synchronization separately and continue monitoring Free-plan restrictions.

NOTE: These are just proposal only for the case above.

## Further reading

- [Power BI dashboard report](report/TaskFlow_Power_BI_Dashboard_Report_v1.md): full business narrative, proposed decisions and limitations.
- [SQL investigation supplement](report/TaskFlow_SQL_Investigation_Report.md): populations, calculations and source references.
- [Validation summary](docs/VALIDATION_SUMMARY.md), [SQL reporting guide](docs/SQL_REPORTING_GUIDE.md), [model guide](docs/MODEL_GUIDE.md) and [reproducibility guidance](docs/REPRODUCIBILITY.md): supporting definitions, evidence and execution options.
