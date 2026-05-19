# titan_proxy — Agent Resolution Guide

**Read this first when given any task scoped to this account.**

## Binding model: wikilinks only

Every vault-internal reference in this account is an Obsidian wikilink `"[[path]]"` — in frontmatter, body, and `MANIFEST.yaml`. Reasons:

- Obsidian auto-updates wikilinks on file rename → no silent breakage.
- Backlinks pane gives inverse lookup for free → never write `used_by:` fields, they'd drift.
- One mechanism end-to-end → no "frontmatter says X, body says Y" inconsistencies.

To resolve a wikilink like `"[[design/cyber_overdrive]]"`:
1. Strip the wrapping `"[[` and `]]"`.
2. Append `.md` if not present.
3. Read the file at that path, relative to either the vault root or the account root (Obsidian's "shortest unique" resolution; in this account the path forms used are unique enough that vault-root resolution works).

Code paths (`src/app/.../page.tsx`, `src/data/copy.ts`, `src/app/globals.css`) stay as raw strings — outside the vault, not Obsidian-managed.

## Hard rule: the persona is the entry point

If a request names a persona, channel, variant letter, or domain, your **first action** is to read the persona file. Never start with the channel file, the design file, or grep.

### How to resolve any input to a persona file

| Input form | Resolves to |
|------------|-------------|
| Persona slug (`ru_family`, `ru_devops`, `ru_business`) | `[[personas/<slug>]]` |
| Variant letter (`a`, `b`, `c`) | persona in `MANIFEST.yaml` where `variant_key == <letter>` |
| Domain (`mtproxy.guru`, `titanproxy.tech`, `mtproxy.link`) | persona in `MANIFEST.yaml` where `domain == <domain>` |
| Phrase ("the family one", "the business landing", "Iranian variant") | best-match persona by description |

If you cannot resolve to exactly one persona, **stop and ask** — do not guess.

Fastest path: load `MANIFEST.yaml` first — every input form above is one lookup against that file.

## Resolution procedure

Once you have the persona file, follow this order. Do not skip steps. Do not reorder.

```
1. Read  MANIFEST.yaml                       (binding table, code anchors, channel list)
2. Read  [[accounts/titan_proxy/account]]    (product invariants — hard refusals apply globally)
3. Read  [[accounts/titan_proxy/brand]]      (names, banned phrases, tariff/limitation refs)
4. Read  [[personas/<persona>]]              (junction — frontmatter has design + voice + landing wikilinks)
5. Follow persona.design wikilink → read [[design/<...>]]
6. Follow persona.voice  wikilink → read [[voice/<...>]]
7. Follow persona.landing wikilink (if doing landing work) OR
   look up [[channels/<channel>/<persona>]] for other channels
```

If `[[channels/<channel>/<persona>]]` does NOT exist yet, that's the file you're creating. Use the matching landing file as the content reference.

## Examples

### "Create a video for ru_family"

```
MANIFEST.yaml.personas.ru_family →
  design:  "[[design/ember]]"
  voice:   "[[voice/family_ru]]"
  channels.landing: "[[channels/landing/ru_family]]"

Reads:
  [[accounts/titan_proxy/account]]      product invariants
  [[accounts/titan_proxy/brand]]        banned phrases, tariff refs
  [[personas/ru_family]]                junction
  [[design/ember]]                      cream + amber tokens, Manrope, warm halo
  [[voice/family_ru]]                   warm everyday RU, no jargon
  [[channels/landing/ru_family]]        existing landing copy — use as content reference

Create: channels/video/ru_family.md   (does not exist yet)
```

### "Update the landing copy for mtproxy.guru"

```
MANIFEST.yaml — domain mtproxy.guru → persona ru_family.

Reads:
  [[accounts/titan_proxy/account]]
  [[accounts/titan_proxy/brand]]
  [[personas/ru_family]]
  [[voice/family_ru]]                   (visual unchanged → design read optional)
  [[channels/landing/ru_family]]        EXISTS → this is the file you edit

Then:
  - Bump  last_synced  in [[channels/landing/ru_family]] frontmatter
  - Mirror change to  src/data/copy.ts  COPY_C  (per MANIFEST code_anchors)
```

### "What changed when you made variant B more midnight?"

```
MANIFEST.yaml — variant_key b → persona ru_business.

Reads:
  [[personas/ru_business]]
  [[design/sapphire]]                   ← edits go here

Then mirror to:
  src/app/globals.css [data-variant="b"]   (per design.source_of_truth and MANIFEST code_anchors)
```

## Inverse lookup — "what uses this design?"

- **Best:** open the design file in Obsidian → check Backlinks pane → every wikilink to this file appears automatically.
- **For agents without UI access:** grep the vault for the wikilink string `"[[design/<slug>]]"` — every match is a consumer.
- **Never** add a `used_by:` field to the design / voice file. That's the drift trap.

## Hard refusals at resolution time

- Never produce output for a persona without reading its design AND voice files. The voice file contains banned terms specific to that register — skipping it produces drift.
- Never mix two voices in one output. If a request implies it ("a video that targets both family and business users"), stop and ask which persona to write for.
- Never invent a persona / design / voice not listed in `MANIFEST.yaml`. New ones require explicit creation through the same template structure.
- Never edit `[[channels/landing/<persona>]]` without bumping its `last_synced` frontmatter date AND noting which `src/data/copy.ts` constant must be updated to match (per `MANIFEST.yaml` `code_anchors`).
- Never replace a wikilink with a bare slug ("design: ember"). Bare slugs are banned in this account — they break silently on rename.
