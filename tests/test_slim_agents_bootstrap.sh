#!/usr/bin/env bash
# test_slim_agents_bootstrap.sh - regression and RED/GREEN verification for slim AGENTS.md BOOTSTRAP.
# Maps to Slim_AGENTS_Bootstrap_For_Subagents_And_Build_Chain DoD 1-3.
# No recursive suite loops; safe to invoke directly or from test_hook_argument_scope.sh.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR ACC_SKIP_GATEWAY

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
PROG="${PROGRAMMING_ROOT:-$HOME/Programming}"
ONBOARDING="$KIT/project-template/ONBOARDING.md"
TASK_FILE="${SAB_TASK_FILE:-$REPO_ROOT/02_Tasks/TiTan_LLM_OS/Slim_AGENTS_Bootstrap_For_Subagents_And_Build_Chain.md}"
DEFAULT_TOOL_REG_SHA="b3addbb9f1b46a1a27c74acefb0605f741fa23aa9446e029ff62b2ecc2cd29e0"
EXPECTED_TOOL_REG_SHA="${TOOL_REGISTRY_PRE_SHA256:-$DEFAULT_TOOL_REG_SHA}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/slim_bootstrap.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

# --- Checkers -----------------------------------------------------------------
check_bootstrap() {
  local f="$1" line
  [ -f "$f" ] || return 1
  grep -qF -- 'You MUST read and adopt' "$f" && return 1
  line="$(grep -F -- '- **BOOTSTRAP:**' "$f" | head -1)"
  [ -n "$line" ] || return 1
  printf '%s\n' "$line" | grep -qF -- 'skip `BOOTSTRAP`' || return 1
  printf '%s\n' "$line" | grep -qF -- 'Vault firewall' || return 1
  printf '%s\n' "$line" | grep -qF -- 'CLAUDE.md' || return 1
  printf '%s\n' "$line" | grep -qF -- '03_Brain/System_Agents.md' || return 1
  printf '%s\n' "$line" | grep -qF -- '<!-- CONTENT PIPELINE' || return 1
  printf '%s\n' "$line" | grep -qF -- 'Context_Injection_Protocol.md § 3' || return 1
  return 0
}

check_onboarding() {
  local f="$1"
  [ -f "$f" ] || return 1
  grep -qF -- '### 3. Declare the project identity in AGENTS.md' "$f" || return 1
  grep -qF -- '- **BOOTSTRAP:**' "$f" || return 1
  grep -qF -- 'skip' "$f" || return 1
  grep -qF -- 'Vault firewall' "$f" || return 1
  grep -qF -- 'CLAUDE.md' "$f" || return 1
  grep -qF -- '03_Brain/System_Agents.md' "$f" || return 1
  grep -qF -- '<!-- CONTENT PIPELINE' "$f" || return 1
  grep -qF -- 'Context_Injection_Protocol.md § 3' "$f" || return 1
  grep -qF -- '**Identity:** This project is `[[<Name>]]`' "$f" || return 1
  return 0
}

check_identity() {
  local f="$1" slug="$2"
  [ -f "$f" ] || return 1
  grep -qF -- "Identity:** This project is \`[[$slug]]\`" "$f"
}

check_first_wikilink() {
  local f="$1" slug="$2" first
  [ -f "$f" ] || return 1
  first="$(grep -oE '\[\[[^]]+\]\]' "$f" | head -1 | tr -d '[]')"
  [ "$first" = "$slug" ]
}

resolve_agents_file() {
  local dir="$1"
  if [ -f "$dir/AGENTS.md" ]; then
    printf '%s\n' "$dir/AGENTS.md"
  elif [ -f "$dir/agents.md" ]; then
    printf '%s\n' "$dir/agents.md"
  else
    printf '%s\n' "$dir/AGENTS.md"
  fi
}

check_brain_projects_untouched() {
  local repo="$1" expected_sha="$2" st line actual_sha
  st="$(git -C "$repo" status --porcelain --untracked-files=all -- 01_Projects/ 03_Brain/ 2>/dev/null)" || return 1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$line" = " M 03_Brain/Tool_Registry.md" ]; then
      [ -f "$repo/03_Brain/Tool_Registry.md" ] || return 1
      actual_sha="$(shasum -a 256 "$repo/03_Brain/Tool_Registry.md" | awk '{print $1}')"
      [ "$actual_sha" = "$expected_sha" ] || return 1
    else
      return 1
    fi
  done <<EOF
$st
EOF
  return 0
}

# --- DoD 1: Root, kit, ONBOARDING, and active onboarded repos -----------------
check_bootstrap "$REPO_ROOT/AGENTS.md" \
  && pass "DoD1: root AGENTS.md slim BOOTSTRAP" \
  || fail "DoD1: root AGENTS.md slim BOOTSTRAP"
check_identity "$REPO_ROOT/AGENTS.md" "TiTan_LLM_OS" \
  && pass "DoD1: root AGENTS.md Identity TiTan_LLM_OS" \
  || fail "DoD1: root AGENTS.md Identity TiTan_LLM_OS"

