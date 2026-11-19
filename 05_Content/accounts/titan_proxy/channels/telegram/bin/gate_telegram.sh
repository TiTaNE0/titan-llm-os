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
import json
import os
import re
import sys
from html.parser import HTMLParser

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
HARDCODED_PRICES = re.compile(r"(?<!\d)(139|329|699)(?!\d)")
LIMITATION_TRIGGER = re.compile(
    r"(звонк|аудио|тариф|\bbasic\b|\bfamily\b|\bpremium\b)",
    re.I,
)
KEY_RE = re.compile(r"^[a-z0-9_]{3,32}$")
START_PARAM_RE = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
ALLOWED_TAGS = {"b", "i", "code", "a", "blockquote"}
ALLOWED_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}


class TelegramHTMLValidator(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.stack: list[str] = []
        self.errors: list[str] = []
        self.text_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag not in ALLOWED_TAGS:
            self.errors.append(f"disallowed HTML tag <{tag}>")
        self.stack.append(tag)

    def handle_endtag(self, tag: str) -> None:
        if not self.stack or self.stack[-1] != tag:
            self.errors.append(f"unbalanced HTML closing tag </{tag}>")
            return
        self.stack.pop()

    def handle_data(self, data: str) -> None:
        self.text_parts.append(data)


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
            in ("onboarding", "offer_reference", "offer", "transparency", "trial_to_paid")
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
        if m := HARDCODED_PRICES.search(plain_text):
            fail(f"{key}: contains hardcoded Star price {m.group(0)!r} (pricing lives in @TitanTGProxy_bot)")

        lower_html = html.lower()
        if needs_limitation and (
            "аудио- и видеозвонки не поддерживаются" not in lower_html
            and "звонки внутри мессенджера недоступны" not in lower_html
        ):
            fail(f"{key}: missing mandatory HARD_LIMITATION disclosure")

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
