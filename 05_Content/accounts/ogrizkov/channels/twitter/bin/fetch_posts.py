#!/usr/bin/env python3
"""fetch_posts.py - reads of known posts through the public conversation endpoint (v3.2).

Grok is used only for the discovery search; every read of a known post goes through here, with
grok as the caller's fallback. Only public post ids and the public handle are sent.

  thread --url U [--url U2 ...] [--all-replies]   one 00b_threads.json entry (several: {"threads", "failed"})
  status --url U                                  views, likes, replies, posted time, author
  my-reply --parent U --handle H                  his reply under a known post, the author's answer, his follow-up
  reply-count --handle H                          his replies today (profile difference, else partial)

my-reply and the partial count follow the conversation cursor up to endpoint.max_pages pages
(default 5). When his reply is not found and a cursor remains after the limit, my-reply returns
found: null with note "unknown" (not "no reply"); measure.py never counts an unknown reading.
A found reply also carries thread_rank (percentile of its views among the thread's replies the fetch
returned, 100 = most viewed; null when pages were left unread or under 5 replies were seen),
thread_replies_seen and share_of_parent (his views / the parent's views).

Endpoint layout (learned 2026-11-23 from live answers, saved as tests/fixtures/fx_*.json):
  /2/conversation/ID -> {code, status, thread[] (ancestors), replies[] (direct replies, ranked), author, cursor}
  /2/status/ID       -> {status}
  /2/profile/HANDLE  -> {code, user {statuses, followers, ...}}
A status has text, raw_text.display_text_range, author{screen_name, followers}, views, likes, replies,
reposts, quotes, bookmarks, created_timestamp, replying_to{screen_name, status}.

PIPELINE_FETCH_DIR: read saved answers conversation_ID.json (page N > 1: conversation_ID_pN.json),
status_ID.json, profile_HANDLE.json and open no connection. Live, page N > 1 is
/2/conversation/ID?cursor=<cursor.bottom of page N-1> (parameter name assumed, not yet seen live).
Exit: 0 JSON on stdout; 4 failure with one reason on stderr (endpoint_http, endpoint_timeout,
endpoint_shape, not_found); 2 usage or test guard.
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import json
import os
import re
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo

BIN = Path(__file__).resolve().parent
C = BIN.parent
STATE = Path(os.environ.get("PIPELINE_STATE_DIR") or C / "runs" / "_index")
PARAMS_FILE = Path(os.environ.get("PIPELINE_PARAMS") or C / "agents" / "params.json")
FETCH_DIR = os.environ.get("PIPELINE_FETCH_DIR")
TOP_REPLIES = 10


class FetchError(Exception):
    pass


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


P = json.loads(PARAMS_FILE.read_text())
EP = P["endpoint"]
TZ = ZoneInfo(P["timezone"])


def now_utc():
    v = os.environ.get("PIPELINE_NOW")
    if not v:
        return dt.datetime.now(dt.timezone.utc)
    t = dt.datetime.fromisoformat(v.replace("Z", "+00:00"))
    return (t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)).astimezone(dt.timezone.utc)


def iso(t):
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def post_id(url):
    m = re.search(r"/status(?:es)?/(\d+)", url or "")
    if not m:
        die(f"not a post URL: {url}")
    return m.group(1)


# ---------- transport ----------------------------------------------------------------
def get(kind, key, cursor=None, page=1):
    if FETCH_DIR:
        p = Path(FETCH_DIR) / (f"{kind}_{key}.json" if page == 1 else f"{kind}_{key}_p{page}.json")
        if not p.exists():
            raise FetchError("not_found")
        try:
            data = json.loads(p.read_text())
        except ValueError:
            raise FetchError("endpoint_shape")
    else:
        url = f"{EP['base'].rstrip('/')}/2/{kind}/{key}"
        if cursor:
            url += "?cursor=" + urllib.parse.quote(cursor, safe="")
        req = urllib.request.Request(url, headers={"User-Agent": "reply-pipeline-fetch/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=EP["timeout_s"]) as r:
                body = r.read()
        except urllib.error.HTTPError as e:
            raise FetchError("not_found" if e.code == 404 else "endpoint_http")
        except (socket.timeout, TimeoutError):
            raise FetchError("endpoint_timeout")
        except urllib.error.URLError as e:
            raise FetchError("endpoint_timeout" if isinstance(e.reason, socket.timeout) else "endpoint_http")
        try:
            data = json.loads(body)
        except ValueError:
            raise FetchError("endpoint_shape")
    if not isinstance(data, dict):
        raise FetchError("endpoint_shape")
    if data.get("code") == 404:
        raise FetchError("not_found")
    return data


def status_obj(data):
    s = data.get("status")
    if not isinstance(s, dict) or "id" not in s or "author" not in s:
        raise FetchError("endpoint_shape")
    return s


def conversation(pid):
    d = get("conversation", pid)
    s = status_obj(d)
    replies = d.get("replies") or []
    if not isinstance(replies, list):
        raise FetchError("endpoint_shape")
    return s, replies


def next_cursor(d):
    c = d.get("cursor")
    return (c.get("bottom") if isinstance(c, dict) else c) or None


def conversation_pages(pid, wanted=None):
    """(status, replies, more): follows the cursor up to endpoint.max_pages pages, or until `wanted`
    (a predicate on a reply) matches. `more` is True when a cursor remains unread, also when a page
    repeats replies already seen (the cursor was not honoured)."""
    d = get("conversation", pid)
    s = status_obj(d)
    replies, seen, page = [], set(), 1
    while True:
        batch = d.get("replies") or []
        if not isinstance(batch, list):
            raise FetchError("endpoint_shape")
        new = [r for r in batch if r.get("id") not in seen]
        if page > 1 and batch and not new:
            return s, replies, True
        seen.update(r.get("id") for r in new)
        replies += new
        cur = next_cursor(d)
        if not cur or not batch or (wanted and any(wanted(r) for r in new)):
            return s, replies, False
        if page >= EP.get("max_pages", 5):
            return s, replies, True
        page += 1
        try:
            d = get("conversation", pid, cursor=cur, page=page)
        except FetchError as e:
            if str(e) == "not_found":
                return s, replies, True
            raise


# ---------- shaping ---------------------------------------------------------------------
def body_text(s):
    text = s.get("text") or ""
    rng = (s.get("raw_text") or {}).get("display_text_range")
    if isinstance(rng, list) and len(rng) == 2 and rng[0] > 0:
        return text[rng[0]:].strip()
    return text.strip()


def when(s):
    ts = s.get("created_timestamp")
    if isinstance(ts, (int, float)):
        return iso(dt.datetime.fromtimestamp(ts, dt.timezone.utc))
    try:
        return iso(dt.datetime.strptime(s.get("created_at", ""), "%a %b %d %H:%M:%S %z %Y"))
    except ValueError:
        return None


def author(s):
    return (s.get("author") or {}).get("screen_name") or ""


def counts(s):
    return {k: s.get(k) for k in ("views", "likes", "replies", "quotes", "reposts", "bookmarks")}


def reply_row(r, full):
    row = {"author": "@" + author(r), "text": body_text(r), "url": r.get("url")}
    if full:
        row.update(counts(r))
        row.update({"posted_at": when(r), "author_followers": (r.get("author") or {}).get("followers"),
                    "replying_to": (r.get("replying_to") or {}).get("screen_name")})
    return row


def thread_entry(url, all_replies=False):
    s, replies = conversation(post_id(url))
    op = author(s).lower()
    others = [r for r in replies if author(r).lower() != op]
    return {
        "url": s.get("url") or url,
        "opening_post": s.get("text") or "",
        "top_replies": [reply_row(r, all_replies) for r in (others if all_replies else others[:TOP_REPLIES])],
        "engagement": counts(s),
        "captured_at": iso(now_utc()),
        "op_replies_in_thread": sum(1 for r in replies if author(r).lower() == op),
        "author_followers": (s.get("author") or {}).get("followers"),
        "posted_at": when(s),
        "source": "endpoint",
    }


# ---------- subcommands ----------------------------------------------------------------
def cmd_thread(a):
    if len(a.url) == 1:
        return thread_entry(a.url[0], a.all_replies)
    out, failed = [], []
    with cf.ThreadPoolExecutor(max_workers=EP["parallel"]) as ex:
        futs = {ex.submit(thread_entry, u, a.all_replies): u for u in a.url}
        for f in cf.as_completed(futs):
            try:
                out.append(f.result())
            except FetchError as e:
                failed.append({"url": futs[f], "reason": str(e)})
    order = {u: i for i, u in enumerate(a.url)}
    out.sort(key=lambda t: order.get(t["url"], len(order)))
    return {"threads": out, "failed": failed}


def cmd_status(a):
    s = status_obj(get("status", post_id(a.url)))
    return {"url": s.get("url"), "views": s.get("views"), "likes": s.get("likes"), "replies": s.get("replies"),
            "posted_at": when(s), "author": author(s), "author_followers": (s.get("author") or {}).get("followers")}


def find_by(replies, handle):
    return next((r for r in replies if author(r).lower() == handle.lower()), None)


def by(handle):
    return lambda r: author(r).lower() == handle.lower()


def replies_of(pid, handle):
    """(the first reply by handle under pid or None, more)."""
    try:
        _, replies, more = conversation_pages(pid, by(handle))
    except FetchError as e:
        if str(e) == "not_found":
            return None, False
        raise
    return find_by(replies, handle), more


def thread_rank(mine, replies, more):
    """(percentile of his reply's views among the thread's replies, 100 = most viewed; replies seen).
    None when pages were left unread or fewer than 5 replies were seen."""
    n = len(replies)
    if more or n < 5:
        return None, n
    v = mine.get("views") or 0
    return round(100 * sum(1 for r in replies if (r.get("views") or 0) <= v) / n), n


def share_of_parent(mine, parent):
    v, pv = mine.get("views"), parent.get("views")
    return round(v / pv, 4) if isinstance(v, int) and isinstance(pv, int) and pv > 0 else None


def cmd_my_reply(a):
    handle = a.handle.lstrip("@")
    # all pages (up to max_pages), not only up to his reply: the thread rank needs the whole thread
    parent, replies, more = conversation_pages(post_id(a.parent))
    mine = find_by(replies, handle)
    if not mine:
        note = f"unknown: a cursor remains after {EP.get('max_pages', 5)} pages" if more else "no reply"
        return {"parent_url": a.parent, "found": None if more else False, "note": "unknown" if more else "no reply",
                "detail": note, "parent_views": parent.get("views")}
    answer, more_a = replies_of(mine["id"], author(parent))
    follow, _ = replies_of(answer["id"], handle) if answer else (None, False)
    rank, seen = thread_rank(mine, replies, more)
    return {
        "parent_url": a.parent, "found": True, "reply_url": mine.get("url"), "text": body_text(mine),
        "posted_at": when(mine), "views": mine.get("views"), "likes": mine.get("likes"),
        "replies": mine.get("replies"), "parent_views": parent.get("views"),
        "thread_rank": rank, "thread_replies_seen": seen, "share_of_parent": share_of_parent(mine, parent),
        "author_answered": True if answer else (None if more_a else False),
        "author_answer_text": body_text(answer) if answer else None,
        "follow_up": ({"url": follow.get("url"), "text": body_text(follow), "posted_at": when(follow)}
                      if follow else None),
    }


def read_json(p, default):
    try:
        return json.loads(Path(p).read_text())
    except (OSError, ValueError):
        return default


def partial_count(handle, today):
    rows = [json.loads(l) for l in (STATE / "delivered.jsonl").read_text().splitlines() if l.strip()] \
        if (STATE / "delivered.jsonl").exists() else []
    urls = sorted({r["url"] for r in rows if r.get("url") and r.get("delivered_at")
                   and dt.datetime.fromisoformat(r["delivered_at"].replace("Z", "+00:00")).astimezone(TZ).date() == today})
    n = 0
    for u in urls:
        try:
            _, replies, _ = conversation_pages(post_id(u))
        except FetchError:
            continue
        for r in replies:
            t = when(r)
            if author(r).lower() == handle.lower() and t and \
                    dt.datetime.fromisoformat(t.replace("Z", "+00:00")).astimezone(TZ).date() == today:
                n += 1
    return n, len(urls)


def cmd_reply_count(a):
    handle = a.handle.lstrip("@")
    today = now_utc().astimezone(TZ).date()
    pc_path = STATE / "posted_counts.json"
    pc = read_json(pc_path, {})
    totals = pc.setdefault("profile_totals", {})
    total, why = None, None
    try:
        user = get("profile", handle).get("user") or {}
        total = user.get("statuses")
        if not isinstance(total, int):
            raise FetchError("endpoint_shape")
    except FetchError as e:
        why = str(e)
    if total is not None:
        # Only yesterday's last total is a baseline: an older one would put several days into today.
        # It still counts from yesterday's last run, not midnight, and includes posts and reposts.
        yday = (today - dt.timedelta(days=1)).isoformat()
        earlier = [yday] if yday in totals else []
        totals[today.isoformat()] = total
        STATE.mkdir(parents=True, exist_ok=True)
        if earlier:
            n = max(0, total - totals[earlier[-1]])
            days = pc.setdefault("days", {})
            days[today.isoformat()] = max(int(days.get(today.isoformat(), 0) or 0), n)
            pc_path.write_text(json.dumps(pc, indent=2) + "\n")
            return {"handle": handle, "count": n, "partial": False, "source": "profile", "total": total,
                    "baseline_date": earlier[-1]}
        pc_path.write_text(json.dumps(pc, indent=2) + "\n")
        why = "no stored profile total from yesterday"
    n, threads = partial_count(handle, today)
    return {"handle": handle, "count": n, "partial": True, "source": "delivered_threads",
            "threads_read": threads, "note": why}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("thread")
    p.add_argument("--url", action="append", required=True)
    p.add_argument("--all-replies", action="store_true")
    p = sub.add_parser("status")
    p.add_argument("--url", required=True)
    p = sub.add_parser("my-reply")
    p.add_argument("--parent", required=True)
    p.add_argument("--handle", required=True)
    p = sub.add_parser("reply-count")
    p.add_argument("--handle", required=True)
    a = ap.parse_args()
    if os.environ.get("PIPELINE_TEST") == "1" and not FETCH_DIR:
        die("test guard: PIPELINE_TEST=1 needs PIPELINE_FETCH_DIR (no live request in tests)", 2)
    fn = {"thread": cmd_thread, "status": cmd_status, "my-reply": cmd_my_reply, "reply-count": cmd_reply_count}[a.cmd]
    try:
        out = fn(a)
    except FetchError as e:
        die(str(e), 4)
    print(json.dumps(out, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
