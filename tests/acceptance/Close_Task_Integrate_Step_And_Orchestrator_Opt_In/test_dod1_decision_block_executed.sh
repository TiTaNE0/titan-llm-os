#!/usr/bin/env bash
# DoD 1 (crit 37/39/41): the Step 4.7 decision block, executed against temp repos.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
S="$(slice "$CLOSE" '^## Step 4\.7 ' '^## Step 5 ')"
BLOCK="$(printf '%s\n' "$S" | awk '/^[[:space:]]*```/{if(f){f=0;if(has)exit;buf="";next}f=1;buf="";has=0;next} f{print; if(index($0,"INTEGRATE=0"))has=1}' )"
[ -n "$BLOCK" ] || { fail "decision block found"; finish; }
hasnt "decision block calls no vault script" "$BLOCK" ".vault_link/.scripts/"
BLOCK="${BLOCK//<Project>/Proj}"
printf '%s\n' "$BLOCK" > "$TMP/block.sh"

run() { # name expected staging(none|local|origin) orch(0|1) cfg(-|NOFILE|content)
  local n="$1" exp="$2" st="$3" orch="$4" cfg="$5" r="$TMP/r_$RANDOM"
  mkdir -p "$r/.vault_link"; ( cd "$r" && git init -q . && git commit -q --allow-empty -m i
    case "$st" in local) git branch staging;; origin) git update-ref refs/remotes/origin/staging HEAD;; esac )
  [ "$cfg" = NOFILE ] || printf '%b' "$cfg" > "$r/.vault_link/Orchestrator_Config.yaml"
  local out
  if [ "$orch" = 1 ]; then out="$(cd "$r" && ORCH_RUN_ID=r bash "$TMP/block.sh")"; else out="$(cd "$r" && env -u ORCH_RUN_ID bash "$TMP/block.sh")"; fi
  eq "$n" "$(printf '%s\n' "$out" | grep '^INTEGRATE=')" "INTEGRATE=$exp"
}
run "interactive, no staging -> 0" 0 none 0 'x: 1\n'
run "interactive, local staging -> 1" 1 local 0 'x: 1\n'
run "interactive, origin/staging only -> 1" 1 origin 0 'x: 1\n'
run "interactive, config [] still -> 1" 1 local 0 'auto_integrate_projects: []\n'
run "orch, [] -> 0" 0 local 1 'auto_integrate_projects: []\n'
run "orch, key missing -> 0" 0 local 1 'other: 1\n'
run "orch, config file missing -> 0" 0 local 1 NOFILE
run "orch, [Other, Proj] -> 1" 1 local 1 'auto_integrate_projects: [Other, Proj]\n'
run "orch, [\"Proj\"] -> 1" 1 local 1 'auto_integrate_projects: ["Proj"]\n'
run "orch, ['Proj'] with comment -> 1" 1 origin 1 "auto_integrate_projects: ['Proj']  # c\n"
run "orch, [ Proj ] -> 1" 1 local 1 'auto_integrate_projects: [ Proj ]\n'
run "orch, [ProjX] -> 0" 0 local 1 'auto_integrate_projects: [ProjX]\n'
run "orch, [XProj] -> 0" 0 local 1 'auto_integrate_projects: [XProj]\n'
run "orch, block-style list -> 0" 0 local 1 'auto_integrate_projects:\n  - Proj\n'
run "orch, indented key -> 0" 0 local 1 '  auto_integrate_projects: [Proj]\n'
run "orch, listed but no staging -> 0" 0 none 1 'auto_integrate_projects: [Proj]\n'
finish
