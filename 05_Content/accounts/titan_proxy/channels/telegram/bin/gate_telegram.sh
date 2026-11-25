#!/usr/bin/env bash
# gate_telegram.sh — Deterministic code gate for Titan Proxy Telegram channel JSON feed.
#
# Usage:
#   gate_telegram.sh <posts1.json> [posts2.json ...]
#
# Exit codes:
#   0  All files passed
#   1  One or more files failed checks
#   2  Missing argument

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <posts.json> [posts2.json ...]" >&2
  exit 2
fi

python3 - "$@" <<'PY'
from datetime import datetime, time
import json
import os
import re
import sys
from html.parser import HTMLParser
from zoneinfo import ZoneInfo

REGULATORY_TRIGGERS = re.compile(
    r"(faketls|dpi|тспу|обход|блокировк|цензур|разблокировк|анонимайзер|ркн)",
    re.I,
)
BANNED_INFRA = re.compile(
    r"(frankfurt|helsinki|amsterdam|германи|финлянди|нидерланд|hetzner|ovh|digitalocean)",
    re.I,
)
BANNED_VOICE = re.compile(
    r"(\bvpn\b|туннель|mtproto|tcp\s*bbr|\brtt\b|\bxtr\b|\bhttps\b|кружоч|пользовател|чел\.|до\s+\d+\s+устройств|\b(?:50|7)\s+устройств|\bsplit\b|\[todo|\btodo\b|\bbest\b|\bfastest\b|world-class|unbreakable|guaranteed)",
    re.I,
)
TECHNICAL_BS = re.compile(
    r"(мощность\s+серверов|ресурс\w*\s+узлов|глубокой\s+маскировк|маршрутизируется)",
    re.I,
)
HARDCODED_PRICES = re.compile(r"(?<!\d)(139|329|699)(?!\d)")
LIMITATION_TRIGGER = re.compile(
    r"(звонк|аудио|тариф|\bbasic\b|\bfamily\b|\bpremium\b)",
    re.I,
)
KEY_RE = re.compile(r"^[a-z0-9_]{3,32}$")
START_PARAM_RE = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
PROMO_SLUG_RE = re.compile(r"^[a-z0-9_-]{2,32}$")
DATE_ONLY_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ALLOWED_TAGS = {"b", "i", "code", "a", "blockquote"}
ALLOWED_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}
MSK = ZoneInfo("Europe/Moscow")
# Already published 2026-11-25 prior to news_brief relevance gate; exempted until retired.
LEGACY_NEWS_KEYS = {"news_20261125"}
NEWS_OFFTOPIC_RE = re.compile(
    r"(\bбет[аеуыо]\w*|\bbeta\b|субтитр|pkpass|диктовк|стикер|видеоредактор|редактор\w*\s+истор|в\s+историях|обои|эмодзи|нейросет|ии-агент|html-виджет|мини-игр|аватарк|liquid\s+glass)",
    re.I,
)
NEWS_DOMAIN_RE = re.compile(
    r"(связ[иью]|интернет|оператор|провайдер|сбо[йяеюи]|перебо|задержк|загрузк|медиа|соединен|мобильн\w*\s+сет|сет[иью]\s+оператор|маршрут|прокси|подключен|трафик|узл[аоуые]|stars|звёзд|звезд|fragment|premiumbot|оплат|пополнен|платёж|платеж)",
    re.I,
)


def _parse_bound(raw: object, *, is_end: bool, tz: ZoneInfo) -> datetime | None:
    if not isinstance(raw, str) or not raw.strip():
        return None
    s = raw.strip()
    try:
        if DATE_ONLY_RE.match(s):
            d = datetime.strptime(s, "%Y-%m-%d").date()
            return datetime.combine(d, time(23, 59, 59) if is_end else time(0, 0, 0), tzinfo=tz)
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=tz)
        return dt
    except ValueError:
        return None


