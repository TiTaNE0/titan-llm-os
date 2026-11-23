#!/usr/bin/env python3
"""Render a batch's replies_to_post.md (v3.2, delivery mode B) as a mobile-friendly HTML email.

Usage:
  email_replies.py REPLIES_MD [--slot SLOT_ID] [--send]
  email_replies.py --verify-delivery --slot SLOT_ID [--subject S]
  email_replies.py --feedback
  email_replies.py --test --send [REPLIES_MD]      (main session only; never in unattended mode)

Writes <batch>/email.html and prints the subject. Only the text before the first "## Skipped" or
"## Quarantined" is parsed; the held check looks at the header only. An item is mailed only with
URL, HOOK, OPEN, QUOTE, POINT and DRAFT (a public_source item also SOURCE and BASIS).
--send goes iCloud -> iCloud through Mail.app on this Mac. Gmail is not used: it rewrites every link
through google.com/url, which stops a tap from opening the X app. A send counts only when the
message is in Mail's Sent mailbox and neither Outbox nor Drafts holds it (incident I-9).
Exit: 0 built, or sent and verified; 2 usage or test guard; 3 nothing sendable (silent);
4 not delivered (reason on stderr: not_in_sent, stuck_outbox, stuck_draft, send_error, state_unknown,
send_state_unknown, timeout); 6 slot already sent.
A send is issued only after the Sent/Outbox/Drafts check answers and shows the message in none of
them; when Mail does not answer (error or time limit) nothing is sent (state_unknown). A send or a
check that hangs after the send was issued gives send_state_unknown: the message may exist, so a
retry goes through the same check first and never sends blindly. No Mail hang ends in a traceback. The operator only wants mail that contains real replies.
"""
import argparse
import datetime as dt
import html
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from zoneinfo import ZoneInfo

NOTHING_TO_SEND = 3
NOT_DELIVERED = 4
ALREADY_SENT = 6
STATE_UNKNOWN = "state_unknown"
SEND_UNKNOWN = "send_state_unknown"
ICLOUD = "evgeniy.ogrizkov@icloud.com"
BIN = Path(__file__).resolve().parent
C = BIN.parent
STUBS = (C / "tests" / "stubs").resolve()
STATE = Path(os.environ.get("PIPELINE_STATE_DIR") or C / "runs" / "_index")
PARAMS = json.loads(Path(os.environ.get("PIPELINE_PARAMS") or C / "agents" / "params.json").read_text())
TZ = ZoneInfo(PARAMS["timezone"])
OSASCRIPT = os.environ.get("OSASCRIPT_BIN") or "osascript"
REQUIRED = ("HOOK", "OPEN", "QUOTE", "POINT", "DRAFT")
FEEDBACK_LINE = ("Feedback: reply to this mail, one line per item: the number, then + or -, then a word: "
                 "good, boring, forced, wrong post, too late. Example: 1 + good / 2 - forced")
REASON_WORDS = ("good", "boring", "forced", "wrong post", "too late")

# Every script takes the action tag as item 1, so one stand-in can answer all of them in tests.
SEND_SCRIPT = """
on run argv
  set theSubject to item 2 of argv
  set theBody to item 3 of argv
  set theAddr to item 4 of argv
  tell application "Mail"
    set msg to make new outgoing message with properties {subject:theSubject, visible:false, sender:theAddr}
    tell msg
      make new to recipient at end of to recipients with properties {address:theAddr}
      set html content to theBody
    end tell
    send msg
  end tell
end run"""

QUERY_SCRIPT = """
on run argv
  set theSubject to item 2 of argv
  tell application "Mail"
    set s to count of (messages of sent mailbox whose subject is theSubject)
    set o to count of (messages of outbox whose subject is theSubject)
    set d to count of (messages of drafts mailbox whose subject is theSubject)
  end tell
  return "sent=" & s & " outbox=" & o & " drafts=" & d
end run"""

FEEDBACK_SCRIPT = """
on run argv
  set theAddr to item 2 of argv
  set out to ""
  tell application "Mail"
    set msgs to (messages of inbox whose subject begins with "Re:" and subject contains "Twitter repl" and sender contains theAddr)
    repeat with m in msgs
      set out to out & "<<<MSG>>>" & linefeed & "id: " & (message id of m) & linefeed & "subject: " & (subject of m) & linefeed & linefeed & (content of m) & linefeed
    end repeat
  end tell
  return out
end run"""


