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
The first reply mail after a Sunday carries the "Last week" block under the items (measure.py weekly
for the 7 days to that Sunday; written when missing); a verified send records it in
runs/_index/weekly_carried.json, so later mails of that week do not repeat it. No mail is ever sent
for the summary alone, and a week with no posted reply has no block.
A message found in Sent is delivered, whatever else exists. A pipeline draft whose subject is in
Sent is a leftover copy, not a stuck send: it is moved to Trash and reported. stuck_draft and
stuck_outbox apply only when the message is not in Sent. --verify-delivery takes the subject from
--subject, the slot's sent marker, or the slot's batch file (runs/SLOT_ID_batch, then _a2_batch),
and writes the sent marker when the message is in Sent.
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
RUNS = Path(os.environ.get("PIPELINE_RUNS_DIR") or C / "runs")
ANALYTICS = Path(os.environ.get("PIPELINE_ANALYTICS_DIR") or C / "runs" / "_analytics")
PARAMS = json.loads(Path(os.environ.get("PIPELINE_PARAMS") or C / "agents" / "params.json").read_text())
TZ = ZoneInfo(PARAMS["timezone"])
OSASCRIPT = os.environ.get("OSASCRIPT_BIN") or "osascript"
REQUIRED = ("HOOK", "OPEN", "QUOTE", "POINT", "DRAFT")
FEEDBACK_LINE = ("Feedback: reply with the item number, + or -, and a word: good, boring, forced, wrong post, "
                 "too late. Example: 1 + good")
FOLLOW_UP_LINE = "If the author answers, reply once the same day."
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

