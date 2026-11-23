#!/usr/bin/env python3
"""target_filter.py - target limits (rule 10), ranking, the large-account lane, the zone list,
the hook sheet parser and the per-item field checks of the @ogrizkov reply pipeline (v3.2).

  zones [--voice F] --out F
  prefilter --candidates F --budget F --out F --cuts F
  rank --survivors F --threads F --out F
  hooks [--patterns F]
  check-item --target F --draft F --thread F --budget F [--source-text F] [--patterns F]
  authors --limit N

Exit: 0 ok, 1 rule failure, 2 input error.
"""
import argparse
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path

BIN = Path(__file__).resolve().parent
C = BIN.parent
STATE = Path(os.environ.get("PIPELINE_STATE_DIR") or C / "runs" / "_index")
PARAMS_FILE = Path(os.environ.get("PIPELINE_PARAMS") or C / "agents" / "params.json")
PATTERNS = Path(os.environ.get("PIPELINE_PATTERNS") or C / "reply_patterns.md")
WATCHLIST = Path(os.environ.get("PIPELINE_WATCHLIST") or C / "agents" / "watchlist.json")
VOICE = Path(os.environ.get("PIPELINE_VOICE") or C.parents[1] / "voice.md")

CUT_POST_TYPES = {"promo", "announcement", "listicle", "giveaway", "connect", "growth_tool", "meme", "poll"}
LANE_MOVES = {"contradicts", "measures_same_variable"}
ID_RE = r"[A-Z]{1,3}\d{1,2}"


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        if default is not None:
            return default
        die(f"missing input: {path}")
    except ValueError as e:
        die(f"bad JSON in {path}: {e}")


def write_json(path, obj):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def now_utc():
    v = os.environ.get("PIPELINE_NOW")
    if not v:
        return dt.datetime.now(dt.timezone.utc)
    t = dt.datetime.fromisoformat(v.replace("Z", "+00:00"))
    return (t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)).astimezone(dt.timezone.utc)


def parse_ts(s):
    if not s:
        return None
    try:
        t = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def iso(t):
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def num(v):
    try:
        return int(str(v).replace(",", ""))
    except (TypeError, ValueError):
        return None


# ---------- zones -------------------------------------------------------------
def parse_zones(text):
    m = re.search(r"<decision_rules>(.*?)</decision_rules>", text, re.S)
    if not m:
        return None
    r = re.search(r"<rule>\s*Authority zones[^:]*:(.*?)</rule>", m.group(1), re.S)
    if not r:
        return None
    zones = [z.strip().rstrip(".").strip() for z in r.group(1).split(",")]
    return [z for z in zones if z] or None


def cmd_zones(a):
    voice = Path(a.voice) if a.voice else VOICE
    try:
        text = voice.read_text()
    except OSError as e:
        die(f"voice file unreadable: {voice}: {e}")
    zones = parse_zones(text)
    if not zones:
        die(f"no 'Authority zones' rule in <decision_rules> of {voice}")
    write_json(a.out, {"source": str(voice), "generated_at": iso(now_utc()), "zones": zones})
    print(json.dumps({"zones": zones}))


# ---------- hooks -------------------------------------------------------------
def parse_hooks(text):
    allowed, banned, types = {}, [], {}
    in_dont, dont_level, cur = False, 0, None
    for line in text.splitlines():
        h = re.match(r"^(#{1,6})\s+(.*)$", line)
        if h:
            level, title = len(h.group(1)), h.group(2).strip()
            cur = None
            if in_dont and level <= dont_level:
                in_dont = False
            if "do not use" in title.lower():
                in_dont, dont_level = True, level
                continue
            m = re.match(rf"^({ID_RE})\s*[-–—:·.]\s*(.+)$", title)
            if m:
                if in_dont:
                    banned.append(m.group(1))
                else:
                    allowed[m.group(1)] = m.group(2).strip()
                    cur = m.group(1)
            continue
        t = re.match(r"^\s*Type:\s*(Deep|Clean)\b", line, re.I)
        if t and cur:
            types[cur] = t.group(1).lower()
        if in_dont:
            m = re.match(rf"^\s*[-*+]\s+({ID_RE})\b", line)
            if m:
                banned.append(m.group(1))
    for b in banned:
        allowed.pop(b, None)
        types.pop(b, None)
    return {"allowed": allowed, "banned": sorted(set(banned)), "types": types}


