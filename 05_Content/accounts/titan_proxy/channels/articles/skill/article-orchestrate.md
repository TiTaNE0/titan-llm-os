---
type: operator_runbook
channel: articles
account: titan_proxy
status: active
created: 2026-11-11
---

# Runbook — SEO Article Batch Pipeline (Titan Proxy)

Repeatable workflow for generating, verifying, and publishing weekly article batches across `titanproxy.tech`, `bestproxy.deals`, and `mtproxy.guru`.

## Prerequisites
- Vault link available at `./.vault_link/`.
- Access to Grok (`grok -p`) for Scout queries.
- Gemini access via `agy -p` with model `Gemini 3.1 Pro (High)` for independent Critic veto.

## Phase 1: Topic Selection (Strategist)
1. Read `05_Content/accounts/titan_proxy/channels/articles/backlog.md`.
2. Pick 1 topic per variant for the current target week.
3. Check `05_Content/accounts/titan_proxy/channels/articles/LEDGER.md` to confirm the topics have not been published or drafted previously.

## Phase 2: Live Research (Scout)
1. Query user discussion context for the chosen topic via Grok:
   ```bash
   grok -p "Найди реальные вопросы и формулировки пользователей по теме: [Тема]. Выдели 3 конкретных технических нюанса или проблемы, с которыми сталкиваются люди. Без общих слов."
   ```
2. Extract user phrasing and common confusion points. Do NOT invent stats or latency metrics.

## Phase 3: Drafting (Writer)
1. Load persona and voice:
   - Variant A: `05_Content/accounts/titan_proxy/voice/terminal_ru.md`
   - Variant B: `05_Content/accounts/titan_proxy/voice/business_ru.md`
   - Variant C: `05_Content/accounts/titan_proxy/voice/family_ru.md`
2. Load invariants: `05_Content/accounts/titan_proxy/channels/articles/drafting_contract.md`.
3. Draft the article in `content/articles/<variant>/<slug>.md` using `Article_Template.md`.
4. Ensure:
   - Answer to core query in first 2–3 sentences.
   - 0 exclamation marks.
   - 0 regulatory trigger words.
   - 2–4 FAQ items included in frontmatter.
   - Related slugs referenced in frontmatter.

## Phase 4: Adversarial Verification (Critic & Gate)
1. Run deterministic code gate:
   ```bash
   ./.vault_link/05_Content/accounts/titan_proxy/channels/articles/bin/gate_article.sh content/articles/<variant>/<slug>.md
   ```
   If gate fails, fix the errors immediately.
2. Submit draft snapshot to Critic (Gemini via `agy -p`) against `rubric.md`:
   ```bash
   agy -p "Оцени статью против rubric.md. Вынеси вердикт SHIP или FIX со списком дефектов." --model "Gemini 3.1 Pro (High)"
   ```
   If Critic returns FIX, revise draft and re-gate.

## Phase 5: Production & Verification
1. Run local test suite:
   ```bash
   npm run lint && npm test && npm run build
   ```
2. Create feature branch `content/article-batch-<week>` and commit changes.
3. Open PR, inspect Vercel preview deployment.
4. Merge into `main` after human review.
5. Record entry in `LEDGER.md`.
