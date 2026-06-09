---
type: pipeline-artifact
artifact: producer-draft
campaign: MockCampaign
run: mock_run_a
piece_id: mock_piece_a
content_type: slideshow
module: tiktok__slideshow__faceless
channel: TikTok
created: 2026-06-09
---

# Mock Draft A — fixture for verify_asset_prompt.sh

## Envelope
- channel: TikTok
- content_type: slideshow
- audience: mock audience for fixture tests
- angle: mock angle for fixture tests
- caption: mock caption line
- cta: mock cta · coming soon

## Profile: slideshow
- cover_hook: mock cover hook description
- slide_copy:
  1. *"mock caption one."*
  2. *"mock caption two."*
  3. *"mock caption three."*

- per_slide_image_intent:
  1. mock scene one description
  2. mock scene two description
  3. mock scene three description

- faceless_note: mock faceless note for fixture tests.

## Slide Brief
```json
{
  "setting": "a generic mock setting used only by the fixture suite",
  "anchor": 2,
  "slides": {
    "1": "mock slide one scene description, anchor-locked, fixture only.",
    "2": "mock slide two scene description, the anchor slide, fixture only.",
    "3": "mock slide three scene description, anchor-locked, fixture only."
  }
}
```

## Asset Inventory
```json
{
  "assets": {
    "mock_obj_01": {
      "type": "object",
      "method": "generate",
      "bg_type": "pink-key",
      "ref": "mock_ref_a",
      "source_slides": [1, 3],
      "subject": "a generic mock object isolated from any background",
      "composition": "centered, eye-level, isolated object, vertical",
      "lighting": "flat soft natural daylight"
    },
    "mock_bg_01": {
      "type": "background",
      "method": "generate",
      "bg_type": "full-bleed",
      "ref": "mock_ref_b",
      "source_slides": [2],
      "subject": "a generic mock environment with no people",
      "composition": "wide POV, vertical 9:16",
      "lighting": "flat natural daylight"
    },
    "mock_template_01": {
      "type": "object",
      "method": "template",
      "bg_type": "n/a",
      "ref": "n/a",
      "source_slides": [1, 2],
      "template": "mock_widget(mode=test, value=42)"
    }
  }
}
```