def now_utc():
    v = os.environ.get("PIPELINE_NOW")
    if not v:
        return dt.datetime.now(dt.timezone.utc)
    t = dt.datetime.fromisoformat(v.replace("Z", "+00:00"))
    return (t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)).astimezone(dt.timezone.utc)


def parse_ts(s):
    try:
        t = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


# ---------- parsing ---------------------------------------------------------------
def split_sections(md):
    return re.split(r"^## (?:Skipped|Quarantined)\b", md, maxsplit=1, flags=re.M)[0]


def parse_header(md):
    head = md.split("\n### ", 1)[0]
    h = {}
    for line in head.splitlines():
        m = re.match(r"^([a-z_]+):\s?(.*)$", line)
        if m:
            h[m.group(1)] = m.group(2).strip()
    return h, head


def parse_items(md):
    items = []
    for block in re.split(r"^### ", split_sections(md), flags=re.M)[1:]:
        lines = block.splitlines()
        m = re.match(r"(\d+)\.\s+(https://\S+)", lines[0])
        if not m:
            continue
        it = {"n": m.group(1), "url": m.group(2), "VERIFY": []}
        for l in lines[1:]:
            fm = re.match(r"-\s+([A-Za-z_]+):\s?(.*)", l)
            if not fm:
                continue
            k, v = fm.group(1), fm.group(2).strip()
            if k == "VERIFY":
                it["VERIFY"].append(v)
            else:
                it[k] = v
        if all(it.get(k) for k in REQUIRED) and (
                it.get("claim") != "public_source" or (it.get("SOURCE") and it.get("BASIS"))):
            items.append(it)
    return sorted(items, key=lambda i: 0 if i.get("mark") == "recommended" else 1)


# ---------- timing ------------------------------------------------------------------
def slot_parts(slot_id):
    m = re.match(r"^(\d{4}-\d{2}-\d{2})_(\d{2})(\d{2})", slot_id or "")
    if not m:
        return None
    return dt.date.fromisoformat(m.group(1)), f"{m.group(2)}:{m.group(3)}"


def window_end(slot_id):
    parts = slot_parts(slot_id)
    if not parts:
        return None
    day, hhmm = parts
    for s in PARAMS["slots"]:
        if hhmm in s["starts"]:
            h, mi = map(int, s["window"][1].split(":"))
            return dt.datetime(day.year, day.month, day.day, h, mi, tzinfo=TZ)
    return None


def post_by(it, slot_id, sent_at):
    limits = [sent_at + dt.timedelta(minutes=PARAMS["timing"]["post_within_min"])]
    we = window_end(slot_id)
    if we:
        limits.append(we)
    pt = parse_ts(it.get("posted_at"))
    if pt:
        limits.append(pt + dt.timedelta(minutes=PARAMS["timing"]["land_within_min"]))
    return min(limits).astimezone(TZ).strftime("%H:%M")


# ---------- html ---------------------------------------------------------------------
def esc(s):
    return html.escape(s or "")


def line(label, value, size=15):
    return (f'<div style="font-size:{size}px;line-height:1.45;color:#3b2a1a;margin-bottom:10px;">'
            f'<span style="color:#7a6248;">{esc(label)}</span> {esc(value)}</div>')


