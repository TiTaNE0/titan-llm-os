#!/usr/bin/env python3
"""produce.py - assemble runs/<batch>/replies_to_post.md (v3.2) and set the recommended/review marks.

Usage: produce.py RUN_DIR --budget BUDGET_JSON

Reads 01_anchored.json, 02_drafts.json, 03_review.json in RUN_DIR and the hook names of the
pattern sheet (PIPELINE_PATTERNS, default reply_patterns.md). Copies draft, answers, point,
hook.instruction and yours byte for byte; never corrects, annotates or flags draft text.
Marks: walks passed items in rank order and marks `recommended` while fewer than post_today are
marked and no posting rule breaks (one per author a day, deep_per_day Deep, the stage's
large_per_day under large accounts); a passed large-account item takes the day's large place
first. The post_today: header line is the number marked; when that is below the budget's
post_today, post_short: says why (and post_reason too when none is marked).
Delivery: recommended first, then review, each best first, up to deliver_cap, at most
tiers.large.per_run lane items, each hook id once per mail; the rest go to Skipped (over cap).
Exit 0, or 2 on bad input.
"""
import json
import os
import sys
from pathlib import Path

BIN = Path(__file__).resolve().parent
C = BIN.parent
PATTERNS = Path(os.environ.get("PIPELINE_PATTERNS") or C / "reply_patterns.md")
STATE = Path(os.environ.get("PIPELINE_STATE_DIR") or C / "runs" / "_index")
sys.path.insert(0, str(BIN))
from target_filter import parse_hooks  # noqa: E402


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def load(path, required=True):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        if required:
            die(f"missing input: {path}")
        return {}
    except ValueError as e:
        die(f"bad JSON in {path}: {e}")


def hook_names():
    try:
        return parse_hooks(PATTERNS.read_text())["allowed"]
    except OSError:
        return {}


def passed_items(anch, drafts, review):
    """Passed targets in rank order, each joined with its draft and review result."""
    dmap = {}
    for d in drafts.get("drafts", []):
        if d.get("url") and not d.get("skip"):
            dmap[d["url"]] = d
    rmap = {r.get("url"): r for r in review.get("results", [])}
    targets = anch.get("targets", [])
    order = sorted(range(len(targets)), key=lambda i: (targets[i].get("rank", i), i))
    out = []
    for i in order:
        t = targets[i]
        r = rmap.get(t.get("url"), {})
        if r.get("status") == "passed" and t.get("url") in dmap:
            out.append({"t": t, "d": dmap[t["url"]], "r": r})
    return out


def is_large(it):
    return str(it["t"].get("tier")) == "3"


def is_deep(it):
    return (it["t"].get("reply_type") or it["d"].get("reply_type")) == "deep"


def caps_filter(items, lane_cap):
    keep, skipped, hooks, lane = [], [], set(), 0
    for it in items:
        hid = (it["d"].get("hook") or {}).get("id")
        if hid in hooks:
            skipped.append((it, f"over cap (hook {hid} already in this mail)"))
            continue
        if is_large(it) and lane >= lane_cap:
            skipped.append((it, "over cap (large-account items per run)"))
            continue
        hooks.add(hid)
        lane += is_large(it)
        keep.append(it)
    return keep, skipped


def set_marks(items, budget):
    """Mark items recommended; return why fewer than post_today are marked, or ""."""
    today = budget.get("recommended_today") or {}
    authors = {a.lower() for a in today.get("authors", [])}
    deep, large = today.get("deep", 0), today.get("large", 0)
    want = budget.get("post_today", 0) or 0
    deep_cap = (budget.get("volume") or {}).get("deep_per_day", 1)
    large_cap = budget.get("large_per_day", 1)
    marked, blocked = [], set()

    def eligible(it):
        a = (it["t"].get("author") or "").lstrip("@").lower()
        rules = [(a in authors, "one per author a day"),
                 (is_deep(it) and deep >= deep_cap, f"{deep_cap} Deep a day"),
                 (is_large(it) and large >= large_cap, f"{large_cap} large account a day")]
        broken = [r for hit, r in rules if hit]
        blocked.update(broken)
        return not broken

    def mark(it):
        nonlocal deep, large
        it["recommended"] = True
        marked.append(it)
        authors.add((it["t"].get("author") or "").lstrip("@").lower())
        deep += is_deep(it)
        large += is_large(it)

    lane = [it for it in items if is_large(it)]
    if want > 0 and lane and large < large_cap and eligible(lane[0]):
        mark(lane[0])
    for it in items:
        if len(marked) >= want:
            break
        if not it.get("recommended") and eligible(it):
            mark(it)
    for it in items:
        it.setdefault("recommended", False)
    return shortfall(len(marked), want, len(items), blocked)


def shortfall(n, want, passed, blocked):
    if n >= want:
        return ""
    if not blocked:
        return f"only {passed} item{'' if passed == 1 else 's'} passed"
    return f"only {n} of {passed} passed items can be recommended ({', '.join(sorted(blocked))})"


