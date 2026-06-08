---
type: pipeline-artifact
artifact: producer-content-type-profiles
prd_ref: "§9.1, §8.10, §8.7, §12.5-Tier3"
locked: 2026-06-01
---

# Producer Output — content-type profile registry

The Producer (Haiku, `anthropic/claude-haiku-4.5`) writes ONE content-type profile per piece into `drafts/`, selected by the Strategist's `content_type`. The **core pipeline is channel-agnostic** — only this output shape varies by type (§8.10). **This registry is the authoritative list of BUILT types — the runbook defers to it.** **`video_short` and `slideshow` (module `tiktok__slideshow__faceless`) are BUILT**; `carousel`/`x_post` remain named-but-empty slots, filled when actually built (§8.7 anti-premature-abstraction).

## GLOBAL RULE — explicit setting anchor (all content types, slides AND video)
Every generation prompt — slideshow `scene`, video `visual_intent.environment`, any future image/video prompt — MUST carry an explicit **setting anchor**: location + era + demographic, sourced from the draft `audience`/`angle`. Image/video models default to the wrong region and era when the setting is implicit (e.g. "apartment" → Soviet-era block). The setting is never left to the model. For slideshows this is the Slide Brief `setting` field, injected into every prompt by `slide_brief.sh`; for video it is `visual_intent.environment`, which must name country, present-day era, and the audience demographic explicitly.

## Common envelope (every content type)
```markdown
# Draft — Intuiscale — [Date] — [piece-id]

## Envelope
- channel: [TikTok | X | ...]
- content_type: [video_short | slideshow | carousel | x_post]
- audience: [segment — from CANON]
- angle: [the strategic beat this piece advances]
- caption: [post copy]
- cta: [low-friction; stays soft until a real destination URL exists in CANON]
```

## Profile: video_short  ← BUILT (Phase 1)
```markdown
## Profile: video_short
- script: [dialogue / VO lines / on-screen beats]
- visual_intent:
    character: [who appears — appearance, wardrobe, demeanor]
    environment: [setting — location, lighting, time of day]
    style_seed: [aesthetic — from CANON visual language: Claymorphism / soft-3D / matte off-white / vibrant accents]
- motion_prompt: [camera movement + action, relative to the visuals]
```
`visual_intent` persists the character/scene/style the Creator + debate already reasoned about (costs ~nothing — capturing existing reasoning), closing the re-research gap before Phase 2. It is **descriptions, NOT generated assets** (asset rendering = Phase-2 research front, §13).

## Profile: slideshow  (module `tiktok__slideshow__faceless`)  ← BUILT (2026-06-05)
TikTok photo-slideshow, **FACELESS** (text-on-image / object / POV-hands — **no on-camera person**). Channel = TikTok; faceless is baked into the profile.
```markdown
## Profile: slideshow
- cover_hook: [slide 1 — the scroll-stop. For a slideshow the HOOK IS THE COVER SLIDE, not 2s of motion.]
- slide_copy: [ordered text, one entry per slide, 4–8 slides — a confessional arc, not a list of facts]
- per_slide_image_intent: [per slide: the still-image description — descriptions, NOT generated assets (§13)]
- faceless_note: [text-over-image / object / POV-hands framing; NO character, NO face on camera]
```
**CRAFT RULE (HARD — the one real T0 signal):** experiential / on-pain **CONFESSIONAL only**, NEVER formula/teaching. Unit-confusion is a **beat inside a personal story**, not the subject. *(Confessional @elleosiliwood traveled — 530 shares; the dry °F→°C formula card @mathmadeeasywithpat died — 2K. Same lesson the video debate loop already learned: told-not-shown / fabricated-stat. Inherited explicitly.)*
- **No `visual_intent.character`** — faceless by definition.
- **Success is SELF-RELATIVE**, never market-relative: does this piece beat our own earlier runs on Swipe-Through Rate + saves/shares (see `Campaigns/<product>/ANALYTICS.md` loop + `05_Marketing_System/gate_config/content_types.md`). Never "did we beat existing creators" — we are *manufacturing* the niche, not entering it.