# Mail can leave a draft copy of a message it has sent (seen 2026-11-24: Sent held the mail, Drafts a
# copy dated one second later). A pipeline draft whose subject is in Sent is such a leftover.
TRASH_LEFTOVERS_SCRIPT = """
on run argv
  set n to 0
  tell application "Mail"
    set ds to (messages of drafts mailbox whose subject contains "Twitter repl")
    repeat with m in ds
      set s to subject of m
      if (count of (messages of sent mailbox whose subject is s)) > 0 then
        delete m
        set n to n + 1
      end if
    end repeat
  end tell
  return "trashed=" & n
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


INK, MUTED, CARD, EDGE, DARK, LIGHT = "#3b2a1a", "#7a6248", "#f3e7d1", "#c9b18a", "#5b3f24", "#f7ecd8"


def badge(text, colour):
    return (f'<span style="display:inline-block;background-color:{colour};color:{LIGHT};font-size:14px;font-weight:bold;'
            f'border-radius:6px;padding:3px 9px;margin:0 6px 6px 0;">{esc(text)}</span>')


def age_text(m):
    m = int(m) if str(m).isdigit() else None
    if m is None:
        return ""
    return f"{m} min old" if m < 60 else f"{m // 60} h {m % 60} min old"


def count_text(v):
    return f"{int(v):,}" if str(v).isdigit() else esc(v)


def card(it, slot_id, sent_at):
    """One item: number and badges, a small meta line, the reply text, the post-by time and the button.
    The hook, the opening instruction, the point, the quoted line and Yours? stay in the file, not here."""
    rec = it.get("mark") == "recommended"
    badges = badge("Post this" if rec else "For review", DARK if rec else "#9a8466")
    if it.get("lane") == "large":
        badges += badge("Large account", "#8a4b1f")
    meta = " &middot; ".join(x for x in (f"@{esc(it.get('author'))}", f"{count_text(it.get('followers'))} followers",
                                          esc(age_text(it.get("age_min"))), f"{count_text(it.get('views'))} views") if x)
    parts = [f'<div style="font-size:18px;font-weight:bold;color:{INK};margin:0 0 6px 0;">{esc(it["n"])}. {badges}</div>',
             f'<div style="font-size:15px;line-height:1.4;color:{MUTED};margin:0 0 12px 0;">{meta}</div>',
             f'<div style="font-size:22px;line-height:1.45;color:{INK};margin:0 0 14px 0;word-wrap:break-word;'
             f'overflow-wrap:break-word;">{esc(it["DRAFT"])}</div>']
    for v in it["VERIFY"]:
        parts.append(f'<div style="font-size:18px;line-height:1.45;color:#8a2b1f;margin:0 0 10px 0;">Check first: {esc(v)}</div>')
    parts.append(f'<div style="font-size:18px;line-height:1.45;color:{MUTED};margin:0 0 12px 0;">'
                 f'Post by {post_by(it, slot_id, sent_at)} or skip</div>')
    parts.append(f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
                 f'<td bgcolor="{DARK}" align="center" style="background-color:{DARK};border-radius:10px;padding:16px;">'
                 f'<a href="{esc(it["url"])}" style="color:{LIGHT};text-decoration:none;font-size:19px;font-weight:bold;'
                 f'display:block;width:100%;">Open post</a></td></tr></table>')
    return (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{CARD}" '
            f'style="background-color:{CARD};border:1px solid {EDGE};border-radius:14px;margin:0 0 16px 0;"><tr>'
            f'<td bgcolor="{CARD}" style="background-color:{CARD};padding:16px;border-radius:14px;">'
            + "".join(parts) + "</td></tr></table>")


def header_text(h, n):
    """The header line ("Post today: N", with its reason when N is lower than expected) and the stage note."""
    k = h.get("post_today", "0")
    k = k if k.isdigit() else "0"
    reason = h.get("post_reason", "") if k == "0" else h.get("post_short", "")
    why = (f", {reason}" if reason.startswith("tripwire") else f" ({reason})") if reason else ""
    line1 = ("TRIAL RUN. " if h.get("mode") == "trial" else "") + f"Post today: {k}{why}"
    return [line1] + ([h["stage_note"]] if h.get("stage_note") else [])


def subject_for(h, n, slot_id):
    parts = slot_parts(slot_id)
    stamp = f"{parts[0].isoformat()} {parts[1]}" if parts else now_utc().astimezone(TZ).strftime("%Y-%m-%d %H:%M")
    if h.get("mode") == "trial":
        return f"[TRIAL] {n} Twitter reply ideas ({stamp})"
    return f"{n} Twitter replies to write ({stamp})"


def week_due(today):
    """The Sunday that ends the last full week, when its "Last week" block has not gone out in a mail yet."""
    end = today - dt.timedelta(days=today.weekday() + 1)
    carried = (json.loads((STATE / "weekly_carried.json").read_text()) if (STATE / "weekly_carried.json").exists()
               else {}).get("week_end")
    return None if carried == end.isoformat() else end


def weekly_lines(end):
    """The summary lines of measure.py weekly for the week ending `end` (written when missing); [] when
    no reply was posted that week."""
    f = ANALYTICS / f"weekly_summary_{end.isoformat()}.md"
    if not f.exists():
        subprocess.run([sys.executable, str(BIN / "measure.py"), "weekly", "--end", end.isoformat()],
                       capture_output=True, text=True, timeout=60)
    lines = [l[2:].strip() for l in (f.read_text().splitlines() if f.exists() else []) if l.startswith("- ")]
    return [] if not lines or lines[0].startswith("Replies posted: 0.") else lines


def weekly_block(lines):
    return (f"<p style='font-size:20px;font-weight:bold;line-height:1.35;color:{INK};margin:8px 0 8px 0'>Last week</p>"
            + "".join(f"<p style='font-size:18px;line-height:1.45;color:{INK};margin:0 0 10px 0'>{esc(t)}</p>" for t in lines))


def mark_week_carried(end):
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / "weekly_carried.json").write_text(json.dumps({"week_end": end.isoformat()}) + "\n")


def build(md, slot_id, sent_at, weekly=False):
    """(subject, html, items, week_end of the "Last week" block carried, or None)."""
    h, _ = parse_header(md)
    if "mode" not in h or re.search(r"HELD|DO NOT POST", h.get("status", "")):
        return None
    items = parse_items(md)
    if not items:
        return None
    slot_id = slot_id or h.get("slot", "")
    head = header_text(h, len(items))
    top = (f"<p style='font-size:20px;font-weight:bold;line-height:1.35;color:{INK};margin:0 0 12px 0'>{esc(head[0])}</p>"
           + "".join(f"<p style='font-size:18px;line-height:1.45;color:{INK};margin:0 0 12px 0'>{esc(t)}</p>" for t in head[1:]))
    foot = "".join(f"<p style='font-size:18px;line-height:1.45;color:{MUTED};margin:12px 0 0 0'>{esc(t)}</p>"
                   for t in (FOLLOW_UP_LINE, FEEDBACK_LINE, h.get("status_line", "")) if t)
    end = week_due(sent_at.astimezone(TZ).date()) if weekly else None
    lines = weekly_lines(end) if end else []
    block = weekly_block(lines) if lines else ""
    body = wrap(top + "".join(card(i, slot_id, sent_at) for i in items) + block + foot)
    return subject_for(h, len(items), slot_id), body, len(items), end if lines else None


def wrap(inner):
    return f"""<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body bgcolor="#e8d9bf" style="margin:0;padding:0;background-color:#e8d9bf;font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:18px;-webkit-text-size-adjust:100%;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#e8d9bf" style="background-color:#e8d9bf;width:100%;"><tr><td bgcolor="#e8d9bf" style="background-color:#e8d9bf;padding:12px;">
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
    """A message found in Sent is delivered, whatever else exists."""
    return bool(st) and st["sent"] > 0


