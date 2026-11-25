#!/usr/bin/env bash
# Acceptance: Antigravity_Pool_Aware_Quota_Regimes (DoD 1-5). Generation uses temp dirs only.
KIT=/Users/titane0/AI_Workflow/claude-agent-kit
LIVE="$HOME/.gemini/config/plugins/claude-agent-kit"
T="$(mktemp -d "${TMPDIR:-/tmp}/ag_acc.XXXXXX")"; trap 'rm -rf "$T"' EXIT
G="gem""ini-"
FAIL=0; N=0
ok(){ N=$((N+1)); echo "ok   $1"; }
bad(){ N=$((N+1)); FAIL=$((FAIL+1)); echo "FAIL $1"; }
has(){ grep -qxF -- "$2" "$1" && ok "$3" || bad "$3 (missing: $2)"; }
hasnt(){ grep -qF -- "$2" "$1" && bad "$3 (present: $2)" || ok "$3"; }

gen(){ # name bindings-body
  mkdir -p "$T/$1"; printf '%s\n' "$2" > "$T/$1.b"
  (cd "$KIT" && ./install.sh setup-antigravity --path "$T/$1/plug" --bindings "$T/$1.b") > "$T/$1.log" 2>&1
  echo $? > "$T/$1.rc"
}
skill(){ echo "$T/$1/plug/skills/orchestrator-tick/SKILL.md"; }
GATES="spec-writer planner pm-reviewer validator failure-panel"
gates_b(){ for r in $GATES; do echo "swarm.role.$r=$1"; done; }

L2="2. \`Gemini-Low Spill\`: G below its floor. Worker roles with route \`none\` or a Pool A route run as routes on the worker spill model (on their tier when it is \`none\`); gate roles with a Pool A route run on the gate fallback model when it is on Pool B, else on their tier; gate roles with route \`none\` stay on their tier; Pool B routes run as listed."
L3="3. \`Claude-Depleted\`: C below its floor. Gate roles with a Pool B route run on the gate fallback model (on their tier when it is \`none\`); worker roles with a Pool B route run on their tier; Pool A routes run as listed."
INTRO="a model ID starting with \`gemini-\` is on the Gemini pool (Pool A), and any other model ID (such as \`claude-*\`) is on the Claude pool (Pool B)"
FIVE='`spec-writer`, `planner`, `pm-reviewer`, `validator`, `failure-panel`'

