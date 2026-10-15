# Validation evidence and limits

TaskFlow is a fictional case study using synthetic data. This summary describes the evidence retained in this package. Historical execution records do not establish current dashboard state or a new SQL run.

| Area | Retained evidence | What it supports |
|---|---|---|
| Source snapshot | [Raw calculation record](sql_validation_2026-10-01/raw_evidence.json), 11 CSVs in `data/raw` | Source hashes, row counts, coverage and selected calculations for the preserved 2023 to 2025 snapshot. |
| SQL | [Execution results](sql_validation_2026-10-01/sql_execution_results.json), [acceptance record](sql_validation_2026-10-01/acceptance_checks.json), [comparison script](sql_validation_2026-10-01/check_results.py) | Recorded 1 October SQL run: 32 result sets, successful transaction rollback and restored view definitions; 740 field-level and integrity assertions. The separate historical parameter-test transcript is outside this package. |
| Report calculations | [SQL supplement](../report/TaskFlow_SQL_Investigation_Report.md), retained SQL outputs and raw tables | Defined populations and arithmetic for report findings. The crosswalk identifies direct records, calculations from retained rows and historical details whose execution evidence is outside the package. |
| Model and DAX references | [Model guide](MODEL_GUIDE.md) and three files in `power bi` | Historical model design, annual KPI authoring conventions and dated measure definitions. These references do not constitute a current model export or a verified saved report. |

The two dated report-evidence folders, their audit scripts, Power BI session outputs and screenshots are excluded. The retained SQL records support the preceding-calendar-month deletion comparison: 32/124 deleted and 3,652/14,445 retained account-month observations. They do not establish that a current saved Power BI model implements the same result. Supplementary raw-journey collision examples remain explicitly historical because their detailed audit output is outside this package.

September model save-and-reopen checks preceded the October edits, and their detailed records are outside this package. The guide's model counts describe that earlier design. Annual KPI values remain authoring expectations from the historical guide, without fresh execution of the DAX. The 4 October handoff described unsaved Power BI changes. Reopening the revised saved artifact, checking all visual interactions, publishing a report and testing signed-out access remain unverified here. No PBIX is included. The owner-supplied public dashboard link is in the README; its inclusion does not establish current model validation or signed-out access.

The retained raw audit and comparison scripts have their required inputs. The raw audit can create additional local findings and JSON outputs. Historical JSON may contain earlier workflow locators; those provenance strings do not instruct readers to load absent files. Use [reproducibility guidance](REPRODUCIBILITY.md) to write any new outputs separately from the retained evidence.

Agreement between SQL and raw-CSV calculations checks implementation consistency over the same synthetic data. It does not independently corroborate customer behaviour. Activity is missing in deletion months, reviews are selected sentiment, first-upgrade billing is incomplete, and service/acquisition evidence is unavailable. Workflow and checkout comparisons remain observational. Product interventions, approval and achieved benefits have not been demonstrated.

For definitions, periods, populations and source locators, use the [SQL supplement](../report/TaskFlow_SQL_Investigation_Report.md). Packaging checks are maintained outside this public package.
