"""Compare executed SQL outputs with independent CSV calculations and integrity rules."""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL_PATH = ROOT / 'validation/sql_execution_results.json'
RAW_PATH = ROOT / 'evidence/raw_evidence.json'
if not SQL_PATH.exists():
    SQL_PATH = Path(__file__).with_name('sql_execution_results.json')
    RAW_PATH = Path(__file__).with_name('raw_evidence.json')
sql = json.loads(SQL_PATH.read_text(encoding='utf-8-sig'))
raw = json.loads(RAW_PATH.read_text(encoding='utf-8-sig'))
queries = {}
for result in sql['result_sets']:
    for row in result['rows']:
        queries.setdefault(row['query_id'], []).append(row)
checks = []

def check(name, actual, expected):
    if isinstance(actual, (float, int)) and isinstance(expected, (float, int)):
        # SQL AVG(decimal) retains six decimals here; allow only its final-place truncation.
        passed = math.isclose(actual, expected, rel_tol=0, abs_tol=1e-6)
    else:
        passed = actual == expected
    checks.append(dict(check=name, passed=passed, actual=actual, expected=expected))

def day(value):
    return value[:10]

for flag in ['success', 'rollback_completed', 'database_view_definitions_unchanged']:
    check(flag, sql.get(flag), True)
monthly = {r['month']:r for r in raw['operational_monthly']}
mapping = {
    'registrations':'registrations', 'observed_active_users':'recorded_active_users',
    'meaningfully_active_users':'meaningfully_active_users', 'meaningful_actions':'meaningful_actions',
    'opening_accounts':'opening_accounts', 'closing_accounts':'closing_accounts',
    'account_deletions':'deletions', 'opening_pro':'opening_pro', 'closing_pro':'closing_pro',
    'first_upgrades':'first_upgrades', 'cancellation_events':'all_pro_cancellation_events',
    'pro_deletion_exits':'pro_deletion_exits', 'opening_pro_cancellers':'opening_pro_cancellations',
    'meaningful_share_of_active':'meaningful_share_of_active',
    'actions_per_meaningfully_active_user':'actions_per_meaningfully_active_user',
    'paid_cancellation_rate':'paid_cancellation_rate'
}
for r in queries['Q01']:
    m=day(r['month_start'])
    for a,b in mapping.items(): check(f'Q01 {m} {a}', r[a], monthly[m][b])
    check(f'Q01 {m} engagement split', r['new_active_users']+r['returning_active_users'], r['observed_active_users'])
for r in queries['Q02']:
    for a,b in {'closing_pro_mom':'dec2025_pro_mom_relative_change',
                'closing_pro_yoy':'dec2025_pro_yoy_relative_change',
                'cancellation_mom_pp':'dec2025_paid_cancellation_mom_pp'}.items():
        check(f'Q02 {a}',r[a],raw['headline_comparisons'][b])
for q,raw_key,date_col,raw_date,fields in [
 ('Q04','reviews_monthly','month_start','month',{'review_count':'reviews','average_rating':'average_rating'}),
 ('Q08','free_restrictions_monthly','month_start','month',{'free_events':'free_events','free_exposed_users':'free_exposed_users','restriction_events':'restriction_events','users_with_restrictions':'users_with_restriction_event','blocks_per_exposed_user':'blocks_per_exposed_free_user','blocks_per_100_free_events':'blocks_per_100_free_events'}),
 ('Q11','conversion_90d_by_cohort','cohort_month','cohort_month',{'registered_users':'cohort_size','eligible_90d_users':'eligible_90d_users','converted_90d_users':'converted_90d_users','conversion_rate_among_eligible':'conversion_rate_eligible_only'})
]:
    reference={x[raw_date]:x for x in raw[raw_key]}
    for r in queries[q]:
        key=day(r[date_col])
        for a,b in fields.items():check(f'{q} {key} {a}',r[a],reference[key][b])
        if q=='Q11' and not r['fully_mature']:check(f'Q11 {key} immature headline',r['headline_mature_conversion_rate'],None)
