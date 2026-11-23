#!/usr/bin/env bash
# verify_v32.sh — Verification Gateway of the reply pipeline v3.2 rebuild.
#
# It wraps no slow suite, so it has no skip mode. It does not run the two legacy doc lints
# (verify_v3_scaffold.sh, verify_gemini_swap.sh): they assert the v3.1 documents.
# It exports PIPELINE_TEST=1, points PIPELINE_PATTERNS at the fixture sheet (never the live sheet)
# and PIPELINE_FETCH_DIR at saved endpoint answers, keeps all state in a temp directory,
# makes no network call and sends no email (Mail, grok, agy and the daily log are stubs).
#
# Groups: T1 gate, T2 email, T3 state, T4 targets, T5 produce, T6 measure, T7 preflight,
# T8 run_traced, T9 probes, T10 docs, T11 fetch_posts. Output: one "[PASS]" or "[FAIL]" line per check.
#
# Usage: /opt/homebrew/bin/bash bin/verify_v32.sh   (from the vault root or anywhere)
# Exit:  0 all pass · 1 a check failed · 2 setup error (bash < 4, python3 or grep_section.sh missing)
set -uo pipefail

if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
  echo "E2: verify_v32.sh needs bash >= 4 (run /opt/homebrew/bin/bash $0)" >&2; exit 2
