#!/usr/bin/env python3
"""Acceptance tests for the reply pipeline v3.2 (task "Reply pipeline - v3.2 panel edit plan").

Each test class maps to one Definition-of-Done item. The tests drive the real scripts end to end
(slot_state.py budget -> produce.py -> email_replies.py, measure.py -> slot_state.py, preflight.sh)
the way a run does, instead of feeding each script a hand-made input.

Offline and isolated: PIPELINE_TEST=1, Mail/grok/agy/daily-log are the stubs in tests/stubs/,
every state, analytics and status path is a temp directory. Nothing touches runs/_index,
runs/_analytics, STATUS.md or a real mailbox. The live pattern sheet is only read.

Run: ACC_SKIP_GATEWAY=1 python3 tests/acceptance/test_v32_acceptance.py -v
With ACC_SKIP_GATEWAY unset, one extra test also runs bin/verify_v32.sh (about 40 s).
"""
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

C = Path(__file__).resolve().parents[2]
BIN = C / "bin"
FX = C / "tests" / "fixtures"
STUBS = C / "tests" / "stubs"
BASH = "/opt/homebrew/bin/bash" if Path("/opt/homebrew/bin/bash").exists() else "bash"
NOW = "2026-11-24T13:41:00Z"          # Tue 15:41 Israel -> slot 2026-11-24_1530
NOW_EVE = "2026-11-24T18:11:00Z"      # Tue 20:11 Israel -> slot 2026-11-24_2000
SLOT, SLOT_EVE = "2026-11-24_1530", "2026-11-24_2000"
ROOT = Path(tempfile.mkdtemp(prefix="v32_acceptance."))

SHEET = ROOT / "sheet.md"
SHEET.write_text("## Hooks\n\n" + "".join(f"### H{i} - Hook name {i}\n\nDescription.\n\n" for i in range(1, 9))
                 + "## Do not use\n\n- X1 - verdict opening\n- X2 - restating\n")
PARAMS = json.loads((C / "agents" / "params.json").read_text())
PARAMS["delivery"].update({"verify_wait_s": 3, "verify_poll_s": 1, "send_timeout_s": 3, "query_timeout_s": 1})
PARAMS_T = ROOT / "params_test.json"
PARAMS_T.write_text(json.dumps(dict(PARAMS, cost=dict(PARAMS["cost"], enforce_grok_caps=True))))
EMPTY_WL = ROOT / "wl_empty.json"
EMPTY_WL.write_text(json.dumps({"authors": [], "large": []}))
_n = [0]
LIVE = [C / "STATUS.md", C / "runs" / f"{'2026-11-24_1530'}_batch"] + [
    C / "runs" / "_index" / n for n in ("scheduler_log.jsonl", "delivered.jsonl", "delivery_state.json", "sent",
                                        "alarms.jsonl", "grok_calls.jsonl", ".run.lock")]


def live_snapshot():
    """What exists of the live state now (live runs write it, so tests compare instead of expecting nothing)."""
    out = {}
    for p in LIVE:
        files = [p] if p.is_file() else sorted(p.rglob("*")) if p.is_dir() else []
        out[str(p)] = [(str(f), f.stat().st_mtime_ns, f.stat().st_size) for f in files if f.is_file()] if p.exists() else None
    return out


LIVE_BEFORE = live_snapshot()


def utc(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def z(t):
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def wjson(p, obj):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=1))
    return p


def wjsonl(p, rows):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("".join(json.dumps(r) + "\n" for r in rows))
    return p


def fresh(**extra):
    """An isolated env: own state, analytics, status file and stub dir."""
    _n[0] += 1
    d = ROOT / f"env{_n[0]}"
    for sub in ("state", "analytics", "stub", "fetch"):
        (d / sub).mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith(("PIPELINE_", "STUB_"))}
    env.update({
        "PIPELINE_TEST": "1", "PIPELINE_NOW": NOW, "PIPELINE_PARAMS": str(PARAMS_T),
        "PIPELINE_STATE_DIR": str(d / "state"), "PIPELINE_ANALYTICS_DIR": str(d / "analytics"),
        "PIPELINE_STATUS_FILE": str(d / "STATUS.md"), "PIPELINE_PATTERNS": str(SHEET),
        "PIPELINE_WATCHLIST": str(EMPTY_WL), "PIPELINE_FETCH_DIR": str(d / "fetch"), "PIPELINE_RUNS_DIR": str(d / "runs"),
        "OSASCRIPT_BIN": str(STUBS / "osascript_stub.sh"), "GROK_BIN": str(STUBS / "cli_stub.sh"),
        "AGY_BIN": str(STUBS / "cli_stub.sh"), "PIPELINE_ALARM_BIN": str(STUBS / "cli_stub.sh"),
        "STUB_DIR": str(d / "stub"), "STUB_AGY_MODELS": "Gemini 4 Neon (High)",
        "PIPELINE_GIT_BRANCH": "main", "PIPELINE_GIT_DIRTY": "0", "_DIR": str(d),
    })
    env.update({k: str(v) for k, v in extra.items()})
    return env


def run(args, env, timeout=120):
    r = subprocess.run([str(a) for a in args], env=env, cwd=str(C), capture_output=True, text=True, timeout=timeout)
    return r.returncode, r.stdout, r.stderr


def py(script, *args, env):
    return run(["python3", BIN / script, *args], env)


def gate(*args, text=None):
    if text is not None:
        f = ROOT / f"draft{time.monotonic_ns()}.txt"
        f.write_text(text)
        args = (*args, f)
    return run([BASH, BIN / "gate.sh", *args], dict(os.environ))[0]


def state(env, **kv):
    p = Path(env["PIPELINE_STATE_DIR"]) / "delivery_state.json"
    cur = json.loads(p.read_text()) if p.exists() else {}
    cur.update(kv)
    wjson(p, cur)


def read_state(env):
    p = Path(env["PIPELINE_STATE_DIR"]) / "delivery_state.json"
    return json.loads(p.read_text()) if p.exists() else {}


def counts(env, per_day, base=dt.date(2026, 11, 24)):
    """posted_counts.json with `per_day` replies on each of the 7 days before `base`."""
    wjson(Path(env["PIPELINE_STATE_DIR"]) / "posted_counts.json",
          {"days": {(base - dt.timedelta(days=i)).isoformat(): per_day for i in range(1, 8)}})


def budget(env, *args):
    r = py("slot_state.py", "budget", *(args or ("--posted-today", "0")), env=env)
    assert r[0] == 0, f"budget failed rc={r[0]} {r[2]}"
    return json.loads(r[1])


def sends(env):
    p = Path(env["STUB_DIR"]) / "sends.count"
    return int(p.read_text()) if p.exists() else 0


def stub_count(env, name):
    p = Path(env["STUB_DIR"]) / name
    return int(p.read_text()) if p.exists() else 0


def slot_lines(env):
    p = Path(env["PIPELINE_STATE_DIR"]) / "scheduler_log.jsonl"
    return [json.loads(l) for l in p.read_text().splitlines()] if p.exists() else []


def item(author, **kw):
    return {"author": author, **kw}


def make_run(env, name, items, extra_results=()):
    """A batch folder with 01_anchored/02_drafts/03_review as the Matcher, Drafter and Critic leave them."""
    d = Path(env["_DIR"]) / "runs" / name
    targets, drafts, results = [], [], []
    for i, it in enumerate(items):
        u = it.get("url") or f"https://x.com/{it['author']}/status/{2000 + i}"
        t = {"url": u, "author": it["author"], "author_followers": it.get("followers", 5000), "tier": it.get("tier", 1),
             "reply_type": it.get("type", "clean"), "claim_origin": it.get("claim", "thread"),
             "ground_with": it.get("ground"), "zone": "AI tooling and workflows",
             "posted_at": it.get("posted_at", "2026-11-24T13:00:00Z"), "age_min_at_capture": 41,
             "parent_views_at_capture": it.get("views", 3000 + i), "rank": i}
        for k in ("source_url", "source_quote", "basis"):
            if k in it:
                t[k] = it[k]
        targets.append(t)
        dr = {"url": u, "answers": f"quoted line {i}", "point": f"angle {i}",
              "hook": {"id": it.get("hook", f"H{i + 1}"), "name": "x", "instruction": f"Open with detail {i}."},
              "draft": it.get("draft", f"Which step {i} did the {it['author']} run change first, the parser or the cache?"),
              "verify_flags": []}
        if it.get("yours"):
            dr["yours"] = it["yours"]
        drafts.append(dr)
        results.append({"url": u, "status": it.get("status", "passed"), "drop_reason": it.get("drop_reason")})
    results += list(extra_results)
    wjson(d / "01_anchored.json", {"batch": name, "targets": targets})
    wjson(d / "02_drafts.json", {"drafts": drafts})
    wjson(d / "03_review.json", {"results": results, "_calibration": {"result": "pass"}, "critic_model": "fixture"})
    return d


def pipeline(env, items, posted_today=("--posted-today", "0"), slot=SLOT, send=False, name=None, email_now=None):
    """budget -> produce -> email, exactly as runbook steps 2, 6 and 7 chain them."""
    b = budget(env, *posted_today)
    run_dir = make_run(env, name or f"{slot}_batch", items)
    bp = wjson(run_dir / "budget.json", b)
    rp = py("produce.py", run_dir, "--budget", bp, env=env)
    assert rp[0] == 0, f"produce failed {rp[2]}"
    md = (run_dir / "replies_to_post.md").read_text()
    args = [run_dir / "replies_to_post.md", "--slot", slot] + (["--send"] if send else [])
    rc, out, err = py("email_replies.py", *args, env=dict(env, PIPELINE_NOW=email_now) if email_now else env)
    html_p = run_dir / "email.html"
    html = html_p.read_text() if html_p.exists() and rc in (0, 4, 6) else ""
    return {"budget": b, "md": md, "rc": rc, "subject": out.strip().splitlines()[0] if out.strip() else "",
            "err": err, "html": html, "run_dir": run_dir}


def mailed(html):
    return html.count(">Open post<")


def badges(html, label):
    return len(re.findall(rf">{re.escape(label)}</span>", html))


def post_today_in_mail(html):
    m = re.search(r"Post today: (\d+)", html)
    return int(m.group(1)) if m else None


def pipeline_posts(env, days, start, views=50, parent_views=5000):
    """Reply-log rows: one posted pipeline reply on each of `days` consecutive days from `start`."""
    rows = [{"reply_url": f"https://x.com/ogrizkov/status/8{start.day}{i}", "arm": "pipeline", "reading": "24h",
             "posted_at": z(dt.datetime(start.year, start.month, start.day, 15, tzinfo=dt.timezone.utc) + dt.timedelta(days=i)),
             "views": views, "parent_views": parent_views} for i in range(days)]
    p = Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl"
    old = p.read_text() if p.exists() else ""
    p.write_text(old + "".join(json.dumps(r) + "\n" for r in rows))


def tripwire_rows(env, specs, start="2026-11-20T10:00:00Z", reading="24h", arm="pipeline"):
    rows = [{"reply_url": f"https://x.com/ogrizkov/status/6{i}{abs(hash(start)) % 1000}", "arm": arm, "reading": reading,
             "views": v, "parent_views": pv, "posted_at": z(utc(start) + dt.timedelta(hours=i))}
            for i, (v, pv) in enumerate(specs)]
    p = Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl"
    old = p.read_text() if p.exists() else ""
    p.write_text(old + "".join(json.dumps(r) + "\n" for r in rows))