check_bootstrap "$KIT/AGENTS.md" \
  && pass "DoD1: claude-agent-kit AGENTS.md slim BOOTSTRAP" \
  || fail "DoD1: claude-agent-kit AGENTS.md slim BOOTSTRAP"
check_identity "$KIT/AGENTS.md" "claude-agent-kit" \
  && pass "DoD1: claude-agent-kit AGENTS.md Identity" \
  || fail "DoD1: claude-agent-kit AGENTS.md Identity"
check_first_wikilink "$KIT/AGENTS.md" "claude-agent-kit" \
  && pass "DoD1: claude-agent-kit first wikilink resolves claude-agent-kit" \
  || fail "DoD1: claude-agent-kit first wikilink"

check_onboarding "$ONBOARDING" \
  && pass "DoD1: ONBOARDING.md documents slim BOOTSTRAP + Identity" \
  || fail "DoD1: ONBOARDING.md documents slim BOOTSTRAP + Identity"

ONBOARDED_REPOS=(
  "stagepass"
  "road-assist"
  "nearest-address-codes"
  "intuiscale"
  "couriers-social"
  "titan-proxy-bot"
  "titan-proxy-landings"
  "voice-bot"
  "mashov-tracker"
)

for dir in "${ONBOARDED_REPOS[@]}"; do
  f="$(resolve_agents_file "$PROG/$dir")"
  check_bootstrap "$f" \
    && pass "DoD1: $dir/AGENTS.md slim BOOTSTRAP" \
    || fail "DoD1: $dir/AGENTS.md slim BOOTSTRAP"
done

IDENTITY_PAIRS=(
  "stagepass:stagepass"
  "road-assist:road-assist"
  "nearest-address-codes:nearest-address-codes"
  "intuiscale:Intuiscale"
  "couriers-social:couriers-social"
  "titan-proxy-bot:titan-proxy-bot"
  "mashov-tracker:mashov-tracker"
)

for pair in "${IDENTITY_PAIRS[@]}"; do
  dir="${pair%%:*}"
  slug="${pair#*:}"
  f="$(resolve_agents_file "$PROG/$dir")"
  check_identity "$f" "$slug" \
    && pass "DoD1: $dir/AGENTS.md Identity $slug" \
    || fail "DoD1: $dir/AGENTS.md Identity $slug"
  check_first_wikilink "$f" "$slug" \
    && pass "DoD1: $dir/AGENTS.md first wikilink resolves $slug" \
    || fail "DoD1: $dir/AGENTS.md first wikilink resolves $slug"
done

NON_ONBOARDED="$PROG/couriers-notes/AGENTS.md"
if [ -f "$NON_ONBOARDED" ] && ! grep -qF -- 'BOOTSTRAP' "$NON_ONBOARDED" && ! grep -qF -- 'System_Agents.md' "$NON_ONBOARDED"; then
  pass "DoD1: couriers-notes/AGENTS.md untouched (no BOOTSTRAP/System_Agents.md)"
else
  fail "DoD1: couriers-notes/AGENTS.md unexpectedly modified or missing"
fi

# --- DoD 1 RED controls (temp copies only) ------------------------------------
cp "$PROG/stagepass/AGENTS.md" "$TMP/red_legacy.md"
printf '\n- **BOOTSTRAP:** You MUST read and adopt all rules, macros, and protocols from `./.vault_link/03_Brain/System_Agents.md` BEFORE taking any action.\n' >> "$TMP/red_legacy.md"
check_bootstrap "$TMP/red_legacy.md" \
  && fail "DoD1 RED: legacy phrasing must fail" \
  || pass "DoD1 RED: legacy phrasing fails check_bootstrap"

sed 's/skip/ignore/g' "$PROG/stagepass/AGENTS.md" > "$TMP/red_noskip.md"
check_bootstrap "$TMP/red_noskip.md" \
  && fail "DoD1 RED: missing skip must fail" \
  || pass "DoD1 RED: missing skip fails check_bootstrap"

grep -vF -- '- **BOOTSTRAP:**' "$PROG/stagepass/AGENTS.md" > "$TMP/red_noboot.md"
check_bootstrap "$TMP/red_noboot.md" \
  && fail "DoD1 RED: missing BOOTSTRAP must fail" \
  || pass "DoD1 RED: missing BOOTSTRAP fails check_bootstrap"

sed 's/<!-- CONTENT PIPELINE/<!-- REMOVED/g' "$PROG/stagepass/AGENTS.md" > "$TMP/red_nomarker.md"
check_bootstrap "$TMP/red_nomarker.md" \
  && fail "DoD1 RED: missing CONTENT PIPELINE marker must fail" \
  || pass "DoD1 RED: missing CONTENT PIPELINE marker fails check_bootstrap"

sed '1i\
See [[Context_Injection_Protocol]]
' "$PROG/stagepass/AGENTS.md" > "$TMP/red_wikilink.md"
check_first_wikilink "$TMP/red_wikilink.md" "stagepass" \
  && fail "DoD1 RED: wikilink above Identity must fail" \
  || pass "DoD1 RED: wikilink above Identity fails check_first_wikilink"

