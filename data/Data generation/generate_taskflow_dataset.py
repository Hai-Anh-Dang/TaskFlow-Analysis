"""
TaskFlow synthetic dataset generator.

Builds a relational dataset (CSV tables) simulating a personal task-management
product going through two years of growth followed by a sharply declining
third year, driven by a documented sequence of business changes:

  2025-02-01  Free plan allowance reduced
  2025-03-01  Pro plan price increased ($9.99 -> $14.99), minimal new features
  2025-04-10  Web interface redesign goes live
  2025-05-10  Mobile (iOS/Android) interface redesign goes live
  2025-06-01  Checkout flow gets extra steps
  2025-07-01  Android app release introduces sync reliability issues

All of this is generated data for a portfolio case study, not real user data.
Scope is intentionally lean: ~1,500 users, ~120,000 activity events, and only
the supporting tables needed to test the "plan/value" and "UX/checkout
friction" hypotheses. Reliability shows up only through review themes and the
failed-action rate already present in Activity_Events -- there is no separate
API request log or incident table; that is a deliberate scope decision, not
an oversight (see data_dictionary.md).
"""

import os
from pathlib import Path
import random
from datetime import date, datetime, timedelta

import numpy as np
import pandas as pd

RNG = np.random.default_rng(42)
random.seed(42)

OUT_DIR = str(Path(__file__).resolve().parents[1] / "generated")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Config: date range, scale targets, business-change timeline
# ---------------------------------------------------------------------------
START_DATE = date(2023, 1, 1)
END_DATE = date(2025, 12, 31)

N_USERS = 1500
TARGET_EVENTS = 120_000

FREE_CUT = date(2025, 2, 1)
PRICE_HIKE = date(2025, 3, 1)
REDESIGN_WEB = date(2025, 4, 10)
REDESIGN_MOBILE = date(2025, 5, 10)
CHECKOUT_REDESIGN = date(2025, 6, 1)
SYNC_ISSUE_START = date(2025, 7, 1)

MONTH_STARTS = []
MONTH_ENDS = []
d = date(START_DATE.year, START_DATE.month, 1)
while d <= END_DATE:
    if d.month == 12:
        nxt = date(d.year + 1, 1, 1)
    else:
        nxt = date(d.year, d.month + 1, 1)
    MONTH_STARTS.append(d)
    MONTH_ENDS.append(nxt - timedelta(days=1))
    d = nxt
N_MONTHS = len(MONTH_STARTS)


def month_index(dt):
    return (dt.year - START_DATE.year) * 12 + (dt.month - START_DATE.month)


def random_day_in_month(m_idx, min_date=None):
    start, end = MONTH_STARTS[m_idx], MONTH_ENDS[m_idx]
    if min_date is not None and min_date > start:
        start = min_date
    if start > end:
        start = end
    span = (end - start).days
    return start + timedelta(days=int(RNG.integers(0, span + 1)))


def bounded_day(m_idx, floor_date):
    """Day within month m_idx, never earlier than floor_date (used whenever
    floor_date's own month is m_idx, e.g. registration month or the month a
    subscription record re-opened)."""
    if month_index(floor_date) == m_idx:
        return random_day_in_month(m_idx, min_date=floor_date)
    return random_day_in_month(m_idx)


def random_time_of_day():
    return timedelta(
        hours=int(RNG.integers(7, 23)),
        minutes=int(RNG.integers(0, 60)),
        seconds=int(RNG.integers(0, 60)),
    )


def scale_to_total(weights, total):
    """Integer counts proportional to weights, summing to exactly `total`
    (largest-remainder rounding)."""
    weights = np.array(weights, dtype=float)
    raw = weights / weights.sum() * total
    floors = np.floor(raw).astype(int)
    remainder = int(total - floors.sum())
    frac = raw - floors
    order = np.argsort(-frac)
    for i in order[:remainder]:
        floors[i] += 1
    return floors


print("Building registration timeline...")

# ---------------------------------------------------------------------------
# 1. Registration timing -- growth in 2023-2024, sharp decline through 2025
# ---------------------------------------------------------------------------
reg_shape_2023 = np.linspace(0.5, 1.0, 12)
reg_shape_2024 = np.linspace(0.95, 1.05, 12)
reg_shape_2025 = np.array(
    [1.20, 1.05, 0.85, 0.55, 0.42, 0.34, 0.30, 0.26, 0.22, 0.19, 0.17, 0.15]
)

reg_counts = np.concatenate(
    [
        scale_to_total(reg_shape_2023, 450),
        scale_to_total(reg_shape_2024, 550),
        scale_to_total(reg_shape_2025, 500),
    ]
)
assert reg_counts.sum() == N_USERS

PLATFORMS = ["Web", "iOS", "Android"]
PLATFORM_WEIGHTS = [0.45, 0.30, 0.25]
ACQ_CHANNELS = ["Organic Search", "Referral", "Social Media", "Paid Ads", "App Store Search"]
ACQ_WEIGHTS = [0.32, 0.22, 0.18, 0.16, 0.12]
COUNTRIES = ["Australia", "United States", "United Kingdom", "Canada", "Singapore", "New Zealand", "Ireland"]
COUNTRY_WEIGHTS = [0.30, 0.24, 0.14, 0.12, 0.08, 0.07, 0.05]
PURPOSES = ["Personal productivity", "Team collaboration", "Study / academic", "Freelance work", "Other"]
PURPOSE_WEIGHTS = [0.42, 0.22, 0.18, 0.12, 0.06]