def load_hooks(path=None):
    p = Path(path) if path else PATTERNS
    try:
        sheet = parse_hooks(p.read_text())
    except OSError:
        die(f"pattern sheet missing: {p}")
    if not sheet["allowed"]:
        die(f"pattern sheet without a usable hook: {p}")
    return sheet


def cmd_hooks(a):
    print(json.dumps(load_hooks(a.patterns), indent=2, ensure_ascii=False))


# ---------- watchlist / authors ----------------------------------------------------
def watchlist():
    w = read_json(WATCHLIST, {"authors": [], "large": []})
    return ({e["handle"].lower(): e for e in w.get("authors", [])},
            {e["handle"].lower(): e for e in w.get("large", [])})


def authors_state():
    return read_json(STATE / "authors.json", {"authors": {}})


def handle_of(c):
    return (c.get("author") or "").lstrip("@").lower()


def update_authors(cands, now):
    st = authors_state()
    a = st.setdefault("authors", {})
    for c in cands:
        h = handle_of(c)
        if not h:
            continue
        e = a.setdefault(h, {"author": h, "answered_him": 0, "op_replies_seen": 0, "delivered": 0})
        if num(c.get("author_followers")) is not None:
            e["followers"] = num(c.get("author_followers"))
        e["last_seen"] = iso(now)
        if num(c.get("op_replies_in_thread")):
            e["op_replies_seen"] = max(e.get("op_replies_seen", 0), num(c["op_replies_in_thread"]))
    write_json(STATE / "authors.json", st)


# ---------- prefilter / rank ----------------------------------------------------------------
def params_from(budget):
    p = read_json(PARAMS_FILE)
    return {k: budget.get(k) or p[k] for k in ("capture", "ranking", "tiers")}


def tier_of(followers, tiers):
    if followers <= tiers["t1_max_followers"]:
        return 1
    return 2 if followers <= tiers["t2_max_followers"] else 3


def has_momentum(views, age, ranking):
    if views is None:
        return False
    if views >= ranking["momentum_views"]:
        return True
    return views / max(age, 1) * ranking["momentum_project_min"] >= ranking["momentum_views"]


def answers_signal(c, tier, small, known):
    h = handle_of(c)
    return int(tier == 1 or h in small or (known.get(h, {}).get("answered_him") or 0) > 0
               or (num(c.get("op_replies_in_thread")) or 0) > 0)


def band_of(age, capture):
    return "0-90" if age <= capture["fresh_min"] else "91-210"


def annotate(c, age, tier, P, small, known):
    views = num(c.get("views"))
    if views is None:
        views = num((c.get("engagement") or {}).get("views"))
    mom = has_momentum(views, age, P["ranking"])
    ans = answers_signal(c, tier, small, known)
    c.update({"tier": tier, "age_min_at_capture": int(age), "parent_views_at_capture": views,
              "momentum": mom, "answers": bool(ans), "score": ans + int(mom),
              "band": band_of(age, P["capture"])})
    return c


def rank_key(c):
    return (0 if c["band"] == "0-90" else 1, -c["score"], c["tier"], c["age_min_at_capture"],
            c.get("content_pillar") or "")


def lane_key(large):
    def k(c):
        ev = large.get(handle_of(c), {}).get("evidence")
        return (0 if ev in ("lab", "builder") else 1, c["age_min_at_capture"])
    return k


def cut_reason(c, age, followers, P, delivered, seen):
    cap, tiers = P["capture"], P["tiers"]
    if c.get("url") in seen:
        return "duplicate"
    if c.get("url") in delivered:
        return "already_delivered"
    if c.get("lang") and str(c["lang"]).lower() not in ("en", "english"):
        return "not_english"
    if str(c.get("post_type") or "discussion").lower() in CUT_POST_TYPES:
        return "post_type"
    if age is None:
        return "no_posted_at"
    if followers is None:
        return "no_followers"
    if followers > tiers["t2_max_followers"]:
        return "large_too_old" if age > tiers["large"]["max_age_min"] else None
    if followers < cap["min_followers"]:
        return "author_too_small"
    if age > cap["max_age_min"]:
        return "too_old"
    if (num(c.get("replies")) or 0) > cap["max_replies"]:
        return "too_many_replies"
    return None