### Asset Inventory (slideshow only — additive output section)
After `faceless_note`, the Producer ALSO emits a `## Asset Inventory` section: the SAME per-slide image intents it just wrote, restructured as the reusable asset list `asset_prompt.sh` consumes. **Zero new inference** — it is the intents, structured. **Output-format only** (no change to reasoning, envelope, or any other field). It MUST be a fenced ```json block (a Markdown table is too fragile for the bash parser):

```json
{
  "assets": {
    "<id>": {
      "type": "object | background",
      "method": "generate | template",
      "bg_type": "pink-key | full-bleed | n/a",
      "ref": "<refs-key only — a pointer, NEVER prompt text; \"n/a\" if none>",
      "source_slides": [<ints — the slides this asset appears in>],
      "subject": "<what the thing IS — generic, pattern-derived, NEVER a single creator's framing>",
      "composition": "<framing / angle / POV>",
      "lighting": "<light quality>",
      "descriptor": "<optional atom detail (skin tone, material) — omit if none>",
      "template": "<template-method assets ONLY — the data spec, e.g. weather(temp=70, unit=F)>"
    }
  }
}
```
The Producer supplies STRUCTURE + scene description only; it does NOT compose the final prompt string (it has no scout access). `asset_prompt.sh` fuses `subject`/`composition`/`lighting`/`descriptor` with the scout `SC_MODE`/`SC_COLOR` it reads, and owns palette/refs/negatives/seed. `template`-method assets carry NO `subject`/`composition`/`lighting` (never generated — copied verbatim).

**Authoring RULES:**
- **id naming:** generated/template atoms get a `_NN` suffix (`coat_rack_01`, `jacket_01`, `phone_empty_01`); single canonical templates take NO suffix (`weather_widget`).
- **Rhyme-dedup (one object recurring across slides = ONE asset, `source_slides` = the union of its slides).** Detect recurrence in the intents you wrote, in this authoritative order: (1) the `faceless_note` object-arc declaration is authoritative — it NAMES the rhyme (jacket+hook arc, thermometer mirror) → ONE asset spanning the arc's slides; (2) explicit cross-slide language ("same", "again", "mirror", "ANCHOR", "SAME <noun>", "the slide-N <noun> again"); (3) the same normalized noun-phrase repeated in the SAME scene state.
- **STATE-DISCRIMINATION (load-bearing):** a noun in a DIFFERENT state is NOT the same atom. run04 jacket hanging-on-hook = `[2,6]`; the slide-3 jacket worn/carried is a different state → EXCLUDED (gives `[2,6]`, not `[2,3,6]`). The fixture (coat_rack) stays itself across `[1,2,6]`; coat_rack and jacket are SEPARATE atoms even when co-located.
- **Phone shell vs UI widget = 2 assets on the same slide.** The physical phone/screen is a generated atom (`phone_empty_01`, pink-key, blank screen). The on-screen UI (weather widget, iMessage thread) is NEVER generated — it is a `template` asset (or kept on-device); the generated phone carries a BLANK screen, the UI is composited later. Do not merge them.
- **Background classification:** `doorway_bg` = interior threshold / entryway; `street_bg` = outdoor street; `window_bg` = view-through-a-window (the window scene takes its own slide). Classify each background slide into exactly one.

### Slide Brief (slideshow only — additive output section, feeds Path B)
The Asset Inventory above feeds **Path A** (atomic assets → cutout → compositor — the reusable/automatable end state, infra not yet built). The Producer ALSO emits a `## Slide Brief` block feeding **Path B**: one full image per slide, all locked to a single **anchor** reference image so the world (room/object/hands) stays identical — the ship-today route, no compositor. Same per-slide reasoning, restructured; **zero new inference**. Fenced ```json:

```json
{
  "setting": "<MANDATORY world anchor (GLOBAL RULE above): location + present-day era + demographic, from the draft audience/angle. Concrete and exclusionary — name what it IS and what it is NOT, so the model cannot drift (e.g. 'contemporary present-day USA, campus-adjacent college town, modern American interiors; subject a young international student ~18-28; NOT European, NOT old-world, NOT Soviet-era'). Injected into EVERY prompt by slide_brief.sh.>",
  "anchor": <slide-int — the slide that cleanly ESTABLISHES the recurring rhyme object in its canonical static state; generated FIRST with no reference, every other slide is generated with it attached>,
  "slides": {
    "<n>": "<full-frame scene, RENDERABLE VISUAL TOKENS ONLY — the whole slide as one image. Detailed and concrete (materials, objects, light), but NO strategy/rationale (that stays in per_slide_image_intent). ONE concrete choice, never either/or slop (write 'slung over a forearm', never 'tied at the waist / slung over a forearm').>"
  }
}
```
The Producer supplies `setting` + anchor + clean per-slide scenes only. `slide_brief.sh` injects `setting` into every prompt, fuses the shared look line (from scout `SC_MODE`/`SC_COLOR`), and emits **self-contained, ready-to-paste prompts** (scene + setting + look in one string — no manual appending). It also owns the reference wiring (anchor → "generate first"; others → "reference: anchor"), caption pairing (from `slide_copy`), and the UI/digit **overlay** notes derived from the Asset Inventory's `template`-method assets. `setting` is REQUIRED (the emitter rejects a draft without it — exit 4); `anchor` must be one of the slide keys.

## Profile: carousel  ← REGISTERED, NOT BUILT (Phase 2+)
- slot reserved: (cover_hook, slide_copy[], per_slide_image_intent[]) — do not produce.

## Profile: x_post  ← REGISTERED, NOT BUILT (Phase 2+)
- slot reserved: (hook, body_or_thread[], optional_image_intent) — do not produce.

## Producer rules (Tier-3 spec — formatting only)
- Mechanical packaging + file output + LEDGER append. No new analysis.
- Fill only the profile for the selected `content_type`; `video_short` and `slideshow` are BUILT — others (`carousel`/`x_post`) STOP and flag.
- Append a LEDGER row (safe append-only); never edit existing rows.
- File-clean: valid front matter, all envelope fields present, `n/a` for any genuinely-empty field (never blank).