users = []
uid = 1
for m_idx, n in enumerate(reg_counts):
    for _ in range(int(n)):
        platform = RNG.choice(PLATFORMS, p=PLATFORM_WEIGHTS)
        users.append(
            {
                "user_id": uid,
                "registration_date": random_day_in_month(m_idx),
                "reg_month_idx": m_idx,
                "acquisition_channel": RNG.choice(ACQ_CHANNELS, p=ACQ_WEIGHTS),
                "primary_platform": platform,
                "country": RNG.choice(COUNTRIES, p=COUNTRY_WEIGHTS),
                "declared_purpose": RNG.choice(PURPOSES, p=PURPOSE_WEIGHTS),
            }
        )
        uid += 1

print(f"  {len(users)} users generated.")


def pro_price(d):
    return 9.99 if d < PRICE_HIKE else 14.99


print("Simulating subscriptions, checkout funnels, and deletions...")

# ---------------------------------------------------------------------------
# 2. Per-user monthly state machine: plan tier, checkout attempts, renewals,
#    cancellations, deletions. Produces Subscription_History, Invoices,
#    Payment_Transactions, checkout-funnel activity events, and per-user
#    deletion info.
# ---------------------------------------------------------------------------
CANCEL_REASONS_PRICE = ["Too expensive", "Not enough value for the price", "Found a cheaper alternative"]
CANCEL_REASONS_OTHER = ["No longer needed", "Switched to a different tool", "Rarely used the extra features", "Other"]
DELETE_REASONS_FREE = ["Too restrictive on the free plan", "Switched to a different tool", "No longer needed"]
DELETE_REASONS_GENERAL = ["No longer needed", "Too complicated", "Switched to a different tool", "Other"]
PAYMENT_METHODS = ["Credit card", "PayPal", "Debit card"]
PAYMENT_METHOD_WEIGHTS = [0.60, 0.25, 0.15]

subs_rows = []
invoice_rows = []
payment_rows = []
checkout_events = []
user_month_tier = {}  # (user_id, month_idx) -> "Free" | "Pro"  (only active months)
user_deletion = {}  # user_id -> (deletion_date, deletion_reason)

sub_ctr = 1
inv_ctr = 1
pay_ctr = 1
checkout_ctr = 1


def new_checkout_funnel(user_id, m_idx, min_date=None):
    """Simulate one checkout attempt in month m_idx. Returns (completed, day)."""
    global checkout_ctr
    d0 = random_day_in_month(m_idx, min_date=min_date)
    ts = datetime.combine(d0, datetime.min.time()) + random_time_of_day()
    checkout_id = f"CO{checkout_ctr:06d}"
    checkout_ctr += 1

    n_steps = 2
    continue_prob = 0.85
    if d0 >= PRICE_HIKE:
        continue_prob -= 0.07
    if d0 >= CHECKOUT_REDESIGN:
        n_steps = 4
        continue_prob -= 0.06

    checkout_events.append(
        dict(user_id=user_id, ts=ts, action="checkout_started", feature="Checkout",
             result="success", checkout_id=checkout_id, journey_id=None, error_code=None)
    )
    cur = ts
    reached = 0
    for s in range(1, n_steps + 1):
        cur += timedelta(seconds=int(RNG.integers(20, 90)))
        if RNG.random() > continue_prob:
            break
        checkout_events.append(
            dict(user_id=user_id, ts=cur, action="step_viewed", feature=f"Checkout step {s}",
                 result="success", checkout_id=checkout_id, journey_id=None, error_code=None)
        )
        cur += timedelta(seconds=15)
        checkout_events.append(
            dict(user_id=user_id, ts=cur, action="step_completed", feature=f"Checkout step {s}",
                 result="success", checkout_id=checkout_id, journey_id=None, error_code=None)
        )
        reached = s

    completed = False
    if reached == n_steps:
        cur += timedelta(seconds=int(RNG.integers(10, 40)))
        pay_ok = RNG.random() < 0.95
        checkout_events.append(
            dict(user_id=user_id, ts=cur, action="payment_submitted", feature="Checkout",
                 result="success" if pay_ok else "failed", checkout_id=checkout_id, journey_id=None,
                 error_code=None if pay_ok else RNG.choice(["CARD_DECLINED", "PAYMENT_TIMEOUT"]))
        )
        if pay_ok:
            cur += timedelta(seconds=5)
            checkout_events.append(
                dict(user_id=user_id, ts=cur, action="purchase_completed", feature="Checkout",
                     result="success", checkout_id=checkout_id, journey_id=None, error_code=None)
            )
            completed = True
    return completed, d0