def empty_bands():
    return {b: {"candidates": 0, "survivors": 0} for b in ("0-90", "91-210")}


def cmd_prefilter(a):
    budget = read_json(a.budget)
    P = params_from(budget)
    cands = read_json(a.candidates).get("candidates", [])
    now = now_utc()
    small, large = watchlist()
    known = authors_state().get("authors", {})
    delivered = set(budget.get("urls_delivered") or [])
    seen, cuts, normal, lane = set(), [], [], []
    bands = empty_bands()
    for c in cands:
        t = parse_ts(c.get("posted_at"))
        age = (now - t).total_seconds() / 60 if t else None
        followers = num(c.get("author_followers"))
        if age is not None and age <= P["capture"]["max_age_min"]:
            bands[band_of(age, P["capture"])]["candidates"] += 1
        why = cut_reason(c, age, followers, P, delivered, seen)
        seen.add(c.get("url"))
        if why:
            cuts.append({"url": c.get("url"), "reason": why})
            continue
        tier = tier_of(followers, P["tiers"])
        c = annotate(dict(c), age, tier, P, small, known)
        (lane if tier == 3 else normal).append(c)
    normal.sort(key=rank_key)
    lane.sort(key=lane_key(large))
    for c in normal:
        bands[c["band"]]["survivors"] += 1
    out = {"generated_at": iso(now), "survivors": normal, "lane": lane,
           "funnel": {"candidates": len(cands), "survivors": len(normal) + len(lane), "by_age_band": bands}}
    write_json(a.out, out)
    write_json(a.cuts, {"cuts": cuts})
    update_authors(cands, now)
    print(json.dumps(out["funnel"]))


def fill_from_snapshot(c, snap):
    eng = snap.get("engagement") or {}
    for k in ("views", "replies"):
        if eng.get(k) is not None:
            c[k] = eng[k]
    for k in ("author_followers", "posted_at", "op_replies_in_thread"):
        if snap.get(k) is not None:
            c[k] = snap[k]
    return c


def cmd_rank(a):
    surv = read_json(a.survivors)
    threads = {t.get("url"): t for t in read_json(a.threads).get("threads", [])}
    P = params_from({})
    now = now_utc()
    small, large = watchlist()
    known = authors_state().get("authors", {})
    cuts = []
    out = {"survivors": [], "lane": []}
    for key in ("survivors", "lane"):
        for c in surv.get(key, []):
            snap = threads.get(c.get("url"))
            if not snap:
                cuts.append({"url": c.get("url"), "reason": "thread_unreadable"})
                continue
            c = fill_from_snapshot(dict(c), snap)
            if key == "survivors" and (num(c.get("replies")) or 0) > P["capture"]["max_replies"]:
                cuts.append({"url": c.get("url"), "reason": "too_many_replies"})
                continue
            t = parse_ts(c.get("posted_at"))
            age = c.get("age_min_at_capture")
            if age is None:
                age = (now - t).total_seconds() / 60 if t else 0
            out[key].append(annotate(c, age, c.get("tier") or tier_of(num(c.get("author_followers")) or 0, P["tiers"]),
                                     P, small, known))
    out["survivors"].sort(key=rank_key)
    out["lane"].sort(key=lane_key(large))
    out["cuts"] = cuts
    write_json(a.out, out)
    update_authors(out["survivors"] + out["lane"], now)
    print(json.dumps({"survivors": len(out["survivors"]), "lane": len(out["lane"]), "cuts": cuts}))


# ---------- check-item -------------------------------------------------------------------------
def squash(s):
    return re.sub(r"\s+", " ", (s or "").replace("’", "'")).strip()


def quote_found(quote, thread):
    q = squash(quote)
    if not q:
        return False
    texts = [thread.get("opening_post")] + [r.get("text") for r in thread.get("top_replies") or []]
    return any(q in squash(t) for t in texts if t)


