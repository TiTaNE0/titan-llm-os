#!/usr/bin/env bash
# DoD 2: the backend/frontend split happens only when a spec field marks it. Runs Step 10's own
# decision command (extracted from execute_task.md) against fixture task files.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
CMD="$(step_body 10 | grep -E "^grep -qxF 'Build split: " | head -n 1)"
[ -n "$CMD" ] || { fail "Step 10 has no grep -qxF 'Build split: ...' decision line"; finish; }
expect "decision command" "grep -qxF 'Build split: backend-frontend' \"\$TASK_PATH\"" "$CMD"

# branch <task>: "split" when Step 10's command matches, else "single".
branch() { TASK_PATH="$1" bash -c "$CMD" && echo split || echo single; }

mk() { mk_task "$TMP/$1.md"; printf '%s\n' "$2" > "$TMP/$1.spec"; awk -v f="$TMP/$1.spec" '
  /<!-- write_task_section section=spec -->/ { print; while ((getline l < f) > 0) print l; next } { print }' "$TMP/$1.md" > "$TMP/$1.t" && mv "$TMP/$1.t" "$TMP/$1.md"; }

mk none     $'### Build split\nBuild split: none'
mk split    $'### Build split\nBuild split: backend-frontend'
mk absent   $'### Summary\nNo split field here.'
mk inline   $'### Notes\nThe planner may write `Build split: backend-frontend` when slices are separable.'
mk indented $'### Build split\n  Build split: backend-frontend'
mk other    $'### Build split\nBuild split: frontend-backend'

expect "Build split: none -> single builder" single "$(branch "$TMP/none.md")"
expect "Build split: backend-frontend -> split" split "$(branch "$TMP/split.md")"
expect "no split field -> single builder (safe default)" single "$(branch "$TMP/absent.md")"
expect "field quoted inside prose -> single builder" single "$(branch "$TMP/inline.md")"
expect "indented field is not the exact line -> single builder" single "$(branch "$TMP/indented.md")"
expect "unknown value -> single builder" single "$(branch "$TMP/other.md")"
finish