for u in users:
    user_id = u["user_id"]
    platform = u["primary_platform"]
    reg_m = u["reg_month_idx"]
    redesign_m = month_index(REDESIGN_WEB) if platform == "Web" else month_index(REDESIGN_MOBILE)

    tier = "Free"
    open_sub_id = f"SUB{sub_ctr:06d}"
    sub_ctr += 1
    open_sub_start = u["registration_date"]
    open_sub_price_notice = None
    deleted = False

    for m in range(reg_m, N_MONTHS):
        m_start = MONTH_STARTS[m]
        tenure = m - reg_m

        # ---- deletion hazard ----
        hazard = 0.0020
        if tier == "Free" and m_start >= FREE_CUT:
            hazard *= 2.5
        if reg_m < redesign_m <= m:
            hazard *= 2.0
        if tier == "Pro" and m_start >= PRICE_HIKE:
            hazard *= 1.4
        if RNG.random() < hazard:
            deletion_date = bounded_day(m, open_sub_start)
            if tier == "Free" and m_start >= FREE_CUT:
                reason = RNG.choice(DELETE_REASONS_FREE)
            else:
                reason = RNG.choice(DELETE_REASONS_GENERAL)
            user_deletion[user_id] = (deletion_date, reason)
            subs_rows.append(
                dict(subscription_id=open_sub_id, user_id=user_id, tier=tier,
                     start_date=open_sub_start, end_date=deletion_date,
                     actual_price=(pro_price(m_start) if tier == "Pro" else 0.0),
                     status="Ended (account deleted)", price_notice_date=open_sub_price_notice,
                     cancellation_request_date=None, cancellation_effective_date=None,
                     cancellation_reason=None)
            )
            deleted = True
            break

        user_month_tier[(user_id, m)] = tier

        if tier == "Free":
            attempt_prob = 0.05 if tenure <= 2 else 0.02
            if m_start >= FREE_CUT:
                attempt_prob *= 1.3
            if RNG.random() < attempt_prob:
                completed, conv_date = new_checkout_funnel(
                    user_id, m, min_date=(open_sub_start if month_index(open_sub_start) == m else None)
                )
                if completed:
                    # close Free sub, open Pro sub
                    subs_rows.append(
                        dict(subscription_id=open_sub_id, user_id=user_id, tier="Free",
                             start_date=open_sub_start, end_date=conv_date, actual_price=0.0,
                             status="Upgraded to Pro", price_notice_date=None,
                             cancellation_request_date=None, cancellation_effective_date=None,
                             cancellation_reason=None)
                    )
                    tier = "Pro"
                    open_sub_id = f"SUB{sub_ctr:06d}"
                    sub_ctr += 1
                    open_sub_start = conv_date
                    open_sub_price_notice = None
        else:  # Pro: monthly renewal
            price = pro_price(m_start)
            inv_date = random_day_in_month(m)
            pay_ok = RNG.random() < 0.96
            invoice_id = f"INV{inv_ctr:06d}"
            inv_ctr += 1
            invoice_rows.append(
                dict(invoice_id=invoice_id, user_id=user_id, subscription_id=open_sub_id,
                     billing_period_start=m_start, billing_period_end=MONTH_ENDS[m],
                     issue_date=inv_date, due_date=inv_date + timedelta(days=7),
                     actual_price=price, discount=0.0, amount_due=price, currency="AUD",
                     invoice_status="Paid" if pay_ok else "Payment failed")
            )
            payment_rows.append(
                dict(transaction_id=f"TXN{pay_ctr:06d}", invoice_id=invoice_id,
                     timestamp=datetime.combine(inv_date, datetime.min.time()) + random_time_of_day(),
                     transaction_type="Payment", amount=price,
                     status="Success" if pay_ok else "Failed",
                     payment_method=RNG.choice(PAYMENT_METHODS, p=PAYMENT_METHOD_WEIGHTS),
                     failure_reason=None if pay_ok else RNG.choice(["Card declined", "Insufficient funds", "Card expired"]),
                     original_transaction_ref=None)
            )
            pay_ctr += 1

            if m_start >= PRICE_HIKE and open_sub_price_notice is None:
                open_sub_price_notice = PRICE_HIKE

            churn_prob = 0.03 if m_start < PRICE_HIKE else 0.09
            if tenure <= 1:
                churn_prob *= 0.4
            if RNG.random() < churn_prob:
                cancel_request = random_day_in_month(m) - timedelta(days=int(RNG.integers(1, 10)))
                cancel_request = max(cancel_request, open_sub_start)
                cancel_effective = MONTH_ENDS[m]
                if m_start >= PRICE_HIKE and RNG.random() < 0.7:
                    reason = RNG.choice(CANCEL_REASONS_PRICE)
                else:
                    reason = RNG.choice(CANCEL_REASONS_OTHER)
                subs_rows.append(
                    dict(subscription_id=open_sub_id, user_id=user_id, tier="Pro",
                         start_date=open_sub_start, end_date=cancel_effective, actual_price=price,
                         status="Cancelled", price_notice_date=open_sub_price_notice,
                         cancellation_request_date=cancel_request, cancellation_effective_date=cancel_effective,
                         cancellation_reason=reason)
                )
                tier = "Free"
                open_sub_id = f"SUB{sub_ctr:06d}"
                sub_ctr += 1
                open_sub_start = cancel_effective + timedelta(days=1)
                open_sub_price_notice = None

    if not deleted:
        # close the still-open subscription as "Active" at the end of the window
        last_m = N_MONTHS - 1
        subs_rows.append(
            dict(subscription_id=open_sub_id, user_id=user_id, tier=tier,
                 start_date=open_sub_start, end_date=None,
                 actual_price=(pro_price(END_DATE) if tier == "Pro" else 0.0),
                 status="Active", price_notice_date=open_sub_price_notice,
                 cancellation_request_date=None, cancellation_effective_date=None,
                 cancellation_reason=None)
        )

