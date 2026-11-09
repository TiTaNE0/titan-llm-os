#!/usr/bin/env bash
# DoD 3: the pinned kit tests are updated, not disabled: each runs green on the real kit and
# goes red when the planner/builder contract it pins is broken in a temp copy.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_kit() { ( cd "$KIT" && env CLAUDE_BIN=__nonexistent__ "$@" ) >"$TMP/out" 2>&1; echo $?; }

for t in test_agent_models.sh test_install_opencode.sh test_topology_regression.sh; do
  rc="$(run_kit bash "tests/$t")"
  [ "$rc" = 0 ] && pass "kit $t green" || fail "kit $t exit $rc: $(tail -n 3 "$TMP/out" | tr '\n' ' ')"
done

grep -qE '^EXPECTED=.*planner:opus' "$KIT/tests/test_agent_models.sh" && grep -qE '^EXPECTED=.*builder:sonnet' "$KIT/tests/test_agent_models.sh" \
  && pass "test_agent_models pins planner:opus builder:sonnet" || fail "test_agent_models EXPECTED lacks planner/builder"
grep -qE '^GATE_ROLES=.*planner' "$KIT/tests/test_install_opencode.sh" && grep -qE '^WORKER_ROLES=.*builder' "$KIT/tests/test_install_opencode.sh" \
  && pass "test_install_opencode role lists mirror install.sh" || fail "test_install_opencode role lists stale"
[ "$(grep -c 'check_planner_contract' "$KIT/tests/test_topology_regression.sh")" -ge 2 ] \
  && [ "$(grep -c 'check_researcher_contract' "$KIT/tests/test_topology_regression.sh")" -ge 2 ] \
  && pass "topology regression defines and calls both contract checks" || fail "topology contract checks not both wired"

# RED: a planner prompt without the Responsibility map fails the topology regression.
grep -vF '### Responsibility map' "$AGENTS/planner.md" > "$TMP/planner_bad.md"
rc="$(run_kit PLANNER_PROMPT="$TMP/planner_bad.md" bash tests/test_topology_regression.sh)"
[ "$rc" != 0 ] && pass "topology regression rejects planner without Responsibility map" || fail "topology regression passed a broken planner"
grep -vF '### Context pack' "$AGENTS/planner.md" > "$TMP/planner_bad2.md"
rc="$(run_kit PLANNER_PROMPT="$TMP/planner_bad2.md" bash tests/test_topology_regression.sh)"
[ "$rc" != 0 ] && pass "topology regression rejects planner without Context pack" || fail "topology regression passed planner without Context pack"

# RED: a planner downgraded to the worker alias, or given a provider/model string, fails test_agent_models.
for bad in 'sonnet' 'anthropic/claude-opus'; do
  rm -rf "$TMP/agents"; cp -R "$AGENTS" "$TMP/agents"
  sed -i.bak "s#^model: opus\$#model: $bad#" "$TMP/agents/planner.md"; rm -f "$TMP/agents/planner.md.bak"
  rc="$(run_kit AGENTS_DIR="$TMP/agents" bash tests/test_agent_models.sh)"
  [ "$rc" != 0 ] && pass "test_agent_models rejects planner model '$bad'" || fail "test_agent_models accepted planner model '$bad'"
done
# RED: dropping builder.md breaks the 11-agent count.
rm -rf "$TMP/agents"; cp -R "$AGENTS" "$TMP/agents"; rm "$TMP/agents/builder.md"
rc="$(run_kit AGENTS_DIR="$TMP/agents" bash tests/test_agent_models.sh)"
[ "$rc" != 0 ] && pass "test_agent_models rejects a kit without builder.md" || fail "test_agent_models passed without builder.md"
finish