def item_lines(n, it, names):
    t, d = it["t"], it["d"]
    hook = d.get("hook") or {}
    hid = hook.get("id", "")
    eng = t.get("engagement") or {}
    views = t.get("parent_views_at_capture", eng.get("views"))
    claim = t.get("claim_origin") or ""
    lines = [f"### {n}. {t['url']}",
             f"- author: {(t.get('author') or '').lstrip('@')}",
             f"- followers: {t.get('author_followers', '')}",
             f"- tier: {t.get('tier', '')}",
             f"- mark: {'recommended' if it['recommended'] else 'review'}"]
    if is_large(it):
        lines.append("- lane: large")
    lines += [f"- type: {t.get('reply_type') or d.get('reply_type') or ''}",
              f"- claim: {claim}",
              f"- bound: {t.get('ground_with') or 'none'}",
              f"- views: {views if views is not None else ''}",
              f"- posted_at: {t.get('posted_at', '')}",
              f"- age_min: {t.get('age_min_at_capture', '')}",
              f"- HOOK: {hid} · {names.get(hid) or hook.get('name', '')}",
              f"- OPEN: {hook.get('instruction', '')}",
              f"- QUOTE: {d.get('answers', '')}",
              f"- POINT: {d.get('point', '')}",
              f"- DRAFT: {d.get('draft', '')}"]
    if d.get("yours"):
        lines.append(f"- YOURS: {d['yours']}")
    if claim == "public_source":
        lines += [f"- SOURCE: {t.get('source_url', '')}", f"- BASIS: {t.get('basis', '')}"]
    for v in d.get("verify_flags") or []:
        lines.append(f"- VERIFY: {v}")
    return lines


def header(batch, budget, review, n_items, n_rec, short):
    cal = (review.get("_calibration") or {}).get("result", "")
    critic = review.get("critic_model") or review.get("critic") or \
        (load(STATE / "critic_model.json", required=False).get("cli_name", ""))
    lines = [f"# Replies to post: batch {batch}", "",
             f"slot: {budget.get('slot_id', '')}",
             f"mode: {budget.get('mode', 'trial')}",
             f"stage: {budget.get('stage', 1)}",
             f"post_today: {n_rec}",
             f"post_reason: {short if short and not n_rec else budget.get('post_reason', '')}",
             f"post_short: {short}",
             f"today_more: {budget.get('today_line', budget.get('today_more', ''))}",
             f"stage_note: {budget.get('stage_note', '')}",
             f"items: {n_items}",
             f"critic: {critic}",
             f"calibration: {cal}",
             f"status_line: {budget.get('status_line', '')}"]
    if review.get("held"):
        lines.append("status: HELD - DO NOT POST")
    return lines


def other_lines(drafts, review, skipped):
    sk = [f"- {it['t']['url']} — skip_reason: {why}" for it, why in skipped]
    for d in drafts.get("drafts", []):
        if d.get("skip"):
            sk.append(f"- {d.get('url')} — skip_reason: {d['skip']}")
    quar = []
    for r in review.get("results", []):
        st, url = r.get("status"), r.get("url")
        if st in ("dropped", "skipped", "held"):
            sk.append(f"- {url} — {st}: {r.get('drop_reason') or r.get('skip_reason') or r.get('critic_verdict') or ''}")
        elif st == "quarantined":
            quar.append(f"- {url} — quarantined: {json.dumps(r.get('reject_history') or r.get('drop_reason') or '')}")
    return sk, quar


def main():
    if len(sys.argv) != 4 or sys.argv[2] != "--budget":
        die(__doc__)
    run = Path(sys.argv[1])
    budget = load(sys.argv[3])
    anch, drafts, review = load(run / "01_anchored.json"), load(run / "02_drafts.json"), load(run / "03_review.json")
    lane_cap = ((budget.get("tiers") or {}).get("large") or {}).get("per_run", 2)
    keep, skipped = caps_filter(passed_items(anch, drafts, review), lane_cap)
    short = set_marks(keep, budget)
    ordered = [it for it in keep if it["recommended"]] + [it for it in keep if not it["recommended"]]
    cap = budget.get("deliver_cap", 6)
    delivered = ordered[:cap]
    skipped += [(it, "over cap (delivery number)") for it in ordered[cap:]]
    n_rec = sum(1 for it in delivered if it["recommended"])
    names = hook_names()
    batch = anch.get("batch") or run.name
    out = header(batch, budget, review, len(delivered), n_rec, short) + ["", "---", ""]
    for n, it in enumerate(delivered, 1):
        out += item_lines(n, it, names) + [""]
    sk, quar = other_lines(drafts, review, skipped)
    out += ["---", "", "## Skipped", ""] + (sk or ["none"]) + ["", "## Quarantined", ""] + (quar or ["none"]) + [""]
    (run / "replies_to_post.md").write_text("\n".join(out))
    print(json.dumps({"batch": batch, "delivered": len(delivered),
                      "recommended": n_rec, "skipped": len(sk)}))


if __name__ == "__main__":
    main()