print(f"  {len(subs_rows)} subscription-history rows, {len(invoice_rows)} invoices, "
      f"{len(payment_rows)} payment transactions, {len(checkout_events)} checkout events.")
print(f"  {len(user_deletion)} accounts deleted.")

print("Building engagement weights and flagging affected user-months...")

# ---------------------------------------------------------------------------
# 3. Engagement weights per (user, active month) -> used to allocate the
#    general activity-event pool. Also flags which user-months are affected
#    by the redesign / allowance-cut / sync-issue windows, reused for reviews.
# ---------------------------------------------------------------------------
from collections import defaultdict

users_by_id = {u["user_id"]: u for u in users}

cells = []
weights = []
redesign_affected_users = set()
sync_issue_users = set()
free_restricted_user_months = []
redesign_affected_months_by_user = defaultdict(list)
sync_issue_months_by_user = defaultdict(list)
free_restricted_months_by_user = defaultdict(list)

for (user_id, m), tier in user_month_tier.items():
    u = users_by_id[user_id]
    platform = u["primary_platform"]
    tenure = m - u["reg_month_idx"]
    m_start = MONTH_STARTS[m]
    redesign_m = month_index(REDESIGN_WEB) if platform == "Web" else month_index(REDESIGN_MOBILE)
    redesign_active = u["reg_month_idx"] < redesign_m <= m

    if redesign_active:
        redesign_affected_users.add(user_id)
        redesign_affected_months_by_user[user_id].append(m)
    if platform == "Android" and m_start >= SYNC_ISSUE_START:
        sync_issue_users.add(user_id)
        sync_issue_months_by_user[user_id].append(m)
    if tier == "Free" and m_start >= FREE_CUT:
        free_restricted_user_months.append((user_id, m))
        free_restricted_months_by_user[user_id].append(m)

    novelty = 1.6 if tenure == 0 else max(0.4, 1.3 - 0.03 * tenure)
    plan_bonus = 1.15 if tier == "Pro" else 1.0
    redesign_penalty = 0.75 if redesign_active else 1.0
    allowance_penalty = 0.7 if (tier == "Free" and m_start >= FREE_CUT) else 1.0
    weight = novelty * plan_bonus * redesign_penalty * allowance_penalty

    cells.append((user_id, m, tier))
    weights.append(weight)

weights = np.array(weights, dtype=float)
general_budget = TARGET_EVENTS - len(checkout_events)
probs = weights / weights.sum()
counts = RNG.multinomial(general_budget, probs)

print(f"  general-pool budget: {general_budget} events across {len(cells)} active user-months.")

# ---------------------------------------------------------------------------
# 4. Generate the general activity-event pool for each (user, month) cell.
# ---------------------------------------------------------------------------
REPEAT_ACTIONS = ["task_completed", "reminder_set", "report_viewed"]
REPEAT_FEATURES = {"task_completed": "Tasks", "reminder_set": "Reminders", "report_viewed": "Reports"}
FREE_RESTRICTION_ACTIONS = ["feature_attempted", "allowance_reached", "action_blocked", "upgrade_page_viewed"]
WORKFLOW_FEATURES = ["Projects", "Tasks", "Reminders", "Reports"]


