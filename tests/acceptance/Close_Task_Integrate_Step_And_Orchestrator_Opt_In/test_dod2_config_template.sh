#!/usr/bin/env bash
# DoD 2: template has auto_integrate_projects: [] ; live config untouched; smoke asserts it.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
T="$VAULT/00_Templates/Orchestrator_Config_Template.yaml"
eq "default empty list" "$(grep -cE '^auto_integrate_projects: \[\]$' "$T")" 1
eq "single key line" "$(grep -c '^auto_integrate_projects:' "$T")" 1
eq "stagepass not listed" "$(grep '^auto_integrate_projects:' "$T" | grep -c stagepass)" 0
eq "key is last line" "$(tail -1 "$T")" 'auto_integrate_projects: []'
# template still valid YAML if a parser is present
if python3 -c 'import yaml' 2>/dev/null; then
  eq "yaml parses to []" "$(python3 -I -c 'import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))["auto_integrate_projects"])' "$T")" '[]'
fi
# smoke script mentions the assertions
SM="$(cat "$VAULT/tests/smoke_orchestrator_tick.sh")"
has "smoke asserts key" "$SM" 'auto_integrate_projects'
# smoke detects removal: tampered template copy must fail the smoke
mkdir -p "$TMP/v/tests" "$TMP/v/00_Templates" "$TMP/v/.scripts"
cp "$VAULT/tests/smoke_orchestrator_tick.sh" "$TMP/v/tests/"; cp "$VAULT/.scripts/"* "$TMP/v/.scripts/" 2>/dev/null
grep -v '^auto_integrate_projects' "$T" > "$TMP/v/00_Templates/Orchestrator_Config_Template.yaml"
if bash "$TMP/v/tests/smoke_orchestrator_tick.sh" >"$TMP/o" 2>&1; then fail "smoke should fail when key removed"; else pass "smoke fails when key removed"; fi
# live config not modified by builder: not tracked, no key added
if [ -f "$VAULT/Orchestrator_Config.yaml" ]; then
  eq "live config has no auto_integrate_projects" "$(grep -c '^auto_integrate_projects' "$VAULT/Orchestrator_Config.yaml")" 0
  eq "live config not in git diff" "$(cd "$VAULT" && git status --porcelain -- Orchestrator_Config.yaml | wc -l | tr -d ' ')" 0
fi
finish
