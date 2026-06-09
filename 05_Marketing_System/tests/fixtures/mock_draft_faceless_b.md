---
type: pipeline-artifact
artifact: producer-draft
campaign: MockCampaign
run: mock_run_b
piece_id: mock_piece_b
content_type: slideshow
module: tiktok__slideshow__faceless
channel: TikTok
created: 2026-06-09
---

# Mock Draft B — fixture for verify_asset_prompt.sh accumulation test

## Envelope
- channel: TikTok
- content_type: slideshow
- audience: mock audience for fixture tests
- angle: mock angle B for accumulation tests
- caption: mock caption B
- cta: mock cta · coming soon

## Profile: slideshow
- cover_hook: mock cover hook B
- slide_copy:
  1. *"mock B caption one."*
  2. *"mock B caption two."*

- per_slide_image_intent:
  1. mock B scene one description
  2. mock B scene two description

- faceless_note: mock faceless note B.

## Slide Brief
```json
{
  "setting": "a different generic mock setting for fixture B",
  "anchor": 1,
  "slides": {
    "1": "mock B slide one scene description, fixture only.",
    "2": "mock B slide two scene description, fixture only."
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
      "source_slides": [1, 2],
      "subject": "a generic mock object isolated from any background",
      "composition": "centered, eye-level, isolated object, vertical",
      "lighting": "flat soft natural daylight"
    },
    "mock_obj_02": {
      "type": "object",
      "method": "generate",
      "bg_type": "pink-key",
      "ref": "mock_ref_a",
      "source_slides": [2],
      "subject": "a different generic mock object, fixture only",
      "composition": "centered, eye-level, isolated object, vertical",
      "lighting": "flat soft natural daylight"
    }
  }
}
```