def gen_events_for_cell(user_id, m, tier, count, redesign_active, sync_issue_active, is_first_month):
    out = []
    remaining = count
    mind = users_by_id[user_id]["registration_date"] if m == users_by_id[user_id]["reg_month_idx"] else None

    if is_first_month and remaining > 0:
        d0 = random_day_in_month(m, mind)
        ts = datetime.combine(d0, datetime.min.time()) + random_time_of_day()
        burst = [("project_created", "Projects", "success"), ("task_created", "Tasks", "success")]
        if remaining >= 3:
            burst.append(("first_task_completed", "Tasks", "success"))
        for i, (act, feat, res) in enumerate(burst):
            if remaining <= 0:
                break
            out.append(dict(user_id=user_id, ts=ts + timedelta(minutes=2 * i), action=act, feature=feat,
                             result=res, checkout_id=None, journey_id=None, error_code=None))
            remaining -= 1

    while remaining > 0:
        w = {"repeat": 0.55, "free_restriction": 0.0, "interface": 0.20, "reliability": 0.10}
        if tier == "Free":
            w["free_restriction"] = 0.25
            w["repeat"] = 0.45
        if redesign_active:
            w["interface"] = 0.35
        if sync_issue_active:
            w["reliability"] = 0.25
        if remaining < 2:
            w["reliability"] = 0.0

        total_w = sum(w.values())
        r = RNG.random() * total_w
        acc = 0.0
        chosen = "repeat"
        for k, v in w.items():
            acc += v
            if r <= acc:
                chosen = k
                break

        d0 = random_day_in_month(m, mind)
        ts_base = datetime.combine(d0, datetime.min.time()) + random_time_of_day()

        if chosen == "repeat":
            act = RNG.choice(REPEAT_ACTIONS)
            feat = REPEAT_FEATURES[act]
            res = "failed" if (redesign_active and RNG.random() < 0.08) else "success"
            out.append(dict(user_id=user_id, ts=ts_base, action=act, feature=feat, result=res,
                             checkout_id=None, journey_id=None,
                             error_code=("ACTION_ERROR" if res == "failed" else None)))
            remaining -= 1

        elif chosen == "free_restriction":
            act = RNG.choice(FREE_RESTRICTION_ACTIONS)
            feat = RNG.choice(["Projects", "Tasks", "Premium Feature", "Upgrade Page"])
            res = "success" if act == "upgrade_page_viewed" else "blocked"
            out.append(dict(user_id=user_id, ts=ts_base, action=act, feature=feat, result=res,
                             checkout_id=None, journey_id=None, error_code=None))
            remaining -= 1

        elif chosen == "interface":
            journey_id = f"J{int(RNG.integers(1, 10_000_000))}"
            n_steps = int(RNG.integers(1, 3))
            bundle = min(remaining, n_steps + 2)
            feat = RNG.choice(WORKFLOW_FEATURES)
            cur = ts_base
            out.append(dict(user_id=user_id, ts=cur, action="workflow_started", feature=feat, result="success",
                             checkout_id=None, journey_id=journey_id, error_code=None))
            steps_added = 1
            fail_now = redesign_active and RNG.random() < 0.30
            for s in range(bundle - 2):
                cur += timedelta(seconds=int(RNG.integers(10, 60)))
                nav_res = "failed" if (fail_now and s == bundle - 3) else "success"
                out.append(dict(user_id=user_id, ts=cur, action="navigation_step", feature=feat, result=nav_res,
                                 checkout_id=None, journey_id=journey_id,
                                 error_code=("NAV_ERROR" if nav_res == "failed" else None)))
                steps_added += 1
            if bundle >= 2:
                cur += timedelta(seconds=20)
                final_action = "action_failed" if fail_now else "workflow_completed"
                out.append(dict(user_id=user_id, ts=cur, action=final_action, feature=feat,
                                 result=("failed" if fail_now else "success"), checkout_id=None,
                                 journey_id=journey_id, error_code=("WORKFLOW_ERROR" if fail_now else None)))
                steps_added += 1
            remaining -= steps_added

        else:  # reliability
            cur = ts_base
            out.append(dict(user_id=user_id, ts=cur, action="sync_requested", feature="Sync", result="success",
                             checkout_id=None, journey_id=None, error_code=None))
            fail = sync_issue_active and RNG.random() < 0.35
            cur += timedelta(seconds=int(RNG.integers(2, 20)))
            out.append(dict(user_id=user_id, ts=cur, action=("sync_failed" if fail else "sync_completed"),
                             feature="Sync", result=("failed" if fail else "success"), checkout_id=None,
                             journey_id=None,
                             error_code=(RNG.choice(["SYNC_CONFLICT", "SYNC_TIMEOUT", "SYNC_SERVER_ERROR"]) if fail else None)))
            remaining -= 2

    return out


first_month_done = set()
general_events = []
for (user_id, m, tier), c in zip(cells, counts):
    if c <= 0:
        continue
    u = users_by_id[user_id]
    platform = u["primary_platform"]
    redesign_m = month_index(REDESIGN_WEB) if platform == "Web" else month_index(REDESIGN_MOBILE)
    redesign_active = u["reg_month_idx"] < redesign_m <= m
    sync_issue_active = platform == "Android" and MONTH_STARTS[m] >= SYNC_ISSUE_START
    is_first = (m == u["reg_month_idx"]) and (user_id not in first_month_done)
    if is_first:
        first_month_done.add(user_id)
    general_events.extend(
        gen_events_for_cell(user_id, m, tier, int(c), redesign_active, sync_issue_active, is_first)
    )

print(f"  {len(general_events)} general-pool events generated.")

print("Assigning platform/version fields and grouping events into sessions...")

# ---------------------------------------------------------------------------
# 5. Combine event pools, assign platform/version/interface fields, group
#    same-day events per user into sessions.
# ---------------------------------------------------------------------------
all_events = general_events + checkout_events
print(f"  {len(all_events)} total activity events (target {TARGET_EVENTS}).")

for e in all_events:
    u = users_by_id[e["user_id"]]
    platform = u["primary_platform"]
    e["platform"] = platform
    d0 = e["ts"].date()
    if platform == "Android":
        e["platform_version"] = "7.0" if d0 >= SYNC_ISSUE_START else "6.8"
    elif platform == "iOS":
        e["platform_version"] = "4.2"
    else:
        e["platform_version"] = "current"
    redesign_date = REDESIGN_WEB if platform == "Web" else REDESIGN_MOBILE
    e["interface_variant"] = "New" if d0 >= redesign_date else "Old"

all_events.sort(key=lambda e: (e["user_id"], e["ts"]))

sessions = []
session_lookup = {}
sess_ctr = 1

for e in all_events:
    key = (e["user_id"], e["ts"].date())
    if key not in session_lookup:
        sid = f"SESS{sess_ctr:07d}"
        sess_ctr += 1
        session_lookup[key] = sid
        sessions.append(dict(session_id=sid, user_id=e["user_id"], platform=e["platform"],
                              platform_version=e["platform_version"], interface_variant=e["interface_variant"],
                              date=e["ts"].date(), start_ts=e["ts"], end_ts=e["ts"],
                              n_events=0, has_failure=False, end_reason="Normal"))
    e["session_id"] = session_lookup[key]