def hook_failures(draft, budget, sheet, rtype=""):
    hook = draft.get("hook")
    if not isinstance(hook, dict) or not hook.get("id"):
        return ["hook_missing"]
    hid = hook["id"]
    if hid in sheet["banned"]:
        return ["hook_banned"]
    if hid not in sheet["allowed"]:
        return ["hook_unknown"]
    out = []
    if hid in (budget.get("hooks_recent") or []):
        out.append("hook_recent")
    if rtype == "clean" and sheet.get("types", {}).get(hid) == "deep":
        out.append("hook_deep_on_clean")
    instr = (hook.get("instruction") or "").strip()
    ids = set(sheet["allowed"]) | set(sheet["banned"])
    if not instr or any(re.search(rf"\b{re.escape(i)}\b", instr) for i in ids):
        out.append("hook_instruction_missing")
    return out


def item_failures(target, draft, thread, budget, source_text):
    out = []
    yours = (draft.get("yours") or "").strip()
    if yours and not yours.endswith("?"):
        out.append("yours_not_question")
    rtype = (target.get("reply_type") or draft.get("reply_type") or "").lower()
    if rtype == "clean":
        zones = read_json(STATE / "authority_zones.json", {"zones": []}).get("zones", [])
        if target.get("zone") not in zones:
            out.append("outside_zones")
    if not quote_found(draft.get("answers"), thread):
        out.append("quote_not_verbatim")
    if (target.get("claim_origin") or "") == "public_source":
        if not (target.get("source_url") and target.get("source_quote") and target.get("basis")):
            out.append("source_missing")
        elif source_text is None or squash(target["source_quote"]) not in squash(source_text):
            out.append("source_quote_not_found")
    if rtype == "deep" and target.get("ground_with") in (budget.get("resting_entries") or []):
        out.append("entry_resting")
    if str(target.get("tier")) == "3" and target.get("move") not in LANE_MOVES:
        out.append("large_move")
    return out


def one(obj):
    if isinstance(obj, dict) and len(obj) == 1 and isinstance(next(iter(obj.values())), list):
        lst = next(iter(obj.values()))
        return lst[0] if lst else {}
    return obj


def cmd_check_item(a):
    target, draft, thread = one(read_json(a.target)), one(read_json(a.draft)), one(read_json(a.thread))
    budget = read_json(a.budget)
    source_text = Path(a.source_text).read_text() if a.source_text and Path(a.source_text).exists() else None
    sheet = load_hooks(a.patterns)
    rtype = (target.get("reply_type") or draft.get("reply_type") or "").lower()
    fails = hook_failures(draft, budget, sheet, rtype) + item_failures(target, draft, thread, budget, source_text)
    print(json.dumps({"url": draft.get("url") or target.get("url"), "ok": not fails, "reasons": fails}))
    if fails:
        print(fails[0], file=sys.stderr)
        sys.exit(1)


def cmd_authors(a):
    small, _ = watchlist()
    known = authors_state().get("authors", {})
    ranked = sorted(known.values(), key=lambda e: (-(e.get("answered_him") or 0),
                                                   -(e.get("op_replies_seen") or 0), e.get("last_seen") or ""))
    out = []
    for h in [e["author"] for e in ranked] + [e["handle"] for e in small.values()]:
        if h.lower() not in [x.lower() for x in out]:
            out.append(h)
    for h in out[:a.limit]:
        print(h)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("zones")
    p.add_argument("--voice")
    p.add_argument("--out", required=True)
    p = sub.add_parser("prefilter")
    for f in ("candidates", "budget", "out", "cuts"):
        p.add_argument("--" + f, required=True)
    p = sub.add_parser("rank")
    for f in ("survivors", "threads", "out"):
        p.add_argument("--" + f, required=True)
    p = sub.add_parser("hooks")
    p.add_argument("--patterns")
    p = sub.add_parser("check-item")
    for f in ("target", "draft", "thread", "budget"):
        p.add_argument("--" + f, required=True)
    p.add_argument("--source-text")
    p.add_argument("--patterns")
    p = sub.add_parser("authors")
    p.add_argument("--limit", type=int, default=20)
    a = ap.parse_args()
    {"zones": cmd_zones, "prefilter": cmd_prefilter, "rank": cmd_rank, "hooks": cmd_hooks,
     "check-item": cmd_check_item, "authors": cmd_authors}[a.cmd](a)


if __name__ == "__main__":
    main()
