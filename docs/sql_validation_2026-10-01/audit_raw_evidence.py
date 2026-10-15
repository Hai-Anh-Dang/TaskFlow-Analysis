"""Reproduce TaskFlow report evidence from preserved CSVs using Python stdlib.

This is an independent calculation, not execution of SQL Server reporting views.
Inputs are read only. Rates use explicit denominators and blank denominators stay null.
"""
from __future__ import annotations

import argparse
import calendar
import csv
import hashlib
import json
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

MEANINGFUL = {"task_completed", "workflow_completed", "first_task_completed", "report_viewed", "reminder_set"}
FRICTION = {"action_blocked", "allowance_reached", "sync_failed", "action_failed"}
CUTOFF = date(2025, 12, 31)


def dt(value):
    return date.fromisoformat(value[:10]) if value else None


def ratio(numerator, denominator):
    return numerator / denominator if denominator else None


def month_start(value):
    return value.replace(day=1)


def shift_month(value, offset):
    index = value.year * 12 + value.month - 1 + offset
    return date(index // 12, index % 12 + 1, 1)


def month_end(value):
    return value.replace(day=calendar.monthrange(value.year, value.month)[1])


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def audit(raw_dir):
    tables = {path.stem: read_csv(path) for path in sorted(raw_dir.glob("*.csv"))}
    manifest = []
    date_fields = {"date", "registration_date", "account_deletion_date", "start_date", "end_date",
                   "timestamp", "issue_date", "review_date", "announcement_date", "rollout_start", "rollout_end"}
    for name, rows in tables.items():
        path = raw_dir / f"{name}.csv"
        coverage = {}
        for field in (set(rows[0]) & date_fields if rows else set()):
            values = [r[field][:10] for r in rows if r[field]]
            coverage[field] = {"non_null_rows": len(values), "min": min(values) if values else None,
                               "max": max(values) if values else None}
        manifest.append({"file": path.name, "rows": len(rows), "bytes": path.stat().st_size,
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "date_coverage": coverage})
    users = {}
    for row in tables["Users"]:
        row = dict(row)
        row["registration"] = dt(row["registration_date"])
        row["deletion"] = dt(row["account_deletion_date"])
        users[row["user_id"]] = row
    history = defaultdict(list)
    pro_history = defaultdict(list)
    for row in tables["Subscription_History"]:
        row = dict(row)
        row["start"] = dt(row["start_date"])
        row["end"] = dt(row["end_date"])
        row["cancel"] = dt(row["cancellation_effective_date"])
        history[row["user_id"]].append(row)
        if row["tier"] == "Pro":
            pro_history[row["user_id"]].append(row)
    for rows in history.values():
        rows.sort(key=lambda r: (r["start"], r["subscription_id"]))
    for rows in pro_history.values():
        rows.sort(key=lambda r: (r["start"], r["subscription_id"]))
        for index, row in enumerate(rows, 1):
            row["entry"] = index
    months = [shift_month(date(2023, 1, 1), offset) for offset in range(36)]
    events_month = defaultdict(list)
    activity_users = defaultdict(set)
    meaningful_users = defaultdict(set)
    meaningful_actions = Counter()
    friction_user_month = Counter()
    broader_friction_user_month = Counter()
    free_events = Counter()
    free_blocks = Counter()
    free_users = defaultdict(set)
    free_blocked_users = defaultdict(set)
    sync_outcomes = Counter()
    sync_failures = Counter()
    meaningful_platform = defaultdict(set)
    event_platform_mismatches = 0
    event_orphans = 0
    tier_ambiguous_events = 0
    tier_missing_events = 0
    deletion_month_events = Counter()
    for row in tables["Activity_Events"]:
        uid = row["user_id"]
        day = dt(row["timestamp"])
        m = month_start(day)
        events_month[m].append(row)
        activity_users[m].add(uid)
        if uid not in users:
            event_orphans += 1
            continue
        signup_platform = users[uid]["signup_platform"]
        if row["platform"] != signup_platform:
            event_platform_mismatches += 1
        if users[uid]["deletion"] and month_start(users[uid]["deletion"]) == m:
            deletion_month_events[uid] += 1
        if row["result"] == "success" and row["action"] in MEANINGFUL:
            meaningful_users[m].add(uid)
            meaningful_actions[m] += 1
            meaningful_platform[(m, signup_platform)].add(uid)
        if row["action"] in FRICTION:
            friction_user_month[(uid, m)] += 1
        if row["result"] == "failed" or row["action"] in {"allowance_reached", "action_blocked"}:
            broader_friction_user_month[(uid, m)] += 1
        matches = [s for s in history[uid] if s["start"] <= day and (s["end"] is None or s["end"] >= day)]
        if len(matches) > 1:
            tier_ambiguous_events += 1
        if not matches:
            tier_missing_events += 1
        if matches and matches[-1]["tier"] == "Free":
            free_events[m] += 1
            free_users[m].add(uid)
            if row["action"] in {"allowance_reached", "action_blocked"}:
                free_blocks[m] += 1
                free_blocked_users[m].add(uid)
        if row["action"] in {"sync_completed", "sync_failed"}:
            key = (m, row["platform"])
            sync_outcomes[key] += 1
            sync_failures[key] += int(row["action"] == "sync_failed")
    registrations = Counter(month_start(u["registration"]) for u in users.values())
    channels = Counter((month_start(u["registration"]), u["acquisition_channel"]) for u in users.values())
    all_channels = sorted({u["acquisition_channel"] for u in users.values()})
    all_platforms = sorted({u["signup_platform"] for u in users.values()})
    operational = []
    for m in months:
        end = month_end(m)
        eligible = [u for u in users.values() if u["registration"] <= end and (u["deletion"] is None or u["deletion"] >= m)]
        ledger = Counter()
        for u in eligible:
            uid = u["user_id"]
            opening = int(any(s["start"] < m and (s["end"] is None or s["end"] >= m) for s in pro_history[uid]))
            closing = int(any(s["start"] <= end and (s["end"] is None or s["end"] > end) for s in pro_history[uid]))
            cancel = any(s["status"] == "Cancelled" and s["cancel"] and m <= s["cancel"] <= end for s in pro_history[uid])
            ledger["opening_pro"] += opening
            ledger["closing_pro"] += closing
            ledger["opening_pro_cancellations"] += opening * int(cancel)
            ledger["opening_accounts"] += int(u["registration"] < m and (u["deletion"] is None or u["deletion"] >= m))
            ledger["closing_accounts"] += int(u["registration"] <= end and (u["deletion"] is None or u["deletion"] > end))
            ledger["deletions"] += int(u["deletion"] is not None and m <= u["deletion"] <= end)
            for s in pro_history[uid]:
                if m <= s["start"] <= end:
                    ledger["first_upgrades" if s["entry"] == 1 else "repeat_upgrades"] += 1
                ledger["all_pro_cancellation_events"] += int(s["status"] == "Cancelled" and s["cancel"] is not None and m <= s["cancel"] <= end)
                ledger["pro_deletion_exits"] += int(s["status"] == "Ended (account deleted)" and s["end"] is not None and m <= s["end"] <= end)
        active = len(activity_users[m])
        meaningful = len(meaningful_users[m])
        operational.append({"month": m.isoformat(), "registrations": registrations[m], "recorded_active_users": active,
                            "meaningfully_active_users": meaningful, "meaningful_actions": meaningful_actions[m],
                            "meaningful_share_of_active": ratio(meaningful, active),
                            "actions_per_meaningfully_active_user": ratio(meaningful_actions[m], meaningful),
                            **dict(ledger), "paid_cancellation_rate": ratio(ledger["opening_pro_cancellations"], ledger["opening_pro"]),
                            "pro_ledger_residual": ledger["opening_pro"] + ledger["first_upgrades"] + ledger["repeat_upgrades"] - ledger["all_pro_cancellation_events"] - ledger["pro_deletion_exits"] - ledger["closing_pro"],
                            "account_ledger_residual": ledger["opening_accounts"] + registrations[m] - ledger["deletions"] - ledger["closing_accounts"]})
    deletion_monthly = []
    deletion_unique = defaultdict(set)
    deletion_unique_friction = defaultdict(set)
    for m in months:
        prior = shift_month(m, -1)
        end = month_end(m)
        if prior < months[0]:
            continue
        groups = defaultdict(list)
        for uid, u in users.items():
            if u["registration"] > prior or (u["deletion"] is not None and u["deletion"] < m):
                continue
            group = "Deleted this month" if u["deletion"] is not None and m <= u["deletion"] <= end else "Retained through month end"
            groups[group].append(uid)
        for group in ("Deleted this month", "Retained through month end"):
            ids = groups[group]
            with_friction = sum(friction_user_month[(uid, prior)] > 0 for uid in ids)
            broader = sum(broader_friction_user_month[(uid, prior)] > 0 for uid in ids)
            deletion_monthly.append({"outcome_month": m.isoformat(), "lookback_start": prior.isoformat(), "lookback_end_exclusive": m.isoformat(),
                                     "outcome": group, "eligible_account_months": len(ids), "with_prior_friction": with_friction,
                                     "prior_friction_rate": ratio(with_friction, len(ids)),
                                     "friction_events": sum(friction_user_month[(uid, prior)] for uid in ids),
                                     "sensitivity_all_failed_results_count": broader,
                                     "sensitivity_all_failed_results_rate": ratio(broader, len(ids))})
            if m.year == 2025:
                deletion_unique[group].update(ids)
                deletion_unique_friction[group].update(uid for uid in ids if friction_user_month[(uid, prior)] > 0)
    deletion_pooled = []
    for group in ("Deleted this month", "Retained through month end"):
        rows = [r for r in deletion_monthly if r["outcome_month"].startswith("2025") and r["outcome"] == group]
        n = sum(r["eligible_account_months"] for r in rows)
        friction = sum(r["with_prior_friction"] for r in rows)
        deletion_pooled.append({"outcome": group, "eligible_account_months": n, "with_prior_friction": friction,
                               "prior_friction_rate": ratio(friction, n), "unique_users": len(deletion_unique[group]),
                               "unique_users_with_any_prior_friction": len(deletion_unique_friction[group]),
                               "friction_events": sum(r["friction_events"] for r in rows)})
    free = [{"month": m.isoformat(), "free_exposed_users": len(free_users[m]), "free_events": free_events[m],
             "restriction_events": free_blocks[m], "users_with_restriction_event": len(free_blocked_users[m]),
             "blocks_per_exposed_free_user": ratio(free_blocks[m], len(free_users[m])),
             "blocks_per_100_free_events": 100 * ratio(free_blocks[m], free_events[m]) if free_events[m] else None,
             "share_exposed_free_users_with_block": ratio(len(free_blocked_users[m]), len(free_users[m]))} for m in months]
    sync = [{"month": m.isoformat(), "event_platform": p, "sync_outcomes": sync_outcomes[(m, p)],
             "sync_failures": sync_failures[(m, p)], "failure_rate": ratio(sync_failures[(m, p)], sync_outcomes[(m, p)])}
            for m in months for p in all_platforms]
    platform_meaningful = [{"month": m.isoformat(), "signup_platform": p,
                            "meaningfully_active_users": len(meaningful_platform[(m, p)])} for m in months for p in all_platforms]
    conversion = []
    for m in months:
        group = [u for u in users.values() if month_start(u["registration"]) == m]
        mature = [u for u in group if u["registration"] + timedelta(days=90) <= CUTOFF]
        converted = sum(bool(pro_history[u["user_id"]]) and u["registration"] <= pro_history[u["user_id"]][0]["start"] <= u["registration"] + timedelta(days=90) for u in mature)
        conversion.append({"cohort_month": m.isoformat(), "cohort_size": len(group), "eligible_90d_users": len(mature),
                           "converted_90d_users": converted, "conversion_rate_eligible_only": ratio(converted, len(mature)),
                           "fully_mature_cohort": month_end(m) + timedelta(days=90) <= CUTOFF})
    reviews = []
    for m in months:
        rows = [r for r in tables["Reviews"] if month_start(dt(r["review_date"])) == m]
        reviews.append({"month": m.isoformat(), "reviews": len(rows), "average_rating": ratio(sum(float(r["rating"]) for r in rows), len(rows)),
                        "issue_categories": dict(Counter(r["issue_category"] for r in rows))})
    registration_baseline = sum(registrations[m] for m in months if m.year == 2024) / 12
    current = {r["month"]: r for r in operational}
    dec = current["2025-12-01"]
    nov = current["2025-11-01"]
    prior_dec = current["2024-12-01"]
    comparisons = {"registration_2024_monthly_mean": registration_baseline,
                   "dec2025_registration_vs2024mean_relative_change": ratio(dec["registrations"], registration_baseline) - 1,
                   "dec2025_pro_mom_relative_change": ratio(dec["closing_pro"], nov["closing_pro"]) - 1,
                   "dec2025_pro_yoy_relative_change": ratio(dec["closing_pro"], prior_dec["closing_pro"]) - 1,
                   "dec2025_paid_cancellation_mom_pp": 100 * (dec["paid_cancellation_rate"] - nov["paid_cancellation_rate"]),
                   "pro_peak": max(operational, key=lambda r: r["closing_pro"]),
                   "deletion_user_count": sum(u["deletion"] is not None for u in users.values()),
                   "deleted_users_with_deletion_month_events": len(deletion_month_events)}
    checks = {"source_csv_count": len(tables), "unique_user_ids": len(users), "event_user_orphans": event_orphans,
              "event_vs_signup_platform_mismatch_rows": event_platform_mismatches,
              "events_with_multiple_date_only_tier_matches": tier_ambiguous_events,
              "events_without_tier_match": tier_missing_events,
              "nonzero_pro_ledger_residual_months": sum(r["pro_ledger_residual"] != 0 for r in operational),
              "nonzero_account_ledger_residual_months": sum(r["account_ledger_residual"] != 0 for r in operational)}
    return {"audit_utc": datetime.now(timezone.utc).isoformat(), "analysis_cutoff": CUTOFF.isoformat(),
            "raw_source_directory": str(raw_dir), "execution_scope": "Independent Python calculation from CSVs; SQL Server not executed by this script.",
            "definitions": {"meaningful_actions": sorted(MEANINGFUL), "meaningful_success_required": True,
                            "friction_actions": sorted(FRICTION), "deletion_window": "Full prior calendar month [lookback_start, outcome_month_start).",
                            "deletion_eligibility": "Registration on/before prior month start; account open at outcome month start; exclude unavailable prior-month coverage.",
                            "pooled_deletion_grain": "Eligible account-months; retained people can repeat and later enter the deleted group.",
                            "free_tier": "Inclusive date interval; latest start_date then subscription_id wins; same-day ordering unknown.",
                            "paid_rate": "Opening Pro users cancelling this month / opening Pro users.",
                            "sync_denominator": "Recorded sync_completed plus sync_failed events; event platform.",
                            "platform_meaningful_population": "Distinct users by signup_platform; same as event platform in this export only if mismatch check is zero."},
            "source_manifest": manifest, "checks": checks, "headline_comparisons": comparisons,
            "operational_monthly": operational, "registrations_by_month_channel": [{"month": m.isoformat(), "channel": c, "registrations": channels[(m, c)]} for m in months for c in all_channels],
            "free_restrictions_monthly": free, "deletion_prior_calendar_month": deletion_monthly,
            "deletion_prior_calendar_month_pooled_2025": deletion_pooled, "sync_monthly": sync,
            "meaningful_active_by_signup_platform": platform_meaningful, "conversion_90d_by_cohort": conversion,
            "reviews_monthly": reviews}


def write_findings(result, output):
    rows = {r["month"]: r for r in result["operational_monthly"]}
    free = {r["month"]: r for r in result["free_restrictions_monthly"]}
    jan, dec = rows["2025-01-01"], rows["2025-12-01"]
    headings = result["headline_comparisons"]
    text = ["# TaskFlow: independent raw-data evidence", "", "TaskFlow is fictional. All results describe the preserved synthetic export.", "",
            f"**Execution:** {result['audit_utc']}. The script reads CSVs and does not execute SQL Server or modify Power BI.", "",
            "## Main observations", "",
            f"- Registrations fall from {jan['registrations']} in January 2025 to {dec['registrations']} in December. The 2024 monthly mean is {headings['registration_2024_monthly_mean']:.2f}; December is {abs(headings['dec2025_registration_vs2024mean_relative_change']):.1%} lower.",
            f"- Recorded active users change from {jan['recorded_active_users']} to {dec['recorded_active_users']}. Meaningfully-active users change from {jan['meaningfully_active_users']} to {dec['meaningfully_active_users']}; meaningful participation changes from {jan['meaningful_share_of_active']:.1%} to {dec['meaningful_share_of_active']:.1%}.",
            f"- Actions per meaningfully-active user change from {jan['actions_per_meaningfully_active_user']:.2f} to {dec['actions_per_meaningfully_active_user']:.2f}, January–December 2025.",
            f"- December closing Pro subscribers are {dec['closing_pro']}. December MoM is {headings['dec2025_pro_mom_relative_change']:+.2%}; YoY is {headings['dec2025_pro_yoy_relative_change']:+.2%}. The peak is {headings['pro_peak']['closing_pro']} in {headings['pro_peak']['month'][:7]}.",
            f"- December paid cancellation rate is {dec['opening_pro_cancellations']}/{dec['opening_pro']} = {dec['paid_cancellation_rate']:.2%}. MoM change is {headings['dec2025_paid_cancellation_mom_pp']:+.4f} percentage points.",
            f"- Free blocks per exposed user change from {free['2025-01-01']['blocks_per_exposed_free_user']:.4f} to {free['2025-12-01']['blocks_per_exposed_free_user']:.4f}. Blocks per 100 Free events change from {free['2025-01-01']['blocks_per_100_free_events']:.4f} to {free['2025-12-01']['blocks_per_100_free_events']:.4f}.",
            "", "## Deletion comparison", "",
            "Both groups use the entire preceding calendar month. Eligibility requires registration on or before that month starts. The outcome is deletion during the selected month versus retention through month end. Friction uses the existing SQL four-action definition: action_blocked, allowance_reached, sync_failed, or action_failed.", ""]
    for r in result["deletion_prior_calendar_month_pooled_2025"]:
        text.append(f"- {r['outcome']}, pooled 2025: {r['with_prior_friction']}/{r['eligible_account_months']} = {r['prior_friction_rate']:.2%}; {r['unique_users']} distinct users represented.")
    for r in result["deletion_prior_calendar_month"]:
        if r["outcome_month"] == "2025-12-01":
            text.append(f"- December 2025 {r['outcome']}: {r['with_prior_friction']}/{r['eligible_account_months']} = {r['prior_friction_rate']:.2%}, using November activity.")
    text.extend(["", "Retained people repeat across months, and some later become deleted users. Pooled account-month rates are descriptive and must not be described as independently matched users. Registration eligibility does not establish complete activity tracking. All deleted users have zero recorded activity in their deletion month because of the generator rule; the prior calendar window avoids that direct distortion.", "",
                 "## Controls and limitations", "",
                 f"- Source manifest records SHA-256, row count, byte size, and available date coverage for {result['checks']['source_csv_count']} CSVs.",
                 f"- Event/signup platform mismatches: {result['checks']['event_vs_signup_platform_mismatch_rows']}; orphan event users: {result['checks']['event_user_orphans']}.",
                 f"- Date-only tier ambiguity affects {result['checks']['events_with_multiple_date_only_tier_matches']} events. The latest subscription start wins consistently with SQL; intraday order is unknown.",
                 f"- Nonzero monthly Pro/account reconciliation residuals: {result['checks']['nonzero_pro_ledger_residual_months']}/{result['checks']['nonzero_account_ledger_residual_months']}.",
                 "- Sync rates describe recorded client events. Differences in engagement by platform do not establish that sync failures caused them.",
                 "- Reviews are selected synthetic sentiment records. Their counts and averages do not describe all users.",
                 "- Alternative all-failed-result friction rates appear only as sensitivity fields in JSON. They use a different definition from the primary SQL measure.", ""])
    output.write_text("\n".join(text), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, default=Path(__file__).resolve().parents[2] / "data/raw")
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parents[2] / "validation/local/raw")
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    result = audit(args.raw_dir)
    destination = args.out_dir / "raw_evidence.json"
    destination.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    write_findings(result, args.out_dir / "RAW_EVIDENCE_FINDINGS.md")
    print(json.dumps({"json": str(destination), "checks": result["checks"],
                      "deletion_pooled_2025": result["deletion_prior_calendar_month_pooled_2025"],
                      "headline": result["headline_comparisons"]}, indent=2))


if __name__ == "__main__":
    main()
