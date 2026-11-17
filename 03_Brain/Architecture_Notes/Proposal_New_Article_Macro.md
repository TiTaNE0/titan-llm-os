---
type: macro_proposal
macro: "/new_article"
target: "03_Brain/System_Agents.md"
status: proposed
created: 2026-11-11
---

# Proposal: `/new_article [Topic] for [[Account]]`

> Architectural proposal for the `/new_article` macro to be graduated into `03_Brain/System_Agents.md` via `/graduate` with explicit user approval.

## Proposed Macro Specification

### `### /new_article [Topic] for [[Account]]`
1. **Account & module check:** Resolve `account` from argument `for [[Account]]` (defaults to `titan_proxy` for article runs, or `modules.yaml → accounts.default`). Verify `article` is in `active_modules` in `05_Content/modules.yaml`. If not, refuse with E1: *"article module inactive — enable in modules.yaml before running."*
2. **Channel tactics:** Read `05_Content/accounts/<account>/channels/articles/strategy.md` and `drafting_contract.md`.
3. **Persona & Voice:** Resolve target persona from topic or frontmatter requirement (`ru_devops`, `ru_business`, `ru_family`). Load matching voice file (`accounts/<account>/voice/<persona>_ru.md`) and universal application procedure `_shared/voice_pass.md`.
4. **Template:** Read `05_Content/modules/article/templates/Article_Template.md`.
5. **Pass 1 (internal):** Technical scratch answering the core query directly in the opening lines. Not emitted.
6. **Pass 2:** Rewrite applying voice laws, persona vocabulary, and zero `!` punctuation. Verify presence of 2–4 FAQ items and related slugs.
7. **Deterministic Gate:** Run `./.vault_link/05_Content/accounts/<account>/channels/articles/bin/gate_article.sh <draft_path>`. If gate fails, halt with E3 and revise.
8. **Critic Check:** Submit draft snapshot to Critic (Gemini 3.1 Pro via `agy -p`) against `rubric.md`. A SHIP verdict is required.
9. **Write File:** Save draft to `content/articles/<variant>/<slug>.md` with canonical frontmatter (`title`, `description`, `slug`, `section`, `persona`, `publishAt`, `faq`, `related`).
10. **Board & Ledger:** Add entry to `05_Content/accounts/<account>/channels/articles/LEDGER.md` in `draft` status.
11. **HALT:** Surface draft path and preview instructions. Do NOT push or set status to `published` without explicit user review.
12. **Telemetry:** `Invoke: emit_telemetry(macro=new_article, status=success|error, duration_ms, error_class, persona)`