sessions_by_id = {s["session_id"]: s for s in sessions}
for e in all_events:
    s = sessions_by_id[e["session_id"]]
    s["n_events"] += 1
    if e["ts"] > s["end_ts"]:
        s["end_ts"] = e["ts"] + timedelta(seconds=10)
    if e["result"] == "failed":
        s["has_failure"] = True

for s in sessions:
    if s["has_failure"]:
        s["end_reason"] = RNG.choice(["Normal", "Timeout", "Error"], p=[0.35, 0.15, 0.50])
    else:
        s["end_reason"] = RNG.choice(["Normal", "Timeout", "Error"], p=[0.90, 0.08, 0.02])
    del s["has_failure"]

print(f"  {len(sessions)} sessions.")

for i, e in enumerate(all_events, start=1):
    e["event_id"] = f"EVT{i:07d}"

activity_events_df = pd.DataFrame(all_events)[
    ["event_id", "user_id", "session_id", "ts", "action", "feature", "result",
     "platform", "platform_version", "interface_variant", "journey_id", "checkout_id", "error_code"]
].rename(columns={"ts": "timestamp"})

sessions_df = pd.DataFrame(sessions)[
    ["session_id", "user_id", "platform", "platform_version", "interface_variant",
     "date", "start_ts", "end_ts", "n_events", "end_reason"]
]

print("Generating reviews...")

# ---------------------------------------------------------------------------
# 6. Reviews -- themed by whatever the reviewer actually experienced.
#    The "sync/reliability" theme is the only evidence trail for the
#    reliability category in this dataset (no separate API/incident table;
#    that's a deliberate scope call).
# ---------------------------------------------------------------------------
POSITIVE_TEMPLATES = [
    "Does exactly what I need for daily task tracking.",
    "Simple and reliable, exactly what I want from a task app.",
    "Great reminders feature, keeps me on track.",
    "Clean interface, easy to use every day.",
    "Solid app for personal productivity.",
]
PRICE_TEMPLATES = [
    "Too expensive for what you actually get now.",
    "Price went up but I don't see the extra value.",
    "Cancelled after the renewal price increase, not worth it anymore.",
    "Pro used to be worth it, not anymore at this price.",
]
RESTRICTION_TEMPLATES = [
    "Free plan is way too restricted now.",
    "Keep hitting the project limit on the free plan.",
    "Used to fit my workflow, now everything gets blocked.",
    "Free tier feels unusable after the allowance cut.",
]
NAVIGATION_TEMPLATES = [
    "Can't find basic features after the redesign.",
    "New layout is confusing, used to be much easier.",
    "Takes way longer to do simple things since the update.",
    "Redesign broke my usual workflow.",
]
SYNC_TEMPLATES = [
    "My changes don't sync across devices anymore.",
    "Constant sync errors on Android lately.",
    "Tasks disappear and reappear, sync is unreliable.",
    "Sync keeps failing since the last app update.",
]
CHECKOUT_TEMPLATES = [
    "Checkout has too many steps now, gave up halfway.",
    "Tried to upgrade but the payment process kept redirecting me.",
    "Way too many steps just to subscribe.",
    "Abandoned my upgrade, checkout was too long.",
]

review_rows = []
review_ctr = 1


def add_review(user_id, review_date, rating, text, category):
    global review_ctr
    review_date = min(review_date, END_DATE)
    u = users_by_id[user_id]
    review_rows.append(dict(review_id=f"REV{review_ctr:05d}", user_id=user_id, review_date=review_date,
                             platform=u["primary_platform"], rating=rating, review_text=text,
                             issue_category=category))
    review_ctr += 1


def sample_users(pool, frac):
    pool = sorted(pool)
    n = max(0, int(len(pool) * frac))
    if n == 0 or not pool:
        return []
    idx = RNG.choice(len(pool), size=min(n, len(pool)), replace=False)
    return [pool[i] for i in idx]


for uid in sample_users(free_restricted_months_by_user.keys(), 0.18):
    m = RNG.choice(free_restricted_months_by_user[uid])
    add_review(uid, random_day_in_month(int(m)), int(RNG.integers(1, 3)), RNG.choice(RESTRICTION_TEMPLATES), "Restriction")

for uid in sample_users(redesign_affected_months_by_user.keys(), 0.15):
    m = RNG.choice(redesign_affected_months_by_user[uid])
    add_review(uid, random_day_in_month(int(m)), int(RNG.integers(2, 4)), RNG.choice(NAVIGATION_TEMPLATES), "Navigation")

for uid in sample_users(sync_issue_months_by_user.keys(), 0.20):
    m = RNG.choice(sync_issue_months_by_user[uid])
    add_review(uid, random_day_in_month(int(m)), int(RNG.integers(1, 3)), RNG.choice(SYNC_TEMPLATES), "Sync")

checkout_by_id = defaultdict(list)
for e in checkout_events:
    checkout_by_id[e["checkout_id"]].append(e)

abandoned_checkout_late = []
for cid, evs in checkout_by_id.items():
    actions = {e["action"] for e in evs}
    start_ts = min(e["ts"] for e in evs)
    if "purchase_completed" not in actions and start_ts.date() >= CHECKOUT_REDESIGN:
        abandoned_checkout_late.append((evs[0]["user_id"], start_ts.date()))