reference={(x['outcome_month'],x['outcome']):x for x in raw['deletion_prior_calendar_month']}
for r in queries['Q16']:
    key=(day(r['outcome_month']),r['outcome'])
    for a,b in {'eligible_account_observations':'eligible_account_months','accounts_with_prior_friction':'with_prior_friction','friction_events':'friction_events','prior_friction_share':'prior_friction_rate'}.items():
        check(f'Q16 {key} {a}',r[a],reference[key][b])
reference={x['outcome']:x for x in raw['deletion_prior_calendar_month_pooled_2025']}
for r in queries['Q16P']:
    for a,b in {'eligible_account_months':'eligible_account_months','distinct_users':'unique_users','account_months_with_prior_friction':'with_prior_friction','prior_friction_share':'prior_friction_rate'}.items():
        check(f'Q16P {r["outcome"]} {a}',r[a],reference[r['outcome']][b])
reference={(x['month'],x['event_platform']):x for x in raw['sync_monthly']}
for r in queries['Q17']:
    key=(day(r['month_start']),r['recorded_platform'])
    for a,b in {'recorded_outcomes':'sync_outcomes','recorded_failures':'sync_failures','failure_rate':'failure_rate'}.items():check(f'Q17 {key} {a}',r[a],reference[key][b])
reference={(x['month'],x['channel']):x for x in raw['registrations_by_month_channel']}
for r in queries['Q06']:
    key=(day(r['month_start']),r['acquisition_channel'])
    check(f'Q06 {key}',r['registrations'],reference[key]['registrations'])
for r in queries['QA01']:
    for field in ['pro_residual','account_residual']:check(f'QA01 {r["month_start"]} {field}',r[field],0)
for r in queries['QA02']:check(f'QA02 {r["attempt_type"]} invalid',r['invalid_attempts'],0)
for field in ['eligibility_or_window_violations','duplicate_account_months']:check('QA03 '+field,queries['QA03'][0][field],0)
check('QA04 deleted users',queries['QA04'][0]['deleted_users'],raw['headline_comparisons']['deletion_user_count'])
check('QA04 deletion-month activity',queries['QA04'][0]['deleted_users_with_deletion_month_events'],0)
for r in queries['QA05A']:
    if r['outcome']=='Abandoned':check('QA05A start-only abandonment',r['attempts_with_one_event'],r['attempts'])
check('QA06 unmatched tiers',queries['QA06'][0]['events_without_subscription_match'],0)
check('QA06 ambiguous tiers',queries['QA06'][0]['events_with_multiple_date_matches'],raw['checks']['events_with_multiple_date_only_tier_matches'])
for field in ['date_rows','distinct_days','expected_contiguous_days']:check('QA07A '+field,queries['QA07A'][0][field],1096)
check('QA07B immature conversion',queries['QA07B'][0]['ineligible_users_with_defined_conversion'],0)
for field in ['missing_pro_row_matches','multiple_pro_row_matches']:check('QA08 '+field,queries['QA08'][0][field],0)
manifest={Path(x['file']).stem:x for x in raw['source_manifest']}
for r in queries['QA09']:check('QA09 '+r['source_table'],r['source_rows'],manifest[r['source_table']]['rows'])
raw_directory = Path(raw['raw_source_directory'])
if not raw_directory.is_absolute():
    raw_directory = Path(__file__).resolve().parents[2] / raw_directory
for entry in raw['source_manifest']:
    path=raw_directory/Path(entry['file']).name
    check('Source unchanged '+path.name,hashlib.sha256(path.read_bytes()).hexdigest().lower(),entry['sha256'].lower())
for entry in sql['script_hashes']:
    candidates=[ROOT/'sql'/entry['file'],Path(__file__).resolve().parents[2]/'sql'/entry['file']]
    path=next(p for p in candidates if p.exists())
    check('Executed script hash '+entry['file'],hashlib.sha256(path.read_bytes()).hexdigest().lower(),entry['sha256'].lower())
result={'scope':'Replay of recorded SQL outputs compared with preserved CSV metrics and boundary/integrity assertions; no fresh SQL execution. Does not validate Power BI visuals.',
        'checks':len(checks),'passed':sum(c['passed'] for c in checks),'failed':[c for c in checks if not c['passed']], 'details':checks}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[2]/'validation/local/sql_acceptance_replay.json')
output = parser.parse_args().output
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='details'},indent=2))
raise SystemExit(0 if not result['failed'] else 1)