def _load_sibling_promos(feed_path: str, tz: ZoneInfo, fail) -> dict[str, dict] | None:
    promos_path = os.path.join(os.path.dirname(os.path.abspath(feed_path)), "promos.json")
    if not os.path.isfile(promos_path):
        return None
    try:
        with open(promos_path, encoding="utf-8") as fh:
            raw = json.load(fh)
    except Exception as exc:
        fail(f"promos.json malformed: {exc}")
        return {}
    campaigns = raw.get("campaigns") if isinstance(raw, dict) else None
    if not isinstance(campaigns, list):
        fail("promos.json must define a 'campaigns' list")
        return {}
    by_slug: dict[str, dict] = {}
    for c in campaigns:
        if not isinstance(c, dict) or not isinstance(c.get("slug"), str):
            fail("promos.json campaign missing string 'slug'")
            continue
        slug = c["slug"]
        if not PROMO_SLUG_RE.match(slug):
            fail(f"promos.json invalid slug {slug!r}")
        s_dt = _parse_bound(c.get("starts_at"), is_end=False, tz=tz)
        e_dt = _parse_bound(c.get("ends_at"), is_end=True, tz=tz)
        if s_dt is None or e_dt is None or s_dt > e_dt:
            fail(f"promos.json {slug}: invalid starts_at/ends_at window")
        bonus = c.get("bonus_days")
        if not isinstance(bonus, dict) or not all(k in bonus for k in ("basic", "family", "premium")):
            fail(f"promos.json {slug}: bonus_days must define basic, family, premium")
        else:
            for tier in ("basic", "family", "premium"):
                val = bonus[tier]
                if not isinstance(val, int) or isinstance(val, bool) or not (1 <= val <= 14):
                    fail(f"promos.json {slug}: bonus_days[{tier}] must be int in [1, 14]")
        by_slug[slug] = {
            "enabled": bool(c.get("enabled")),
            "starts_at": s_dt,
            "ends_at": e_dt,
        }
    return by_slug


