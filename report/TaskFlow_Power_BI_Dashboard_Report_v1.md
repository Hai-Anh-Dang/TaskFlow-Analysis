# TaskFlow Power BI dashboard report

TaskFlow is a fictional personal productivity product.

**Interactive dashboard:** [View interactive dashboard](https://app.powerbi.com/view?r=eyJrIjoiZTdjZTU2MGItOTg5Yy00M2ViLWIzOGItZmFlN2QyNmQyZTZmIiwidCI6Ijc1ZGIzZDY4LTExMGYtNDI1NS05MTE5LWFhNjMxOGMyMDY2YyJ9&pageName=dc71aa5d5ce7497809ea)

## 1. Executive summary and decisions requested

TaskFlow's useful product engagement weakened during 2025 while many users continued to record activity. The paid base contracted after May, registrations ended below the previous year's normal level, and selected review ratings fell. The investigation concentrates on two leading explanations: the Pro price increase and its perceived value, and system design friction in everyday workflows and checkout. These are explanations to investigate; the synthetic observational evidence does not establish root causes. The cause of the registration decline remains unresolved.

December had 1,155 users with recorded activity, above January's 1,074, yet only 810 completed a meaningful action, compared with 1,020 in January. Successful meaningful actions fell from 2,636 to 1,316. A stable active-user headline would therefore conceal much of the deterioration in product use.

| Management finding | Observed result | Implication |
| --- | --- | --- |
| New inflow weakened. | December's 13 registrations were 71.6% below the 2024 monthly average of 45.8. | Fewer new accounts limit future engagement and upgrade opportunities. |
| Useful engagement fell. | Meaningful participation fell from 95.0% to 70.1% of recorded active users between January and December. Actions per meaningfully active user fell from 2.58 to 1.62. | Both the number of users recording successful product actions and their depth of use weakened. |
| The paid base lost its earlier gains. | Closing Pro subscribers fell from May's peak of 187 to 144 in December, a 23.0% reduction. | Weaker first and repeat entries, while exits continued, reversed paid-base growth. Subscription entry and retention both require attention. |
| Product processes performed worse. | Checkout completion fell from 67.9% before June to 26.3% afterward. New-interface workflows recorded 25.4% failure among resolved attempts, versus Old's 1.9%. | Everyday use and subscription entry provide concrete processes for design review and testing. |
| Selected review sentiment weakened. | The average fell from 4.36/5 across 67 reviews in 2023 to 2024 to 2.41/5 across 728 in February to December 2025. | Reviews identify experiences to investigate, with limits on how broadly they can be interpreted. |

The paid-base bridge is important to both explanations. First and repeat Pro entries averaged 23.3 per month in March to May and 9.5 in July to December, a 59.3% reduction. Cancellations also fell between these periods, from 18.3 to 13.2 per month, but continuing exits exceeded the weaker entry flow. The late contraction therefore needs an explanation of entry as well as retention.

Management should consider two coordinated workstreams: confirm higher-price exposure and assess Pro value; and diagnose affected workflows and checkout before selecting focused design tests. Their delivery order should depend on affected users, severity, feasibility and trade-offs. Android reliability remains a specific supporting investigation, Free allowances need continued monitoring, and acquisition requires additional measurement. Section 4 sets out the choices and conditions for proceeding.

## 2. The operational downturn: Dashboard 1

### 2.1 Registrations fell below the earlier baseline

December's 13 registrations compare with 48 in December 2024 and the 2024 monthly average of 45.8. Registrations fell from 105 in January 2025 to 37 in May, the first month below that average, and then to 13 in December. The decline is material against both the comparable calendar month and the earlier annual benchmark. Reference: D1-1.

January's 105 registrations followed 48 in December 2024, with no listed change explaining the increase. The headline comparison therefore uses the 2024 average. The available evidence begins at registration, so it cannot distinguish fewer visitors from poorer signup conversion. 

### 2.2 Continued activity concealed weaker useful engagement

Recorded activity remained widespread, but fewer users completed successful product actions. The comparison uses all platforms and the same calendar-month definitions. References: D1-2 and D1-4.

| Engagement measure | January 2025 | December 2025 |
| --- | ---: | ---: |
| Users with any recorded activity | 1,074 | 1,155 |
| Meaningfully active users | 1,020 | 810 |
| Meaningfully active share of recorded active users | 95.0% | 70.1% |
| Successful meaningful actions | 2,636 | 1,316 |
| Actions per meaningfully active user | 2.58 | 1.62 |
| All recorded events per active user | 5.65 | 3.09 |
| Active users with only one recorded event | 27, 2.5% | 284, 24.6% |

Meaningful actions are successful task completion, workflow completion, first-task completion, report viewing and reminder setting. Purchases are separate. This distinction prevents navigation, blocked actions and failures from being interpreted as useful engagement. December 2024's action intensity was 2.52, providing a comparable month that also shows weaker depth of use in December 2025. 

The wider activity measures show lighter recorded use as well. In December, 345 active users had no successful meaningful action. Within this group, 161 had only one event, 91 had a failed result and 109 had a blocked result. These groups overlap: a user can have a single failed or blocked event. The comparison supports examining both depth of use and friction, without attributing the engagement gap to either mechanism. Calculation detail: D1-2 and section 3.1 of the SQL supplement, using the retained activity records.

Cohort retention gives a further indication of weaker continuing use. It measures meaningful activity at a calendar-month age against the original registration cohort, including accounts later deleted.

| Registration cohorts | Retention at age three | Retention at age six |
| --- | ---: | ---: |
| 2023 | 437/450, 97.1% | 414/450, 92.0% |
| 2024 | 527/550, 95.8% | 480/550, 87.3% |
| Eligible 2025 cohorts | 355/455, 78.0% | 278/387, 71.8% |

The 2025 groups cover January to September at age three and January to June at age six. Individual cohorts vary, so the pooled deterioration does not imply that every later cohort retained less well. Different observation periods and smaller later groups also limit attribution to a particular product change.

First-Pro conversion weakened in several mature cohorts: January recorded 19/105 conversions within 90 days, or 18.1%, compared with April's 4/48, or 8.3%. March's 15/75, or 20.0%, interrupts a simple falling trend. June to September rates ranged from 4.3% to 7.7%, with 19 to 30 registrants per cohort. October to December are excluded from dashboard comparisons because their monthly cohorts are immature at cutoff. Reference: D2-3. 

### 2.3 The paid base weakened after May

Closing Pro subscribers rose from 145 in December 2024 to 187 in May 2025, then fell to 144 in December. December's 0.7% increase over November's 143 is small relative to the loss since May. References: KPI cards, D1-3 and D1-6.

The annual movement explains the nearly flat opening-to-closing result. The opening 145 subscribers gained 160 first upgrades and ten returning Pro entries, while losing 160 cancellations and 11 Pro account-deletion exits. New entries offset much of the loss. Cancellation and account deletion are different outcomes: a subscriber can cancel Pro and continue using Free. 

| Average monthly Pro movement | March to May 2025 | July to December 2025 |
| --- | ---: | ---: |
| First entries | 21.3 | 9.0 |
| Repeat entries | 2.0 | 0.5 |
| All entries | 23.3 | 9.5 |
| Cancellation exits | 18.3 | 13.2 |
| Pro account-deletion exits | 1.3 | 1.2 |
| Net subscriber movement | +3.7 | -4.8 |

March to May gained 11 subscribers across three months; July to December lost 29 across six. June, between these periods, recorded six entries and 20 cancellations, reducing Pro from 187 to 173. The change from growth to contraction is consistent with much weaker entry relative to continuing exits. It does not describe steadily rising cancellation counts. Calculation detail: D1-3 and section 3.2 of the SQL supplement, using the retained monthly SQL results.

Average monthly cancellation was 3.6% in 2024 and 9.2% from March to December 2025, about 2.6 times higher. These are unweighted averages of monthly rates for opening Pro cohorts. December's rate was 12/143, or 8.4%, compared with November's 11/145, or 7.6%. One cancellation changes December's rate by about 0.7 percentage points, making counts essential when interpreting small monthly movements.

### 2.4 Account growth slowed

The account base grew from 979 at January's opening to 1,350 at December's close: 500 registrations less 129 deletions added 371 accounts. October was the only 2025 month with negative net movement, with 17 registrations and 19 deletions. November and December added only two and one net accounts respectively. The concern is weakening inflow and limited growth late in the year, alongside lower useful engagement. Reference: D1-5.

### 2.5 Review sentiment weakened early in the year

January's ten reviews averaged 4.60/5, February's 33 averaged 2.67/5, and December's 93 averaged 2.24/5. Before 2025, 11 of the 19 months with reviews had fewer than five, while five further calendar months had none. Review volume matters when interpreting the change. Reference: D1-7.

Themes include restrictions, navigation, synchronization, price and checkout. Reviewers are selected records, and some reviews share generation rules with affected user-months. They identify questions to investigate but cannot estimate dissatisfaction across all users or independently confirm a cause. 

## 3. Two leading explanations: Dashboard 2

The scenario register records a Pro monthly price increase from AUD 9.99 to AUD 14.99 in March, interface rollouts in April and May, and a checkout change in June. These changes provide the context for the two explanations below. Reduced Free allowances in February and the Android release in July remain relevant supporting context. The register records scenario changes; it does not establish each user's exposure or response.

### 3.1 Pro pricing and perceived value

The Pro monthly price increased by AUD 5.00, or 50.1%. Opening-cohort cancellation rose from 5/160, or 3.1%, in February to 20/176, or 11.4%, in March. Mean monthly cancellation was 3.6% in 2024 and 9.2% in March to December 2025. The sustained higher rate warrants examining whether the higher price matched the value subscribers received. References: D2-2 and the scenario price register.

Price or value concerns were assigned to 100 of 160 recorded 2025 cancellations, or 62.5%. These are generator-assigned simulation labels, not independently measured customer motivations. They describe the assigned reason mix among cancellation events and cannot estimate cancellation risk among all subscribers.

The subscriber bridge also limits a pricing-only explanation. Pro continued growing through May despite the March price increase, and later cancellation counts were lower while Pro entries weakened substantially. Price/value could affect willingness to enter Pro as well as remain subscribed, but this connection needs evidence of actual exposure and decision-making. Cancellation had already risen before March, and interface and checkout changes overlap the later period.

The next inquiry should confirm which subscribers received higher-price invoices, paid them, received notice and experienced relevant features. A value assessment can then consider retaining the current price, a limited price or packaging test, and other billing options where feasible. Annual billing has no demonstrated benefit in this evidence. Incomplete first-upgrade billing prevents a complete revenue or profitability comparison.

### 3.2 System design: everyday workflows and checkout

The second explanation concerns two different processes: completing useful work inside TaskFlow and completing the path into Pro. Poorer outcomes in both justify design diagnosis. The evidence does not establish how much either process contributed to lower engagement, cancellations or fewer upgrades.

#### Everyday workflows

In 2025, Old recorded 42 failures among 2,198 resolved workflow attempts, or 1.9%; New recorded 992 among 3,908, or 25.4%. Resolved means completed plus failed. Old had 2,889 valid starts and New had 5,876, so exposure was unequal. Within New, Android Projects recorded 69/216 failures, or 31.9%, Android Tasks 55/190, or 28.9%, and iOS Projects 87/301, or 28.9%. Reference: D2-5.

These specific workflows give UX and Engineering concrete tasks to review. The larger failure share provides a plausible mechanism for difficulty completing useful work, alongside the weaker engagement baseline. Recorded variant exposure and synthetic monthly behaviour differ, however, so the comparison is descriptive. Start-only attempts form the constructed abandoned class and cannot establish intentional customer abandonment.

Review the task sequence, observed failures and user needs before selecting a limited workflow change. Retaining the current design while gathering evidence remains an option; a scoped design test or rollback depends on confirmed usability findings and technical feasibility.

#### Checkout

Before June, 305/449 checkouts completed, or 67.9%, across January 2023 to May 2025. June to December completed 63/240, or 26.3%. A nearby equal-length comparison gives the same direction: March to May completed 70/111, or 63.1%, versus June to August's 21/102, or 20.6%. Reference: D2-7.

In the earlier flow, 370 of 449 starts completed stage one and 317 completed stage two. In the later flow, 181 of 240 completed stage one, 130 stage two, 98 stage three and 64 stage four. Progression weakened before the final stage. Recorded payment failures were 12/317 submissions before June and 1/64 afterward. The comparison places the inquiry on progression through the flow, while preserving payment monitoring.

Weaker checkout completion is consistent with difficulty entering Pro during a period of lower subscriber entries. It cannot quantify upgrades lost to design or the benefit of shortening the flow. Step numbers identify position; their purposes and required controls remain unconfirmed. Other changes and synthetic continuation rules also overlap the comparison. Confirm the process before choosing a focused test, and measure completed purchases per valid start alongside stage progression and payment outcomes.

### 3.3 Supporting findings and unresolved questions

Android synchronization warrants a specific reliability investigation. Android recorded zero failures among 26 resolved sync outcomes in June, 26/76, or 34.2%, in July and 29/88, or 33.0%, in December. Web and iOS recorded zero failures in the same July and December windows. Its July onset cannot explain deterioration already visible earlier in 2025. The fixed later-engagement follow-up includes only four users, and client outcomes lack the service evidence needed to locate the failing component. Reproduction and tracing should precede a fix. Reference: D2-6.

Free restriction evidence remains mixed. Restrictions per recorded Free user fell from 389/921, or 0.42, in January to 222/1,019, or 0.22, in December, while the affected share fell from 32.0% to 19.0%. Restrictions per 100 Free events were 7.60 in January, 9.05 in February and 7.80 in December. Different denominators explain why lower user exposure can coexist with a higher event share. Free restrictions were assigned as the deletion reason for 47/129 exits, or 36.4%; these simulated labels cannot establish that restrictions caused those exits. Link exposure to later outcomes before considering an allowance test. Reference: D2-1.

The broad preceding-friction comparison gives little separation between deletion outcomes. Under the same full previous-calendar-month window, eligible deleted observations had friction in 32/124 cases, or 25.8%, versus 3,652/14,445 retained observations, or 25.3%. The difference is 0.5 percentage points, calculated before rounding the component rates. The retained SQL results and dated DAX definitions specify this same window and eligibility; the current saved dashboard has not been verified. Retained users repeat across months and may later be deleted. Other assigned deletion reasons include no longer needing the product, 42, and switching tools, 35. Deleted accounts lack deletion-month events, so the comparison cannot describe their activity during the month of exit. Reference: D2-4.

The registration cause remains unresolved. All five channels had fewer registrations in December than January. Organic Search fell from 36 to two and Paid Ads from 16 to five. Paid Ads' share rose from 15.2% to 38.5% because other channels declined more. Visitors, signup attempts, campaign exposure, spend and competitor evidence are absent. Neither the price nor design explanation can be used to assign the acquisition decline without this additional evidence. Reference: D2-8.

## 4. Implications and recommendations

Begin two coordinated inquiries: Pro exposure and value, and system design across workflows and checkout. The first addresses the commercial proposition; the second examines whether users can complete useful work and enter Pro successfully. Both relate to the operational baseline, and neither establishes a complete explanation of the downturn.

The evidence supports choosing the next inquiry and a feasible test. It does not support ranking potential financial benefits or comparing unlike percentages as a priority score. Affected population, severity, reproducibility, feasibility, reversibility and business trade-offs should guide the delivery sequence once confirmed.

| Focus | Proposed response and alternatives | Condition for proceeding | Evaluation measures and safeguard |
| --- | --- | --- | --- |
| Pro price and perceived value | Confirm higher-price exposure and assess value. Compare retaining current pricing with a limited price or packaging test; assess other billing options only where feasible. | Confirm invoice/payment and notice exposure, obtain value evidence, and assess billing capability and financial coverage. | Opening-cohort cancellation, first and repeat entries, meaningful use and the full subscriber bridge. Estimate financial outcomes only within confirmed coverage. |
| Workflow design | Review affected tasks and failures. Compare gathering evidence under the current design with a scoped change or rollback test. | Confirm usability findings, comparable exposure, severity and technical feasibility. | Failed resolved attempts and completion per valid start, with affected-user counts. Inspect other workflows for adverse effects. |
| Checkout design | Confirm step purposes and required controls, then compare the current flow with a focused progression test. | Agree the process requirements, confirm valid starts and identify a feasible change. | Completed purchases per valid start, cumulative stage progression and first/repeat Pro entries. Monitor payment failures and confirmed control outcomes. |

Design tests have directly observable process outcomes, while a price test requires reliable exposure and financial coverage. Improvement in a workflow or checkout measure should also be checked against meaningful participation and subscriber movement. These broader outcomes help assess whether a local process gain accompanies better product use; they do not, by themselves, establish causality.

Android reliability can be investigated alongside the design inquiry where resources permit. Continue observing Free restriction exposure and comparable deletion outcomes. Specify acquisition measurement from visitors through completed registration so its unresolved cause can be examined.

Product and Billing are proposed contributors to the price/value assessment, and UX and Engineering to design diagnosis. Ownership, resources, review windows and acceptance criteria remain for management to agree. The recommendations are draft proposals without approved targets, budgets, delivery commitments or measured benefits.

## 5. Data, measures and limitations

The case contains 1,500 synthetic accounts and 120,000 recorded events over 2023 to 2025.

Active users have at least one recorded event in a month. Meaningfully active users have a defined successful product action. Cancellation rates use the opening Pro cohort on both sides of the calculation. Retention preserves original registration-cohort sizes, and dashboard 90-day conversion uses fully mature monthly cohorts. The 31 December 2025 cutoff governs maturity even though the report is prepared in 2026. Percentages and average monthly counts are generally rounded to one decimal place, with half values rounded up; activity intensities and review ratings use two. Comparisons use unrounded values. Exact fractions and calculation detail appear in the [SQL supplement](TaskFlow_SQL_Investigation_Report.md).

The limits affect different decisions:

- Each account uses one platform. Platform differences cannot establish how the same user responds across devices.
- Infrastructure logs are absent. Sync outcomes identify a reliability concern without locating its mechanism.
- First-upgrade billing is incomplete. Recurring-payment evidence cannot establish complete revenue, profitability or a packaging return.
- Deleted users lack deletion-month events, and date-only boundaries cannot recover intraday ordering. Use the stated preceding windows and eligibility.
- Workflow abandonment, cancellation and deletion reason labels, and selected review patterns reflect synthetic generation. They cannot establish customer intent or independent corroboration.
- Small conversion cohorts and the four-user sync follow-up limit later-outcome comparisons. Unobserved rates remain blank.

The January registration spike remains unexplained, and business-change dates supply scenario context with limited attribution. Product, Billing, UX, Engineering and Marketing perspectives in the case do not represent real stakeholder interviews.