def card(it, trial, slot_id, sent_at):
    rec = it.get("mark") == "recommended"
    badges = [("Recommended to post" if rec else "For review", "#5b3f24" if rec else "#9a8466")]
    if it.get("lane") == "large":
        badges.append(("Large account", "#8a4b1f"))
    if trial:
        badges.append(("TRIAL", "#6b6b6b"))
    badge_html = "".join(f'<span style="display:inline-block;background-color:{c};color:#f7ecd8;font-size:12px;'
                         f'border-radius:6px;padding:2px 8px;margin:0 6px 6px 0;">{esc(t)}</span>' for t, c in badges)
    meta = (f"#{it['n']} &middot; @{esc(it.get('author'))} &middot; {esc(it.get('followers'))} followers &middot; "
            f"tier {esc(it.get('tier'))} &middot; {esc(it.get('age_min'))} min old &middot; {esc(it.get('views'))} views at capture")
    parts = [f'<div style="font-size:13px;color:#7a6248;margin-bottom:6px;">{meta}</div>', f"<div>{badge_html}</div>",
             f'<div style="font-size:13px;margin-bottom:10px;word-break:break-all;"><a href="{esc(it["url"])}" style="color:#8a4b1f;">{esc(it["url"])}</a></div>',
             line("They wrote:", it["QUOTE"]), line("Angle:", it["POINT"]), line("How to open:", it["OPEN"]),
             line("Starter (rewrite in your own words):", it["DRAFT"], 17)]
    if it.get("YOURS"):
        parts.append(line("Yours?", it["YOURS"]))
    if it.get("claim") == "public_source":
        parts.append(f'<div style="font-size:14px;margin-bottom:6px;word-break:break-all;"><span style="color:#7a6248;">Source:</span> '
                     f'<a href="{esc(it["SOURCE"])}" style="color:#8a4b1f;">{esc(it["SOURCE"])}</a></div>')
        parts.append(line("Why it holds:", it["BASIS"], 14))
    for v in it["VERIFY"]:
        parts.append(line("VERIFY:", v, 13))
    parts.append(line("", f"Post by {post_by(it, slot_id, sent_at)} or skip", 14))
    parts.append(f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td bgcolor="#5b3f24" align="center" style="background-color:#5b3f24;border-radius:10px;padding:12px;">'
                 f'<a href="{esc(it["url"])}" style="color:#f7ecd8;text-decoration:none;font-size:15px;display:block;">Open post</a></td></tr></table>')
    return ('<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f3e7d1" style="background-color:#f3e7d1;border:1px solid #c9b18a;border-radius:14px;margin:0 0 16px 0;"><tr><td bgcolor="#f3e7d1" style="background-color:#f3e7d1;padding:16px;border-radius:14px;">'
            + "".join(parts) + "</td></tr></table>")


def header_text(h, n):
    k = h.get("post_today", "0")
    reason = h.get("post_reason", "")
    if k.isdigit() and int(k) > 0:
        post = f"Post today: {k}, marked 'recommended to post'; the others are for review."
    elif reason.startswith("tripwire"):
        post = f"Post today: 0, {reason}. All items are for review."
    elif reason:
        post = f"Post today: 0 ({reason}). All items are for review."
    else:
        post = "Post today: 0. All items are for review."
    more = h.get("today_more", "")
    total = (f"Today in total: {more} more replies, yours included." if more.isdigit()
             else f"Today in total: {more}, yours included.")
    lines = [f"{n} items. {post} {total} If the author answers, reply once the same day, in your own words. "
             "Write each reply in your own words."]
    if k.isdigit() and int(k) > 0 and h.get("post_short"):
        lines.append(f"Why only {k}: {h['post_short']}.")
    if h.get("stage_note"):
        lines.append(h["stage_note"])
    if h.get("mode") == "trial":
        lines.insert(0, "TRIAL RUN.")
    return lines


def subject_for(h, n, slot_id):
    parts = slot_parts(slot_id)
    stamp = f"{parts[0].isoformat()} {parts[1]}" if parts else now_utc().astimezone(TZ).strftime("%Y-%m-%d %H:%M")
    if h.get("mode") == "trial":
        return f"[TRIAL] {n} Twitter reply ideas ({stamp})"
    return f"{n} Twitter replies to write ({stamp})"


def build(md, slot_id, sent_at):
    h, _ = parse_header(md)
    if "mode" not in h or re.search(r"HELD|DO NOT POST", h.get("status", "")):
        return None
    items = parse_items(md)
    if not items:
        return None
    slot_id = slot_id or h.get("slot", "")
    trial = h.get("mode") == "trial"
    top = "".join(f"<p style='font-size:15px;color:#5a4630;margin:0 0 12px 0'>{esc(t)}</p>" for t in header_text(h, len(items)))
    foot = (f"<p style='font-size:14px;color:#5a4630;margin:12px 0 6px 0'>{esc(FEEDBACK_LINE)}</p>"
            f"<p style='font-size:13px;color:#7a6248;margin:0'>{esc(h.get('status_line', ''))}</p>")
    body = wrap(top + "".join(card(i, trial, slot_id, sent_at) for i in items) + foot)
    return subject_for(h, len(items), slot_id), body, len(items)