sed 's/<!-- CONTENT PIPELINE/<!-- REMOVED/g' "$ONBOARDING" > "$TMP/red_onboarding.md"
check_onboarding "$TMP/red_onboarding.md" \
  && fail "DoD1 RED: stripped ONBOARDING.md must fail" \
  || pass "DoD1 RED: stripped ONBOARDING.md fails check_onboarding"

# --- DoD 2: 03_Brain/ and 01_Projects/ untouched (in-flight task gate only) ---
if [ -f "$TASK_FILE" ]; then
  check_brain_projects_untouched "$REPO_ROOT" "$EXPECTED_TOOL_REG_SHA" \
    && pass "DoD2: 01_Projects/ and 03_Brain/ untouched (Tool_Registry.md sha verified)" \
    || fail "DoD2: unexpected change under 01_Projects/ or 03_Brain/"
else
  echo "SKIP: DoD2 live 01_Projects/ and 03_Brain/ check (task archived)"
fi

# --- DoD 2 RED/GREEN fixture proofs in disposable temp git repo ---------------
FIX_REPO="$TMP/fix_repo"
mkdir -p "$FIX_REPO/01_Projects" "$FIX_REPO/03_Brain"
printf 'project-a\n' > "$FIX_REPO/01_Projects/Alpha.md"
printf 'brain-a\n' > "$FIX_REPO/03_Brain/System_Agents.md"
printf 'tool-reg-v1\n' > "$FIX_REPO/03_Brain/Tool_Registry.md"
git -C "$FIX_REPO" init -q
git -C "$FIX_REPO" config user.name test
git -C "$FIX_REPO" config user.email test@example.com
git -C "$FIX_REPO" config commit.gpgsign false
git -C "$FIX_REPO" add -A
git -C "$FIX_REPO" commit -qm init

# Simulate pre-existing dirty M 03_Brain/Tool_Registry.md
printf 'tool-reg-dirty-pre\n' > "$FIX_REPO/03_Brain/Tool_Registry.md"
FIX_PRE_SHA="$(shasum -a 256 "$FIX_REPO/03_Brain/Tool_Registry.md" | awk '{print $1}')"

check_brain_projects_untouched "$FIX_REPO" "$FIX_PRE_SHA" \
  && pass "DoD2 GREEN fixture: pre-existing dirty Tool_Registry.md passes" \
  || fail "DoD2 GREEN fixture: pre-existing dirty Tool_Registry.md should pass"

# RED: altering Tool_Registry.md sha256 fails
printf 'tool-reg-tampered\n' > "$FIX_REPO/03_Brain/Tool_Registry.md"
check_brain_projects_untouched "$FIX_REPO" "$FIX_PRE_SHA" \
  && fail "DoD2 RED fixture: tampered Tool_Registry.md must fail" \
  || pass "DoD2 RED fixture: tampered Tool_Registry.md fails"
printf 'tool-reg-dirty-pre\n' > "$FIX_REPO/03_Brain/Tool_Registry.md"

# RED: modifying another 03_Brain/ file fails
printf 'brain-modified\n' > "$FIX_REPO/03_Brain/System_Agents.md"
check_brain_projects_untouched "$FIX_REPO" "$FIX_PRE_SHA" \
  && fail "DoD2 RED fixture: modified 03_Brain/ file must fail" \
  || pass "DoD2 RED fixture: modified 03_Brain/ file fails"
git -C "$FIX_REPO" checkout -q -- 03_Brain/System_Agents.md

# RED: creating untracked file under 03_Brain/ fails
printf 'new-brain\n' > "$FIX_REPO/03_Brain/Untracked.md"
check_brain_projects_untouched "$FIX_REPO" "$FIX_PRE_SHA" \
  && fail "DoD2 RED fixture: untracked 03_Brain/ file must fail" \
  || pass "DoD2 RED fixture: untracked 03_Brain/ file fails"
rm -f "$FIX_REPO/03_Brain/Untracked.md"

# RED: modifying 01_Projects/ file fails
printf 'project-modified\n' > "$FIX_REPO/01_Projects/Alpha.md"
check_brain_projects_untouched "$FIX_REPO" "$FIX_PRE_SHA" \
  && fail "DoD2 RED fixture: modified 01_Projects/ file must fail" \
  || pass "DoD2 RED fixture: modified 01_Projects/ file fails"
git -C "$FIX_REPO" checkout -q -- 01_Projects/Alpha.md

# RED: creating untracked file under 01_Projects/ fails
printf 'new-project\n' > "$FIX_REPO/01_Projects/Beta.md"
check_brain_projects_untouched "$FIX_REPO" "$FIX_PRE_SHA" \
  && fail "DoD2 RED fixture: untracked 01_Projects/ file must fail" \
  || pass "DoD2 RED fixture: untracked 01_Projects/ file fails"
rm -f "$FIX_REPO/01_Projects/Beta.md"

if [ "$FAILS" -eq 0 ]; then
  echo "ALL GREEN"
  exit 0
fi
echo "$FAILS check(s) failed"
exit 1