fi
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
C="$(cd "$BIN/.." && pwd -P)"
VAULT="$(cd "$C/../../../../.." && pwd -P)"
GREP_SECTION="$VAULT/.vault_link/.scripts/grep_section.sh"
[ -x "$GREP_SECTION" ] || [ -f "$GREP_SECTION" ] || { echo "E2: grep_section.sh not found at $GREP_SECTION" >&2; exit 2; }
command -v python3 >/dev/null || { echo "E2: python3 not found" >&2; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/verify_v32.XXXXXX")" || { echo "E2: no temp dir" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT
export PIPELINE_TEST=1
export PIPELINE_PATTERNS="$C/tests/fixtures/reply_patterns_fixture.md"
export PIPELINE_FETCH_DIR="$T/fetch"
export PIPELINE_STATE_DIR="$T/state" PIPELINE_ANALYTICS_DIR="$T/analytics" PIPELINE_STATUS_FILE="$T/STATUS.md"
export OSASCRIPT_BIN="$C/tests/stubs/osascript_stub.sh" GROK_BIN="$C/tests/stubs/cli_stub.sh"
export AGY_BIN="$C/tests/stubs/cli_stub.sh" PIPELINE_ALARM_BIN="$C/tests/stubs/cli_stub.sh"
export STUB_DIR="$T/stub" PIPELINE_RUNS_DIR="$T/runs"
mkdir -p "$PIPELINE_FETCH_DIR" "$PIPELINE_STATE_DIR" "$PIPELINE_ANALYTICS_DIR"
cp "$C/tests/fixtures/fx_conversation.json" "$PIPELINE_FETCH_DIR/conversation_2124541215333044480.json"
cp "$C/tests/fixtures/fx_status.json" "$PIPELINE_FETCH_DIR/status_2124541215333044480.json"

PASS=1
chk() {  # chk LABEL CMD...  (runs CMD with eval; pass on exit 0)
  local label="$1"; shift
  if eval "$@" >/dev/null 2>&1; then echo "  [PASS] $label"; else echo "  [FAIL] $label"; PASS=0; fi
}

# ---------- T1 gate ------------------------------------------------------------------------
echo "=== T1 gate ==="
G=(/opt/homebrew/bin/bash "$BIN/gate.sh"); F="$C/tests/fixtures"
[ -x /opt/homebrew/bin/bash ] || G=("$BASH" "$BIN/gate.sh")
gate_rc() { "${G[@]}" "$@" >/dev/null 2>&1; echo $?; }
gate_is() { local want="$1"; shift; [ "$(gate_rc "$@")" = "$want" ]; }
chk "verify_gate.sh exits 0" '"${G[0]}" "$BIN/verify_gate.sh"'
chk "anchor_paste_fail fails with anchor_cak06" 'gate_is 1 --anchor "$F/anchor_cak06.txt" "$F/anchor_paste_fail.txt"'
chk "anchor_rewrite_pass passes" 'gate_is 0 --anchor "$F/anchor_cak06.txt" "$F/anchor_rewrite_pass.txt"'
chk "jargon_fail fails" 'gate_is 1 "$F/jargon_fail.txt"'
chk "jargon_thread_pass passes with --thread jargon_thread.txt" 'gate_is 0 --thread "$F/jargon_thread.txt" "$F/jargon_thread_pass.txt"'
chk "agreement_only_fail fails" 'gate_is 1 "$F/agreement_only_fail.txt"'
chk "clean_experience_fail fails with --type clean" 'gate_is 1 --type clean "$F/clean_experience_fail.txt"'
chk "clean_experience_fail passes with --type deep" 'gate_is 0 --type deep "$F/clean_experience_fail.txt"'
chk "history_reuse_fail fails with history_14d" 'gate_is 1 --history "$F/history_14d.txt" "$F/history_reuse_fail.txt"'
chk "max_words_25_fail fails with --max-words 25" 'gate_is 1 --max-words 25 "$F/max_words_25_fail.txt"'
chk "link_fail fails" 'gate_is 1 "$F/link_fail.txt"'
chk "hashtag_fail fails" 'gate_is 1 "$F/hashtag_fail.txt"'
chk "semicolon_pass (aren;t) passes" 'gate_is 0 "$F/semicolon_pass.txt"'
chk "lone_question_pass passes" 'gate_is 0 "$F/lone_question_pass.txt"'
chk "batch: batcha_shipped fails" 'gate_is 1 --batch "$F/batcha_shipped.md"'
chk "batch: batch_same_wc fails" 'gate_is 1 --batch "$F/batch_same_wc.md"'
chk "batch: batch_tic_fail fails" 'gate_is 1 --batch "$F/batch_tic_fail.md"'
chk "batch: batch_questions_pass passes" 'gate_is 0 --batch "$F/batch_questions_pass.md"'
chk "batch: varied_form passes" 'gate_is 0 --batch "$F/varied_form.md"'
chk "batch: same_skeleton fails" 'gate_is 1 --batch "$F/same_skeleton.md"'
chk "gate.sh has no needshort or maxlong" '! grep -qE "needshort|maxlong" "$BIN/gate.sh"'

# ---------- T2-T11 (python harness) ----------------------------------------------------------
export V_BIN="$BIN" V_C="$C" V_T="$T" V_GREP_SECTION="$GREP_SECTION" V_VAULT="$VAULT"
python3 - <<'PY'
import json, os, re, shutil, subprocess, sys, time, datetime as dt
from pathlib import Path

BIN, C, T = Path(os.environ["V_BIN"]), Path(os.environ["V_C"]), Path(os.environ["V_T"])
FX = C / "tests" / "fixtures"
STUBS = C / "tests" / "stubs"
BASH = "/opt/homebrew/bin/bash" if Path("/opt/homebrew/bin/bash").exists() else "bash"
ok_all = True
_n = [0]

def check(label, cond):
    global ok_all
    print(f"  [{'PASS' if cond else 'FAIL'}] {label}")
    ok_all &= bool(cond)

def case(label, fn):
    try:
        check(label, fn())
    except Exception as e:  # a crash in a case is a failed check, never a silent pass
        check(f"{label} (error: {type(e).__name__}: {str(e)[:120]})", False)

def fresh(**extra):
    """A new isolated state/analytics/stub dir set; returns an env dict."""
    _n[0] += 1
    d = T / f"case{_n[0]}"
    for sub in ("state", "analytics", "stub"):
        (d / sub).mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env.update({"PIPELINE_STATE_DIR": str(d / "state"), "PIPELINE_ANALYTICS_DIR": str(d / "analytics"),
                "PIPELINE_STATUS_FILE": str(d / "STATUS.md"), "STUB_DIR": str(d / "stub"),
                "PIPELINE_PARAMS": str(PARAMS_T)})
    env.update({k: str(v) for k, v in extra.items()})
    env["_DIR"] = str(d)
    return env

def run(args, env, inp=None, timeout=60):
    r = subprocess.run([str(a) for a in args], env=env, cwd=str(C), capture_output=True, text=True,
                       input=inp, timeout=timeout)
    return r.returncode, r.stdout, r.stderr

def py(script, *args, env):
    return run(["python3", BIN / script, *args], env)

def jout(rc_out_err):
    return json.loads(rc_out_err[1])

def write(path, text):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(text)
    return Path(path)

def wjson(path, obj):
    return write(path, json.dumps(obj, indent=1))

def wjsonl(path, rows):
    return write(path, "".join(json.dumps(r) + "\n" for r in rows))

def utc(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))

def z(t):
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# test params: same as the live file, with short Mail waits so the delivery cases run in seconds
params = json.loads((C / "agents" / "params.json").read_text())
params["delivery"].update({"verify_wait_s": 2, "verify_poll_s": 1, "send_timeout_s": 2})
PARAMS_T = wjson(T / "params_test.json", params)
NOW = "2026-11-24T13:41:00Z"      # 15:41 Israel, slot 15:30
SLOT = "2026-11-24_1530"

# ================================ T2 email ===================================================
print("=== T2 email ===")
E = BIN / "email_replies.py"
def email(*args, env):
    return run(["python3", E, *args], env)
def html_of(env):
    return Path(env["PIPELINE_STATE_DIR"], "email.html").read_text()

e = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z")
rc, out, err = email(FX / "replies_mode_b.md", "--slot", SLOT, env=e)
hb = html_of(e)
case("mode_b with filled Skipped/Quarantined yields exactly 2 items", lambda: rc == 0 and hb.count(">Open post<") == 2 and "never be mailed" not in hb)
case("live subject has no [TRIAL]", lambda: out.strip() == "2 Twitter replies to write (2026-11-24 15:30)")
case("replies_held.md exits 3", lambda: email(FX / "replies_held.md", "--slot", SLOT, env=e)[0] == 3)
case("replies_clean_no_source.md exits 3", lambda: email(FX / "replies_clean_no_source.md", "--slot", SLOT, env=e)[0] == 3)
nomode = write(T / "nomode" / "replies_to_post.md", re.sub(r"^mode: .*\n", "", (FX / "replies_mode_b.md").read_text(), flags=re.M))
case("a file with no mode: line exits 3", lambda: email(nomode, "--slot", SLOT, env=e)[0] == 3)
et = fresh(PIPELINE_NOW="2026-11-24T18:41:00Z")
rc_t, out_t, _ = email(FX / "replies_trial.md", "--slot", "2026-11-24_2000", env=et)
ht = html_of(et)
case("trial subject starts [TRIAL]", lambda: rc_t == 0 and out_t.startswith("[TRIAL] 2 Twitter reply ideas (2026-11-24 20:00)"))
case("trial header says TRIAL RUN and every item has a TRIAL badge", lambda: "TRIAL RUN" in ht and ht.count(">TRIAL<") == 2)
for name, h in (("live", hb), ("trial", ht)):
    case(f"{name} header: Post today: 1, today total, follow-up line",
         lambda h=h: "Post today: 1" in h and "Today in total: 2 more replies, yours included" in h
         and "If the author answers, reply once the same day" in h)
case("recommended item shows 'Recommended to post' and comes first; the other 'For review'",
     lambda: hb.find("Recommended to post") != -1 and hb.find("Recommended to post") < hb.find("For review"))
case("a lane item shows 'Large account'", lambda: "Large account" in ht)
case("every item shows the post's views at capture", lambda: hb.count("views at capture") == 2 and "48969 views at capture" in hb)
paused = (FX / "replies_mode_b.md").read_text().replace("post_today: 1", "post_today: 0").replace(
    "post_reason: stage 1: up to 1 per run, 2 pipeline items a day",
    "post_reason: tripwire: the last 5 posted replies had 8 views or fewer at 24 hours; back on 2026-12-01").replace(
    "- mark: recommended", "- mark: review")
ep = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z")
email(write(T / "paused" / "replies_to_post.md", paused), "--slot", SLOT, env=ep)
hp = Path(T / "paused" / "email.html").read_text()
case("paused header: 'Post today: 0, tripwire' with reason and date; items still for review",
     lambda: "Post today: 0, tripwire: the last 5 posted replies had 8 views or fewer at 24 hours; back on 2026-12-01" in hp
     and hp.count("For review") == 2)
case("without post_short the header has no 'Why only' line", lambda: "Why only" not in hb)
shorted = (FX / "replies_mode_b.md").read_text().replace("post_today: 1\n", "post_today: 1\npost_short: only 1 item passed\n")
es = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z")
email(write(T / "shorted" / "replies_to_post.md", shorted), "--slot", SLOT, env=es)
hs = Path(T / "shorted" / "email.html").read_text()
case("with post_short the header says 'Why only 1: only 1 item passed.'", lambda: "Why only 1: only 1 item passed." in hs)
case("a stage_note line is shown in the header", lambda: "Stage 1 again: tripwire pause until 2026-11-20" in hb)
case("each item: link, quoted line, angle, How to open, starter, post-by",
     lambda: all(hb.count(s) == 2 for s in ("They wrote:", "Angle:", "How to open:", "Starter (rewrite in your own words):", "Post by "))
     and "https://x.com/sristhi_saha/status/2124017472831389724" in hb)
case("no hook id appears anywhere in the mail", lambda: not re.search(r"\b[HX]\d\b", hb + ht))
case("a 'Yours?' line is shown when the item has one", lambda: "Yours?" in hb and "Have you seen a compaction drop" in hb)
for field in ("HOOK", "OPEN"):
    md = (FX / "replies_mode_b.md").read_text()
    first = md.index("### 1.")
    md2 = md[:first] + re.sub(rf"^- {field}: .*\n", "", md[first:md.index("### 2.")], flags=re.M) + md[md.index("### 2."):]
    em = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z")
    p = write(T / f"no{field}" / "replies_to_post.md", md2)
    email(p, "--slot", SLOT, env=em)
    case(f"an item with its - {field}: line removed is not mailed", lambda p=p: Path(p.parent, "email.html").read_text().count(">Open post<") == 1)
case("post-by: send + 120 wins (item 1 at 15:50 -> 17:50)", lambda: "Post by 17:50 or skip" in hb)
case("post-by: post time + 360 wins (item 2 posted 11:00 -> 17:00)", lambda: "Post by 17:00 or skip" in hb)
ew = fresh(PIPELINE_NOW="2026-11-24T14:40:00Z")
email(FX / "replies_mode_b.md", "--slot", SLOT, env=ew)
case("post-by: the window end wins (sent 16:40 -> 18:30)", lambda: "Post by 18:30 or skip" in html_of(ew))
case("the mail ends with the feedback line and the status line",
     lambda: hb.rfind("Open post") < hb.find("Feedback: reply to this mail, one line per item") < hb.find("Since the last mail: 3 slots"))
# delivery scenarios
ed = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z", STUB_MAIL_MODE="deliver")
sends = lambda env: int((Path(env["STUB_DIR"]) / "sends.count").read_text()) if (Path(env["STUB_DIR"]) / "sends.count").exists() else 0
marker = lambda env, s=SLOT: (Path(env["PIPELINE_STATE_DIR"]) / "sent" / s).exists()
rc_d = email(FX / "replies_mode_b.md", "--slot", SLOT, "--send", env=ed)[0]
case("scenario delivered: exit 0 and a marker", lambda: rc_d == 0 and marker(ed) and sends(ed) == 1)
rc_2 = email(FX / "replies_mode_b.md", "--slot", SLOT, "--send", env=ed)[0]
case("a second send for the slot: exit 6, send counter unchanged", lambda: rc_2 == 6 and sends(ed) == 1)
ei = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z", STUB_MAIL_MODE="stuck")
rc_i, _, err_i = email(FX / "replies_mode_b.md", "--slot", SLOT, "--send", env=ei)
case("scenario I-9 (stays in Drafts/Outbox): exit 4, no marker", lambda: rc_i == 4 and not marker(ei) and "stuck_outbox" in err_i)
ea = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z", STUB_MAIL_MODE="deliver")
write(Path(ea["STUB_DIR"]) / "mail_sent", "2 Twitter replies to write (2026-11-24 15:30)\n")
rc_a = email(FX / "replies_mode_b.md", "--slot", SLOT, "--send", env=ea)[0]
case("scenario already in Sent, no marker: no second send, marker written, exit 0", lambda: rc_a == 0 and sends(ea) == 0 and marker(ea))
eh = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z", STUB_MAIL_MODE="hang", STUB_HANG_S="8")
t0 = time.monotonic()
rc_h, _, err_h = email(FX / "replies_mode_b.md", "--slot", SLOT, "--send", env=eh)
case("scenario hang: exit 4, no traceback", lambda: rc_h == 4 and "Traceback" not in err_h and time.monotonic() - t0 < 20)
case("--verify-delivery: 0 for the delivered slot", lambda: email("--verify-delivery", "--slot", SLOT, env=ed)[0] == 0)
case("--verify-delivery: 4 for the stuck slot",
     lambda: email("--verify-delivery", "--slot", SLOT, "--subject", "2 Twitter replies to write (2026-11-24 15:30)", env=ei)[0] == 4)
ef = fresh(STUB_FEEDBACK=FX / "feedback_reply.txt")
rc_f, out_f, _ = email("--feedback", env=ef)
fb = [json.loads(l) for l in out_f.splitlines() if l.strip()] if rc_f == 0 else []
def fb_ok():
    tr = next(m for m in fb if m["slot_id"] == "2026-11-24_2000")
    lv = next(m for m in fb if m["slot_id"] == "2026-11-24_1530")
    reasons = {mk["reason"] for m in fb for mk in m["marks"]}
    return (len(fb) == 2 and [mk["verdict"] for mk in tr["marks"]] == ["would_post", "would_not", "would_not"]
            and reasons == {"good", "boring", "forced", "wrong post", "too late"}
            and "the second thread was a promo really" in tr["free_text"] and "nice mail" in lv["free_text"]
            and "quoted original" not in json.dumps(fb))
case("--feedback reads a trial and a live reply: marks with reason words, unparsed lines in free_text", fb_ok)
eg = fresh(OSASCRIPT_BIN="/usr/bin/osascript")
case("PIPELINE_TEST=1 with a non-stub OSASCRIPT_BIN exits 2", lambda: email(FX / "replies_mode_b.md", "--slot", SLOT, env=eg)[0] == 2)
ex = fresh(PIPELINE_NOW="2026-11-24T13:50:00Z", STUB_MAIL_MODE="deliver")
rc_x, out_x, _ = email("--test", "--send", env=ex)
case("--test --send goes through the stub with a [TEST] subject and verification", lambda: rc_x == 0 and out_x.startswith("[TEST] Twitter reply email check") and sends(ex) == 1)

# ================================ T3 state ===================================================
print("=== T3 state ===")
def ss(*args, env):
    return py("slot_state.py", *args, env=env)
def budget(env, *extra):
    r = ss("budget", *(extra or ("--posted-today", "0")), env=env)
    return json.loads(r[1]) if r[0] == 0 else {"_rc": r[0], "_err": r[2]}
def state(env, **kv):
    p = Path(env["PIPELINE_STATE_DIR"]) / "delivery_state.json"
    cur = json.loads(p.read_text()) if p.exists() else {}
    cur.update(kv)
    wjson(p, cur)
def counts(env, days_back_values, today=None):
    base = dt.date(2026, 11, 24)
    wjson(Path(env["PIPELINE_STATE_DIR"]) / "posted_counts.json",
          {"days": {(base - dt.timedelta(days=i)).isoformat(): v for i, v in days_back_values.items()}})
for t, want in (("2026-11-24T13:41:00Z", "2026-11-24_1530"), ("2026-11-24T18:11:00Z", "2026-11-24_2000")):
    r = ss("slot-id", env=fresh(PIPELINE_NOW=t))
    case(f"slot id at {t} is {want[-5:]}", lambda r=r, want=want: r[0] == 0 and r[1].strip() == want)
for t in ("2026-11-24T14:45:00Z", "2026-11-24T07:00:00Z"):
    case(f"slot id exits 3 at {t}", lambda t=t: ss("slot-id", env=fresh(PIPELINE_NOW=t))[0] == 3)
s1 = fresh(PIPELINE_NOW=NOW)
b = budget(s1)
case("send_cutoff is 16:25 for the first slot", lambda: b.get("send_cutoff") == "16:25")
case("stage 1, no replies in 7 days: allowance 2, post_today 1", lambda: b["allowance_today"] == 2 and b["post_today"] == 1)
def cap_everywhere():
    caps = []
    for st in (1, 2, 3):
        env = fresh(PIPELINE_NOW=NOW)
        state(env, stage=st)
        caps.append(budget(env)["deliver_cap"])
    env = fresh(PIPELINE_NOW=NOW)
    write(Path(env["PIPELINE_ANALYTICS_DIR"]) / "weekly.md", "pinned_post_url: https://x.com/ogrizkov/status/1\n")
    ss("set-mode", "--slot", "15:30", "live", env=env)
    caps.append(budget(env)["deliver_cap"])
    state(env, paused_until="2026-12-01", pause_reason="tripwire")
    caps.append(budget(env)["deliver_cap"])
    return caps == [6] * 5
case("deliver_cap is 6 in trial and live, at stages 1-3, and during a pause", cap_everywhere)
b2 = budget(fresh(PIPELINE_NOW=NOW), "--posted-today", "2")
case("2 replies already today: today_more 0, post_today 0 with its reason, deliver_cap 6",
     lambda: b2["today_more"] == 0 and b2["post_today"] == 0 and "already posted 2" in b2["post_reason"] and b2["deliver_cap"] == 6)
s4 = fresh(PIPELINE_NOW=NOW); counts(s4, {i: 2 for i in range(1, 8)})
case("7-day average 2 at stage 1: allowance 4", lambda: budget(s4)["allowance_today"] == 4)
s5 = fresh(PIPELINE_NOW=NOW); counts(s5, {i: 1 for i in range(1, 8)}); state(s5, stage=2)
b5 = budget(s5)
case("stage 2, average 1: allowance 3, post_today at most 2", lambda: b5["allowance_today"] == 3 and b5["post_today"] == 2)
case("--partial gives post_today at most 1", lambda: budget(s5, "--posted-today", "0", "--partial")["post_today"] == 1)
bu = budget(s5, "--posted-today-unknown")
case("--posted-today-unknown gives post_today at most 1 and the 'stay within' line",
     lambda: bu["post_today"] == 1 and bu["today_line"] == "stay within 3 replies in total today")
g = fresh(PIPELINE_NOW=NOW)
case("grok_probe_needed true with no slot-log line", lambda: budget(g)["grok_probe_needed"] is True)
ss("log", "--slot", "2026-11-24_1530", "--reason", "no_pass", "--grok-calls", "2", "--grok-ok", "true", env=g)
case("grok_probe_needed false after a line with grok_ok true", lambda: budget(g)["grok_probe_needed"] is False)
ss("log", "--slot", "2026-11-24_1530", "--reason", "infra", "--grok-calls", "1", "--grok-ok", "false", env=g)
case("grok_probe_needed true after a failed call", lambda: budget(g)["grok_probe_needed"] is True)
def posted_days(env, n, start=dt.date(2026, 11, 10)):
    rows = [{"reply_url": f"https://x.com/ogrizkov/status/9{i}", "arm": "pipeline", "reading": "24h",
             "posted_at": z(dt.datetime(start.year, start.month, start.day, 15, tzinfo=dt.timezone.utc) + dt.timedelta(days=i)),
             "views": 50, "parent_views": 5000} for i in range(n)]
    wjsonl(Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", rows)
st6 = fresh(PIPELINE_NOW=NOW); posted_days(st6, 6)
case("set-stage 2 refused after 6 posting days", lambda: ss("set-stage", "2", "--reason", "x", env=st6)[0] == 1)
st7 = fresh(PIPELINE_NOW=NOW); posted_days(st7, 7)
case("set-stage 2 accepted after 7 posting days with no tripwire", lambda: ss("set-stage", "2", "--reason", "seven days", env=st7)[0] == 0)
b7 = budget(st7)
case("after a stage change the budget carries the stage_note", lambda: b7["stage"] == 2 and "Stage 2" in b7["stage_note"])
run_dir = T / "rec" / f"{SLOT}_batch"
shutil.copy(FX / "replies_mode_b.md", write(run_dir / "replies_to_post.md", "").parent / "replies_to_post.md")
ss("record", "--slot", SLOT, "--replies", run_dir / "replies_to_post.md", env=st7)
case("record clears the stage_note (shown once)", lambda: budget(st7)["stage_note"] == "")
stt = fresh(PIPELINE_NOW=NOW); posted_days(stt, 7)
ss("pause", "--days", "7", "--reason", "tripwire", env=stt)
case("set-stage 2 refused when a tripwire fired", lambda: ss("set-stage", "2", "--reason", "x", env=stt)[0] == 1)
bt = budget(stt)
case("a tripwire pause: stage 1, post_today 0 with the tripwire reason, deliver_cap 6",
     lambda: bt["stage"] == 1 and bt["post_today"] == 0 and bt["post_reason"].startswith("tripwire") and bt["deliver_cap"] == 6)
s3 = fresh(PIPELINE_NOW=NOW); state(s3, stage=2)
A3 = Path(s3["PIPELINE_ANALYTICS_DIR"])
wjson(A3 / "under_the_hood" / "2026-11.json", {"accountLabels": [], "postLabels": []})
case("set-stage 3 refused without a raise verdict", lambda: ss("set-stage", "3", "--reason", "x", env=s3)[0] == 1)
write(A3 / "period_2026-11-20.md", "# Period\n\nVerdict: raise. The operator confirms.\n")
wjson(A3 / "under_the_hood" / "2026-11.json", {"accountLabels": [{"label": "SpamHighRecall"}], "postLabels": []})
case("set-stage 3 refused without a label-free monthly report", lambda: ss("set-stage", "3", "--reason", "x", env=s3)[0] == 1)
wjson(A3 / "under_the_hood" / "2026-11.json", {"accountLabels": [], "postLabels": []})
case("set-stage 3 accepted with both", lambda: ss("set-stage", "3", "--reason", "raise", env=s3)[0] == 0)
sm = fresh(PIPELINE_NOW=NOW)
case("set-mode live refused while weekly.md has no pinned post URL", lambda: ss("set-mode", "--slot", "15:30", "live", env=sm)[0] == 1)
write(Path(sm["PIPELINE_ANALYTICS_DIR"]) / "weekly.md", "# Weekly\n\npinned_post_url: https://x.com/ogrizkov/status/123\n")
case("set-mode live accepted with one", lambda: ss("set-mode", "--slot", "15:30", "live", env=sm)[0] == 0)
sr = fresh(PIPELINE_NOW=NOW)
now = utc(NOW)
led = [
    {"item_id": "2026-11-24_1530#1", "slot_id": "2026-11-24_1530", "url": "https://x.com/a/status/1", "author": "alice", "tier": 1,
     "recommended": True, "reply_type": "clean", "hook": "H1", "delivered_at": z(now - dt.timedelta(minutes=30)), "starter": "s1"},
    {"item_id": "2026-11-24_1530#2", "slot_id": "2026-11-24_1530", "url": "https://x.com/b/status/2", "author": "bob", "tier": 1,
     "recommended": True, "reply_type": "deep", "ground_with": "CAK-01", "hook": "H4", "delivered_at": z(now - dt.timedelta(minutes=30)), "starter": "s2"},
    {"item_id": "2026-11-24_1530#3", "slot_id": "2026-11-24_1530", "url": "https://x.com/claudeai/status/3", "author": "claudeai", "tier": 3,
     "recommended": True, "reply_type": "clean", "hook": "H5", "delivered_at": z(now - dt.timedelta(minutes=30)), "starter": "s3"},
    {"item_id": "2026-11-14_1530#1", "slot_id": "2026-11-14_1530", "url": "https://x.com/c/status/4", "author": "carol", "tier": 1,
     "recommended": True, "reply_type": "deep", "ground_with": "DEV-06", "hook": "H2", "delivered_at": z(now - dt.timedelta(days=10, minutes=60)), "starter": "s4"},
    {"item_id": "2026-10-24_1530#1", "slot_id": "2026-10-24_1530", "url": "https://x.com/d/status/5", "author": "dave", "tier": 1,
     "recommended": True, "reply_type": "deep", "ground_with": "DEV-03", "hook": "H3", "delivered_at": z(now - dt.timedelta(days=31, minutes=60)), "starter": "s5"},
    {"item_id": "2026-11-21_1530#1", "slot_id": "2026-11-21_1530", "url": "https://x.com/e/status/6", "author": "erin", "tier": 1,
     "recommended": False, "reply_type": "deep", "ground_with": "DEV-07", "hook": "H6", "delivered_at": z(now - dt.timedelta(days=3)), "starter": "s6"},
]
led = led[3:] + led[:3]   # ledger order = delivery order: the three of today last
wjsonl(Path(sr["PIPELINE_STATE_DIR"]) / "delivered.jsonl", led)
wjsonl(Path(sr["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", [
    {"reply_url": "https://x.com/ogrizkov/status/91", "arm": "pipeline", "item_id": "2026-11-14_1530#1", "reading": "24h",
     "posted_at": z(now - dt.timedelta(days=10)), "views": 30, "parent_views": 3000},
    {"reply_url": "https://x.com/ogrizkov/status/92", "arm": "pipeline", "item_id": "2026-10-24_1530#1", "reading": "24h",
     "posted_at": z(now - dt.timedelta(days=31)), "views": 30, "parent_views": 3000}])
br = budget(sr)
case("recommended_today lists the author, the Deep count and the large-account count",
     lambda: "alice" in br["recommended_today"]["authors"] and br["recommended_today"]["deep"] == 1 and br["recommended_today"]["large"] == 1)
case("an entry posted 10 days ago rests (DEV-06, reuse 30d)", lambda: "DEV-06" in br["resting_entries"])
case("an entry posted 31 days ago does not rest (DEV-03)", lambda: "DEV-03" not in br["resting_entries"])
case("an entry delivered for review 3 days ago and not posted does not rest (DEV-07)", lambda: "DEV-07" not in br["resting_entries"])
case("hooks_recent lists the hooks of the last 2 delivered items", lambda: br["hooks_recent"] == ["H4", "H5"])
rr = fresh(PIPELINE_NOW=NOW)
ss("record", "--slot", SLOT, "--replies", run_dir / "replies_to_post.md", env=rr)
ss("record", "--slot", SLOT, "--replies", run_dir / "replies_to_post.md", env=rr)
case("record twice writes once", lambda: len((Path(rr["PIPELINE_STATE_DIR"]) / "delivered.jsonl").read_text().splitlines()) == 2)
def log_slots(env, reasons, start="2026-11-20"):
    d0 = dt.date.fromisoformat(start)
    i = 0
    for k, reason in enumerate(reasons):
        day = d0 + dt.timedelta(days=k // 2)
        hh = "1530" if k % 2 == 0 else "2000"
        e2 = dict(env); e2["PIPELINE_NOW"] = z(dt.datetime(day.year, day.month, day.day, 13 if hh == "1530" else 18, 20, tzinfo=dt.timezone.utc))
        ss("log", "--slot", f"{day.isoformat()}_{hh}", "--reason", reason, env=e2)
def health_at(env, now_s):
    e2 = dict(env); e2["PIPELINE_NOW"] = now_s
    return json.loads(ss("health", env=e2)[1])
H_NOW = "2026-11-24T18:25:00Z"
for label, reasons, want in (("2 guard stops in 10 slots raise the alarm", ["delivered"] * 7 + ["guard", "delivered", "guard"], True),
                             ("2 locked stops raise the alarm", ["delivered"] * 8 + ["locked", "locked"], True),
                             ("1 no_pass does not", ["delivered"] * 9 + ["no_pass"], False),
                             ("a grok_balance stop counts", ["delivered"] * 8 + ["grok_balance", "no_pass"], True)):
    he = fresh()
    log_slots(he, reasons)
    case(label, lambda he=he, want=want: health_at(he, H_NOW)["alarm"] is want)
case("the alarm stand-in receives --date, --entry and --source-persona Executioner",
     lambda: re.search(r"--date 2026-11-\d\d --entry ALARM reply pipeline \d\d:\d\d: .* --source-persona Executioner",
                       (Path(he["STUB_DIR"]) / "alarm_args.log").read_text()) is not None)
case("alarm lines are deduplicated (same reason inside 7 days exits 1)",
     lambda: ss("alarm", "--reason", "non_delivery", "--text", "again", env=dict(he, PIPELINE_NOW=H_NOW))[0] == 1)
ms = fresh()
ss("log", "--slot", "2026-11-24_1530", "--reason", "delivered", env=dict(ms, PIPELINE_NOW="2026-11-24T14:20:00Z"))
hm = health_at(ms, "2026-11-25T13:41:00Z")
case("a missing expected slot is reported and raises the alarm at once", lambda: hm["missed_slots"] == ["2026-11-24_2000"] and hm["alarm"] is True)
case("the missed slot is logged as missed", lambda: any(json.loads(l).get("reason") == "missed" and json.loads(l)["slot_id"] == "2026-11-24_2000"
                                                       for l in (Path(ms["PIPELINE_STATE_DIR"]) / "scheduler_log.jsonl").read_text().splitlines()))
sst = fresh(PIPELINE_NOW=H_NOW)
log_slots(sst, ["delivered"] * 11 + ["guard"])
ss("status", env=sst)
stx = Path(sst["STATUS_FILE"] if "STATUS_FILE" in sst else sst["PIPELINE_STATUS_FILE"]).read_text()
case("status rewrites the status file: last 10 slots, stage, posting recommendation, open alarms",
     lambda: stx.count("_1530 |") + stx.count("_2000 |") == 10 and "## Stage" in stx and "## Posting recommendation today" in stx and "## Open alarms" in stx)
case("status --line gives the mail line", lambda: ss("status", "--line", env=sst)[1].strip() == "Since the last mail: 1 slots, 1 without mail (guard). Stage 1.")
def trial(reasons_by_slot, weekend=True):
    env = fresh()
    days = [dt.date(2026, 11, 23) + dt.timedelta(days=i) for i in range(7)]  # Mon 23 .. Sun 29
    if not weekend:
        days = [d for d in days if d.weekday() < 5]
    for hh, reasons in reasons_by_slot.items():
        for d, reason in zip(days, reasons):
            ss("log", "--slot", f"{d.isoformat()}_{hh}", "--reason", reason, "--mode", "trial",
               env=dict(env, PIPELINE_NOW=z(dt.datetime(d.year, d.month, d.day, 13, tzinfo=dt.timezone.utc))))
    return ss("trial-report", env=env)[0]
case("trial report: 13 of 14 with full coverage exits 0", lambda: trial({"1530": ["delivered"] * 7, "2000": ["delivered"] * 6 + ["no_pass"]}) == 0)
case("trial report: 12 of 14 exits 1", lambda: trial({"1530": ["delivered"] * 6 + ["no_pass"], "2000": ["delivered"] * 6 + ["no_pass"]}) == 1)
case("trial report: missing weekend coverage exits 1", lambda: trial({"1530": ["delivered"] * 5, "2000": ["delivered"] * 5}, weekend=False) == 1)

# ================================ T4 targets =================================================
print("=== T4 targets ===")
tf = lambda *a, env: py("target_filter.py", *a, env=env)
t4 = fresh(PIPELINE_NOW=NOW, PIPELINE_WATCHLIST=wjson(T / "wl_empty.json", {"authors": [], "large": []}))
now = utc(NOW)
ago = lambda m: z(now - dt.timedelta(minutes=m))
def cand(name, followers, age, views=500, replies=10, post_type="discussion"):
    return {"url": f"https://x.com/{name}/status/1{abs(hash(name)) % 10**8}", "author": name, "author_followers": followers,
            "posted_at": ago(age), "views": views, "replies": replies, "lang": "en", "post_type": post_type}
cands = [cand("old", 5000, 250), cand("busy", 5000, 30, replies=55), cand("promo", 5000, 30, post_type="promo"),
         cand("tiny", 600, 30), cand("bigold", 150000, 80), cand("mid", 40000, 40),
         cand("lane", 150000, 40, replies=300), cand("t60", 5000, 60, views=100), cand("t150", 5000, 150, views=100),
         cand("v25k", 6000, 50, views=25000), cand("v2k", 6000, 45, views=2000), cand("mom", 7000, 30, views=4000),
         cand("t2mom", 40000, 20, views=30000), cand("t1nomom", 8000, 70, views=100),
         {**cand("noviews", 9000, 35), "views": None}]
url = {c["author"]: c["url"] for c in cands}
wjson(T / "t4" / "cands.json", {"candidates": cands})
b4 = wjson(T / "t4" / "budget.json", {**json.loads(ss("budget", "--posted-today", "0", env=t4)[1])})
rc4 = tf("prefilter", "--candidates", T / "t4" / "cands.json", "--budget", b4, "--out", T / "t4" / "surv.json", "--cuts", T / "t4" / "cuts.json", env=t4)
surv = json.loads((T / "t4" / "surv.json").read_text())
cuts = {c["url"]: c["reason"] for c in json.loads((T / "t4" / "cuts.json").read_text())["cuts"]}
order = [c["author"] for c in surv["survivors"]]
case("prefilter cuts with one reason each (too_old, too_many_replies, post_type, author_too_small, large_too_old)",
     lambda: rc4[0] == 0 and cuts == {url["old"]: "too_old", url["busy"]: "too_many_replies", url["promo"]: "post_type",
                                      url["tiny"]: "author_too_small", url["bigold"]: "large_too_old"})
case("a 40,000-follower author is kept as tier 2", lambda: next(c for c in surv["survivors"] if c["author"] == "mid")["tier"] == 2)
case("a 150,000-follower author at 40 minutes with 300 replies is kept in the lane", lambda: [c["author"] for c in surv["lane"]] == ["lane"])
case("a 60-minute candidate ranks before a 150-minute one", lambda: order.index("t60") < order.index("t150"))
case("inside a band a tier-1 post with 25,000 views ranks before one with 2,000", lambda: order.index("v25k") < order.index("v2k"))
case("a 30-minute post with 4,000 views counts as momentum", lambda: next(c for c in surv["survivors"] if c["author"] == "mom")["momentum"] is True)
case("tier-2 with momentum and tier-1 without have the same score; tier 1 first",
     lambda: (lambda a, b: a["score"] == b["score"] and order.index("t1nomom") < order.index("t2mom"))(
         next(c for c in surv["survivors"] if c["author"] == "t2mom"), next(c for c in surv["survivors"] if c["author"] == "t1nomom")))
case("a post with no view count has no momentum", lambda: next(c for c in surv["survivors"] if c["author"] == "noviews")["momentum"] is False)
case("every survivor carries parent_views_at_capture and momentum",
     lambda: all("parent_views_at_capture" in c and "momentum" in c for c in surv["survivors"] + surv["lane"]))
case("the age-band counts are written", lambda: surv["funnel"]["by_age_band"]["0-90"]["survivors"] > 0 and surv["funnel"]["by_age_band"]["91-210"]["survivors"] == 1)
threads = {"threads": [{"url": c["url"], "opening_post": "x", "top_replies": [], "engagement": {"views": c.get("views") or 0, "replies": 5}}
                       for c in surv["survivors"] + surv["lane"] if c["author"] != "t60"]}
wjson(T / "t4" / "threads.json", threads)
tf("rank", "--survivors", T / "t4" / "surv.json", "--threads", T / "t4" / "threads.json", "--out", T / "t4" / "ranked.json", env=t4)
ranked = json.loads((T / "t4" / "ranked.json").read_text())
case("rank cuts a survivor with no snapshot as thread_unreadable", lambda: {"url": url["t60"], "reason": "thread_unreadable"} in ranked["cuts"])
voice = write(T / "t4" / "voice.md", "<decision_rules>\n<rule>Authority zones — post fast: AI tooling and workflows, model selection for coding, indie shipping experience.</rule>\n</decision_rules>\n")
rz = tf("zones", "--voice", voice, "--out", Path(t4["PIPELINE_STATE_DIR"]) / "authority_zones.json", env=t4)
case("zones returns the list from a voice fixture", lambda: rz[0] == 0 and json.loads(rz[1])["zones"] == ["AI tooling and workflows", "model selection for coding", "indie shipping experience"])
case("zones exits 2 without the rule", lambda: tf("zones", "--voice", write(T / "t4" / "v2.md", "<decision_rules>\n</decision_rules>\n"), "--out", T / "t4" / "z2.json", env=t4)[0] == 2)
thread = json.loads(py("fetch_posts.py", "thread", "--url", "https://x.com/nateherk/status/2124541215333044480", env=t4)[1])
wjson(T / "t4" / "thread.json", thread)
tgt_base = {"url": thread["url"], "reply_type": "clean", "claim_origin": "thread", "zone": "AI tooling and workflows", "tier": 1, "move": "answers_question"}
def ci(target=None, draft=None, budget_over=None, source=None):
    tp = wjson(T / "t4" / "tgt.json", {**tgt_base, **(target or {})})
    dd = json.loads((FX / "hook_ok.json").read_text()); dd.update(draft or {})
    dp = wjson(T / "t4" / "draft.json", dd)
    bp = wjson(T / "t4" / "b.json", {**json.loads(b4.read_text()), **(budget_over or {})})
    args = ["check-item", "--target", tp, "--draft", dp, "--thread", T / "t4" / "thread.json", "--budget", bp]
    if source is not None:
        args += ["--source-text", write(T / "t4" / "src.txt", source)]
    r = tf(*args, env=t4)
    return r[0], (json.loads(r[1])["reasons"] if r[1].strip().startswith("{") else [r[2].strip()])
case("check-item: a verbatim quote passes", lambda: ci() == (0, []))
case("check-item: a paraphrased quote fails", lambda: "quote_not_verbatim" in ci(draft={"answers": "set autocompact at 400 thousand"})[1])
case("check-item: a public_source item without a source fails", lambda: "source_missing" in ci(target={"claim_origin": "public_source"})[1])
case("check-item: a source quote missing from the saved page fails",
     lambda: "source_quote_not_found" in ci(target={"claim_origin": "public_source", "source_url": "https://docs.example.com/a", "source_quote": "Compaction keeps the last 20 turns.", "basis": "the docs say so"}, source="Other text entirely.")[1])
case("check-item: a Clean item outside the zones fails outside_zones", lambda: "outside_zones" in ci(target={"zone": "cooking"})[1])
case("check-item: a yours line that is not a question fails", lambda: "yours_not_question" in ci(draft={"yours": "Tell them about your run."})[1])
case("check-item: a lane item with another move than a correction or a number fails", lambda: "large_move" in ci(target={"tier": 3, "move": "answers_question"})[1])
case("check-item: a second Deep item or a second question is not rejected here",
     lambda: ci(target={"reply_type": "deep", "ground_with": "CAK-05"}, budget_over={"recommended_today": {"authors": [], "deep": 1, "large": 0}})[0] == 0)
hk = tf("hooks", env=t4)
case("hooks: H1 and H2 allowed with short names, X1 banned (fixture sheet)",
     lambda: json.loads(hk[1]) == {"allowed": {"H1": "Question first, one concrete detail", "H2": "One noticed detail, then the question"}, "banned": ["X1"],
                                   "types": {"H1": "clean", "H2": "clean"}})
for fx_name, want in (("hook_missing.json", "hook_missing"), ("hook_unknown.json", "hook_unknown"), ("hook_banned.json", "hook_banned")):
    case(f"check-item: {fx_name} fails with {want}", lambda fx_name=fx_name, want=want: want in ci(draft={**{"hook": None}, **json.loads((FX / fx_name).read_text())})[1])
case("check-item: hook_ok fails with hook_recent when the budget lists H1", lambda: "hook_recent" in ci(budget_over={"hooks_recent": ["H1"]})[1])
case("check-item: an empty instruction line fails hook_instruction_missing",
     lambda: "hook_instruction_missing" in ci(draft={"hook": {"id": "H1", "name": "Question first", "instruction": ""}})[1])

# ================================ T5 produce =================================================
print("=== T5 produce ===")
def mk_run(name, items, review_extra=None, sheet=None):
    d = T / "t5" / name
    targets, drafts, results = [], [], []
    for i, it in enumerate(items):
        u = f"https://x.com/{it.get('author', 'a' + str(i))}/status/{1000 + i}"
        targets.append({"url": u, "author": it.get("author", f"a{i}"), "author_followers": it.get("followers", 5000),
                        "tier": it.get("tier", 1), "reply_type": it.get("type", "clean"), "claim_origin": "thread",
                        "ground_with": it.get("ground"), "posted_at": "2026-11-24T13:00:00Z", "age_min_at_capture": 41,
                        "parent_views_at_capture": 1000 + i, "rank": i})
        drafts.append({"url": u, "answers": f"quote {i}", "point": f"point {i}",
                       "hook": {"id": it.get("hook", f"H{i + 1}"), "name": "draft name", "instruction": f"Open with detail {i}."},
                       "draft": it.get("draft", f"Draft number {i} asks about step {i}?"), "verify_flags": []})
        results.append({"url": u, "status": it.get("status", "passed")})
    results += review_extra or []
    wjson(d / "01_anchored.json", {"batch": name, "targets": targets})
    wjson(d / "02_drafts.json", {"drafts": drafts})
    wjson(d / "03_review.json", {"results": results, "_calibration": {"result": "pass"}, "critic_model": "fixture critic"})
    return d
def produce(d, post_today=1, rec_today=None, sheet=None):
    b = wjson(d / "budget.json", {"slot_id": SLOT, "mode": "trial", "stage": 1, "post_today": post_today, "post_reason": "stage 1",
                                  "today_line": "2", "stage_note": "", "status_line": "Since the last mail: no slot without mail. Stage 1.",
                                  "deliver_cap": 6, "recommended_today": rec_today or {"authors": [], "deep": 0, "large": 0},
                                  "volume": {"author_per_day": 1, "deep_per_day": 1}, "large_per_day": 1,
                                  "tiers": {"large": {"per_run": 2}}})
    env = fresh()
    if sheet:
        env["PIPELINE_PATTERNS"] = str(sheet)
    r = py("produce.py", d, "--budget", b, env=env)
    md = (d / "replies_to_post.md").read_text() if r[0] == 0 else ""
    head = md.split("## Skipped")[0]
    items = re.findall(r"^### \d+\. (\S+)", head, re.M)
    skipped = md.split("## Skipped")[1].split("## Quarantined")[0] if "## Skipped" in md else ""
    marks = re.findall(r"^- mark: (\w+)", head, re.M)
    return md, items, skipped, marks
sheet8 = write(T / "t5" / "sheet8.md", "## Hooks\n\n" + "".join(f"### H{i} - Hook name {i}\n\n" for i in range(1, 9)) + "## Do not use\n\n- X1 - verdict\n")
md8, it8, sk8, _ = produce(mk_run("eight", [{"author": f"u{i}", "hook": f"H{i + 1}"} for i in range(8)]), sheet=sheet8)
case("8 passed items with 8 hooks: 6 delivered, 2 in Skipped (over cap)", lambda: len(it8) == 6 and sk8.count("over cap") == 2)
case("every item has HOOK (id · sheet name), OPEN, mark and views",
     lambda: len(re.findall(r"^- HOOK: H\d · Hook name \d$", md8, re.M)) == 6 and md8.count("- OPEN: ") == 6
     and md8.count("- mark: ") == 6 and md8.count("- views: ") == 6)
semi = "Caps aren;t the only way, weight credits by backend, 1x versus 25x"
mds, _, _, _ = produce(mk_run("semi", [{"author": "s1", "hook": "H1", "draft": semi}, {"author": "s2", "hook": "H2"}]))
case("drafts copied byte for byte, aren;t included", lambda: f"- DRAFT: {semi}\n" in mds)
case("no output line matches encoding|typo|artifact", lambda: not re.search(r"encoding|typo|artifact", mds, re.I))
_, itl, skl, _ = produce(mk_run("lane", [{"author": f"lab{i}", "tier": 3, "followers": 900000, "hook": f"H{i + 1}"} for i in range(3)]), sheet=sheet8)
case("3 passed lane items give 2 delivered", lambda: len(itl) == 2 and "large-account" in skl)
_, ith, skh, _ = produce(mk_run("samehook", [{"author": "h1", "hook": "H1"}, {"author": "h2", "hook": "H1"}]))
case("of two items with the same hook the lower-ranked one goes to Skipped", lambda: len(ith) == 1 and "h1" in ith[0] and "h2/status" in skh)
mdq, itq, _, _ = produce(mk_run("questions", [{"author": f"q{i}", "hook": f"H{i + 1}", "draft": f"Which setting did you use for case {i}?"} for i in range(4)]), sheet=sheet8)
case("a mail of 4 questions is written whole", lambda: len(itq) == 4)
_, it1, _, mk1 = produce(mk_run("pt1", [{"author": "p1", "hook": "H1"}, {"author": "p2", "hook": "H2"}]), post_today=1)
case("post_today 1: the top item recommended, the rest review", lambda: mk1 == ["recommended", "review"] and "p1" in it1[0])
md2, it2, _, mk2 = produce(mk_run("pt2", [{"author": "A", "type": "deep", "hook": "H1", "ground": "CAK-01"}, {"author": "A", "hook": "H2"},
                                          {"author": "B", "type": "deep", "hook": "H3", "ground": "CAK-02"}, {"author": "C", "hook": "H4"}],
                                   review_extra=[{"url": "https://x.com/dropped/status/1", "status": "dropped", "drop_reason": "forced_anchor"}]),
                           post_today=2, sheet=sheet8)
case("post_today 2: same author and a second Deep stay review; the next eligible is recommended; recommended first",
     lambda: mk2 == ["recommended", "recommended", "review", "review"] and "/A/" in it2[0] and "/C/" in it2[1])
lane_items = [{"author": "small1", "hook": "H1"}, {"author": "biglab", "tier": 3, "followers": 900000, "hook": "H2"}]
_, itL, _, mkL = produce(mk_run("laneplace", lane_items), post_today=1)
case("a passed lane item with an unused large place and post_today 1 is the recommended one",
     lambda: "biglab" in itL[0] and mkL[0] == "recommended" and mkL.count("recommended") == 1)
_, itL2, _, mkL2 = produce(mk_run("laneused", lane_items), post_today=1, rec_today={"authors": [], "deep": 0, "large": 1})
case("with the day's large place used the lane item is review",
     lambda: dict(zip([u.split("/")[3] for u in itL2], mkL2)).get("biglab") == "review")
mdS1 = produce(mk_run("short1", [{"author": "o1", "hook": "H1"}]), post_today=2)[0]
case("post_today 2 with 1 passed item: header post_today 1 and post_short 'only 1 item passed'",
     lambda: "\npost_today: 1\n" in mdS1 and "\npost_short: only 1 item passed\n" in mdS1)
mdSA = produce(mk_run("shortauthor", [{"author": "A", "hook": "H1"}, {"author": "A", "hook": "H2"}]), post_today=2)[0]
case("post_today 2, two items by one author: header post_today 1 and post_short names the author rule",
     lambda: "\npost_today: 1\n" in mdSA and re.search(r"^post_short: only 1 of 2 .*one per author a day", mdSA, re.M))
mdS0 = produce(mk_run("shortnone", [{"author": "A", "hook": "H1"}]), post_today=1, rec_today={"authors": ["A"], "deep": 0, "large": 0})[0]
case("every item blocked: header post_today 0 and post_reason says why",
     lambda: "\npost_today: 0\n" in mdS0 and re.search(r"^post_reason: only 0 of 1 .*one per author a day", mdS0, re.M))
case("no shortfall: post_short is empty and post_reason comes from the budget",
     lambda: "\npost_short: \n" in md2 and "\npost_reason: stage 1\n" in md2)
_, it0, _, mk0 = produce(mk_run("pt0",[{"author": "z1", "hook": "H1"}, {"author": "z2", "hook": "H2"}]), post_today=0)
case("post_today 0: every item review and all are still written", lambda: mk0 == ["review", "review"])
mdD, _, _, _ = produce(mk_run("dq", [{"author": "k1", "hook": "H1"}],
                               review_extra=[{"url": "https://x.com/k1/status/1000", "status": "passed"}]))
mdQ = mk_run("quar", [{"author": "g1", "hook": "H1"}, {"author": "g2", "hook": "H2", "status": "quarantined"}],
             review_extra=[])
mdQ_md = produce(mdQ)[0]
case("dropped and quarantined targets are listed", lambda: "dropped: forced_anchor" in md2 and "quarantined:" in mdQ_md)
case("the header holds post_today:, today_more: and status_line:", lambda: all(k in md8 for k in ("\npost_today: ", "\ntoday_more: ", "\nstatus_line: ")))

# ================================ T6 measure =================================================
print("=== T6 measure ===")
me = lambda *a, env: py("measure.py", *a, env=env)
m0 = fresh(PIPELINE_NOW=NOW)
me("init", env=m0)
case("init creates weekly.md and marks.md", lambda: (Path(m0["PIPELINE_ANALYTICS_DIR"]) / "weekly.md").exists() and (Path(m0["PIPELINE_ANALYTICS_DIR"]) / "marks.md").exists())
m1 = fresh(PIPELINE_NOW="2026-11-25T15:00:00Z")
base_t = utc("2026-11-24T13:00:00Z")
led6 = []
for i in range(13):
    led6.append({"item_id": f"{SLOT}#{i + 1}", "slot_id": SLOT, "url": f"https://x.com/au{i}/status/{500 + i}", "author": f"au{i}",
                 "tier": 3 if i == 0 else 1, "recommended": i < 2, "reply_type": "clean", "move": "practitioner_question" if i % 2 else "contradicts",
                 "hook": f"H{1 + i % 2}", "starter": "Which threshold did you pick for the long runs?", "parent_views_at_capture": 1000 + i,
                 "posted_at": z(base_t - dt.timedelta(minutes=40)), "delivered_at": z(base_t), "mode": "trial",
                 "post_by": z(base_t + dt.timedelta(hours=2))})
wjsonl(Path(m1["PIPELINE_STATE_DIR"]) / "delivered.jsonl", led6)
pages = []
for i in range(12):
    rd = {"parent_url": led6[i]["url"], "found": True, "reply_url": f"https://x.com/ogrizkov/status/77{i}",
          "text": "Which threshold did you pick for the long runs?" if i else "I ran this on 3 repos and the 400k cap held.",
          "posted_at": z(base_t + dt.timedelta(minutes=30)), "views": 20 + i, "likes": 1, "replies": 0, "parent_views": 9000 + i,
          "author_answered": i == 1, "reading": "24h"}
    if i == 1:
        rd["follow_up"] = {"url": "https://x.com/ogrizkov/status/7799", "text": "Thanks, then the 200k cap it is.", "posted_at": z(base_t + dt.timedelta(minutes=80))}
    pages.append(rd)
pages.append({"parent_url": led6[12]["url"], "found": False, "note": "no reply"})
pp = wjson(T / "t6" / "pages.json", pages)
me("merge", "--pages", pp, env=m1)
me("merge", "--pages", pp, env=m1)
log6 = [json.loads(l) for l in (Path(m1["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl").read_text().splitlines()]
pipe6 = [r for r in log6 if r["arm"] == "pipeline"]
case("merge over a page of 12 readings logs 12 rows once", lambda: len(pipe6) == 12)
case("no row for a delivered item he did not post", lambda: not any(r.get("item_id") == f"{SLOT}#13" for r in log6))
case("a follow-up is logged as arm follow_up and sets followed_up on the first reply",
     lambda: any(r["arm"] == "follow_up" for r in log6) and next(r for r in pipe6 if r["reply_url"].endswith("771"))["followed_up"] is True)
r0 = next(r for r in pipe6 if r["reply_url"].endswith("770"))
case("parent_views stored", lambda: r0["parent_views"] == 9000)
case("added_experience set for a posted text that adds 'I ran' to a Clean starter", lambda: r0["added_experience"] is True)
case("hook, move, tier, views at capture and the recommended mark copied from the ledger",
     lambda: (r0["hook"], r0["move"], r0["tier"], r0["parent_views_at_capture"], r0["recommended"]) == ("H1", "contradicts", 3, 1000, True))
def tw(views_list, parent_views):
    env = fresh(PIPELINE_NOW="2026-11-24T13:41:00Z")
    wjsonl(Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", [
        {"reply_url": f"https://x.com/ogrizkov/status/66{i}", "arm": "pipeline", "reading": "24h", "views": v, "parent_views": parent_views,
         "posted_at": z(utc("2026-11-20T10:00:00Z") + dt.timedelta(hours=i))} for i, v in enumerate(views_list)])
    r = me("tripwire", env=env)
    return json.loads(r[1])["tripped"], env
tripped, twe = tw([3, 5, 8, 2, 7], 2500)
btw = budget(twe)
case("tripwire: 5 replies at 8 views or fewer under parents above 2,000 set a 7-day pause",
     lambda: tripped and json.loads((Path(twe["PIPELINE_STATE_DIR"]) / "delivery_state.json").read_text())["paused_until"] == "2026-12-01")
case("after the tripwire the budget gives post_today 0, deliver_cap 6, stage 1", lambda: btw["post_today"] == 0 and btw["deliver_cap"] == 6 and btw["stage"] == 1)
case("the same 5 under parents with 800 views do not count", lambda: tw([3, 5, 8, 2, 7], 800)[0] is False)
case("4 such replies plus one at 9 views do not trip", lambda: tw([3, 5, 8, 2, 9], 2500)[0] is False)
def agreement(n_post, n_not, gate_change_after=None, review_marks=False):
    env = fresh(PIPELINE_NOW="2026-12-05T10:00:00Z")
    rows = []
    for i in range(n_post + n_not):
        rows.append({"item_id": f"2026-11-{(i % 20) + 1:02d}_1530#{i}", "slot_id": f"2026-11-{(i % 20) + 1:02d}_1530",
                     "url": f"https://x.com/m{i}/status/{i}", "recommended": not review_marks,
                     "delivered_at": z(utc("2026-11-01T10:00:00Z") + dt.timedelta(hours=i))})
    wjsonl(Path(env["PIPELINE_STATE_DIR"]) / "delivered.jsonl", rows)
    me("init", env=env)
    for i, r in enumerate(rows):
        me("marks", "--item", r["item_id"], "--verdict", "would_post" if i < n_post else "would_not", "--reason", "good", "--source", "chat", env=env)
    if gate_change_after is not None:
        gc = utc("2026-11-01T10:00:00Z") + dt.timedelta(hours=gate_change_after, minutes=30)
        write(Path(env["PIPELINE_ANALYTICS_DIR"]) / "gate_changes.md", f"- {z(gc)} · tightened rule 3\n")
    r = me("agreement", env=env)
    return r[0], json.loads(r[1])
case("agreement: 21 of 26 exits 0", lambda: agreement(21, 5)[0] == 0)
case("agreement: 20 of 26 exits 1", lambda: agreement(20, 6)[0] == 1)
case("agreement: 25 marks exits 1", lambda: agreement(21, 4)[0] == 1)
case("agreement: marks on review items count", lambda: agreement(21, 5, review_marks=True)[0] == 0)
case("agreement: after a recorded gate change only items delivered after it count",
     lambda: (lambda r: r[0] == 1 and r[1]["marked_items"] == 26 - 3)(agreement(21, 5, gate_change_after=2)))
def period_env(n, share_ok=True, answers=0, med_views=12, hook_split=(30, 5), moves=True, visits=None, day=14, live="2026-11-10"):
    env = fresh(PIPELINE_NOW="2026-11-24T20:00:00Z")
    state(env, live_since=live)
    rows, ledr = [], []
    for i in range(n):
        t = utc("2026-11-12T10:00:00Z") + dt.timedelta(hours=6 * i)
        iid = f"x#{i}"
        ledr.append({"item_id": iid, "slot_id": "s", "url": f"https://x.com/p{i}/status/{i}", "recommended": True,
                     "tier": 3 if i % 5 == 0 else 1, "momentum": i % 2 == 0, "delivered_at": z(t),
                     "post_by": z(t + dt.timedelta(hours=2) if share_ok else t - dt.timedelta(hours=1))})
        rows.append({"reply_url": f"https://x.com/ogrizkov/status/5{i}", "arm": "pipeline", "item_id": iid, "reading": "48h",
                     "posted_at": z(t + dt.timedelta(minutes=30)), "views": med_views, "tier": 3 if i % 5 == 0 else 1,
                     "move": "contradicts" if i % 2 else "practitioner_question", "hook": "H1" if i < hook_split[0] else "H2",
                     "author_answered": i < answers, "author_only_corrected": False, "type": "clean"})
    wjsonl(Path(env["PIPELINE_STATE_DIR"]) / "delivered.jsonl", ledr)
    wjsonl(Path(env["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", rows)
    wjson(Path(env["PIPELINE_ANALYTICS_DIR"]) / "under_the_hood" / "2026-11.json", {"accountLabels": [], "postLabels": []})
    if visits:
        write(Path(env["PIPELINE_ANALYTICS_DIR"]) / "weekly.md", "pinned_post_url: \n\n| week | profile visits | new follows |\n|---|---|---|\n"
              + "".join(f"| {w} | {v} | {f} |\n" for w, v, f in visits))
    wjson(Path(env["PIPELINE_ANALYTICS_DIR"]) / "../wl.json", {"authors": [{"handle": h} for h in ("aa", "bb", "cc", "dd", "ee", "ff")], "large": []})
    env["PIPELINE_WATCHLIST"] = str(Path(env["PIPELINE_ANALYTICS_DIR"]).parent / "wl.json")
    r = me("period", "--end", "2026-11-24", "--day", str(day), env=env)
    return (Path(env["PIPELINE_ANALYTICS_DIR"]) / "period_2026-11-24.md").read_text() if r[0] == 0 else r[2]
p_raise = period_env(40, answers=3, hook_split=(35, 5))
case("period: raise verdict", lambda: "Verdict: raise. The operator confirms." in p_raise)
p_hold = period_env(20, answers=1, hook_split=(15, 5))
case("period: hold with the second-run line", lambda: "Verdict: hold: decide on a second run inside the window. The operator confirms." in p_hold)
p_none = period_env(20, share_ok=False, answers=1, hook_split=(15, 5))
case("period: no volume change", lambda: "Verdict: no volume change. The operator confirms." in p_none)
case("period: posted share computed over recommended items only", lambda: "posted share: 40 of 40 recommended items posted in time = 1.00 (review items do not count)" in p_raise)
case("period: large-account lane against small authors table", lambda: "Large-account lane against small authors" in p_raise and "large account (tier 3)" in p_raise)
case("period: table by move", lambda: "### By move" in p_raise and "practitioner_question" in p_raise)
case("period: table of posts with and without momentum", lambda: "momentum at capture" in p_raise and "no momentum" in p_raise)
p_hook = period_env(35, answers=3, hook_split=(30, 5))
case("period: by-hook table, 30 replies judged and 5 'not judged'",
     lambda: re.search(r"\| H1 \| 30 \| 12 \| \d+ \| yes \|", p_hook) and "| H2 | 5 | - | - | not judged |" in p_hook)
p_bn = period_env(20, answers=1, hook_split=(15, 5), visits=[("week 0", 40, 3), ("week 1", 70, 3)])
case("period: bottleneck line when visits rise and follows are flat", lambda: "The profile is the bottleneck: visits rose and follows did not." in p_bn)
p28 = period_env(45, answers=1, hook_split=(40, 5), day=28, live="2026-10-27")
case("period: day 28 with 1 author answer gives the watchlist line with the weakest third",
     lambda: "Verdict: replace the weakest third of the watchlist; volume stays. The operator confirms." in p28 and "Weakest third of the watchlist" in p28 and "aa, bb" in p28)
ix = fresh(PIPELINE_NOW=NOW)
wjsonl(Path(ix["PIPELINE_ANALYTICS_DIR"]) / "reply_log.jsonl", [{"reply_url": "https://x.com/ogrizkov/status/123456789", "arm": "pipeline", "hook": "H1", "tier": 1}])
rp = me("import-export", "--file", write(T / "t6" / "per_post.csv", "Post id,Date,Impressions,Profile visits\n123456789,2026-11-20,300,4\n"), env=ix)
case("import-export: a per-post file with a profile-visits column is joined", lambda: rp[0] == 0 and "joined 1 rows" in rp[1])
ra = me("import-export", "--file", write(T / "t6" / "totals.csv", "Date,Profile visits,New follows\n2026-11-20,40,1\n"), env=ix)
case("import-export: an account-totals file falls back with its message", lambda: ra[0] == 0 and "account totals only" in ra[1])
ru = me("import-export", "--file", write(T / "t6" / "odd.csv", "Foo,Bar\n1,2\n"), env=ix)
case("import-export: an unknown layout exits 1 and prints the header row", lambda: ru[0] == 1 and "header: Foo | Bar" in ru[1])
du = fresh(PIPELINE_NOW=NOW)
case("due: patterns_refresh_due true with no proposal newer than 14 days", lambda: json.loads(me("due", env=du)[1])["patterns_refresh_due"] is True)
write(Path(du["PIPELINE_ANALYTICS_DIR"]) / "patterns_proposal_2026-11-20.md", "x")
case("due: patterns_refresh_due false with one", lambda: json.loads(me("due", env=du)[1])["patterns_refresh_due"] is False)
case("the stub send counter stays 0 throughout T6", lambda: not any((Path(e["STUB_DIR"]) / "sends.count").exists() for e in (m0, m1, twe, ix, du)))

# ================================ T7 preflight ================================================
print("=== T7 preflight ===")
PF = BIN / "preflight.sh"
def pf(env, *args):
    return run([BASH, PF, *args], env, timeout=120)
def penv(**extra):
    return fresh(**{"PIPELINE_NOW": NOW, "PIPELINE_GIT_BRANCH": "main", "PIPELINE_GIT_DIRTY": "0", **extra})
def slot_lines(env):
    p = Path(env["PIPELINE_STATE_DIR"]) / "scheduler_log.jsonl"
    return [json.loads(l) for l in p.read_text().splitlines()] if p.exists() else []
cnt = lambda env, f: int((Path(env["STUB_DIR"]) / f).read_text()) if (Path(env["STUB_DIR"]) / f).exists() else 0
p1 = penv()
r1 = pf(p1)
r2 = pf(p1)
tok1 = json.loads(r1[1])["run_token"] if r1[0] == 0 else ""
r3 = pf(p1, "--run-token", tok1)
case("a second session of the same slot while the lock is held exits 5 and writes a log line",
     lambda: r1[0] == 0 and r2[0] == 5 and slot_lines(p1)[-1]["reason"] == "locked")
case("the run token is written into the batch folder and passes the lock (RESUME / new attempt)",
     lambda: tok1 and (Path(os.environ["PIPELINE_RUNS_DIR"]) / "2026-11-24_1530_batch" / "run_token").read_text().strip() == tok1 and r3[0] == 0)
pf(p1, "--release")
pst = penv()
lock = Path(pst["PIPELINE_STATE_DIR"]) / ".run.lock"; lock.mkdir(parents=True)
write(lock / "started_at", str(int(utc(NOW).timestamp()) - 3 * 3600)); write(lock / "pid", "1")
case("a stale lock is taken over", lambda: pf(pst)[0] == 0)
pb = penv(PIPELINE_GIT_BRANCH="feat/x")
case("a non-main branch exits 6 and writes a log line", lambda: pf(pb)[0] == 6 and slot_lines(pb)[-1]["reason"] == "guard")
pg = penv()
ss("log", "--slot", "2026-11-23_2000", "--reason", "delivered", "--grok-calls", "2", "--grok-ok", "true", env=dict(pg, PIPELINE_NOW="2026-11-23T18:40:00Z"))
case("with a last line that has grok_ok true the grok stand-in is not called", lambda: pf(pg)[0] == 0 and cnt(pg, "grok.count") == 0)
pn = penv()
case("with no such line it is called once", lambda: pf(pn)[0] == 0 and cnt(pn, "grok.count") == 1)
pd = penv(STUB_AGY_DEAD="Gemini 4 Neon (High)")
case("a dead first rung makes the second rung win and critic_model.json names it",
     lambda: pf(pd)[0] == 0 and json.loads((Path(pd["PIPELINE_STATE_DIR"]) / "critic_model.json").read_text())["telemetry_id"] == "gemini-4-argon-high")
pq = penv()
wjson(Path(pq["PIPELINE_STATE_DIR"]) / "critic_qualified.json", {"gemini-4-neon-high": {"result": "fail", "at": "2026-11-23T10:00:00Z"}})
case("a rung with a failed qualification is skipped",
     lambda: pf(pq)[0] == 0 and "Gemini 4 Neon" not in (Path(pq["STUB_DIR"]) / "cli_calls.log").read_text()
     and json.loads((Path(pq["PIPELINE_STATE_DIR"]) / "critic_model.json").read_text())["telemetry_id"] == "gemini-4-argon-high")
pbal = penv(STUB_GROK="balance")
rb = pf(pbal)
case("grok '402 ... balance exhausted' exits 11 with 'grok balance exhausted' and a grok_balance log line",
     lambda: rb[0] == 11 and "grok balance exhausted" in rb[1] + rb[2] and slot_lines(pbal)[-1]["reason"] == "grok_balance")
pe = penv(PIPELINE_FETCH_DIR=T / "empty_fetch")
(T / "empty_fetch").mkdir(exist_ok=True)
re_ = pf(pe)
case("an endpoint that does not answer gives exit 0 with endpoint_ok false", lambda: re_[0] == 0 and json.loads(re_[1])["endpoint_ok"] is False)
pdr = penv(); write(Path(pdr["STUB_DIR"]) / "mail_drafts", "[TRIAL] 2 Twitter reply ideas (2026-11-23 20:00)\n")
case("a Drafts message with the pipeline subject exits 9", lambda: pf(pdr)[0] == 9)
pob = penv(); write(Path(pob["STUB_DIR"]) / "mail_outbox", "something stuck\n")
case("an Outbox message exits 9", lambda: pf(pob)[0] == 9)
pm = penv(PIPELINE_PATTERNS=T / "nope" / "reply_patterns.md")
rm_ = pf(pm)
case("a missing pattern sheet exits 10 with the message naming the path", lambda: rm_[0] == 10 and str(T / "nope" / "reply_patterns.md") in rm_[2])
pu = penv(PIPELINE_PATTERNS=write(T / "nohook.md", "## Do not use\n\n- X1 - verdict\n"))
case("a sheet with no usable hook exits 10", lambda: pf(pu)[0] == 10)

# ================================ T8 run_traced ===============================================
print("=== T8 run_traced ===")
rt = T / "rt"; rt.mkdir()
t0 = time.monotonic()
r8 = run([BASH, BIN / "run_traced.sh", "--run-dir", rt, "--role", "t", "--out", rt / "o", "--timeout", "2", "--", "sleep", "30"], dict(os.environ), timeout=30)
el = time.monotonic() - t0
tel = [json.loads(l) for l in (rt / "_telemetry.jsonl").read_text().splitlines()]
case("--timeout 2 around sleep 30 returns 124 within 10 s, outcome timeout", lambda: r8[0] == 124 and el < 10 and tel[-1]["outcome"] == "timeout")
run([BASH, BIN / "run_traced.sh", "--run-dir", rt, "--role", "t", "--out", rt / "o2", "--", "echo", "no block here"], dict(os.environ))
case("output with no fenced json gives outcome no_block", lambda: json.loads((rt / "_telemetry.jsonl").read_text().splitlines()[-1])["outcome"] == "no_block")

# ================================ T9 probes ===================================================
print("=== T9 probes ===")
probes = json.loads((C / "tests" / "critic_probes.json").read_text())["probes"]
REQ = ("id", "url", "snapshot", "reply_type", "author_claim", "move", "grounded_claim", "draft", "expect", "expect_fail", "why")
case("critic_probes.json is valid JSON with 7 probes", lambda: len(probes) == 7)
case("every probe has every required field", lambda: all(all(k in p for k in REQ) for p in probes))
case("no null snapshot", lambda: all(isinstance(p["snapshot"], dict) and p["snapshot"].get("opening_post") for p in probes))
case("exactly one SHIP probe", lambda: sum(p["expect"] == "SHIP" for p in probes) == 1)
QC = BIN / "qualify_critic.sh"
picks = [run([BASH, QC, "--pick", "--slot", s], dict(os.environ))[1].split() for s in ("2026-11-24_1530", "2026-11-24_2000")]
kind = {p["id"]: p["expect"] for p in probes}
case("--pick returns one must-fail and one must-ship probe", lambda: sorted(kind[i] for i in picks[0]) == ["FIX", "SHIP"])
case("the must-fail probe changes across slots", lambda: picks[0][0] != picks[1][0])
case("--evaluate critic_out_calibrated.json exits 0", lambda: run([BASH, QC, "--evaluate", FX / "critic_out_calibrated.json", "--model", "x"], dict(os.environ))[0] == 0)
case("critic_out_ships_all.json exits 1", lambda: run([BASH, QC, "--evaluate", FX / "critic_out_ships_all.json", "--model", "x"], dict(os.environ))[0] == 1)
cal = json.loads((FX / "critic_out_calibrated.json").read_text())
for r in cal["results"]:
    if r["critic_verdict"] == "SHIP":
        r["critic_verdict"] = "FIX"
case("an output that fails the must-ship probe exits 1", lambda: run([BASH, QC, "--evaluate", wjson(T / "cal_bad.json", cal), "--model", "x"], dict(os.environ))[0] == 1)

# ================================ T10 docs ====================================================
print("=== T10 docs ===")
GS = os.environ["V_GREP_SECTION"]
RS = C / "agents" / "role_specs"
RB = C / "skill" / "twitter-reply-orchestrate.md"
pairs = [(RS / "matcher.md", "Claim-first fit test"), (RS / "matcher.md", "Reply types (Deep and Clean)"),
         (RS / "critic.md", "Rubric v1.4"), (RS / "critic.md", "Interest review (rule 11)"), (RS / "critic.md", "Calibration probes"),
         (RS / "drafter.md", "Interest first"), (RS / "drafter.md", "Starter draft rules"), (RS / "scout.md", "Target limits (rule 10)"),
         (RS / "wins.md", "Pattern refresh")] + [(RB, h) for h in ("UNATTENDED MODE", "DELIVERY", "MAINTENANCE", "MEASUREMENT", "LEARNING", "TRIAL AND LAUNCH")]
for f, h in pairs:
    case(f"grep_section {f.name} '{h}' populated", lambda f=f, h=h: run(["bash", GS, f, h, "populated"], dict(os.environ))[0] == 0)
txt = lambda p: Path(p).read_text()
case("claimed_contribution occurs 0 times in critic.md and the runbook", lambda: "claimed_contribution" not in txt(RS / "critic.md") + txt(RB))
ladder = json.loads(txt(C / "agents" / "critic_ladder.json"))
names = [v for r in ladder["rungs"] for v in (r["cli_name"], r["telemetry_id"])]
scan = [RB, C / "agents" / "roster.md", C / "AGENTS_CONSTRAINTS.md", C / "PIPELINE_OVERVIEW.md", C / "skill" / "scheduled_task_prompt.md"] \
       + sorted(RS.glob("*.md")) + [BIN / n for n in ("gate.sh", "verify_gate.sh", "email_replies.py", "run_traced.sh", "batch_report.sh",
                                                     "preflight.sh", "slot_state.py", "target_filter.py", "fetch_posts.py", "produce.py",
                                                     "measure.py", "qualify_critic.sh")]
hits = [(p.name, n) for p in scan if p.exists() for n in names if n in txt(p)]
case("no ladder cli_name or telemetry_id occurs in runbook, roster, role specs, constraints, overview, scheduled prompt or bin scripts", lambda: not hits)
if hits:
    print("      hits:", hits[:6])
sp = txt(C / "skill" / "scheduled_task_prompt.md") if (C / "skill" / "scheduled_task_prompt.md").exists() else ""
case("the scheduled prompt states 15:30 and 20:00 and holds no cap and no model name",
     lambda: "15:30" in sp and "20:00" in sp and not re.search(r"TARGET|MAX_|max_grok|\bcap\b|Gemini|Claude [A-Z]|claude-|gpt|grok-", sp, re.I))
pj = json.loads(txt(C / "agents" / "params.json"))
D1 = ["timezone", "slots", "runs_per_window", "slot_grace_min", "timing", "capture", "ranking", "tiers", "volume", "reuse_days", "thin_run",
      "tripwire", "alarm", "trial", "hooks", "measure", "cost", "endpoint", "delivery", "lock_stale_min", "critic_qualified_days", "probes_per_call"]
case("params.json: all D1 keys, max_grok_calls 3, runs_per_window 1, no question cap",
     lambda: all(k in pj for k in D1) and pj["cost"]["max_grok_calls"] == 3 and pj["runs_per_window"] == 1 and "question" not in json.dumps(pj))
case("critic_ladder.json: 4 rungs with cli_name, telemetry_id, provider; no Claude or GPT rung",
     lambda: len(ladder["rungs"]) == 4 and all(set(r) == {"cli_name", "telemetry_id", "provider"} for r in ladder["rungs"])
     and not re.search(r"claude|gpt|opus|sonnet", json.dumps(ladder["rungs"]), re.I))
wl = json.loads(txt(C / "agents" / "watchlist.json"))
case("watchlist.json: authors 1,000-20,000, large above 125,000, every handle in its source file",
     lambda: wl["authors"] and wl["large"] and all(1000 <= e["followers"] <= 20000 for e in wl["authors"])
     and all(e["followers"] > 125000 for e in wl["large"])
     and all(re.search(rf"@?\b{re.escape(e['handle'])}\b", txt(C / e["source"])) for e in wl["authors"] + wl["large"])
     and all(e["source"].startswith("council/2026-11-23/raw/") for e in wl["authors"] + wl["large"]))
stg = C / "strategy.md"
STRAT = ["23 November 2026", "58", "A project fact only when it answers, contradicts or measures the post's claim; otherwise one checkable point the thread lacks.",
         "Original posts: 2-4 a week. Replies: the pipeline delivers up to 6 items per run for review; how many to post each day follows the stages (2, then 4, then 6 pipeline replies a day).",
         "Reply runs start at 15:30 and 20:00 Israel, so the mail is in the inbox when the posting windows open at 16:30 and 21:00; post within 2 h or skip.",
         "Max 1 reply per author per day; 1 a day under accounts of 125k+; no agreement-only drafts; 10 replies a day at most.",
         "Never say in a reply how it was written. Never deny AI drafting if asked."]
case("strategy.md holds the six new strings and the added line", lambda: stg.exists() and all(s in txt(stg) for s in STRAT))
vt = txt(C.parents[1] / "voice.md")
case("voice.md holds the new rule and the Gemma-4 example",
     lambda: "When there is no draft of his, do not imitate his mistakes." in vt and "Gemma" in vt and "voice example only; hardware details stay out of replies" in vt)
au = txt(C / "project_authority.md")
ent = re.split(r"^### (?=[A-Z]{2,4}-\d+)", au, flags=re.M)[1:]
case("every authority entry has reuse: 30d", lambda: len(ent) == 30 and all(re.search(r"^- reuse: 30d$", e, re.M) for e in ent))
cr = txt(RS / "critic.md")
case("critic.md: the two B2 sentences, tell (j) and the question sentence",
     lambda: "Never reject for a missing project fact. Never pass because of a project noun." in cr and "(j)" in cr and "opens with a verdict on the post" in cr
     and "A question passes only when it names something concrete from the post and does not ask what the post already says." in cr)
dr = txt(RS / "drafter.md")
case("drafter.md: names reply_patterns.md, X1, X2, X7, the question rule, hook never overrides, examples never copied",
     lambda: all(s in dr for s in ("reply_patterns.md", "X1", "X2", "X7", "never asks what the post already says",
                                   "a hook never overrides", "The examples in the pattern sheet are other people's replies. They show a shape. They are never copied.")))
case("wins.md says the pattern sheet is never changed by a run", lambda: "The pattern sheet itself is never changed by a run" in txt(RS / "wins.md"))
rb = txt(RB)
case("runbook: grok for the discovery search only, fetch_posts.py for reads, append_log.sh for alarms, no board or queue_attention alarm path",
     lambda: "grok is used only for the discovery search" in rb and "fetch_posts.py" in rb and "append_log.sh" in rb
     and "queue_attention" not in rb and not re.search(r"board line|_Board\.md", rb))

# ================================ T11 fetch_posts =============================================
print("=== T11 fetch_posts ===")
fe = fresh(PIPELINE_NOW=NOW)
fp = lambda *a, env=fe: py("fetch_posts.py", *a, env=env)
P_URL = "https://x.com/nateherk/status/2124541215333044480"
th = json.loads(fp("thread", "--url", P_URL)[1])
case("thread on fx_conversation.json: opening post, top replies with URLs, counts, op_replies_in_thread, followers, post time",
     lambda: th["opening_post"].startswith("My favorite Claude Code tip") and th["top_replies"] and all(r["url"].startswith("https://x.com/") for r in th["top_replies"])
     and th["engagement"]["views"] == 48969 and th["op_replies_in_thread"] == 0 and th["author_followers"] == 38157 and th["posted_at"] == "2026-11-22T16:31:12Z")
stt_ = json.loads(fp("status", "--url", P_URL)[1])
case("status on fx_status.json: views, likes, replies, post time", lambda: (stt_["views"], stt_["likes"], stt_["replies"], stt_["posted_at"]) == (48969, 534, 128, "2026-11-22T16:31:12Z"))
fx_dir = Path(os.environ["PIPELINE_FETCH_DIR"])
conv = json.loads((FX / "fx_conversation.json").read_text())
mine = next(r for r in conv["replies"] if r["author"]["screen_name"] == "efraindev")
answer = {**conv["status"], "id": "2124570000000000001", "url": "https://x.com/nateherk/status/2124570000000000001",
          "text": "@efraindev 200k works too, depends on the task", "raw_text": {"text": "@efraindev 200k works too, depends on the task", "display_text_range": [11, 46]},
          "replying_to": {"screen_name": "efraindev", "status": mine["id"]}}
fxa = T / "fetch_answer"; shutil.copytree(fx_dir, fxa)
wjson(fxa / f"conversation_{mine['id']}.json", {"code": 200, "status": mine, "thread": [conv["status"], mine], "replies": [answer]})
fa = fresh(PIPELINE_NOW=NOW, PIPELINE_FETCH_DIR=fxa)
my = json.loads(fp("my-reply", "--parent", P_URL, "--handle", "efraindev", env=fa)[1])
case("my-reply finds the reply by handle and reports the author's answer",
     lambda: my["found"] and my["reply_url"].endswith(mine["id"]) and my["author_answered"] and my["author_answer_text"] == "200k works too, depends on the task")
case("my-reply reports 'unknown', not 'no reply', when a cursor remains unread", lambda: json.loads(fp("my-reply", "--parent", P_URL, "--handle", "ogrizkov")[1]).get("note") == "unknown")
fxn = T / "fetch_nocursor"; shutil.copytree(fx_dir, fxn)
wjson(fxn / "conversation_2124541215333044480.json", {k: v for k, v in conv.items() if k != "cursor"})
case("my-reply reports 'no reply' when there is none and no cursor remains",
     lambda: json.loads(fp("my-reply", "--parent", P_URL, "--handle", "ogrizkov", env=fresh(PIPELINE_NOW=NOW, PIPELINE_FETCH_DIR=fxn))[1]).get("note") == "no reply")
fpro = T / "fetch_profile"; shutil.copytree(fx_dir, fpro)
wjson(fpro / "profile_ogrizkov.json", {"code": 200, "user": {"screen_name": "ogrizkov", "statuses": 975, "followers": 58}})
fr = fresh(PIPELINE_NOW=NOW, PIPELINE_FETCH_DIR=fpro)
wjson(Path(fr["PIPELINE_STATE_DIR"]) / "posted_counts.json", {"profile_totals": {"2026-11-23": 971}})
rcnt = json.loads(fp("reply-count", "--handle", "ogrizkov", env=fr)[1])
case("reply-count returns the profile difference when a profile answer is saved", lambda: rcnt["count"] == 4 and rcnt["partial"] is False)
fr2 = fresh(PIPELINE_NOW=NOW)
rc2 = json.loads(fp("reply-count", "--handle", "ogrizkov", env=fr2)[1])
case("reply-count gives a partial count otherwise", lambda: rc2["partial"] is True)
rnf = fp("status", "--url", "https://x.com/a/status/1")
case("a missing saved answer exits 4 with not_found", lambda: rnf[0] == 4 and rnf[2].strip() == "not_found")
write(fx_dir / "status_2.json", "{broken")
rbr = fp("status", "--url", "https://x.com/a/status/2")
case("a broken answer exits 4 with endpoint_shape", lambda: rbr[0] == 4 and rbr[2].strip() == "endpoint_shape")
nofd = {k: v for k, v in fe.items() if k != "PIPELINE_FETCH_DIR"}
case("PIPELINE_TEST=1 and no PIPELINE_FETCH_DIR exits 2", lambda: fp("status", "--url", P_URL, env=nofd)[0] == 2)

sys.exit(0 if ok_all else 1)
PY
py_rc=$?
[ "$py_rc" -eq 0 ] || PASS=0
[ "$py_rc" -le 1 ] || echo "E2: python harness crashed (rc=$py_rc)" >&2

echo "===== VERDICT: $([ $PASS -eq 1 ] && echo 'ALL PASS' || echo 'FAIL') ====="
[ "$py_rc" -gt 1 ] && exit 2
[ $PASS -eq 1 ] && exit 0 || exit 1