common(){ # name label
  local s; s="$(skill "$1")"
  [ "$(cat "$T/$1.rc")" = 0 ] && ok "$2 setup rc 0" || { bad "$2 setup rc ($(head -3 "$T/$1.log"))"; return; }
  has "$s" "$L2" "$2 regime 2 per pool (DoD2)"
  has "$s" "$L3" "$2 regime 3 per pool (DoD2)"
  grep -qF -- "$INTRO" "$s" && ok "$2 intro pool-by-model (DoD1)" || bad "$2 intro"
  hasnt "$s" "worker on the Claude pool (Pool B);" "$2 stale claim gone (DoD1)"
  hasnt "$s" "3. \`Claude-Depleted\`: C below its floor. Gate routes run" "$2 old regime 3 gone"
  grep -qF "Never run a gate role on a worker tier or on the worker spill model" "$s" && ok "$2 never-gate-on-worker rule kept" || bad "$2 never-gate rule"
  (cd "$KIT" && ./install.sh check-antigravity --path "$T/$1/plug") >/dev/null 2>&1 && ok "$2 check-antigravity 0" || bad "$2 check-antigravity"
  for f in "$T/$1"/plug/skills/*/SKILL.md; do [ "$(wc -c <"$f")" -le 24000 ] || bad "$2 size $f"; done
}

# gemini gates (operator shape)
gen gem "gate=pro
worker=flash
$(gates_b ${G}alpha-judge-high)
swarm.fallback.gate=${G}alpha-judge-high
swarm.spill.worker=claude-beta-spill-med"
common gem "gemini-gates"; s="$(skill gem)"
has "$s" "- Routes on Pool A: $FIVE" "gemini-gates A list"
has "$s" '- Routes on Pool B: `none`' "gemini-gates B none"
has "$s" '- Fallback model pools: gate fallback `Pool A`, worker spill `Pool B`' "gemini-gates fallback pools"

# claude gates
gen cla "gate=pro
worker=flash
$(gates_b claude-alpha-judge-high)
swarm.fallback.gate=${G}alpha-fallback-high
swarm.spill.worker=claude-beta-spill-med"
common cla "claude-gates"; s="$(skill cla)"
has "$s" '- Routes on Pool A: `none`' "claude-gates A none"
has "$s" "- Routes on Pool B: $FIVE" "claude-gates B list"
has "$s" '- Fallback model pools: gate fallback `Pool A`, worker spill `Pool B`' "claude-gates fallback pools"

# mixed, claude fallback
gen mix "gate=pro
worker=flash
swarm.role.spec-writer=${G}alpha-judge-high
swarm.role.planner=${G}alpha-judge-high
swarm.role.pm-reviewer=${G}alpha-judge-high
swarm.role.failure-panel=${G}alpha-judge-high
swarm.role.validator=claude-alpha-judge-high
swarm.role.builder=${G}beta-worker-med
swarm.fallback.gate=claude-alpha-fallback-high
swarm.spill.worker=claude-beta-spill-med"
common mix "mixed"; s="$(skill mix)"
has "$s" '- Routes on Pool A: `spec-writer`, `planner`, `pm-reviewer`, `failure-panel`, `builder`' "mixed A list"
has "$s" '- Routes on Pool B: `validator`' "mixed B list"
has "$s" '- Fallback model pools: gate fallback `Pool B`, worker spill `Pool B`' "mixed fallback pools"

# prefix edge
gen edge "gate=pro
worker=flash
swarm.role.validator=geminix-alpha
swarm.role.planner=x${G}alpha
swarm.spill.worker=claude-beta-spill-med"
s="$(skill edge)"
has "$s" '- Routes on Pool A: `none`' "edge A none (only exact gemini- prefix is Pool A)"
has "$s" '- Routes on Pool B: `planner`, `validator`' "edge B list"
has "$s" '- Fallback model pools: gate fallback `none`, worker spill `Pool B`' "edge unset fallback is none"

# tier-only: no hybrid text
gen tier "gate=pro
worker=flash"
s="$(skill tier)"
{ grep -qE "Routes on Pool|Hybrid swarm|Fallback model pools|Gemini-Low Spill" "$s"; } && bad "tier-only has hybrid text" || ok "tier-only has no hybrid/quota text"

# DoD4 read-only on live plugin
if [ -f "$LIVE/skills/orchestrator-tick/SKILL.md" ]; then
  s="$LIVE/skills/orchestrator-tick/SKILL.md"
  has "$s" "- Routes on Pool A: $FIVE" "live A list"
  has "$s" '- Routes on Pool B: `none`' "live B none"
  has "$s" '- Fallback model pools: gate fallback `Pool A`, worker spill `Pool B`' "live fallback pools"
  grep -qF -- "$INTRO" "$s" && ok "live intro" || bad "live intro"
  hasnt "$s" "worker on the Claude pool (Pool B);" "live stale claim absent"
  has "$s" "$L2" "live regime 2"; has "$s" "$L3" "live regime 3"
else bad "live plugin missing"; fi
(cd "$KIT" && ./install.sh check-antigravity) >/dev/null 2>&1 && ok "live check-antigravity 0 (DoD4)" || bad "live check-antigravity"

# DoD5: kit-only changes, hygiene scan
ch="$(cd "$KIT" && git status --porcelain | awk '{print $2}' | sort | tr '\n' ' ')"
case "$ch" in *install.sh*) ;; esac
extra="$(cd "$KIT" && git status --porcelain | awk '{print $2}' | grep -vE '^(install.sh|README.md|tests/test_install_antigravity.sh)$' || true)"
[ -z "$extra" ] && ok "kit changes limited to install.sh/README/test (DoD5)" || bad "unexpected kit changes: $extra"
(cd "$KIT" && git diff --name-only | grep -qE 'tests/test_antigravity_acceptance.sh|global/agents|project-template') && bad "forbidden kit files touched" || ok "forbidden kit files untouched"
if (cd "$KIT" && grep -rEn "cla""ude-(opus|sonnet|haiku|fable)-|gem""ini-[0-9a-z]" install.sh README.md tests/ >/dev/null 2>&1); then
  # operator-style synthetic spill id lives only in my temp files; any hit in kit is a violation
  bad "model-string literal in kit"; else ok "no model-string literals in kit (DoD5)"; fi

echo "$((N-FAIL))/$N passed"; [ "$FAIL" = 0 ]