def wrap(inner):
    return f"""<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body bgcolor="#e8d9bf" style="margin:0;padding:0;background-color:#e8d9bf;font-family:-apple-system,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#e8d9bf" style="background-color:#e8d9bf;"><tr><td bgcolor="#e8d9bf" style="background-color:#e8d9bf;padding:12px;">
<div style="max-width:560px;margin:0 auto;">{inner}</div></td></tr></table></body></html>"""


# ---------- Mail ----------------------------------------------------------------------
class MailTimeout(Exception):
    pass


def osa(script, *args, timeout=None):
    t = timeout or PARAMS["delivery"].get("query_timeout_s", 60)
    try:
        return subprocess.run([OSASCRIPT, "-e", script, *args], capture_output=True, text=True, timeout=t)
    except subprocess.TimeoutExpired:
        raise MailTimeout(args[0] if args else "osascript")


def mail_state(subject):
    """Counts in Sent, Outbox and Drafts, or None when Mail did not answer (state unknown)."""
    try:
        r = osa(QUERY_SCRIPT, "query", subject)
    except MailTimeout:
        return None
    vals = dict(re.findall(r"(sent|outbox|drafts)=(\d+)", r.stdout))
    if r.returncode != 0 or len(vals) != 3:
        return None
    return {k: int(vals[k]) for k in ("sent", "outbox", "drafts")}


def stuck_reason(st, issued=False):
    if st is None:
        return SEND_UNKNOWN if issued else STATE_UNKNOWN
    if st["outbox"]:
        return "stuck_outbox"
    if st["drafts"]:
        return "stuck_draft"
    return "not_in_sent"


def delivered(st):
    return bool(st) and st["sent"] > 0 and not st["outbox"] and not st["drafts"]


def poll(subject):
    d = PARAMS["delivery"]
    deadline = time.monotonic() + d["verify_wait_s"]
    st = mail_state(subject)
    while not delivered(st) and time.monotonic() < deadline:
        time.sleep(d["verify_poll_s"])
        st = mail_state(subject)
    return st


def marker_path(slot_id):
    return STATE / "sent" / slot_id


def write_marker(slot_id, subject, n, urls):
    p = marker_path(slot_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"subject": subject, "items": n, "urls": urls,
                             "verified_at": now_utc().strftime("%Y-%m-%dT%H:%M:%SZ")}) + "\n")


def send_verified(slot_id, subject, body, n, urls):
    """Send only when a state check proves the message is in none of Sent, Outbox and Drafts."""
    if slot_id and marker_path(slot_id).exists():
        print(f"slot {slot_id} already sent; nothing sent", file=sys.stderr)
        return ALREADY_SENT
    st = mail_state(subject)
    if st is None:
        print(f"{STATE_UNKNOWN} (Mail did not answer the Sent/Outbox/Drafts check; nothing sent)", file=sys.stderr)
        return NOT_DELIVERED
    if delivered(st):
        if slot_id:
            write_marker(slot_id, subject, n, urls)
        print("already in Sent; no second send")
        return 0
    issued = False
    if not (st["outbox"] or st["drafts"]):
        try:
            r = osa(SEND_SCRIPT, "send", subject, body, ICLOUD,
                    timeout=PARAMS["delivery"].get("send_timeout_s", 120))
        except MailTimeout:
            print(f"{SEND_UNKNOWN} (the send hung after it was issued; the next attempt checks Sent first)",
                  file=sys.stderr)
            return NOT_DELIVERED
        if r.returncode != 0:
            print(f"send_error {r.stderr.strip()[:200]}", file=sys.stderr)
            return NOT_DELIVERED
        issued = True
    st = poll(subject)
    if not delivered(st):
        print(stuck_reason(st, issued), file=sys.stderr)
        return NOT_DELIVERED
    if slot_id:
        write_marker(slot_id, subject, n, urls)
    print(f"sent to {ICLOUD} and verified in Sent")
    return 0