# ============ DoD: Delivery and posting are separate =========================================
class DeliveryAndPostingSeparate(unittest.TestCase):

    def test_run_delivers_six_ranked_and_recommends_post_today_from_real_budget(self):
        env = fresh()
        r = pipeline(env, [item(f"au{i}", hook=f"H{i + 1}") for i in range(8)])
        self.assertEqual(r["rc"], 0, r["err"])
        self.assertEqual(r["budget"]["post_today"], 1)
        self.assertEqual(mailed(r["html"]), 6, "up to 6 passed items are delivered")
        self.assertEqual(post_today_in_mail(r["html"]), 1)
        self.assertEqual(badges(r["html"], "Post this"), 1)
        self.assertEqual(badges(r["html"], "For review"), 5)
        first = r["html"].find("/au0/status/")
        self.assertTrue(0 < first < r["html"].find("/au1/status/"), "the best-ranked item is the recommended one, first")

    def test_stage_two_with_a_high_average_recommends_two(self):
        env = fresh()
        state(env, stage=2)
        counts(env, 3)
        r = pipeline(env, [item(f"bu{i}", hook=f"H{i + 1}") for i in range(4)])
        self.assertEqual(r["budget"]["allowance_today"], 5)   # min(6, 3 + 2)
        self.assertEqual(r["budget"]["post_today"], 2)
        self.assertEqual(badges(r["html"], "Post this"), 2)
        self.assertEqual(mailed(r["html"]), 4)

    def test_stage_three_allowance_is_the_smaller_of_stage_total_and_average_plus_two(self):
        for avg, want_allow, want_post in ((10, 10, 3), (3, 5, 3), (0, 2, 2)):
            with self.subTest(avg=avg):
                env = fresh()
                state(env, stage=3)
                counts(env, avg)
                b = budget(env)
                self.assertEqual((b["allowance_today"], b["post_today"]), (want_allow, want_post))
                self.assertEqual(b["deliver_cap"], 6)

    def test_no_posting_room_still_delivers_everything_for_review(self):
        env = fresh()
        r = pipeline(env, [item(f"cu{i}", hook=f"H{i + 1}") for i in range(3)], posted_today=("--posted-today", "4"))
        self.assertEqual(r["budget"]["post_today"], 0)
        self.assertEqual(r["rc"], 0)
        self.assertEqual(mailed(r["html"]), 3)
        self.assertEqual(badges(r["html"], "Post this"), 0)
        self.assertIn("Post today: 0", r["html"])
        self.assertIn("you already posted 4 replies today", r["html"])

    def test_mail_post_today_matches_the_number_of_recommended_items(self):
        """'post today: N' with the top N marked recommended: the line must not promise more than is marked."""
        env = fresh()
        state(env, stage=2)
        counts(env, 3)
        r = pipeline(env, [item("solo", hook="H1")])
        self.assertEqual(r["budget"]["post_today"], 2)
        self.assertEqual(mailed(r["html"]), 1)
        self.assertEqual(post_today_in_mail(r["html"]), badges(r["html"], "Post this"),
                         "mail says 'Post today: N' but marks a different number of items recommended")
        self.assertIn("only 1 item passed", r["html"], "the mail does not say why fewer items are recommended")

    def test_stage_does_not_open_by_the_calendar(self):
        env = fresh()
        state(env, stage=1, stage_set_at="2026-10-01T10:00:00Z")
        b = budget(env)
        self.assertEqual(b["stage"], 1)
        self.assertFalse(b["stage_ready"])
        self.assertEqual(py("slot_state.py", "set-stage", "2", "--reason", "54 days passed", env=env)[0], 1)

    def test_many_posts_on_few_days_do_not_open_stage_two(self):
        env = fresh()
        rows = [{"reply_url": f"https://x.com/ogrizkov/status/44{i}", "arm": "pipeline", "reading": "24h",
                 "posted_at": z(utc("2026-11-10T12:00:00Z") + dt.timedelta(days=i % 3, minutes=i)), "views": 40,
                 "parent_views": 5000} for i in range(12)]
        wjsonl(Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", rows)
        self.assertEqual(py("slot_state.py", "set-stage", "2", "--reason", "x", env=env)[0], 1)

    def test_stage_two_can_open_again_after_a_tripwire_restart(self):
        """The tripwire restarts at stage 1; 7 new posting days with no new tripwire must open stage 2 again."""
        env = fresh(PIPELINE_NOW="2026-11-01T10:00:00Z")
        self.assertEqual(py("slot_state.py", "pause", "--days", "7", "--reason", "tripwire", env=env)[0], 0)
        env2 = dict(env, PIPELINE_NOW=NOW)
        pipeline_posts(env2, 7, dt.date(2026, 11, 10))
        rc, out, err = py("slot_state.py", "set-stage", "2", "--reason", "seven posting days after the restart", env=env2)
        self.assertEqual(rc, 0, f"set-stage 2 refused after a restart: {err.strip()}")

    def test_posting_days_before_a_tripwire_do_not_open_stage_two(self):
        env = fresh(PIPELINE_NOW="2026-11-20T10:00:00Z")
        pipeline_posts(env, 7, dt.date(2026, 11, 10))
        self.assertEqual(py("slot_state.py", "pause", "--days", "7", "--reason", "tripwire", env=env)[0], 0)
        self.assertEqual(py("slot_state.py", "set-stage", "2", "--reason", "x", env=dict(env, PIPELINE_NOW=NOW))[0], 1)

    def test_posting_days_during_the_tripwire_pause_do_not_count_for_stage_two(self):
        """Intended rule: the 7 posting days of the restarted stage 1 are counted only after the pause ends."""
        env = fresh(PIPELINE_NOW="2026-11-01T10:00:00Z")
        py("slot_state.py", "pause", "--days", "7", "--reason", "tripwire", env=env)
        self.assertEqual(read_state(env)["paused_until"], "2026-11-08")
        pipeline_posts(env, 6, dt.date(2026, 11, 2))     # 2-7 Nov, inside the pause
        pipeline_posts(env, 1, dt.date(2026, 11, 10))    # one day after it
        rc, _, err = py("slot_state.py", "set-stage", "2", "--reason", "x", env=dict(env, PIPELINE_NOW=NOW))
        self.assertEqual(rc, 1, "set-stage 2 accepted with 6 of its 7 posting days inside the tripwire pause")

    def test_post_short_is_empty_when_the_recommendation_is_met(self):
        for posted, items in ((("--posted-today", "0"), [item("m1", hook="H1"), item("m2", hook="H2")]),
                              (("--posted-today", "4"), [item("m3", hook="H1")])):
            with self.subTest(posted=posted):
                r = pipeline(fresh(), items, posted_today=posted)
                self.assertRegex(r["md"], r"(?m)^post_short: *$")
                self.assertNotRegex(r["html"], r"Post today: [1-9]\d* \(", "no shortfall reason when the recommendation is met")

    def test_post_short_says_why_when_the_author_rule_blocks_a_second_mark(self):
        env = fresh()
        state(env, stage=2)
        counts(env, 3)
        r = pipeline(env, [item("same", hook="H1"), item("same", hook="H2", url="https://x.com/same/status/99")])
        self.assertEqual(r["budget"]["post_today"], 2)
        self.assertRegex(r["md"], r"(?m)^post_today: 1$")
        self.assertRegex(r["md"], r"(?m)^post_short: .*one per author a day")
        self.assertEqual((post_today_in_mail(r["html"]), badges(r["html"], "Post this")), (1, 1))
        self.assertRegex(r["html"], r"Post today: 1 \(only 1 of 2 passed items can be recommended: one per author a day\)<")

    def test_one_recommended_reply_per_author_per_day_across_mails(self):
        env = fresh()
        r1 = pipeline(env, [item("alice", hook="H1"), item("bob", hook="H2")])
        self.assertIn("/alice/", r1["html"][:r1["html"].find("For review")])
        self.assertEqual(py("slot_state.py", "record", "--slot", SLOT, "--replies", r1["run_dir"] / "replies_to_post.md", env=env)[0], 0)
        env_eve = dict(env, PIPELINE_NOW=NOW_EVE)
        r2 = pipeline(env_eve, [item("alice", hook="H3", url="https://x.com/alice/status/777"), item("carol", hook="H4")],
                      slot=SLOT_EVE, name=f"{SLOT_EVE}_batch")
        self.assertIn("alice", r2["budget"]["recommended_today"]["authors"])
        marks = dict(re.findall(r"^### \d+\. https://x\.com/(\w+)/status/\d+\n(?:- (?!mark).*\n)*- mark: (\w+)", r2["md"], re.M))
        self.assertEqual(marks, {"carol": "recommended", "alice": "review"})

    def test_stage_change_is_shown_in_the_next_mail_once(self):
        env = fresh()
        pipeline_posts(env, 7, dt.date(2026, 11, 10))
        self.assertEqual(py("slot_state.py", "set-stage", "2", "--reason", "posted on 7 days", env=env)[0], 0)
        r1 = pipeline(env, [item("dan", hook="H1")])
        self.assertIn("Stage 2 from today: posted on 7 days", r1["html"])
        py("slot_state.py", "record", "--slot", SLOT, "--replies", r1["run_dir"] / "replies_to_post.md", env=env)
        r2 = pipeline(dict(env, PIPELINE_NOW=NOW_EVE), [item("erin", hook="H2")], slot=SLOT_EVE, name=f"{SLOT_EVE}_batch")
        self.assertNotIn("Stage 2 from today", r2["html"])


# ============ DoD: Targets and the large-account lane ======================================
class LargeAccountLane(unittest.TestCase):

    def prefilter(self, env, cands, watchlist=None):
        if watchlist:
            env["PIPELINE_WATCHLIST"] = str(wjson(Path(env["_DIR"]) / "wl.json", watchlist))
        now = utc(env["PIPELINE_NOW"])
        full = []
        for c in cands:
            full.append({"url": f"https://x.com/{c['author']}/status/{abs(hash(c['author'])) % 10**9}", "lang": "en",
                         "post_type": "discussion", "views": c.get("views", 500), "replies": c.get("replies", 10),
                         "author": c["author"], "author_followers": c["followers"],
                         "posted_at": z(now - dt.timedelta(minutes=c["age"]))})
        d = Path(env["_DIR"])
        bp = wjson(d / "budget.json", budget(env))
        wjson(d / "cands.json", {"candidates": full})
        r = py("target_filter.py", "prefilter", "--candidates", d / "cands.json", "--budget", bp,
               "--out", d / "surv.json", "--cuts", d / "cuts.json", env=env)
        self.assertEqual(r[0], 0, r[2])
        surv = json.loads((d / "surv.json").read_text())
        cuts = {c["url"].split("/")[3]: c["reason"] for c in json.loads((d / "cuts.json").read_text())["cuts"]}
        return surv, cuts

    def test_lane_boundary_at_125k_and_60_minutes(self):
        surv, cuts = self.prefilter(fresh(), [
            {"author": "at125k", "followers": 125000, "age": 70}, {"author": "over125k", "followers": 125001, "age": 70},
            {"author": "lab59", "followers": 300000, "age": 59, "replies": 900}])
        tiers = {c["author"]: c["tier"] for c in surv["survivors"] + surv["lane"]}
        self.assertEqual(tiers.get("at125k"), 2, "125,000 followers is tier 2, not the lane")
        self.assertEqual(cuts.get("over125k"), "large_too_old")
        self.assertEqual([c["author"] for c in surv["lane"]], ["lab59"])

    def test_lane_ranks_labs_and_builders_first(self):
        wl = {"authors": [], "large": [
            {"handle": "labx", "followers": 900000, "evidence": "lab", "source": "x", "added": "2026-11-23"},
            {"handle": "othery", "followers": 400000, "evidence": "other", "source": "x", "added": "2026-11-23"}]}
        surv, _ = self.prefilter(fresh(), [{"author": "othery", "followers": 400000, "age": 10},
                                           {"author": "labx", "followers": 900000, "age": 50}], watchlist=wl)
        self.assertEqual([c["author"] for c in surv["lane"]], ["labx", "othery"])

    def test_at_most_two_lane_items_delivered_and_flagged(self):
        env = fresh()
        r = pipeline(env, [item(f"lab{i}", tier=3, followers=900000, hook=f"H{i + 1}") for i in range(3)]
                     + [item("small", hook="H5")])
        self.assertEqual(r["rc"], 0)
        self.assertEqual(mailed(r["html"]), 3)
        self.assertEqual(badges(r["html"], "Large account"), 2)

    def test_at_most_one_lane_item_recommended_in_a_mail(self):
        env = fresh()
        state(env, stage=2)
        counts(env, 3)
        r = pipeline(env, [item("lab1", tier=3, followers=900000, hook="H1"),
                           item("lab2", tier=3, followers=800000, hook="H2"), item("small", hook="H3")])
        self.assertEqual(r["budget"]["post_today"], 2)
        rec = r["md"].split("## Skipped")[0]
        lane_rec = re.findall(r"- mark: recommended\n- lane: large", rec)
        self.assertEqual(len(lane_rec), 1)

    def test_lane_place_used_by_an_earlier_mail_today_makes_the_next_lane_item_review(self):
        env = fresh()
        r1 = pipeline(env, [item("lab1", tier=3, followers=900000, hook="H1"), item("s1", hook="H2")])
        self.assertIn("- mark: recommended\n- lane: large", r1["md"])
        py("slot_state.py", "record", "--slot", SLOT, "--replies", r1["run_dir"] / "replies_to_post.md", env=env)
        r2 = pipeline(dict(env, PIPELINE_NOW=NOW_EVE), [item("lab2", tier=3, followers=900000, hook="H3"), item("s2", hook="H4")],
                      slot=SLOT_EVE, name=f"{SLOT_EVE}_batch")
        self.assertEqual(r2["budget"]["recommended_today"]["large"], 1)
        self.assertNotIn("- mark: recommended\n- lane: large", r2["md"])
        self.assertIn("- mark: review\n- lane: large", r2["md"])

    def test_lane_starter_limit_is_25_words(self):
        w25 = " ".join(["word"] * 24 + ["end."])
        self.assertEqual(gate("--max-words", "25", text=w25), 0)
        self.assertEqual(gate("--max-words", "25", text=w25 + " more"), 1)


# ============ DoD: Hooks =====================================================================
class Hooks(unittest.TestCase):

    def check_item(self, draft_over=None, sheet=None, drop_keys=()):
        env = fresh()
        if sheet:
            env["PIPELINE_PATTERNS"] = str(sheet)
        d = Path(env["_DIR"])
        wjson(Path(env["PIPELINE_STATE_DIR"]) / "authority_zones.json", {"zones": ["AI tooling and workflows"]})
        thread = wjson(d / "thread.json", {"url": "https://x.com/a/status/1", "opening_post": "We set auto-compact to 400k and it held.",
                                           "top_replies": []})
        target = wjson(d / "target.json", {"url": "https://x.com/a/status/1", "reply_type": "clean", "claim_origin": "thread",
                                           "zone": "AI tooling and workflows", "tier": 1, "move": "practitioner_question"})
        draft = {"url": "https://x.com/a/status/1", "answers": "set auto-compact to 400k",
                 "hook": {"id": "H1", "name": "x", "instruction": "Ask about the 400k setting itself."},
                 "draft": "Does the 400k cap keep the reasons or only the plan?"}
        draft.update(draft_over or {})
        for k in drop_keys:
            draft.pop(k, None)
        bp = wjson(d / "b.json", {"hooks_recent": [], "resting_entries": []})
        r = py("target_filter.py", "check-item", "--target", target, "--draft", wjson(d / "draft.json", draft),
               "--thread", thread, "--budget", bp, env=env)
        reasons = json.loads(r[1])["reasons"] if r[1].strip().startswith("{") else [r[2].strip()]
        return r[0], reasons

    def test_live_pattern_sheet_parses_to_h1_h7_allowed_and_x1_x7_banned(self):
        env = fresh()
        r = py("target_filter.py", "hooks", "--patterns", C / "reply_patterns.md", env=env)
        self.assertEqual(r[0], 0, r[2])
        sheet = json.loads(r[1])
        self.assertEqual(sorted(sheet["allowed"]), [f"H{i}" for i in range(1, 8)])
        self.assertEqual(sheet["banned"], [f"X{i}" for i in range(1, 8)])

    def test_every_do_not_use_hook_of_the_live_sheet_is_rejected(self):
        for i in range(1, 8):
            with self.subTest(hook=f"X{i}"):
                rc, why = self.check_item({"hook": {"id": f"X{i}", "name": "x", "instruction": "Open plainly."}},
                                          sheet=C / "reply_patterns.md")
                self.assertEqual((rc, why[0]), (1, "hook_banned"))

    def test_every_allowed_hook_of_the_live_sheet_passes(self):
        """On this Clean item every allowed hook passes except H4, whose sheet type is Deep (validator 2026-11-24)."""
        for i in range(1, 8):
            with self.subTest(hook=f"H{i}"):
                rc, why = self.check_item({"hook": {"id": f"H{i}", "name": "x", "instruction": "Open plainly."}},
                                          sheet=C / "reply_patterns.md")
                self.assertEqual((rc, why), (1, ["hook_deep_on_clean"]) if i == 4 else (0, []))

    def test_a_draft_with_no_hook_key_is_rejected(self):
        self.assertEqual(self.check_item(drop_keys=("hook",)), (1, ["hook_missing"]))

    def test_a_hook_id_in_the_instruction_line_is_rejected(self):
        rc, why = self.check_item({"hook": {"id": "H1", "name": "x", "instruction": "Use H1: ask about the setting."}})
        self.assertEqual((rc, why), (1, ["hook_instruction_missing"]))

    def test_a_banned_id_listed_as_a_hook_heading_too_stays_banned(self):
        sheet = ROOT / "sheet_conflict.md"
        sheet.write_text("## Hooks\n\n### H1 - Question\n\n### X1 - Verdict opening\n\n## Do not use\n\n- X1 - verdict\n")
        rc, why = self.check_item({"hook": {"id": "X1", "name": "x", "instruction": "Open plainly."}}, sheet=sheet)
        self.assertEqual((rc, why[0]), (1, "hook_banned"))

    def test_an_item_with_an_empty_open_line_is_not_mailed(self):
        env = fresh()
        md = (FX / "replies_mode_b.md").read_text().replace("- OPEN: Ask one question about the 400k setting itself.", "- OPEN: ")
        p = Path(env["_DIR"]) / "b" / "replies_to_post.md"
        p.parent.mkdir(parents=True)
        p.write_text(md)
        self.assertEqual(py("email_replies.py", p, "--slot", SLOT, env=env)[0], 0)
        self.assertEqual(mailed((p.parent / "email.html").read_text()), 1)

    def test_a_hook_is_used_once_per_mail_end_to_end(self):
        env = fresh()
        r = pipeline(env, [item("h1", hook="H1"), item("h2", hook="H1"), item("h3", hook="H2")])
        self.assertEqual(mailed(r["html"]), 2)
        self.assertNotIn("/h2/status/", r["html"])


# ============ DoD: Reliability - verified delivery (I-9) and preflight ======================
class VerifiedDelivery(unittest.TestCase):
    SUBJ = "2 Twitter replies to write (2026-11-24 15:30) #5dec"

    def send(self, env, src=FX / "replies_mode_b.md", slot=SLOT):
        return py("email_replies.py", src, "--slot", slot, "--send", env=env)

    def marker(self, env, slot=SLOT):
        return (Path(env["PIPELINE_STATE_DIR"]) / "sent" / slot).exists()

    def test_a_message_already_stuck_in_drafts_is_not_sent_again_and_fails(self):
        env = fresh()
        (Path(env["STUB_DIR"]) / "mail_drafts").write_text(self.SUBJ + "\n")
        rc, _, err = self.send(env)
        self.assertEqual((rc, sends(env), self.marker(env)), (4, 0, False))
        self.assertIn("stuck_draft", err)

    def test_a_message_already_in_the_outbox_is_not_sent_again_and_fails(self):
        env = fresh()
        (Path(env["STUB_DIR"]) / "mail_outbox").write_text(self.SUBJ + "\n")
        rc, _, err = self.send(env)
        self.assertEqual((rc, sends(env), self.marker(env)), (4, 0, False))
        self.assertIn("stuck_outbox", err)

    def test_a_stuck_send_fails_within_the_bounded_wait(self):
        env = fresh(STUB_MAIL_MODE="stuck")
        t0 = time.monotonic()
        rc, _, _ = self.send(env)
        self.assertEqual(rc, 4)
        self.assertLess(time.monotonic() - t0, PARAMS["delivery"]["verify_wait_s"] + 6)
        self.assertFalse(self.marker(env))

    def test_a_retry_after_a_failed_delivery_is_allowed_and_counts_once_verified(self):
        env = fresh(STUB_MAIL_MODE="stuck")
        self.assertEqual(self.send(env)[0], 4)
        for box in ("mail_outbox", "mail_drafts"):
            (Path(env["STUB_DIR"]) / box).write_text("")
        env["STUB_MAIL_MODE"] = "deliver"
        self.assertEqual(self.send(env)[0], 0)
        self.assertTrue(self.marker(env))
        self.assertEqual(sends(env), 2)

    def test_a_mail_error_is_exit_4_send_error_without_marker(self):
        env = fresh(STUB_MAIL_MODE="error")
        rc, _, err = self.send(env)
        self.assertEqual(rc, 4)
        self.assertTrue(err.startswith("send_error"), err)
        self.assertFalse(self.marker(env))

    def test_a_second_send_for_a_slot_is_refused_even_with_another_file(self):
        env = fresh()
        self.assertEqual(self.send(env)[0], 0)
        other = Path(env["_DIR"]) / "a2" / "replies_to_post.md"
        other.parent.mkdir(parents=True)
        shutil.copy(FX / "replies_trial.md", other)
        self.assertEqual(self.send(env, src=other)[0], 6)
        self.assertEqual(sends(env), 1)

    def test_nothing_is_mailed_when_nothing_passes(self):
        env = fresh()
        r = pipeline(env, [item("x1", status="dropped", drop_reason="forced_anchor"),
                           item("x2", status="quarantined")], send=True)
        self.assertEqual(r["rc"], 3)
        self.assertEqual(sends(env), 0)
        self.assertFalse(self.marker(env))
        py("slot_state.py", "log", "--slot", SLOT, "--reason", "no_pass", env=env)
        status = Path(env["PIPELINE_STATUS_FILE"]).read_text()
        self.assertIn(f"| {SLOT} | no_pass |", status)

    def test_skipped_and_quarantined_sections_are_never_mailed_in_either_order(self):
        env = fresh()
        md = (FX / "replies_mode_b.md").read_text()
        head, rest = md.split("### 1.", 1)
        items = "### 1." + rest.split("---\n\n## Skipped")[0]
        flipped = head + "## Quarantined\n\n" + items + "\n## Skipped\n\n- none\n"
        p = Path(env["_DIR"]) / "q" / "replies_to_post.md"
        p.parent.mkdir(parents=True)
        p.write_text(flipped)
        self.assertEqual(self.send(env, src=p)[0], 3)
        self.assertEqual(sends(env), 0)

    def test_over_cap_items_produced_into_skipped_are_not_mailed(self):
        env = fresh()
        r = pipeline(env, [item(f"oc{i}", hook=f"H{i + 1}") for i in range(8)], send=True)
        self.assertEqual(r["rc"], 0)
        self.assertEqual(mailed(r["html"]), 6)
        for name in ("oc6", "oc7"):
            self.assertIn(f"/{name}/status/", r["md"].split("## Skipped")[1])
            self.assertNotIn(f"/{name}/status/", r["html"])
        self.assertEqual(sends(env), 1)


class Preflight(unittest.TestCase):

    def pf(self, env, *a):
        return run([BASH, BIN / "preflight.sh", *a], env)

    def test_a_non_pipeline_draft_does_not_block_the_run(self):
        env = fresh()
        (Path(env["STUB_DIR"]) / "mail_drafts").write_text("Notes to self\n")
        self.assertEqual(self.pf(env)[0], 0)

    def test_mail_automation_not_answering_stops_with_9_and_is_counted(self):
        env = fresh(STUB_MAIL_DEAD="1")
        self.assertEqual(self.pf(env)[0], 9)
        self.assertEqual(slot_lines(env)[-1]["reason"], "preflight_failed")


# ============ DoD: grok use ==================================================================
class GrokUse(unittest.TestCase):

    def pf(self, env):
        return run([BASH, BIN / "preflight.sh"], env)

    def test_grok_budget_is_three_calls_per_run(self):
        b = budget(fresh())
        self.assertEqual(b["caps"]["max_grok_calls"], 3)
        self.assertEqual(b["caps"]["maintenance_grok_calls"], 2)

    def test_dead_grok_has_its_own_exit_and_spends_one_call(self):
        env = fresh(STUB_GROK="dead")
        rc, _, _ = self.pf(env)
        self.assertEqual(rc, 7)
        self.assertEqual(stub_count(env, "grok.count"), 1)
        line = slot_lines(env)[-1]
        self.assertEqual((line["reason"], line["grok_ok"], line["grok_calls"]), ("infra", False, 1))

    def test_balance_exhausted_is_exit_11_not_the_dead_exit(self):
        env = fresh(STUB_GROK="balance")
        rc, out, err = self.pf(env)
        self.assertEqual(rc, 11)
        self.assertEqual(stub_count(env, "grok.count"), 1)
        self.assertIn("grok balance exhausted", out + err)

    def test_two_balance_stops_raise_an_alarm_line_in_the_daily_log_and_no_mail(self):
        env = fresh(STUB_GROK="balance")
        self.assertEqual(self.pf(env)[0], 11)
        self.assertEqual(run([BASH, BIN / "preflight.sh"], dict(env, PIPELINE_NOW=NOW_EVE))[0], 11)
        reasons = [l["reason"] for l in slot_lines(env)]
        self.assertEqual(reasons, ["grok_balance", "grok_balance"])
        h = json.loads(py("slot_state.py", "health", env=dict(env, PIPELINE_NOW=NOW_EVE))[1])
        self.assertEqual(h["non_delivered_in_window"].get("grok_balance"), 2)
        alarm = (Path(env["STUB_DIR"]) / "alarm_args.log").read_text()
        self.assertRegex(alarm, r"--entry ALARM reply pipeline 20:11: .*grok balance")
        self.assertEqual(sends(env), 0)


# ============ DoD: Tripwire ==================================================================
class Tripwire(unittest.TestCase):

    def trip(self, env):
        r = py("measure.py", "tripwire", env=env)
        self.assertEqual(r[0], 0, r[2])
        return json.loads(r[1])["tripped"]

    def test_tripwire_sets_post_today_zero_and_the_mail_still_delivers_for_review(self):
        env = fresh()
        state(env, stage=2)
        tripwire_rows(env, [(3, 5000), (5, 5000), (8, 5000), (2, 5000), (7, 5000)])
        self.assertTrue(self.trip(env))
        r = pipeline(env, [item(f"tw{i}", hook=f"H{i + 1}") for i in range(3)], send=True)
        self.assertEqual((r["budget"]["stage"], r["budget"]["post_today"], r["budget"]["deliver_cap"]), (1, 0, 6))
        self.assertEqual(r["rc"], 0)
        self.assertEqual(mailed(r["html"]), 3)
        self.assertEqual(badges(r["html"], "Post this"), 0)
        self.assertEqual(badges(r["html"], "For review"), 3)
        self.assertIn("Post today: 0, tripwire: the last 5 posted replies had 8 views or fewer at 24 hours; back on 2026-12-01", r["html"])
        self.assertEqual(sends(env), 1)

    def test_tripwire_alarm_goes_to_the_daily_log_never_mail(self):
        env = fresh()
        tripwire_rows(env, [(1, 5000)] * 5)
        self.assertTrue(self.trip(env))
        self.assertIn("tripwire", (Path(env["STUB_DIR"]) / "alarm_args.log").read_text())
        self.assertEqual(sends(env), 0)

    def test_low_replies_under_small_parents_are_ignored_not_counted(self):
        env = fresh()
        specs = [(3, 5000), (900, 800), (5, 5000), (4, 1500), (8, 5000), (2, 5000), (950, 300), (7, 5000)]
        tripwire_rows(env, specs)
        self.assertTrue(self.trip(env), "replies under parents of 2,000 views or fewer neither count nor break the run")

    def test_a_parent_of_exactly_2000_views_does_not_count(self):
        env = fresh()
        tripwire_rows(env, [(3, 2000)] * 5)
        self.assertFalse(self.trip(env))

    def test_only_24_hour_readings_count(self):
        env = fresh()
        tripwire_rows(env, [(3, 5000)] * 5, reading="48h")
        self.assertFalse(self.trip(env))

    def test_follow_up_replies_do_not_count(self):
        env = fresh()
        tripwire_rows(env, [(3, 5000)] * 5, arm="follow_up")
        self.assertFalse(self.trip(env))

    def test_the_same_five_replies_do_not_trip_again_after_the_pause(self):
        env = fresh()
        tripwire_rows(env, [(3, 5000)] * 5)
        self.assertTrue(self.trip(env))
        later = dict(env, PIPELINE_NOW="2026-12-02T13:41:00Z")
        self.assertFalse(self.trip(later))
        self.assertGreater(budget(later)["post_today"], 0)

    def test_merged_24h_readings_feed_the_tripwire(self):
        env = fresh(PIPELINE_NOW="2026-11-25T15:00:00Z")
        base = utc("2026-11-24T13:00:00Z")
        led = [{"item_id": f"{SLOT}#{i + 1}", "slot_id": SLOT, "url": f"https://x.com/m{i}/status/{900 + i}", "author": f"m{i}",
                "tier": 1, "recommended": True, "reply_type": "clean", "hook": "H1", "starter": "Which cap did you use?",
                "posted_at": z(base - dt.timedelta(minutes=30)), "delivered_at": z(base), "mode": "trial"} for i in range(5)]
        wjsonl(Path(env["PIPELINE_STATE_DIR"]) / "delivered.jsonl", led)
        pages = [{"parent_url": led[i]["url"], "found": True, "reply_url": f"https://x.com/ogrizkov/status/55{i}",
                  "text": "Which cap held for you on long runs?", "posted_at": z(base + dt.timedelta(minutes=20 + i)),
                  "views": 4, "likes": 0, "replies": 0, "parent_views": 12000, "author_answered": False, "reading": "24h"}
                 for i in range(5)]
        self.assertEqual(py("measure.py", "merge", "--pages", wjson(Path(env["_DIR"]) / "pages.json", pages), env=env)[0], 0)
        self.assertTrue(self.trip(env))


# ============ DoD: Gate ======================================================================
class Gate(unittest.TestCase):

    def test_agreement_only_openers_are_rejected(self):
        for t in ("Exactly, this is how teams should work.", "So true, this is what nobody says out loud.",
                  "Well said, the whole thread is gold for builders.", "Spot on, nothing more to add here really.",
                  "You're right, this is how it works for most teams.", "100% this, every team should read the thread.",
                  "Couldn't agree more with every word in this post.", "EXACTLY this, the whole thread in one line.",
                  "Great point, the thread nails it for small teams."):
            with self.subTest(t=t):
                self.assertEqual(gate(text=t), 1)

    def test_agreement_that_adds_a_turn_passes(self):
        self.assertEqual(gate(text="Agreed, but the cap breaks once the plan spans two sessions."), 0)

    def test_over_40_words_fails_and_40_passes(self):
        w40 = " ".join(["step"] * 39 + ["done."])
        self.assertEqual(gate(text=w40), 0)
        self.assertEqual(gate(text=w40 + " extra"), 1)

    def test_links_and_hashtags_are_rejected_but_a_number_sign_is_not(self):
        for t in ("See http://example.com for the cap setting there", "See https://docs.x.ai for the cap setting",
                  "See www.example.com for the cap setting there", "The cap setting matters more than people think #evals"):
            with self.subTest(t=t):
                self.assertEqual(gate(text=t), 1)
        self.assertEqual(gate(text="The #1 cause was the cap setting, not the model."), 0)

    def test_stacked_agreement_fails_but_a_real_so_turn_passes(self):
        self.assertEqual(gate(text="Totally agree, so true, this nails it for teams."), 1)
        self.assertEqual(gate(text="Agreed, so the cap has to move before the plan grows."), 0)

    def test_agreement_opener_with_a_measured_number_passes(self):
        """A1: agreement only means no digit, no '?' and no turn word; a 100% measurement is a digit."""
        self.assertEqual(gate(text="Agreed, 100% of the long runs hit the same cap."), 0)

    def test_bare_domains_fail_as_links(self):
        for t in ("The thread at x.com/karpathy/status/1 says the same thing", "The fix is in github.com/a/b under the cache module",
                  "The numbers are on docs.anthropic.com in the limits table", "See example.org for the full benchmark table"):
            with self.subTest(t=t):
                self.assertEqual(gate(text=t), 1)

    def test_ordinary_starters_are_not_taken_for_links(self):
        for t in ("Node.js held up until the 400k context, then the parser broke.", "Small models, e.g. Gemma, keep the plan longer?",
                  "Did v2.1.3 change the compaction step or only the cap?", "Our install.sh pins Python 3.12 for that reason.",
                  "Which line of claude.md made the agent stop at the cap?", "The package.json script runs before config.yaml loads.",
                  "That is 3.5x the cost, i.e. most of the U.S. budget.", "Loading libcudart.so failed after the driver update last night.",
                  "Mail.app keeps the draft when the outgoing server is off."):
            with self.subTest(t=t):
                self.assertEqual(gate(text=t), 0)

    def test_semicolon_contraction_alone_passes_single_and_batch(self):
        self.assertEqual(gate(text="Caps aren;t the only way, weight credits by backend, 1x versus 25x."), 0)
        f = ROOT / "batch_one_semi.md"
        f.write_text("- DRAFT: Caps aren;t the only lever, credits by backend matter at 25x.\n"
                     "- DRAFT: Which parser did the 400k run break first, JSON or YAML?\n"
                     "- DRAFT: Our nightly job fell over at 3 retries when the queue doubled overnight.\n")
        self.assertEqual(gate("--batch", f), 0)

    def test_clean_starters_with_implied_experience_are_rejected(self):
        for t in ("We tested this on 3 repos and it held.", "In our setup the 400k cap held fine.",
                  "I switched to the 200k cap after two weeks."):
            with self.subTest(t=t):
                self.assertEqual(gate("--type", "clean", text=t), 1)
        self.assertEqual(gate("--type", "clean", text="Does the 400k cap keep the reasons or only the plan?"), 0)

    def test_internal_label_is_whole_word(self):
        self.assertEqual(gate(text="The vault keeps every note of the 400k run."), 1)
        self.assertEqual(gate(text="The price vaulted past 20 dollars in a week."), 0)

    def test_restating_and_verdict_openings_are_judged_by_the_critic_rubric(self):
        """Not deterministic in gate.sh: rule 2 (restate) and tell (j) live in the Critic rubric and Drafter spec."""
        cr = (C / "agents" / "role_specs" / "critic.md").read_text()
        self.assertIn("FAIL if, with the replier's project nouns and numbers removed, the reply only restates the OP or a top reply.", cr)
        self.assertIn("(j) opens with a verdict on the post", cr)
        dr = (C / "agents" / "role_specs" / "drafter.md").read_text()
        self.assertRegex(dr, r"never opens with a verdict on the post \(X1\)")
        self.assertRegex(dr, r"never restates the post \(X2\)")


# ============ DoD: Timing, mode B, trial, operator inputs ===================================
class TimingModeBTrial(unittest.TestCase):

    def test_evening_slot_cutoff_and_post_by_inside_the_window(self):
        env = fresh(PIPELINE_NOW=NOW_EVE)
        b = budget(env)
        self.assertEqual((b["slot_id"], b["window"], b["send_cutoff"]), (SLOT_EVE, ["21:00", "23:00"], "20:55"))
        r = pipeline(env, [item("late", hook="H1", posted_at="2026-11-24T19:30:00Z")], slot=SLOT_EVE,
                     name=f"{SLOT_EVE}_batch", email_now="2026-11-24T20:00:00Z")   # mail built at 22:00 Israel
        self.assertIn("Post by 23:00 or skip", r["html"])

    def test_public_source_item_carries_source_link_and_basis(self):
        env = fresh()
        r = pipeline(env, [item("doc", hook="H1", claim="public_source", source_url="https://docs.example.com/compaction",
                                source_quote="Compaction keeps the last 20 turns.", basis="the vendor docs state the limit")])
        self.assertEqual(mailed(r["html"]), 1)
        self.assertIn("- SOURCE: https://docs.example.com/compaction", r["md"], "the source stays in the file")
        self.assertIn("- BASIS: the vendor docs state the limit", r["md"])
        for s in ("Source:", "Why it holds:", "docs.example.com"):
            self.assertNotIn(s, r["html"], "the mail carries the reply only (round 5)")

    def test_public_source_item_without_basis_is_not_mailed(self):
        env = fresh()
        r = pipeline(env, [item("doc", hook="H1", claim="public_source", source_url="https://docs.example.com/c",
                                source_quote="Compaction keeps the last 20 turns.")])
        self.assertEqual(r["rc"], 3)

    def test_mode_b_card_end_to_end(self):
        env = fresh()
        r = pipeline(env, [item("cardy", hook="H1", yours="Have you hit this cap on a long run?")])
        h = r["html"]
        for s in ("@cardy", "5,000 followers", "41 min old", "3,000 views", "Which step 0 did the cardy run change first",
                  "Post by ", ">Open post<", "Post this", "If the author answers, reply once the same day.",
                  "Feedback: reply with the item number"):
            self.assertIn(s, h)
        for s in ("They wrote:", "quoted line 0", "Angle:", "angle 0", "How to open:", "Open with detail 0.",
                  "Starter", "Yours?", "Have you hit this cap on a long run?", "Today in total:", "in your own words"):
            self.assertNotIn(s, h, "round 5: the mail carries the reply, not instructions")
        for s in ("- QUOTE: quoted line 0", "- POINT: angle 0", "- OPEN: Open with detail 0.", "- YOURS: Have you hit"):
            self.assertIn(s, r["md"], "the removed lines stay in replies_to_post.md for measurement")
        self.assertNotRegex(h, r"\bH\d\b", "no hook id appears in the mail")

    def test_trial_by_default_then_live_per_slot_after_pinned_post(self):
        env = fresh()
        r = pipeline(env, [item("t1", hook="H1")])
        self.assertTrue(r["subject"].startswith("[TRIAL] 1 Twitter reply ideas (2026-11-24 15:30)"), r["subject"])
        self.assertIn("TRIAL RUN.", r["html"])
        self.assertEqual(py("measure.py", "init", env=env)[0], 0)
        weekly = Path(env["PIPELINE_ANALYTICS_DIR"]) / "weekly.md"
        self.assertRegex(weekly.read_text(), r"(?m)^pinned_post_url: *$")
        self.assertIn("| week 0 |", weekly.read_text())
        self.assertEqual(py("slot_state.py", "set-mode", "--slot", "15:30", "live", env=env)[0], 1)
        weekly.write_text(weekly.read_text().replace("pinned_post_url: ", "pinned_post_url: https://x.com/ogrizkov/status/42"))
        self.assertEqual(py("slot_state.py", "set-mode", "--slot", "15:30", "live", env=env)[0], 0)
        r2 = pipeline(env, [item("t2", hook="H2")], name="live_batch")
        self.assertRegex(r2["subject"], r"^1 Twitter replies to write \(2026-11-24 15:30\) #[0-9a-f]{4}$")
        self.assertNotIn(">TRIAL<", r2["html"])
        self.assertEqual(budget(dict(env, PIPELINE_NOW=NOW_EVE))["mode"], "trial", "the 20:00 slot stays in trial")


# ============ Validator round (2026-11-24): fixes and their tests ============================
class MailStateUnknown(unittest.TestCase):
    """Critical 1 and Important 2: an unknown Mail state never sends; a hang is exit 4, no traceback."""

    def send(self, env):
        return py("email_replies.py", FX / "replies_mode_b.md", "--slot", SLOT, "--send", env=env)

    def marker(self, env):
        return (Path(env["PIPELINE_STATE_DIR"]) / "sent" / SLOT).exists()

    def test_query_fails_send_would_work_three_attempts_send_nothing(self):
        env = fresh(STUB_QUERY_MODE="error")
        for _ in range(3):
            rc, _, err = self.send(env)
            self.assertEqual(rc, 4)
            self.assertTrue(err.startswith("state_unknown"), err)
        self.assertEqual((sends(env), self.marker(env)), (0, False))

    def test_query_hang_before_the_send_is_exit_4_without_traceback(self):
        env = fresh(STUB_QUERY_MODE="hang", STUB_HANG_S="2")
        rc, _, err = self.send(env)
        self.assertEqual(rc, 4)
        self.assertNotIn("Traceback", err)
        self.assertTrue(err.startswith("state_unknown"), err)
        self.assertEqual(sends(env), 0)

    def test_state_lost_after_the_send_says_so_and_retries_never_send_blindly(self):
        env = fresh(STUB_QUERY_MODE="error_after_send")
        rc, _, err = self.send(env)
        self.assertEqual((rc, sends(env)), (4, 1))
        self.assertTrue(err.startswith("send_state_unknown"), err)
        rc2, _, err2 = self.send(env)
        self.assertEqual((rc2, sends(env)), (4, 1), "a retry with an unknown state must not send again")
        self.assertTrue(err2.startswith("state_unknown"), err2)
        env["STUB_QUERY_MODE"] = "ok"
        rc3, out3, _ = self.send(env)
        self.assertEqual((rc3, sends(env), self.marker(env)), (0, 1, True))
        self.assertIn("already in Sent", out3)

    def test_poll_hang_after_the_send_is_send_state_unknown_without_traceback(self):
        env = fresh(STUB_QUERY_MODE="hang_after_send", STUB_HANG_S="2")
        rc, _, err = self.send(env)
        self.assertEqual((rc, sends(env)), (4, 1))
        self.assertNotIn("Traceback", err)
        self.assertTrue(err.startswith("send_state_unknown"), err)

    def test_send_hang_is_send_state_unknown(self):
        env = fresh(STUB_MAIL_MODE="hang", STUB_HANG_S="5")
        rc, _, err = self.send(env)
        self.assertEqual(rc, 4)
        self.assertNotIn("Traceback", err)
        self.assertTrue(err.startswith("send_state_unknown"), err)
        self.assertFalse(self.marker(env))

    def test_verify_delivery_with_an_unknown_state_is_state_unknown(self):
        env = fresh(STUB_QUERY_MODE="error")
        rc, _, err = py("email_replies.py", "--verify-delivery", "--slot", SLOT, "--subject", "x", env=env)
        self.assertEqual(rc, 4)
        self.assertTrue(err.startswith("state_unknown"), err)

    def test_feedback_hang_is_exit_4_without_traceback(self):
        env = fresh(STUB_MAIL_MODE="deliver", STUB_FEEDBACK=str(FX / "feedback_reply.txt"))
        hang = Path(env["_DIR"]) / "hang_osa.sh"
        hang.write_text("#!/usr/bin/env bash\nsleep 2\n")
        hang.chmod(0o755)
        env2 = {k: v for k, v in env.items() if k != "PIPELINE_TEST"}
        env2["OSASCRIPT_BIN"] = str(hang)
        rc, _, err = py("email_replies.py", "--feedback", env=env2)
        self.assertEqual(rc, 4)
        self.assertNotIn("Traceback", err)

    def test_post_today_zero_with_no_reason_has_no_empty_brackets(self):
        env = fresh()
        md = (FX / "replies_mode_b.md").read_text().replace("post_today: 1", "post_today: 0").replace(
            "post_reason: stage 1: up to 1 per run, 2 pipeline items a day", "post_reason: ")
        f = Path(env["_DIR"]) / "noreason" / "replies_to_post.md"
        f.parent.mkdir(parents=True)
        f.write_text(md)
        self.assertEqual(py("email_replies.py", f, "--slot", SLOT, env=env)[0], 0)
        html = (f.parent / "email.html").read_text()
        self.assertIn(">Post today: 0<", html)
        self.assertNotIn("()", html)


DAY_CAP = PARAMS["cost"]["max_grok_calls_day"]


class GrokBudgetInCode(unittest.TestCase):
    """Important 3 and 4: the grok cap is kept in code, the probe counts, the day cap of params.json holds, a2 reuses candidates."""

    def spend_the_day(self, env):
        for i in range(DAY_CAP // 3):
            for _ in range(3):
                self.assertEqual(self.call(env, "discovery", slot=f"2026-11-24_{6 + i:02d}00")[0], 0)

    def call(self, env, purpose, slot=SLOT, batch=None):
        args = ["grok-call", "--slot", slot, "--purpose", purpose] + (["--batch", batch] if batch else [])
        return py("slot_state.py", *args, env=env)

    def test_budget_reports_calls_left_and_the_probe_counts_against_the_run(self):
        env = fresh()
        b = budget(env)
        self.assertEqual((b["grok_calls_left_run"], b["grok_calls_left_today"], b["grok_discovery_batch"]), (3, DAY_CAP, None))
        self.assertEqual(run([BASH, BIN / "preflight.sh"], env)[0], 0)
        self.assertEqual(stub_count(env, "grok.count"), 1, "a fresh state needs the probe")
        b = budget(env)
        self.assertEqual((b["grok_calls_left_run"], b["grok_calls_left_today"]), (2, DAY_CAP - 1))

    def test_a_fourth_run_call_is_refused_and_the_slot_log_says_so(self):
        env = fresh()
        for purpose in ("probe", "discovery", "discovery"):
            self.assertEqual(self.call(env, purpose, batch=f"{SLOT}_batch")[0], 0)
        rc, _, err = self.call(env, "widen", batch=f"{SLOT}_batch")
        self.assertEqual(rc, 1)
        self.assertIn("grok budget at 0 (run)", err)
        py("slot_state.py", "log", "--slot", SLOT, "--reason", "delivered", env=env)
        line = slot_lines(env)[-1]
        self.assertEqual(line["grok_calls_left_run"], 0)
        self.assertIn("grok budget at 0", line["grok_stop"])

    def test_the_daily_cap_holds_across_slots(self):
        env = fresh()
        self.spend_the_day(env)
        env_eve = dict(env, PIPELINE_NOW=NOW_EVE)
        self.assertEqual(budget(env_eve)["grok_calls_left_today"], 0)
        rc, _, err = self.call(env_eve, "maintenance", slot=SLOT_EVE)
        self.assertEqual(rc, 1)
        self.assertIn("(today)", err)
        tomorrow = dict(env, PIPELINE_NOW="2026-11-25T13:41:00Z")
        self.assertEqual(budget(tomorrow)["grok_calls_left_today"], DAY_CAP)

    def test_caps_off_nothing_is_refused_and_every_call_is_logged(self):
        env = fresh()
        off = Path(env["_DIR"]) / "params_caps_off.json"
        off.write_text(json.dumps(dict(PARAMS, cost=dict(PARAMS["cost"], enforce_grok_caps=False))))
        env = dict(env, PIPELINE_PARAMS=str(off))
        for _ in range(DAY_CAP + 2):
            self.assertEqual(self.call(env, "discovery")[0], 0)
        rows = [json.loads(l) for l in (Path(env["PIPELINE_STATE_DIR"]) / "grok_calls.jsonl").read_text().splitlines() if l.strip()]
        self.assertEqual(len([r for r in rows if not r.get("refused")]), DAY_CAP + 2)
        self.assertEqual(run([BASH, BIN / "preflight.sh"], env)[0], 0)

    def test_a_second_attempt_reuses_the_first_discovery(self):
        env = fresh()
        self.assertEqual(self.call(env, "discovery", batch=f"{SLOT}_batch")[0], 0)
        self.assertEqual(budget(env)["grok_discovery_batch"], f"{SLOT}_batch")
        rc, _, err = self.call(env, "discovery", batch=f"{SLOT}_a2_batch")
        self.assertEqual(rc, 1)
        self.assertIn(f"reuse runs/{SLOT}_batch/00_candidates.json", err)
        self.assertEqual(budget(env)["grok_calls_left_run"], 2, "a refused call spends nothing")

    def test_run_traced_does_not_run_grok_when_the_budget_is_at_0(self):
        env = fresh()
        for _ in range(3):
            self.call(env, "discovery", batch=f"{SLOT}_batch")
        rt = Path(env["_DIR"]) / "rt"
        rt.mkdir()
        rc, _, _ = run([BASH, BIN / "run_traced.sh", "--run-dir", rt, "--role", "scout", "--out", rt / "o",
                        "--grok-slot", SLOT, "--grok-purpose", "widen", "--grok-batch", f"{SLOT}_batch", "--",
                        STUBS / "cli_stub.sh", "-p", "find posts"], env)
        self.assertEqual(rc, 75)
        self.assertEqual(stub_count(env, "grok.count"), 0)
        self.assertIn("grok budget", (rt / "o").read_text())

    def test_run_traced_refuses_a_grok_command_without_the_budget_flags(self):
        env = fresh()
        fake = Path(env["_DIR"]) / "fakebin" / "grok"
        fake.parent.mkdir()
        fake.write_text(f"#!/usr/bin/env bash\ntouch {Path(env['_DIR']) / 'grok_ran'}\n")
        fake.chmod(0o755)
        rt = Path(env["_DIR"]) / "rt"
        rt.mkdir()
        rc, _, _ = run([BASH, BIN / "run_traced.sh", "--run-dir", rt, "--role", "scout", "--out", rt / "o", "--", fake, "-p", "x"], env)
        self.assertEqual(rc, 64)
        self.assertFalse((Path(env["_DIR"]) / "grok_ran").exists())

    def test_preflight_with_the_day_spent_stops_with_grok_budget_and_calls_nothing(self):
        env = fresh()
        self.spend_the_day(env)
        rc, _, _ = run([BASH, BIN / "preflight.sh"], env)
        self.assertEqual(rc, 7)
        self.assertEqual(stub_count(env, "grok.count"), 0)
        self.assertEqual(slot_lines(env)[-1]["reason"], "grok_budget")


class RunLock(unittest.TestCase):
    """The lock holds a run token: only a caller presenting it (RESUME, a new attempt) passes; no_pass releases it."""

    def pf(self, env, *a):
        return run([BASH, BIN / "preflight.sh", *a], env)

    def token_file(self, env):
        return Path(env["PIPELINE_RUNS_DIR"]) / f"{SLOT}_batch" / "run_token"

    def test_a_second_session_of_the_same_slot_is_refused(self):
        env = fresh()
        rc, out, _ = self.pf(env)
        self.assertEqual(rc, 0)
        tok = json.loads(out)["run_token"]
        self.assertEqual(self.token_file(env).read_text().strip(), tok)
        rc2, _, _ = self.pf(env)
        self.assertEqual(rc2, 5, "a bare second session of the slot must not pass the lock")
        self.assertEqual(slot_lines(env)[-1]["reason"], "locked")
        self.assertTrue((Path(env["PIPELINE_STATE_DIR"]) / ".run.lock").is_dir(), "the refused session left the lock alone")
        self.assertEqual(self.pf(env, "--run-token", "not-the-token")[0], 5)

    def test_the_run_token_passes_the_lock_and_stays_the_same(self):
        env = fresh()
        tok = json.loads(self.pf(env)[1])["run_token"]
        rc, out, _ = self.pf(env, "--run-token", tok)
        self.assertEqual(rc, 0)
        self.assertEqual((json.loads(out)["run_token"], json.loads(out)["resuming"]), (tok, True))

    def test_a_stale_lock_is_taken_over_with_a_new_token(self):
        env = fresh()
        tok = json.loads(self.pf(env)[1])["run_token"]
        lock = Path(env["PIPELINE_STATE_DIR"]) / ".run.lock"
        (lock / "started_at").write_text(str(int(utc(NOW).timestamp()) - 3 * 3600))
        rc, out, _ = self.pf(env)
        self.assertEqual(rc, 0)
        self.assertNotEqual(json.loads(out)["run_token"], tok)

    def test_a_no_pass_run_releases_the_lock(self):
        env = fresh()
        self.assertEqual(self.pf(env)[0], 0)
        lock = Path(env["PIPELINE_STATE_DIR"]) / ".run.lock"
        self.assertTrue(lock.is_dir())
        py("slot_state.py", "log", "--slot", SLOT, "--reason", "no_pass", env=env)
        self.assertFalse(lock.exists())
        self.assertEqual(self.pf(env)[0], 0)

    def test_a_no_pass_line_of_another_slot_leaves_the_lock_alone(self):
        env = fresh()
        self.assertEqual(self.pf(env)[0], 0)
        py("slot_state.py", "log", "--slot", "2026-11-23_2000", "--reason", "no_pass", env=env)
        self.assertTrue((Path(env["PIPELINE_STATE_DIR"]) / ".run.lock").is_dir())


class ProbeOncePerSlot(unittest.TestCase):
    """A good probe is recorded for the slot; RESUME and a new attempt reuse it and spend no call."""

    def pf(self, env, *a):
        return run([BASH, BIN / "preflight.sh", *a], env)

    def call(self, env, purpose):
        return py("slot_state.py", "grok-call", "--slot", SLOT, "--purpose", purpose, "--batch", f"{SLOT}_batch", env=env)

    def test_a_resume_after_probe_and_two_discovery_calls_spends_nothing_and_passes(self):
        env = fresh()
        tok = json.loads(self.pf(env)[1])["run_token"]
        self.assertEqual(stub_count(env, "grok.count"), 1)
        self.call(env, "discovery")
        self.call(env, "discovery")
        self.assertEqual(budget(env)["grok_calls_left_run"], 0)
        rc, out, err = self.pf(env, "--run-token", tok)
        self.assertEqual(rc, 0, err)
        self.assertEqual((json.loads(out)["grok_probe"], json.loads(out)["grok_probe_skipped"]), (False, False))
        self.assertEqual(stub_count(env, "grok.count"), 1, "the recorded probe is reused")
        self.assertNotIn("grok_budget", [l["reason"] for l in slot_lines(env)])

    def test_the_probe_is_repeated_after_a_failed_grok_call_of_the_slot(self):
        env = fresh()
        tok = json.loads(self.pf(env)[1])["run_token"]
        self.call(env, "discovery")
        py("slot_state.py", "grok-result", "--slot", SLOT, "--purpose", "discovery", "--ok", "false", env=env)
        self.assertTrue(budget(env)["grok_probe_needed"])
        rc, out, _ = self.pf(env, "--run-token", tok)
        self.assertEqual(rc, 0)
        self.assertTrue(json.loads(out)["grok_probe"])
        self.assertEqual(stub_count(env, "grok.count"), 2)
        self.assertFalse(budget(env)["grok_probe_needed"], "the new good probe is recorded")

    def test_a_resume_is_never_stopped_by_the_budget_for_its_probe(self):
        env = fresh()
        tok = json.loads(self.pf(env)[1])["run_token"]
        self.call(env, "discovery")
        self.call(env, "discovery")
        py("slot_state.py", "grok-result", "--slot", SLOT, "--purpose", "discovery", "--ok", "false", env=env)
        rc, out, err = self.pf(env, "--run-token", tok)
        self.assertEqual(rc, 0, err)
        self.assertTrue(json.loads(out)["grok_probe_skipped"])
        self.assertEqual(stub_count(env, "grok.count"), 1)

    def test_a_failed_grok_call_through_run_traced_is_recorded(self):
        env = fresh(STUB_GROK="dead")
        rt = Path(env["_DIR"]) / "rt"
        rt.mkdir()
        rc, _, _ = run([BASH, BIN / "run_traced.sh", "--run-dir", rt, "--role", "scout", "--out", rt / "o",
                        "--grok-slot", SLOT, "--grok-purpose", "discovery", "--grok-batch", f"{SLOT}_batch", "--",
                        STUBS / "cli_stub.sh", "-p", "find posts"], env)
        self.assertEqual(rc, 1)
        rows = [json.loads(l) for l in (Path(env["PIPELINE_STATE_DIR"]) / "grok_calls.jsonl").read_text().splitlines()]
        self.assertEqual(rows[-1]["result"], "failed")
        self.assertTrue(budget(env)["grok_probe_needed"])
        self.assertEqual(budget(env)["grok_calls_left_run"], 2, "a result row spends nothing")


class MeasureAnswersAndExperience(unittest.TestCase):

    def merge(self, env, pages, starter="Which cap did you use?"):
        led = [{"item_id": f"{SLOT}#{i + 1}", "slot_id": SLOT, "url": pg["parent_url"], "author": f"m{i}", "tier": 1,
                "recommended": True, "reply_type": "clean", "hook": "H1", "starter": starter,
                "posted_at": "2026-11-24T12:30:00Z", "delivered_at": "2026-11-24T13:00:00Z", "mode": "trial"}
               for i, pg in enumerate(pages)]
        wjsonl(Path(env["PIPELINE_STATE_DIR"]) / "delivered.jsonl", led)
        r = py("measure.py", "merge", "--pages", wjson(Path(env["_DIR"]) / "pages.json", pages), env=env)
        self.assertEqual(r[0], 0, r[2])
        return [json.loads(l) for l in (Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl").read_text().splitlines()]

    def page(self, i, answered, text="Which cap held for you on long runs?"):
        return {"parent_url": f"https://x.com/m{i}/status/{900 + i}", "found": True, "reply_url": f"https://x.com/ogrizkov/status/66{i}",
                "text": text, "posted_at": "2026-11-24T13:20:00Z", "views": 40, "likes": 0, "replies": 0,
                "parent_views": 5000, "author_answered": answered, "reading": "24h"}

    def test_an_unknown_author_answer_is_stored_as_null_and_not_counted(self):
        env = fresh(PIPELINE_NOW="2026-11-25T15:00:00Z")
        rows = self.merge(env, [self.page(0, None), self.page(1, True), self.page(2, False)])
        self.assertEqual([r["author_answered"] for r in rows], [None, True, False])
        r = py("measure.py", "period", "--end", "2026-11-25", env=env)
        self.assertEqual(r[0], 0, r[2])
        rep = sorted(Path(env["PIPELINE_ANALYTICS_DIR"]).glob("period_*.md"))[-1].read_text()
        self.assertIn("- author answers without corrections: 1", rep)
        self.assertIn("- author answer unknown (not counted): 1", rep)
        self.assertIn("1 answers in 2 posted with a known answer", rep)
        authors = json.loads((Path(env["PIPELINE_STATE_DIR"]) / "authors.json").read_text())["authors"]
        self.assertEqual({k: v["answered_him"] for k, v in authors.items()}, {"m1": 1})

    def test_added_experience_follows_the_gate_clean_rule(self):
        texts = ["I've hit this too once the cache passed 300k.", "Ran into the same wall at 200k.",
                 "Which cap held for you on long runs?", "Tried the 200k cap yet, or do you keep 400k?"]
        env = fresh(PIPELINE_NOW="2026-11-25T15:00:00Z")
        rows = self.merge(env, [self.page(i, False, t) for i, t in enumerate(texts)])
        self.assertEqual([r["added_experience"] for r in rows], [True, True, False, False])
        for t, want in zip(texts, (1, 1, 0, 0)):
            with self.subTest(t=t):
                self.assertEqual(gate("--type", "clean", text=t), want, "the flag and the gate must agree")


class DeepHookOnClean(unittest.TestCase):
    """Important 6: a Deep hook (H4) is refused on a Clean item; it stays allowed on a Deep item."""

    def check(self, rtype):
        env = fresh(PIPELINE_PATTERNS=C / "reply_patterns.md")
        d = Path(env["_DIR"])
        wjson(Path(env["PIPELINE_STATE_DIR"]) / "authority_zones.json", {"zones": ["AI tooling and workflows"]})
        thread = wjson(d / "thread.json", {"url": "https://x.com/a/status/1", "opening_post": "We set auto-compact to 400k and it held.",
                                           "top_replies": []})
        target = wjson(d / "target.json", {"url": "https://x.com/a/status/1", "reply_type": rtype, "claim_origin": "thread",
                                           "zone": "AI tooling and workflows", "tier": 1, "move": "practitioner_question",
                                           "ground_with": "CAK-01"})
        draft = wjson(d / "draft.json", {"url": "https://x.com/a/status/1", "answers": "set auto-compact to 400k",
                                         "hook": {"id": "H4", "name": "x", "instruction": "Say what was run and what came out."},
                                         "draft": "Ran the 400k cap on a 3-repo eval, the plan held for two sessions."})
        bp = wjson(d / "b.json", {"hooks_recent": [], "resting_entries": []})
        r = py("target_filter.py", "check-item", "--target", target, "--draft", draft, "--thread", thread, "--budget", bp, env=env)
        return r[0], json.loads(r[1])["reasons"]

    def test_h4_on_a_clean_item_is_rejected(self):
        rc, reasons = self.check("clean")
        self.assertEqual(rc, 1)
        self.assertIn("hook_deep_on_clean", reasons)

    def test_h4_on_a_deep_item_is_allowed(self):
        rc, reasons = self.check("deep")
        self.assertNotIn("hook_deep_on_clean", reasons)
        self.assertEqual(rc, 0, reasons)

    def test_the_live_sheet_gives_every_hook_a_type(self):
        r = py("target_filter.py", "hooks", "--patterns", C / "reply_patterns.md", env=fresh())
        types = json.loads(r[1])["types"]
        self.assertEqual(types["H4"], "deep")
        self.assertEqual(sorted(types), [f"H{i}" for i in range(1, 8)])

    def test_clean_starters_that_imply_experience_fail_and_questions_to_you_pass(self):
        for t in ("I've run into exactly this with the 400k cache.", "I also ran this on a cold cache and it held.",
                  "I'm running the same setup on a 200k cap.", "Tried this last spring, the cache died at 300k.",
                  "Ran into the same wall when the tool list grew.", "Me too, the cache dies after the third tool call."):
            with self.subTest(t=t):
                self.assertEqual(gate("--type", "clean", text=t), 1)
        for t in ("Tried the 200k cap yet, or do you keep 400k for the planner?",
                  "I'm curious, did you keep the 400k cap after the parser broke?"):
            with self.subTest(t=t):
                self.assertEqual(gate("--type", "clean", text=t), 0)


class ConversationPaging(unittest.TestCase):
    """Important 7: my-reply follows the cursor; a cursor left after the limit is 'unknown', never counted."""
    PID = "2124541215333044480"
    URL = f"https://x.com/nateherk/status/{PID}"

    def pages(self, env, n, mine_on=None, cursor_after_last=True):
        conv = json.loads((FX / "fx_conversation.json").read_text())
        base = conv["replies"][0]
        fd = Path(env["PIPELINE_FETCH_DIR"])
        for k in range(1, n + 1):
            reps = [] if k == 1 else [dict(base, id=f"9{k}{i}", url=f"https://x.com/u{k}{i}/status/9{k}{i}",
                                           author=dict(base["author"], screen_name=f"u{k}{i}")) for i in range(3)]
            if k == mine_on:
                reps.append(dict(base, id=f"77{k}", url=f"https://x.com/ogrizkov/status/77{k}", views=12,
                                 author=dict(base["author"], screen_name="ogrizkov")))
            page = dict(conv, replies=(conv["replies"] if k == 1 else reps))
            if k == n and not cursor_after_last:
                page.pop("cursor", None)
            else:
                page["cursor"] = {"bottom": f"cur{k}"}
            wjson(fd / (f"conversation_{self.PID}.json" if k == 1 else f"conversation_{self.PID}_p{k}.json"), page)

    def my_reply(self, env):
        r = py("fetch_posts.py", "my-reply", "--parent", self.URL, "--handle", "ogrizkov", env=env)
        self.assertEqual(r[0], 0, r[2])
        return json.loads(r[1])

    def test_his_reply_on_page_three_is_found(self):
        env = fresh()
        self.pages(env, 3, mine_on=3)
        out = self.my_reply(env)
        self.assertTrue(out["found"])
        self.assertTrue(out["reply_url"].endswith("/773"))

    def test_a_cursor_left_after_five_pages_is_unknown_not_no_reply(self):
        env = fresh()
        self.pages(env, 6, mine_on=6)
        out = self.my_reply(env)
        self.assertIsNone(out["found"])
        self.assertEqual(out["note"], "unknown")

    def test_no_cursor_left_is_no_reply(self):
        env = fresh()
        self.pages(env, 2, cursor_after_last=False)
        out = self.my_reply(env)
        self.assertEqual((out["found"], out["note"]), (False, "no reply"))

    def test_an_unknown_reading_writes_no_row_and_the_item_stays_due(self):
        env = fresh(PIPELINE_NOW="2026-11-25T15:00:00Z")
        led = [{"item_id": f"{SLOT}#1", "slot_id": SLOT, "url": self.URL, "author": "nateherk", "tier": 1,
                "recommended": True, "reply_type": "clean", "hook": "H1", "starter": "Which cap?",
                "delivered_at": "2026-11-24T13:50:00Z", "mode": "trial"}]
        wjsonl(Path(env["PIPELINE_STATE_DIR"]) / "delivered.jsonl", led)
        pages = [{"parent_url": self.URL, "found": None, "note": "unknown", "parent_views": 48969}]
        r = py("measure.py", "merge", "--pages", wjson(Path(env["_DIR"]) / "pages.json", pages), env=env)
        self.assertEqual(r[0], 0, r[2])
        self.assertEqual(json.loads(r[1]), {"rows_added": 0, "unknown": 1})
        self.assertFalse((Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl").exists())
        due = json.loads(py("measure.py", "due", env=env)[1])["items"]
        self.assertEqual([d["item_id"] for d in due], [f"{SLOT}#1"])

    def test_a_row_without_a_view_count_never_feeds_the_tripwire(self):
        env = fresh()
        tripwire_rows(env, [(None, 5000)] * 5)
        r = py("measure.py", "tripwire", env=env)
        self.assertFalse(json.loads(r[1])["tripped"])


class PickedProbesRequired(unittest.TestCase):
    """Important 8: with --probes every picked probe must be in the critic output."""

    def evaluate(self, results, *extra):
        f = wjson(ROOT / f"critic_{time.monotonic_ns()}.json", {"results": results})
        return run([BASH, BIN / "qualify_critic.sh", "--evaluate", f, "--model", "x", *extra], fresh())

    def test_a_dropped_must_fail_probe_fails_the_call(self):
        cal = json.loads((FX / "critic_out_calibrated.json").read_text())["results"]
        probes = {p["id"]: p for p in json.loads((C / "tests" / "critic_probes.json").read_text())["probes"]}
        ship = [r for r in cal if " ".join((r.get("draft") or "").split()) == " ".join(probes["probe-good-01"]["draft"].split())]
        self.assertEqual(len(ship), 1)
        self.assertEqual(self.evaluate(ship)[0], 0, "without --probes only the present probes are checked")
        rc, out, _ = self.evaluate(ship, "--probes", "probe-boring-01,probe-good-01")
        self.assertEqual(rc, 1)
        self.assertIn("probe-boring-01: picked probe missing", out)

    def test_both_picked_probes_present_and_right_pass(self):
        cal = json.loads((FX / "critic_out_calibrated.json").read_text())["results"]
        pick = run([BASH, BIN / "qualify_critic.sh", "--pick", "--slot", SLOT], fresh())[1].split()
        self.assertEqual(self.evaluate(cal, "--probes", ",".join(pick))[0], 0)

    def test_an_unknown_probe_id_is_a_usage_error(self):
        self.assertEqual(self.evaluate([], "--probes", "probe-nope")[0], 2)


class ValidatorMinor(unittest.TestCase):

    def test_a_monthly_report_without_label_keys_does_not_open_stage_three(self):
        env = fresh()
        state(env, stage=2)
        a = Path(env["PIPELINE_ANALYTICS_DIR"])
        (a / "period_2026-11-20.md").write_text("# Period\n\nVerdict: raise.\n")
        wjson(a / "under_the_hood" / "2026-10.json", {"impressions": 100})
        rc, _, err = py("slot_state.py", "set-stage", "3", "--reason", "x", env=env)
        self.assertEqual(rc, 1)
        self.assertIn("monthly X report", err)
        wjson(a / "under_the_hood" / "2026-10.json", {"accountLabels": [], "postLabels": []})
        self.assertEqual(py("slot_state.py", "set-stage", "3", "--reason", "x", env=env)[0], 0)

    def test_reply_count_uses_only_yesterday_as_its_baseline(self):
        env = fresh()
        wjson(Path(env["PIPELINE_FETCH_DIR"]) / "profile_ogrizkov.json", {"code": 200, "user": {"statuses": 110}})
        wjson(Path(env["PIPELINE_STATE_DIR"]) / "posted_counts.json", {"profile_totals": {"2026-11-20": 100}})
        old = json.loads(py("fetch_posts.py", "reply-count", "--handle", "ogrizkov", env=env)[1])
        self.assertTrue(old["partial"], "a 4-day-old total must not put 4 days into today")
        env2 = fresh()
        wjson(Path(env2["PIPELINE_FETCH_DIR"]) / "profile_ogrizkov.json", {"code": 200, "user": {"statuses": 110}})
        wjson(Path(env2["PIPELINE_STATE_DIR"]) / "posted_counts.json", {"profile_totals": {"2026-11-23": 104}})
        new = json.loads(py("fetch_posts.py", "reply-count", "--handle", "ogrizkov", env=env2)[1])
        self.assertEqual((new["count"], new["partial"]), (6, False))

    def test_the_operator_minutes_table_is_in_the_overview(self):
        t = (C / "PIPELINE_OVERVIEW.md").read_text()
        self.assertIn("## 11. Operator minutes", t)
        self.assertIn("| Each day, stage 1 | Total: posting part 17, with reading and marks up to 32 | 32 |", t)

    def test_the_runbook_names_the_per_slot_share_check_before_going_live(self):
        t = (C / "skill" / "twitter-reply-orchestrate.md").read_text()
        self.assertIn("that slot's own share in `trial-report`", t)


# ============ Round 5 (first live run): delivery check, ready replies, mobile layout ==========
class SentIsDelivered(unittest.TestCase):
    """A message in Sent is delivered whatever else exists; a draft copy of it is a leftover moved to Trash."""
    SUBJ = "2 Twitter replies to write (2026-11-24 15:30) #5dec"

    def send(self, env, src=FX / "replies_mode_b.md"):
        return py("email_replies.py", src, "--slot", SLOT, "--send", env=env)

    def box(self, env, name):
        p = Path(env["STUB_DIR"]) / name
        return p.read_text().splitlines() if p.exists() else []

    def test_a_send_that_leaves_a_draft_copy_is_delivered_and_the_copy_trashed(self):
        env = fresh(STUB_MAIL_MODE="deliver_leftover")
        rc, out, err = self.send(env)
        self.assertEqual(rc, 0, err)
        self.assertIn("moved to Trash (1)", out)
        self.assertEqual((sends(env), self.box(env, "mail_drafts"), self.box(env, "mail_trash")), (1, [], [self.SUBJ]))
        self.assertTrue((Path(env["PIPELINE_STATE_DIR"]) / "sent" / SLOT).exists())

    def test_a_retry_with_the_message_in_sent_and_a_draft_copy_sends_nothing(self):
        env = fresh()
        Path(env["STUB_DIR"], "mail_sent").write_text(self.SUBJ + "\n")
        Path(env["STUB_DIR"], "mail_drafts").write_text(self.SUBJ + "\n")
        rc, out, _ = self.send(env)
        self.assertEqual((rc, sends(env)), (0, 0))
        self.assertIn("already in Sent", out)
        self.assertEqual(self.box(env, "mail_drafts"), [])

    def test_a_draft_not_in_sent_is_never_trashed(self):
        env = fresh()
        other = "[TRIAL] 3 Twitter reply ideas (2026-11-23 20:00)"
        Path(env["STUB_DIR"], "mail_drafts").write_text(other + "\n")
        env["STUB_MAIL_MODE"] = "deliver_leftover"
        self.assertEqual(self.send(env)[0], 0)
        self.assertEqual(self.box(env, "mail_drafts"), [other])

    def test_an_earlier_batch_of_the_slot_with_the_same_count_does_not_block_the_send(self):
        env = fresh()
        first = pipeline(env, [item("e1", hook="H1"), item("e2", hook="H2")], name="earlier_batch")
        Path(env["STUB_DIR"], "mail_sent").write_text(first["subject"] + "\n")
        r = pipeline(env, [item("n1", hook="H1"), item("n2", hook="H2")], send=True)
        self.assertNotEqual(r["subject"], first["subject"])
        self.assertEqual((r["rc"], sends(env)), (0, 1), r["err"])

    def test_verify_delivery_finds_the_subject_in_the_batch_file_and_writes_the_marker(self):
        env = fresh()
        r = pipeline(env, [item("vd1", hook="H1"), item("vd2", hook="H2")])
        Path(env["STUB_DIR"], "mail_sent").write_text(r["subject"] + "\n")
        rc, out, err = py("email_replies.py", "--verify-delivery", "--slot", SLOT, env=env)
        self.assertEqual(rc, 0, err)
        self.assertIn(f"delivered: {r['subject']}", out)
        marker = json.loads((Path(env["PIPELINE_STATE_DIR"]) / "sent" / SLOT).read_text())
        self.assertEqual((marker["subject"], marker["items"]), (r["subject"], 2))
        self.assertEqual(py("email_replies.py", r["run_dir"] / "replies_to_post.md", "--slot", SLOT, "--send", env=env)[0], 6)
        self.assertEqual(sends(env), 0)

    def test_verify_delivery_with_no_batch_and_no_marker_says_why(self):
        rc, _, err = py("email_replies.py", "--verify-delivery", "--slot", SLOT, env=fresh())
        self.assertEqual(rc, 4)
        self.assertIn("no marker and no batch file", err)

    def test_preflight_passes_a_leftover_copy_and_stops_on_a_real_stuck_draft(self):
        env = fresh()
        Path(env["STUB_DIR"], "mail_sent").write_text(self.SUBJ + "\n")
        Path(env["STUB_DIR"], "mail_drafts").write_text(self.SUBJ + "\n")
        self.assertEqual(run([BASH, BIN / "preflight.sh"], env)[0], 0)
        env2 = fresh()
        Path(env2["STUB_DIR"], "mail_drafts").write_text(self.SUBJ + "\n")
        self.assertEqual(run([BASH, BIN / "preflight.sh"], env2)[0], 9)


class ReadyRepliesMail(unittest.TestCase):

    def test_the_drafter_writes_a_finished_reply_in_his_voice(self):
        t = (C / "agents" / "role_specs" / "drafter.md").read_text()
        self.assertIn("## Reply rules", t)
        self.assertIn("posts as it is", t)
        self.assertNotIn("Starter draft rules", t)
        self.assertIn("voice.md", t)

    def test_feedback_on_the_simpler_mail_is_still_read(self):
        env = fresh()
        r = pipeline(env, [item("fb1", hook="H1"), item("fb2", hook="H2")])
        fb = Path(env["_DIR"]) / "fb.txt"
        fb.write_text(f"<<<MSG>>>\nid: <m1@x>\nsubject: Re: {r['subject']}\n\n1 + good\n2 - forced\n\nOn Tue wrote:\n> old\n")
        rc, out, _ = py("email_replies.py", "--feedback", env=dict(env, STUB_FEEDBACK=str(fb)))
        self.assertEqual(rc, 0)
        msg = json.loads(out.splitlines()[0])
        self.assertEqual((msg["slot_id"], [(m["n"], m["verdict"], m["reason"]) for m in msg["marks"]]),
                         (SLOT, [(1, "would_post", "good"), (2, "would_not", "forced")]))
        self.assertIn("Feedback: reply with the item number, + or -, and a word", r["html"])


# ============ Round 5 D: results of posted replies, weekly summary, "Last week" block =========
MONDAY = "2026-11-30T13:41:00Z"       # Mon 15:41 Israel -> slot 2026-11-30_1530
MON_SLOT = "2026-11-30_1530"


def weekly_rows(env, specs, start="2026-11-23T10:00:00Z"):
    """reply_log rows, 48 h readings: (views, parent_views, thread_rank, answered) per posted pipeline reply."""
    rows = [{"reply_url": f"https://x.com/ogrizkov/status/7{i:03d}", "arm": "pipeline", "reading": "48h",
             "views": v, "parent_views": pv, "thread_rank": tr, "author_answered": ans, "hook": "H1", "tier": 1,
             "text_posted": f"Reply number {i} says one two three four five six seven eight nine ten eleven",
             "posted_at": z(utc(start) + dt.timedelta(hours=6 * i))} for i, (v, pv, tr, ans) in enumerate(specs)]
    wjsonl(Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", rows)


class ThreadRankAndShare(unittest.TestCase):
    PID = "2124541215333044480"
    URL = f"https://x.com/nateherk/status/{PID}"

    def conv(self, env, views_others, mine_views, cursor=False):
        conv = json.loads((FX / "fx_conversation.json").read_text())
        base = conv["replies"][0]
        reps = [dict(base, id=f"5{i}", url=f"https://x.com/o{i}/status/5{i}", views=v,
                     author=dict(base["author"], screen_name=f"o{i}")) for i, v in enumerate(views_others)]
        reps.append(dict(base, id="777", url="https://x.com/ogrizkov/status/777", views=mine_views,
                         author=dict(base["author"], screen_name="ogrizkov")))
        page = dict(conv, replies=reps, status=dict(conv["status"], views=10000))
        if not cursor:
            page.pop("cursor", None)
        wjson(Path(env["PIPELINE_FETCH_DIR"]) / f"conversation_{self.PID}.json", page)

    def my_reply(self, env):
        r = py("fetch_posts.py", "my-reply", "--parent", self.URL, "--handle", "ogrizkov", env=env)
        self.assertEqual(r[0], 0, r[2])
        return json.loads(r[1])

    def test_rank_share_and_replies_seen(self):
        env = fresh()
        self.conv(env, [10, 20, 30, 40, 500, 600, 700, 800, 900], 50)
        out = self.my_reply(env)
        self.assertEqual((out["thread_rank"], out["thread_replies_seen"], out["share_of_parent"]), (50, 10, 0.005))

    def test_the_most_viewed_reply_ranks_100(self):
        env = fresh()
        self.conv(env, [1, 2, 3, 4], 99)
        self.assertEqual(self.my_reply(env)["thread_rank"], 100)

    def test_fewer_than_5_replies_seen_gives_null(self):
        env = fresh()
        self.conv(env, [1, 2, 3], 99)
        out = self.my_reply(env)
        self.assertEqual((out["thread_rank"], out["thread_replies_seen"]), (None, 4))

    def test_pages_left_unread_give_null(self):
        env = fresh()
        self.conv(env, [10, 20, 30, 40, 500, 600], 50, cursor=True)
        out = self.my_reply(env)
        self.assertTrue(out["found"])
        self.assertIsNone(out["thread_rank"])

    def test_merge_stores_the_three_fields(self):
        env = fresh(PIPELINE_NOW="2026-11-25T15:00:00Z")
        led = [{"item_id": f"{SLOT}#1", "slot_id": SLOT, "url": self.URL, "author": "nateherk", "tier": 1, "recommended": True,
                "reply_type": "clean", "hook": "H1", "starter": "Which cap?", "delivered_at": "2026-11-24T13:50:00Z", "mode": "trial"}]
        wjsonl(Path(env["PIPELINE_STATE_DIR"]) / "delivered.jsonl", led)
        page = [{"parent_url": self.URL, "found": True, "reply_url": "https://x.com/ogrizkov/status/777", "text": "Which cap?",
                 "posted_at": "2026-11-24T14:00:00Z", "views": 50, "parent_views": 10000, "thread_rank": 50,
                 "thread_replies_seen": 10, "share_of_parent": 0.005, "author_answered": False, "reading": "24h"}]
        py("measure.py", "merge", "--pages", wjson(Path(env["_DIR"]) / "p.json", page), env=env)
        row = json.loads((Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl").read_text().splitlines()[0])
        self.assertEqual((row["thread_rank"], row["thread_replies_seen"], row["share_of_parent"]), (50, 10, 0.005))


class WeeklySummary(unittest.TestCase):

    def weekly(self, env, end="2026-11-29"):
        r = py("measure.py", "weekly", "--end", end, env=env)
        self.assertEqual(r[0], 0, r[2])
        return (Path(env["PIPELINE_ANALYTICS_DIR"]) / f"weekly_summary_{end}.md").read_text()

    def test_counts_top_three_and_both_comparisons(self):
        env = fresh(PIPELINE_PATTERNS=C / "reply_patterns.md")
        specs = [(40, 5000, 90, True), (30, 6000, 80, False), (20, 7000, 70, False), (10, 8000, 30, False),
                 (15, 9000, 20, True), (200, 50000, 95, False), (300, 60000, 10, False)]
        weekly_rows(env, specs)
        t = self.weekly(env)
        self.assertIn("# Last week, 2026-11-23 to 2026-11-29", t)
        self.assertIn("- Replies posted: 7. Median views: 30. The author answered 2.", t)
        self.assertEqual(t.count("- Top: "), 3)
        self.assertIn('- Top: "Reply number 6 says one two three four five six seven eight" 300 views, '
                      'Question first, one concrete detail, tier 1, thread rank 10.', t)
        self.assertIn("- By the size of the post: posts under 20,000 views: 5 replies, median 20 views, 2 answered; "
                      "posts of 20,000 views and more: too few replies to tell (2).", t)
        self.assertIn("- By the reply's rank in its thread: top third: too few replies to tell (4); "
                      "the rest: too few replies to tell (3).", t)
        weekly_rows(env, specs + [(60, 5000, 99, False), (70, 5000, 98, True)])
        t2 = self.weekly(env)
        self.assertIn("top third: 6 replies, median 50 views, 2 answered; the rest: too few replies to tell (3).", t2)

    def test_replies_outside_the_week_and_unranked_replies_are_left_out(self):
        env = fresh()
        weekly_rows(env, [(40, 5000, None, False)] * 6, start="2026-11-16T10:00:00Z")
        t = self.weekly(env)
        self.assertIn("- Replies posted: 0.", t)
        self.assertIn("top third: too few replies to tell (0); the rest: too few replies to tell (0).", t)


class LastWeekBlock(unittest.TestCase):

    def mail(self, env, author, now, slot, name, send=True):
        return pipeline(dict(env, PIPELINE_NOW=now), [item(author, hook="H1")], slot=slot, name=name, send=send)

    def test_the_first_monday_mail_carries_the_block_and_later_mails_do_not(self):
        env = fresh()
        weekly_rows(env, [(40, 5000, 90, True)] * 6)
        r1 = self.mail(env, "mo1", MONDAY, MON_SLOT, f"{MON_SLOT}_batch")
        self.assertEqual(r1["rc"], 0)
        h = r1["html"]
        self.assertIn(">Last week</p>", h)
        self.assertIn("Replies posted: 6.", h)
        self.assertLess(h.rfind(">Open post<"), h.find(">Last week<"))
        self.assertIn("font-size:20px;font-weight:bold;line-height:1.35;color:#3b2a1a;margin:8px 0 8px 0'>Last week", h)
        r2 = self.mail(env, "mo2", "2026-11-30T18:11:00Z", "2026-11-30_2000", "2026-11-30_2000_batch")
        self.assertEqual(r2["rc"], 0)
        self.assertNotIn("Last week", r2["html"])
        self.assertEqual(sends(env), 2, "no separate mail for the summary")

    def test_no_monday_mail_puts_the_block_into_the_next_mail(self):
        env = fresh()
        weekly_rows(env, [(40, 5000, 90, True)] * 6)
        r = self.mail(env, "tu1", "2026-12-01T13:41:00Z", "2026-12-01_1530", "2026-12-01_1530_batch")
        self.assertIn(">Last week</p>", r["html"])

    def test_a_failed_send_keeps_the_block_for_the_next_mail(self):
        env = fresh(STUB_MAIL_MODE="error")
        weekly_rows(env, [(40, 5000, 90, True)] * 6)
        self.assertEqual(self.mail(env, "mo1", MONDAY, MON_SLOT, f"{MON_SLOT}_batch")["rc"], 4)
        env["STUB_MAIL_MODE"] = "deliver"
        r = self.mail(env, "mo2", "2026-11-30T18:11:00Z", "2026-11-30_2000", "2026-11-30_2000_batch")
        self.assertIn(">Last week</p>", r["html"])

    def test_a_week_with_no_posted_reply_has_no_block(self):
        env = fresh()
        r = self.mail(env, "mo1", MONDAY, MON_SLOT, f"{MON_SLOT}_batch")
        self.assertNotIn("Last week", r["html"])


# ============ Isolation and the Verification Gateway =========================================
class ZZIsolationAndGateway(unittest.TestCase):

    def test_tests_never_touched_live_state(self):
        after = live_snapshot()
        for k, v in LIVE_BEFORE.items():
            self.assertEqual(after[k], v, f"a test changed the live {k}")

    @unittest.skipIf(os.environ.get("ACC_SKIP_GATEWAY") == "1", "ACC_SKIP_GATEWAY=1: the gateway runs once in its own step")
    def test_verification_gateway_is_green(self):
        rc, out, _ = run([BASH, BIN / "verify_v32.sh"], dict(os.environ), timeout=600)
        self.assertEqual(rc, 0)
        self.assertNotIn("[FAIL]", out)


def tearDownModule():
    shutil.rmtree(ROOT, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