def trash_leftovers(st, subject):
    """Move draft copies of sent pipeline messages to Trash and say so; never touches a draft not in Sent."""
    if st and st["drafts"] == 0:
        time.sleep(PARAMS["delivery"]["verify_poll_s"])  # the leftover copy can appear a moment after the send
        st = mail_state(subject) or st
    if not st or not st["drafts"]:
        return
    try:
        r = osa(TRASH_LEFTOVERS_SCRIPT, "trash_leftovers")
    except MailTimeout:
        print("leftover draft copy not moved (Mail did not answer); the message is in Sent", file=sys.stderr)
        return
    m = re.search(r"trashed=(\d+)", r.stdout)
    print(f"leftover draft copy of a sent message moved to Trash ({m.group(1) if m else '?'})")


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


def slot_batches(slot_id):
    """(subject, items, urls) of each batch file of the slot, first attempt first."""
    out = []
    for name in (f"{slot_id}_batch", f"{slot_id}_a2_batch"):
        f = RUNS / name / "replies_to_post.md"
        if f.exists():
            md = f.read_text()
            built = build(md, slot_id, now_utc())
            if built:
                out.append((built[0], built[2], [i["url"] for i in parse_items(md)]))
    return out


def verify_delivery(slot_id, subject=None):
    """Re-check a slot without sending; a message found in Sent writes the sent marker."""
    if subject:
        cands = [(subject, None, [])]
    elif marker_path(slot_id).exists():
        cands = [(json.loads(marker_path(slot_id).read_text()).get("subject"), None, [])]
    else:
        cands = slot_batches(slot_id)  # no marker yet: the subject comes from the slot's batch file
    if not cands:
        print("not_in_sent (no subject: no marker and no batch file for the slot)", file=sys.stderr)
        return NOT_DELIVERED
    st = None
    for subj, n, urls in cands:
        st = mail_state(subj)
        if delivered(st):
            if not marker_path(slot_id).exists():
                write_marker(slot_id, subj, n, urls)
            print(f"delivered: {subj}")
            trash_leftovers(st, subj)
            return 0
    print(stuck_reason(st), file=sys.stderr)
    return NOT_DELIVERED


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
        trash_leftovers(st, subject)
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
    trash_leftovers(st, subject)
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
        sys.exit(verify_delivery(a.slot, a.subject))
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
    built = build(md, a.slot, sent_at, weekly=not a.test)
    if built is None:
        print("nothing to send: no complete item, no mode line, or batch held", file=sys.stderr)
        sys.exit(NOTHING_TO_SEND)
    subject, body, n, week_end = built
    if a.test:
        subject = f"[TEST] Twitter reply email check ({sent_at.astimezone(TZ).strftime('%Y-%m-%d %H:%M')})"
    out_html = src.parent / "email.html" if src.name == "replies_to_post.md" else STATE / "email.html"
    out_html.parent.mkdir(parents=True, exist_ok=True)
    out_html.write_text(body)
    print(subject)
    if a.send:
        urls = [i["url"] for i in parse_items(md)]
        rc = send_verified(None if a.test else a.slot, subject, body, n, urls)
        if rc == 0 and week_end and not a.test:
            mark_week_carried(week_end)  # the "Last week" block went out in this mail
        sys.exit(rc)


if __name__ == "__main__":
    main()
