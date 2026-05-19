# titan_proxy — Account Index

Brand kit for the Titan Proxy product. Drives the landings repo (`titan-proxy-landings`) and any future video / social pipeline. One source of truth per piece of content; code is generated from these files.

## Agents start here

1. **`AGENTS.md`** — procedural rules for ANY task in this account (what to read, in what order, what not to do)
2. **`MANIFEST.yaml`** — machine-readable persona ↔ design ↔ voice ↔ channel bindings (single-read resolution table)

If you're an agent given a task scoped to `titan_proxy`, read both before doing anything else.

## Layout

```
titan_proxy/
├── account.md                       # product identity, invariants, hard refusals
├── brand.md                         # name forms, banned phrases, canonical claim, tariff/limitation refs
├── personas/                        # 1 persona = 1 audience segment = 1 variant
│   ├── ru_devops.md                 # → Variant A
│   ├── ru_business.md               # → Variant B
│   └── ru_family.md                 # → Variant C
├── design/                          # visual systems (mirror of globals.css [data-variant="..."] blocks)
│   ├── cyber_overdrive.md           # used by ru_devops
│   ├── sapphire.md                  # used by ru_business
│   └── ember.md                     # used by ru_family
├── voice/                           # tone / register profiles
│   ├── terminal_ru.md
│   ├── business_ru.md
│   └── family_ru.md
└── channels/
    └── landing/                     # full landing copy — mirrors src/data/copy.ts exactly
        ├── ru_devops.md
        ├── ru_business.md
        └── ru_family.md
```

## Variant ↔ vault mapping

| Variant | Persona | Design | Voice | Domain | Code anchor |
|---------|---------|--------|-------|--------|-------------|
| **A** | [[personas/ru_devops]] | [[design/cyber_overdrive]] | [[voice/terminal_ru]] | titanproxy.tech | `COPY_A`, `FAQ_A`, `STATUS_BADGE_A` |
| **B** | [[personas/ru_business]] | [[design/sapphire]] | [[voice/business_ru]] | mtproxy.link | `COPY_B`, `FAQ_B`, `STATUS_BADGE_B` |
| **C** | [[personas/ru_family]] | [[design/ember]] | [[voice/family_ru]] | mtproxy.guru | `COPY_C`, `FAQ_C`, `STATUS_BADGE_C` |

## Where the actual code lives

Repo: `~/Programming/titan-proxy-landings/`

| Vault file | Drives code file |
|------------|------------------|
| `design/*.md` color tokens | `src/app/globals.css` — `[data-variant="X"]` block |
| `personas/*.md` font choice | `src/app/<variant>/layout.tsx` — `next/font/google` imports |
| `channels/landing/*.md` | `src/data/copy.ts` — `COPY_<X>`, `FAQ_<X>`, `STATUS_BADGE_<X>` |
| `personas/*.md` SEO block | `src/app/<variant>/page.tsx` — `export const metadata` |
| `brand.md` tariff refs | `src/data/tariffs.ts` (never duplicated in channel copy) |

## Adding a new variant (sketch)

1. `personas/<new>.md` — pick a `variant_key` letter (next free, e.g. `d`). Frontmatter must contain `design: "[[design/<style>]]"`, `voice: "[[voice/<voice>]]"`, `landing: "[[channels/landing/<new>]]"` — all wikilinks.
2. `design/<style>.md` — define color tokens + font + effects.
3. `voice/<voice>.md` — define register.
4. `channels/landing/<new>.md` — write full copy. Frontmatter must link `persona: "[[personas/<new>]]"`, `design`, `voice` as wikilinks.
5. Register the persona in `MANIFEST.yaml` (also using wikilinks).
6. Run the (future) generator → produces:
   - `src/app/d/layout.tsx`
   - `src/app/d/page.tsx`
   - `src/data/copy.ts` append (`COPY_D`, `FAQ_D`, `STATUS_BADGE_D`)
   - `src/app/globals.css` append `[data-variant="d"]` block

## Binding model: wikilinks only

Every cross-reference between vault files in this account uses an Obsidian wikilink `"[[path]]"` — in frontmatter, body, and `MANIFEST.yaml`. Bare slugs (`design: ember`) are banned because they break silently when a file is renamed.

- Obsidian auto-updates wikilinks on rename → the binding self-heals.
- Inverse lookups ("what uses `[[design/ember]]`?") come from Obsidian's **Backlinks pane** automatically. Never write `used_by:` fields — they create a second source of truth that drifts.
- Code paths (`src/...`) stay as raw strings — outside the vault.

## Drift policy

When the code changes:
- If copy in `src/data/copy.ts` is edited → update the matching `[[channels/landing/<persona>]]` AND bump `last_synced` in its frontmatter
- If `globals.css` variant tokens change → update the matching `[[design/<slug>]]`
- These vault files are NOT regenerated from code; they're the source. Code is the derivative.