class TelegramHTMLValidator(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.stack: list[str] = []
        self.errors: list[str] = []
        self.text_parts: list[str] = []
        self.blockquote_depth: int = 0
        self.lead_text_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag not in ALLOWED_TAGS:
            self.errors.append(f"disallowed HTML tag <{tag}>")
        self.stack.append(tag)
        if tag == "blockquote":
            self.blockquote_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if not self.stack or self.stack[-1] != tag:
            self.errors.append(f"unbalanced HTML closing tag </{tag}>")
            return
        self.stack.pop()
        if tag == "blockquote" and self.blockquote_depth > 0:
            self.blockquote_depth -= 1

    def handle_data(self, data: str) -> None:
        self.text_parts.append(data)
        if self.blockquote_depth == 0:
            self.lead_text_parts.append(data)


def validate_file(path: str) -> bool:
    file_failed = False

    def fail(msg: str) -> None:
        nonlocal file_failed
        print(f"GATE FAIL: {path}: {msg}", file=sys.stderr)
        file_failed = True

    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        fail("File does not exist")
        return False
    except json.JSONDecodeError as exc:
        fail(f"Malformed JSON ({exc})")
        return False

    if not isinstance(data, dict) or not isinstance(data.get("posts"), list) or not data["posts"]:
        fail("Top-level JSON must be an object with non-empty 'posts' list")
        return False

    tz = MSK
    sched = data.get("schedule")
    if isinstance(sched, dict) and isinstance(sched.get("timezone"), str) and sched["timezone"].strip():
        try:
            tz = ZoneInfo(sched["timezone"].strip())
        except Exception:
            tz = MSK

    promos_by_slug = _load_sibling_promos(path, tz, fail)

    seen_keys: set[str] = set()
    required_fields = ("key", "role", "rubric", "silent", "enabled", "cta_text", "start_param", "html")

    for idx, post in enumerate(data["posts"]):
        if not isinstance(post, dict):
            fail(f"posts[{idx}] must be an object")
            continue

        missing = [f for f in required_fields if f not in post]
        if missing:
            fail(f"posts[{idx}] missing required fields: {', '.join(missing)}")
            continue

        key = str(post["key"])
        if not KEY_RE.match(key):
            fail(f"post key {key!r} must match ^[a-z0-9_]{{3,32}}$")
        if key in seen_keys:
            fail(f"duplicate post key {key!r}")
        seen_keys.add(key)

        if post["role"] not in ("pin", "rotational"):
            fail(f"{key}: invalid role {post['role']!r} (expected 'pin' or 'rotational')")
        if not isinstance(post["silent"], bool) or not isinstance(post["enabled"], bool):
            fail(f"{key}: 'silent' and 'enabled' must be booleans")

        cta = post["cta_text"]
        if not isinstance(cta, str) or not (1 <= len(cta) <= 64):
            fail(f"{key}: cta_text must be 1..64 chars")
        elif "!" in cta:
            fail(f"{key}: cta_text contains banned '!'")

        sp = post["start_param"]
        if not isinstance(sp, str) or not START_PARAM_RE.match(sp):
            fail(f"{key}: invalid start_param {sp!r}")

        # Optional time-window, priority, max_sends, promo_slug
        raw_from = post.get("publish_from")
        raw_until = post.get("publish_until")
        dt_from = _parse_bound(raw_from, is_end=False, tz=tz) if raw_from is not None else None
        dt_until = _parse_bound(raw_until, is_end=True, tz=tz) if raw_until is not None else None
        if raw_from is not None and dt_from is None:
            fail(f"{key}: invalid publish_from {raw_from!r}")
        if raw_until is not None and dt_until is None:
            fail(f"{key}: invalid publish_until {raw_until!r}")
        if dt_from is not None and dt_until is not None and dt_from > dt_until:
            fail(f"{key}: publish_from ({raw_from}) must be <= publish_until ({raw_until})")

        if (
            post["rubric"] in ("promo", "holiday")
            or (post["rubric"] == "news_brief" and post["enabled"])
        ) and (raw_from is None or raw_until is None):
            fail(f"{key}: rubric {post['rubric']!r} requires both publish_from and publish_until")

        if "priority" in post and (not isinstance(post["priority"], int) or isinstance(post["priority"], bool)):
            fail(f"{key}: priority must be an integer")
        if "max_sends" in post and (
            not isinstance(post["max_sends"], int)
            or isinstance(post["max_sends"], bool)
            or post["max_sends"] < 1
        ):
            fail(f"{key}: max_sends must be an integer >= 1")

        promo_slug = post.get("promo_slug")
        if promo_slug is not None:
            if not isinstance(promo_slug, str) or not PROMO_SLUG_RE.match(promo_slug):
                fail(f"{key}: invalid promo_slug {promo_slug!r}")
            elif promos_by_slug is not None:
                camp = promos_by_slug.get(promo_slug)
                if camp is None:
                    fail(f"{key}: promo_slug {promo_slug!r} not found in promos.json")
                elif not camp["enabled"]:
                    fail(f"{key}: promo_slug {promo_slug!r} is not enabled in promos.json")
                elif dt_from is not None and dt_until is not None:
                    c_start, c_end = camp["starts_at"], camp["ends_at"]
                    if c_start is not None and c_end is not None and (dt_until < c_start or dt_from > c_end):
                        fail(f"{key}: post window does not overlap promo {promo_slug!r} window")

        html = post["html"]
        if not isinstance(html, str) or not html.strip():
            fail(f"{key}: html must be a non-empty string")
            continue

        if "!" in html:
            fail(f"{key}: contains banned '!'")

        parser = TelegramHTMLValidator()
        parser.feed(html)
        parser.close()
        if parser.stack:
            parser.errors.append(f"unclosed HTML tag(s): {', '.join(parser.stack)}")
        for err in parser.errors:
            fail(f"{key}: {err}")

        plain_text = "".join(parser.text_parts).strip()
        plain_len = len(plain_text)

        image_val = post.get("image")
        if image_val is not None:
            if not isinstance(image_val, str) or not image_val.strip():
                fail(f"{key}: image must be a non-empty relative path string")
            else:
                img_rel = image_val.strip()
                norm_parts = os.path.normpath(img_rel).split(os.sep)
                _, ext = os.path.splitext(img_rel.lower())
                if os.path.isabs(img_rel) or ".." in norm_parts:
                    fail(f"{key}: image path must be relative without '..': {img_rel!r}")
                elif ext not in ALLOWED_IMAGE_EXTS:
                    fail(f"{key}: image extension {ext!r} not in {sorted(ALLOWED_IMAGE_EXTS)}")
                else:
                    base_dir = os.path.dirname(os.path.abspath(path))
                    candidate = os.path.realpath(os.path.join(base_dir, img_rel))
                    if os.path.commonpath([os.path.realpath(base_dir), candidate]) != os.path.realpath(base_dir):
                        fail(f"{key}: image path escapes feed directory: {img_rel!r}")
                    elif not os.path.isfile(candidate):
                        fail(f"{key}: image file not found: {img_rel!r}")
                if plain_len > 1024:
                    fail(f"{key}: image caption plain-text length ({plain_len}) exceeds 1024")

        needs_limitation = (
            post["role"] == "pin"
            or post["rubric"]
            in ("onboarding", "offer_reference", "offer", "promo", "transparency", "trial_to_paid")
            or bool(LIMITATION_TRIGGER.search(plain_text))
        )
        is_reference = post["role"] == "pin" or post["rubric"] in (
            "onboarding",
            "offer_reference",
            "stars_guide",
        )
        if is_reference:
            if plain_len < 300 or plain_len > 600:
                fail(
                    f"{key}: plain-text length ({plain_len}) outside allowed reference range [300, 600]"
                )
        else:
            max_std = 290 if needs_limitation else 260
            if plain_len < 120 or plain_len > max_std:
                fail(
                    f"{key}: plain-text length ({plain_len}) outside allowed standard range [120, {max_std}]"
                )

        if m := REGULATORY_TRIGGERS.search(html):
            fail(f"{key}: contains prohibited regulatory trigger {m.group(0)!r}")
        if m := BANNED_INFRA.search(html):
            fail(f"{key}: contains prohibited infrastructure geo/provider name {m.group(0)!r}")
        if m := BANNED_VOICE.search(plain_text):
            fail(f"{key}: contains banned business_ru/brand term {m.group(0)!r}")
        if post["enabled"]:
            if m := TECHNICAL_BS.search(plain_text):
                fail(f"{key}: contains banned technical-BS / invented causality {m.group(0)!r}")
        if m := HARDCODED_PRICES.search(plain_text):
            fail(f"{key}: contains hardcoded Star price {m.group(0)!r} (pricing lives in @TitanTGProxy_bot)")

        lower_html = html.lower()
        if needs_limitation and (
            "аудио- и видеозвонки не поддерживаются" not in lower_html
            and "звонки внутри мессенджера недоступны" not in lower_html
        ):
            fail(f"{key}: missing mandatory HARD_LIMITATION disclosure")

        if post["rubric"] == "news_brief" and post["enabled"] and key not in LEGACY_NEWS_KEYS:
            lead_text = "".join(parser.lead_text_parts).strip()
            if m := NEWS_OFFTOPIC_RE.search(plain_text):
                fail(f"{key}: active news_brief contains off-topic/beta term {m.group(0)!r}")
            if not NEWS_DOMAIN_RE.search(lead_text):
                fail(
                    f"{key}: active news_brief headline/body outside <blockquote> lacks connectivity/Stars domain relevance"
                )
            if (
                isinstance(post.get("priority"), int)
                and not isinstance(post["priority"], bool)
                and post["priority"] >= 10
                and post.get("max_sends") != 1
            ):
                fail(f"{key}: urgent news_brief (priority >= 10) requires max_sends: 1")

    if file_failed:
        return False
    print(f"GATE PASS: {path} ({len(data['posts'])} posts)")
    return True


overall_status = 0
for path in sys.argv[1:]:
    if not validate_file(path):
        overall_status = 1

sys.exit(overall_status)
PY