price_cancelled = [r for r in subs_rows if r["status"] == "Cancelled" and r["cancellation_reason"] in CANCEL_REASONS_PRICE]
idx = RNG.choice(len(price_cancelled), size=min(int(len(price_cancelled) * 0.5), len(price_cancelled)), replace=False) if price_cancelled else []
for i in idx:
    r = price_cancelled[int(i)]
    d0 = r["cancellation_effective_date"] + timedelta(days=int(RNG.integers(0, 10)))
    add_review(r["user_id"], d0, int(RNG.integers(1, 3)), RNG.choice(PRICE_TEMPLATES), "Price")

idx = RNG.choice(len(abandoned_checkout_late), size=min(int(len(abandoned_checkout_late) * 0.12), len(abandoned_checkout_late)), replace=False) if abandoned_checkout_late else []
for i in idx:
    uid, d0 = abandoned_checkout_late[int(i)]
    add_review(uid, d0 + timedelta(days=int(RNG.integers(0, 5))), int(RNG.integers(2, 4)), RNG.choice(CHECKOUT_TEMPLATES), "Checkout")

active_user_months = defaultdict(list)
for (uid, m), _tier in user_month_tier.items():
    active_user_months[uid].append(m)
for uid in sample_users(active_user_months.keys(), 0.15):
    m = RNG.choice(active_user_months[uid])
    add_review(uid, random_day_in_month(int(m)), int(RNG.integers(4, 6)), RNG.choice(POSITIVE_TEMPLATES), "Positive / other")

reviews_df = pd.DataFrame(review_rows)
print(f"  {len(reviews_df)} reviews generated.")

print("Building dimension and remaining fact tables...")

# ---------------------------------------------------------------------------
# 7. Users, Subscription_History, Invoices, Payments, and dimension tables
# ---------------------------------------------------------------------------
users_rows_out = []
for u in users:
    dd, dr = user_deletion.get(u["user_id"], (None, None))
    users_rows_out.append(dict(
        user_id=u["user_id"], registration_date=u["registration_date"],
        acquisition_channel=u["acquisition_channel"], signup_platform=u["primary_platform"],
        country=u["country"], declared_purpose=u["declared_purpose"],
        account_deletion_date=dd, deletion_reason=dr,
    ))
users_df = pd.DataFrame(users_rows_out)

subs_df = pd.DataFrame(subs_rows)
invoices_df = pd.DataFrame(invoice_rows)
payments_df = pd.DataFrame(payment_rows)

platforms_df = pd.DataFrame([
    dict(platform_id="PLAT01", platform_name="Web", platform_type="Web"),
    dict(platform_id="PLAT02", platform_name="iOS", platform_type="Mobile"),
    dict(platform_id="PLAT03", platform_name="Android", platform_type="Mobile"),
])

plan_versions_df = pd.DataFrame([
    dict(plan_version_id="PLAN001", tier="Free", effective_start=date(2023, 1, 1), effective_end=date(2025, 1, 31),
         price=0.0, billing_frequency=None, project_allowance=10, task_allowance=200,
         features="Basic task management, reminders"),
    dict(plan_version_id="PLAN002", tier="Free", effective_start=FREE_CUT, effective_end=None,
         price=0.0, billing_frequency=None, project_allowance=3, task_allowance=50,
         features="Basic task management, reminders"),
    dict(plan_version_id="PLAN003", tier="Pro", effective_start=date(2023, 1, 1), effective_end=date(2025, 2, 28),
         price=9.99, billing_frequency="Monthly", project_allowance=None, task_allowance=None,
         features="Unlimited projects & tasks, reminders, reports, calendar integration"),
    dict(plan_version_id="PLAN004", tier="Pro", effective_start=PRICE_HIKE, effective_end=None,
         price=14.99, billing_frequency="Monthly", project_allowance=None, task_allowance=None,
         features="Unlimited projects & tasks, reminders, reports, calendar integration, priority support"),
])

