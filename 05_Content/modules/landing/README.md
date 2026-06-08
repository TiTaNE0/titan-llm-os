# Landing Page Module

**Status:** inactive
**Channel:** Web — landing pages, micro-copy, hero structures
**Prefix:** `landing_`
**Owner:** Evgeny Ogrizkov

## Scope

Web micro-copy: hero blocks, onboarding text, single-page value propositions. Output is markdown copy intended for dev handoff. Voice comes from `accounts/<account>/voice.md` (default account: `ogrizkov`); this module adds landing-page structural conventions only.

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — module manifest |
| `strategy.md` | Copy playbook: above-fold rules, CTA conventions |
| `templates/Landing_Template.md` | Default landing copy skeleton |

## How it's loaded

When activated, macros will:
1. Read `templates/Landing_Template.md` for structure
2. Read `strategy.md` for above-fold and CTA rules
3. Read `accounts/<account>/voice.md` for tone + `_shared/voice_pass.md` for application procedure
4. Generate a copy draft and HALT for user review

## Activation

1. Move `landing` from `inactive_modules` to `active_modules` in `05_Content/modules.yaml`
2. Run `/enable_module landing`
3. Implement the `/new_landing` macro in `03_Brain/System_Agents.md` (currently a stub)

## Inactive Guard

Any macro that checks `modules.yaml` and finds `landing` absent from `active_modules` must halt immediately:
> "landing module inactive — enable in modules.yaml before running."
