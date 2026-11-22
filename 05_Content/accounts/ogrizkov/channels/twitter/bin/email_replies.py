#!/usr/bin/env python3
"""Render a batch's replies_to_post.md (or HALT.json) as a mobile-friendly HTML email.

Usage: email_replies.py <runs/<batch>/replies_to_post.md | runs/<batch>/HALT.json>
Writes runs/<batch>/email.html and prints the subject line. Sending is done by the
Gmail connector in the scheduled task, so no credentials live in the vault.
"""
import html
import json
import re
import sys
from pathlib import Path


def parse(md: str):
    header = md.split("\n---", 1)[0]
    summary = [l for l in header.splitlines()[1:] if l.strip()]
    items = []
    for block in re.split(r"^### ", md, flags=re.M)[1:]:
        lines = block.splitlines()
        m = re.match(r"(\d+)\.\s+(\S+)", lines[0])
        if not m:
            continue
        item = {"n": m.group(1), "url": m.group(2)}
        for l in lines[1:]:
            fm = re.match(r"-\s+(author|views|DRAFT|content_pillar):\s*(.*)", l)
            if fm:
                item[fm.group(1)] = fm.group(2).strip()
        if "DRAFT" in item:
            items.append(item)
    tail = md.split("## Skipped", 1)
    extra = "## Skipped" + tail[1] if len(tail) > 1 else ""
    return summary, items, extra


def card(it):
    e = html.escape
    pillar = e(it.get("content_pillar", "").split("·")[0].strip())
    return f"""
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f3e7d1" style="background-color:#f3e7d1;border:1px solid #c9b18a;border-radius:14px;margin:0 0 16px 0;"><tr><td bgcolor="#f3e7d1" style="background-color:#f3e7d1;padding:16px;border-radius:14px;">
  <div style="font-size:13px;color:#7a6248;margin-bottom:8px;">
    #{e(it['n'])} &middot; @{e(it.get('author',''))} &middot; {e(it.get('views',''))} views &middot; {pillar}
  </div>
  <div style="font-size:13px;margin-bottom:10px;word-break:break-all;">
    <a href="{e(it['url'])}" style="color:#8a4b1f;">{e(it['url'])}</a>
  </div>
  <div style="font-size:18px;line-height:1.45;color:#3b2a1a;margin-bottom:14px;">{e(it['DRAFT'])}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td bgcolor="#5b3f24" align="center" style="background-color:#5b3f24;border-radius:10px;padding:12px;">
    <a href="{e(it['url'])}" style="color:#f7ecd8;text-decoration:none;font-size:15px;display:block;">Open tweet to reply</a>
  </td></tr></table>
</td></tr></table>"""


def build(md_path: Path):
    batch = md_path.parent.name
    if md_path.name == "HALT.json":
        halt = json.loads(md_path.read_text())
        body = f"<p style='font-size:16px'>Batch <b>{html.escape(batch)}</b> halted.</p><pre style='white-space:pre-wrap;font-size:13px'>{html.escape(json.dumps(halt, indent=2))}</pre>"
        return f"Twitter replies HALTED: {batch}", wrap(body)
    md = md_path.read_text()
    summary, items, extra = parse(md)
    head = "".join(f"<p style='font-size:14px;color:#5a4630;margin:0 0 6px 0'>{html.escape(s)}</p>" for s in summary)
    if re.search(r"HELD|DO NOT POST", md):
        head = "<p style='font-size:16px;color:#b00020;font-weight:bold'>BATCH HELD - DO NOT POST</p>" + head
    cards = "".join(card(i) for i in items) or "<p>No drafts this run.</p>"
    foot = f"<pre style='white-space:pre-wrap;font-size:12px;color:#7a6248'>{html.escape(extra.strip())}</pre>" if extra.strip() else ""
    return f"{len(items)} Twitter replies ready: {batch}", wrap(head + "<div style='height:12px'></div>" + cards + foot)


def wrap(inner):
    return f"""<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body bgcolor="#e8d9bf" style="margin:0;padding:0;background-color:#e8d9bf;font-family:-apple-system,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#e8d9bf" style="background-color:#e8d9bf;"><tr><td bgcolor="#e8d9bf" style="background-color:#e8d9bf;padding:12px;">
<div style="max-width:560px;margin:0 auto;">{inner}</div></td></tr></table></body></html>"""


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    subject, body = build(src)
    (src.parent / "email.html").write_text(body)
    print(subject)