change_register_df = pd.DataFrame([
    dict(change_id="CHG001", description="Free plan allowance reduced (10->3 projects, 200->50 tasks)",
         intended_benefit="Encourage upgrades to Pro", announcement_date=date(2025, 1, 15),
         rollout_start=FREE_CUT, rollout_end=FREE_CUT, affected_plans="Free",
         affected_platforms="Web, iOS, Android", affected_versions="All", rollout_group="All Free users"),
    dict(change_id="CHG002", description="Pro plan price increased $9.99 -> $14.99; added priority support",
         intended_benefit="Increase revenue per subscriber", announcement_date=date(2025, 2, 10),
         rollout_start=PRICE_HIKE, rollout_end=PRICE_HIKE, affected_plans="Pro",
         affected_platforms="Web, iOS, Android", affected_versions="All",
         rollout_group="All Pro subscribers, applied at next renewal"),
    dict(change_id="CHG003", description="Web interface redesign (navigation and layout overhaul)",
         intended_benefit="Modernise UI, ease onboarding", announcement_date=date(2025, 3, 20),
         rollout_start=date(2025, 4, 1), rollout_end=date(2025, 4, 15), affected_plans="Free, Pro",
         affected_platforms="Web", affected_versions="All", rollout_group="All web users, phased over 2 weeks"),
    dict(change_id="CHG004", description="Mobile interface redesign (same overhaul extended to iOS/Android)",
         intended_benefit="Consistent experience across platforms", announcement_date=date(2025, 4, 20),
         rollout_start=date(2025, 5, 1), rollout_end=date(2025, 5, 15), affected_plans="Free, Pro",
         affected_platforms="iOS, Android", affected_versions="All", rollout_group="All mobile users, phased over 2 weeks"),
    dict(change_id="CHG005", description="Checkout flow redesign (added verification and plan-confirmation steps)",
         intended_benefit="Reduce erroneous signups, improve plan-selection accuracy", announcement_date=date(2025, 5, 15),
         rollout_start=CHECKOUT_REDESIGN, rollout_end=CHECKOUT_REDESIGN, affected_plans="Free (upgrade flow)",
         affected_platforms="Web, iOS, Android", affected_versions="All", rollout_group="All users starting checkout"),
    dict(change_id="CHG006", description="Android app release v7.0 (backend sync service migration)",
         intended_benefit="Improve long-term sync performance", announcement_date=date(2025, 6, 25),
         rollout_start=SYNC_ISSUE_START, rollout_end=date(2025, 7, 10), affected_plans="Free, Pro",
         affected_platforms="Android", affected_versions="7.0+", rollout_group="All Android users on auto-update"),
])

date_rows = []
dcur = START_DATE
while dcur <= END_DATE:
    date_rows.append(dict(date=dcur, year=dcur.year, quarter=(dcur.month - 1) // 3 + 1, month=dcur.month,
                           week=dcur.isocalendar()[1], weekday=dcur.strftime("%A")))
    dcur += timedelta(days=1)
date_df = pd.DataFrame(date_rows)

print("Running validation checks...")

# ---------------------------------------------------------------------------
# 8. Validation: referential integrity, chronology, row counts
# ---------------------------------------------------------------------------
issues = []

valid_users = set(users_df["user_id"])
for name, df in [("Subscription_History", subs_df), ("Sessions", sessions_df),
                  ("Activity_Events", activity_events_df), ("Invoices", invoices_df),
                  ("Reviews", reviews_df)]:
    bad = set(df["user_id"]) - valid_users
    if bad:
        issues.append(f"{name}: {len(bad)} user_id values not found in Users")

bad_inv = set(payments_df["invoice_id"]) - set(invoices_df["invoice_id"])
if bad_inv:
    issues.append(f"Payment_Transactions: {len(bad_inv)} invoice_id values not found in Invoices")

reg_lookup = dict(zip(users_df["user_id"], users_df["registration_date"]))
del_lookup = dict(zip(users_df["user_id"], users_df["account_deletion_date"]))

early = activity_events_df.merge(users_df[["user_id", "registration_date"]], on="user_id")
early = early[early["timestamp"].dt.date < early["registration_date"]]
if len(early):
    issues.append(f"Activity_Events: {len(early)} events occur before the user's registration date")

late = activity_events_df.merge(users_df[["user_id", "account_deletion_date"]].dropna(), on="user_id")
late = late[late["timestamp"].dt.date > late["account_deletion_date"]]
if len(late):
    issues.append(f"Activity_Events: {len(late)} events occur after the user's account-deletion date")

bad_subs = subs_df[subs_df["end_date"].notna() & (subs_df["end_date"] < subs_df["start_date"])]
if len(bad_subs):
    issues.append(f"Subscription_History: {len(bad_subs)} rows have end_date before start_date")

row_counts = {
    "Users": len(users_df), "Platforms": len(platforms_df), "Plan_Versions": len(plan_versions_df),
    "Subscription_History": len(subs_df), "Sessions": len(sessions_df),
    "Activity_Events": len(activity_events_df), "Invoices": len(invoices_df),
    "Payment_Transactions": len(payments_df), "Reviews": len(reviews_df),
    "Business_Change_Register": len(change_register_df), "Date": len(date_df),
}

regs_by_year = users_df["registration_date"].apply(lambda d: d.year).value_counts().sort_index()
dels_by_year = users_df["account_deletion_date"].dropna().apply(lambda d: d.year).value_counts().sort_index()

print("  Row counts:", row_counts)
print("  Registrations by year:", dict(regs_by_year))
print("  Deletions by year:", dict(dels_by_year))
if issues:
    print("  ISSUES FOUND:")
    for i in issues:
        print("   -", i)
else:
    print("  No referential-integrity or chronology issues found.")

print("Writing CSV files...")

# ---------------------------------------------------------------------------
# 9. Export
# ---------------------------------------------------------------------------
tables = {
    "Date": date_df,
    "Platforms": platforms_df,
    "Plan_Versions": plan_versions_df,
    "Users": users_df,
    "Subscription_History": subs_df,
    "Sessions": sessions_df,
    "Activity_Events": activity_events_df,
    "Invoices": invoices_df,
    "Payment_Transactions": payments_df,
    "Reviews": reviews_df,
    "Business_Change_Register": change_register_df,
}

for name, df in tables.items():
    df.to_csv(os.path.join(OUT_DIR, f"{name}.csv"), index=False)

print(f"  Wrote {len(tables)} CSV files to {OUT_DIR}")
print("Done.")