# ---------- feedback ---------------------------------------------------------------------
def parse_feedback(raw):
    out = []
    for chunk in raw.split("<<<MSG>>>")[1:]:
        head, _, body = chunk.strip("\n").partition("\n\n")
        meta = dict(re.findall(r"^(id|subject):\s*(.*)$", head, re.M))
        stamp = re.search(r"\((\d{4}-\d{2}-\d{2}) (\d{2}):(\d{2})\)", meta.get("subject", ""))
        marks, free = [], []
        for l in body.splitlines():
            if l.startswith(">") or re.match(r"^On .+ wrote:\s*$", l):
                break
            m = re.match(r"^\s*(\d+)\s*([+-])\s*(.*)$", l)
            if m:
                words = m.group(3).strip()
                reason = next((w for w in REASON_WORDS if w in words.lower()), None)
                marks.append({"n": int(m.group(1)), "verdict": "would_post" if m.group(2) == "+" else "would_not",
                              "reason": reason, "note": words})
            elif l.strip():
                free.append(l)
        out.append({"message_id": meta.get("id"), "subject": meta.get("subject"),
                    "slot_id": f"{stamp.group(1)}_{stamp.group(2)}{stamp.group(3)}" if stamp else None,
                    "marks": marks, "free_text": "\n".join(free)})
    return out


# ---------- cli ----------------------------------------------------------------------------
def guard():
    if os.environ.get("PIPELINE_TEST") == "1":
        try:
            ok = Path(OSASCRIPT).resolve().is_relative_to(STUBS)
        except (OSError, ValueError):
            ok = False
        if not ok:
            print("test guard: PIPELINE_TEST=1 needs OSASCRIPT_BIN inside tests/stubs/", file=sys.stderr)
            sys.exit(2)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("replies", nargs="?")
    ap.add_argument("--slot")
    ap.add_argument("--send", action="store_true")
    ap.add_argument("--verify-delivery", action="store_true")
    ap.add_argument("--subject")
    ap.add_argument("--feedback", action="store_true")
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    guard()
    try:
        dispatch(a)
    except MailTimeout as e:
        print(f"timeout (Mail did not answer: {e})", file=sys.stderr)
        sys.exit(NOT_DELIVERED)


def dispatch(a):
    if a.feedback:
        r = osa(FEEDBACK_SCRIPT, "feedback", ICLOUD)
        if r.returncode != 0:
            print(f"feedback read failed: {r.stderr.strip()[:200]}", file=sys.stderr)
            sys.exit(NOT_DELIVERED)
        for msg in parse_feedback(r.stdout):
            print(json.dumps(msg, ensure_ascii=False))
        return
    if a.verify_delivery:
        if not a.slot:
            sys.exit("--verify-delivery needs --slot")
        subject = a.subject
        if not subject and marker_path(a.slot).exists():
            subject = json.loads(marker_path(a.slot).read_text()).get("subject")
        if not subject:
            print("not_in_sent", file=sys.stderr)
            sys.exit(NOT_DELIVERED)
        st = mail_state(subject)
        if delivered(st):
            print(f"delivered: {subject}")
            return
        print(stuck_reason(st), file=sys.stderr)
        sys.exit(NOT_DELIVERED)
    if a.test:
        if not a.send:
            sys.exit("--test needs --send")
        src = Path(a.replies) if a.replies else C / "tests" / "fixtures" / "replies_mode_b.md"
    else:
        if not a.replies:
            sys.exit(__doc__)
        src = Path(a.replies)
        if a.send and not a.slot:
            sys.exit("--send needs --slot")
    try:
        md = src.read_text()
    except OSError:
        print(f"nothing to send: cannot read {src}", file=sys.stderr)
        sys.exit(NOTHING_TO_SEND)
    sent_at = now_utc()
    built = build(md, a.slot, sent_at)
    if built is None:
        print("nothing to send: no complete item, no mode line, or batch held", file=sys.stderr)
        sys.exit(NOTHING_TO_SEND)
    subject, body, n = built
    if a.test:
        subject = f"[TEST] Twitter reply email check ({sent_at.astimezone(TZ).strftime('%Y-%m-%d %H:%M')})"
    out_html = src.parent / "email.html" if src.name == "replies_to_post.md" else STATE / "email.html"
    out_html.parent.mkdir(parents=True, exist_ok=True)
    out_html.write_text(body)
    print(subject)
    if a.send:
        urls = [i["url"] for i in parse_items(md)]
        sys.exit(send_verified(None if a.test else a.slot, subject, body, n, urls))


if __name__ == "__main__":
    main()
