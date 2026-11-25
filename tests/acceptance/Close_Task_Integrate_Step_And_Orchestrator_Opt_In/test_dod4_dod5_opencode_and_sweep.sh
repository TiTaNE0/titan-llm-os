#!/usr/bin/env bash
# DoD 4 (generated OpenCode commands) and DoD 5 (no /ship, no fenced push/merge/gh).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
OC="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/command"
if [ -f "$OC/close_task.md" ]; then
  eq "live close_task has Step 4.7" "$(grep -c '^## Step 4\.7 ' "$OC/close_task.md")" 1
  eq "live tick has Step 4a" "$(grep -c '^### Step 4a ' "$OC/orchestrator_tick.md")" 1
  has "live tick has retry marker" "$(cat "$OC/orchestrator_tick.md")" .integrate_retry
  for f in close_task execute_task orchestrator_tick; do
    if grep -q '@\|!`\|\$[0-9]' "$OC/$f.md"; then fail "live $f has banned token"; else pass "live $f clean"; fi
  done
else echo "SKIP: no live opencode commands"; fi
# hermetic regeneration
if (cd "$K" && env HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/xdg" bash install.sh setup-opencode --path "$TMP/oc/agent" --command-path "$TMP/oc/command" >"$TMP/inst.log" 2>&1; echo $? > "$TMP/rc"); then :; fi
case "$(cat "$TMP/rc")" in 0|3) pass "hermetic setup-opencode rc ok";; *) fail "hermetic setup-opencode rc $(cat "$TMP/rc")";; esac
eq "generated close_task Step 4.7" "$(grep -c '^## Step 4\.7 ' "$TMP/oc/command/close_task.md")" 1
eq "generated tick Step 4a" "$(grep -c '^### Step 4a ' "$TMP/oc/command/orchestrator_tick.md")" 1
# DoD 5 sweep
for f in "$CMD"/*.md; do b=$(basename "$f")
  if grep -q '@' "$f"; then fail "$b has @"; fi
  if grep -q '!`' "$f"; then fail "$b has !\`"; fi
  if grep -qE '\$[0-9]' "$f"; then fail "$b has \$digit"; fi
  if grep -qE '(^|[^A-Za-z0-9_])/ship([^A-Za-z0-9_-]|$)' "$f"; then fail "$b has /ship"; fi
  bad="$(fenced "$f" | grep -E 'git push|git merge|(^|[[:space:];&|(])gh[[:space:]]' || true)"
  [ -z "$bad" ] || fail "$b fenced push/merge/gh: $bad"
done
[ "$FAILED" -eq 0 ] && pass "all runbooks clean (no @, /ship, push/merge/gh)"
finish
