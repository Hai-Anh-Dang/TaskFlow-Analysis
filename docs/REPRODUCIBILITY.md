# Reproduction and evidence

Run commands from the repository root. The supplied CSVs are the analysis snapshot. They contain synthetic records; preserve them unchanged when reproducing reported figures.

## Inspect without Power BI or SQL Server

Read the dashboard report and SQL supplement, then inspect their linked query outputs and source tables. Python audits use only the standard library. To recompute selected raw-data results into a separate local output folder:

```powershell
New-Item -ItemType Directory -Force './validation/local' | Out-Null
python './docs/sql_validation_2026-10-01/audit_raw_evidence.py' --raw-dir './data/raw' --out-dir './validation/local/raw'
```

Public audit-script defaults write under the ignored `validation/local` directory. Choose a separate output path when keeping multiple runs. The recorded JSON files contain historical validation results, not a claim that their SQL or DAX was run during packaging. `check_results.py` replays comparisons of the retained SQL outputs and CSV audit metrics, including current input hashes. It does not connect to SQL Server or Power BI. Run it with a separate output path:

```powershell
python './docs/sql_validation_2026-10-01/check_results.py' --output './validation/local/sql_acceptance_replay.json'
```

## SQL Server path

Use SQL Server with a `TaskFlow` database and all 11 source tables imported from `data/raw`, under `dbo`, with CSV filenames as table names. Consult the [dictionary](data_dictionary.md). Review inferred import types across the full file: user IDs, counts and allowances must not be inferred as SQL `tinyint`; allow unbounded or sufficiently wide Unicode strings, date/datetime fields and decimal monetary amounts. Blank optional fields remain NULL.

The package assumes all 11 source tables have been imported. It does not provide a complete database bootstrap. Import with types and NULL handling that preserve the supplied records, then verify source counts before applying the reporting definitions.

For a populated database, validate the reporting definitions transactionally:

```powershell
& './sql/validate_reporting.ps1' -Server '.\SQLEXPRESS' -Database 'TaskFlow' -ProjectRoot (Get-Location).Path -EvidenceDirectory './validation/local/sql'
```

This runner temporarily applies the reporting views, runs the dashboard queries, and rolls back the changes. Check its success, rollback and restored-definition flags. Running `02_reporting_views.sql` directly instead persists its changes. See the [SQL guide](SQL_REPORTING_GUIDE.md) for query parameters and scope.

The repository preserves the 1 October SQL run and its acceptance records. They are prior execution evidence; the packaging task does not connect to or deploy a database. The two reporting SQL files are copied byte-for-byte so their hashes remain comparable to that run. The validation runner's server default is a portable local placeholder.

## Optional scenario generation

The generator explains how the fictional case was created. Its public copy writes to `data/generated`, separate from the supplied snapshot:

```powershell
python -m pip install -r requirements.txt
python './data/Data generation/generate_taskflow_dataset.py'
```

The generator uses seed 42, but the original dependency versions are not recorded. A fresh run is not guaranteed to reproduce the shipped bytes. Do not replace `data/raw` or reuse the report findings without comparing outputs and rerunning the analysis. Assigned reasons, abandonment patterns and overlapping scenario rules limit causal interpretation.

## Power BI

The [model guide](MODEL_GUIDE.md) describes the historical design, annual KPI setup and dated DAX references. It is not a current model export. The [validation summary](VALIDATION_SUMMARY.md) describes retained evidence and omitted historical detail. The PBIX is deliberately excluded. The owner-supplied interactive dashboard URL is in the project README. Signed-out access has not been verified by this package.
