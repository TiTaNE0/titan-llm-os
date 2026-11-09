#!/usr/bin/env bash
# DoD 3 (behaviour): the existing acceptance folders and this task's folder skip their nested
# full-gateway test under the shared env AND under their legacy names, still run it when no skip
# env is set, and the exit code then reflects only the remaining checks (a skip neither forces
# failure nor hides a real failure). Runs scratch copies of the real run_all.sh files.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ACC="$VAULT/tests/acceptance"
# run_case <label> <run_all> <gateway-stub-name> <env...>: prints "<stub-ran> <rc>"
run_case() {
  local label="$1" ra="$2" stub="$3" d; shift 3
  d="$TMP/v/tests/acceptance/$label"; rm -rf "$d"; mkdir -p "$d" "$TMP/kit"
  cp "$ra" "$d/run_all.sh"
  printf '#!/usr/bin/env bash\ntouch "%s/ran"\n' "$d" > "$d/$stub"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/test_dod1_ok.sh"
  [ -n "${BAD:-}" ] && printf '#!/usr/bin/env bash\nexit 1\n' > "$d/test_dod1_bad.sh"
  ( cd "$d" && env -u ACC_SKIP_GATEWAY -u PMR_ACC_SKIP_GATEWAY -u KTI_ACC_SKIP_GATEWAY KIT_ROOT="$TMP/kit" "$@" bash run_all.sh >"$d.out" 2>&1 ); local rc=$?
  [ -e "$d/ran" ] && echo "ran $rc" || echo "skipped $rc"
}
check() { # folder-label run_all stub legacy-env
  expect "$1 ACC_SKIP_GATEWAY=1 skips gateway, exit 0" "skipped 0" "$(run_case "$1" "$2" "$3" ACC_SKIP_GATEWAY=1)"
  grep -q '^SKIP' "$TMP/v/tests/acceptance/$1.out" && pass "$1 prints a SKIP line" || fail "$1 prints no SKIP line"
  if [ -n "$4" ]; then expect "$1 legacy $4 still skips" "skipped 0" "$(run_case "$1" "$2" "$3" "$4")"; fi
  expect "$1 without skip env runs the gateway" "ran 0" "$(run_case "$1" "$2" "$3" X=1)"
  expect "$1 skip does not hide a real failure" "skipped 1" "$(BAD=1 run_case "$1" "$2" "$3" ACC_SKIP_GATEWAY=1)"
}
check PMR "$ACC/PM_Reviewer_Single_Pass_Findings/run_all.sh" test_dod3_gateway_green.sh PMR_ACC_SKIP_GATEWAY=1
check KTI "$ACC/Kit_Suites_Live_Telemetry_Isolation/run_all.sh" test_dod3_stub.sh KTI_ACC_SKIP_GATEWAY=1
check CTT "$(dirname "${BASH_SOURCE[0]}")/run_all.sh" test_dod5_gateway_green.sh ""
# Every acceptance folder whose tests launch a real gateway must name the shared env in run_all.sh.
for ra in "$ACC"/*/run_all.sh; do
  d="$(basename "$(dirname "$ra")")"
  [ "$d" = Chain_Consolidation_Planner_Context_Pack ] && continue
  nested=0
  for t in "$(dirname "$ra")"/test_*.sh; do
    grep -E 'bash ("\$VAULT"/|"?\$GATEWAY"?|tests/test_)[a-z_]*' "$t" 2>/dev/null | grep -vqE '_SKIP_SUITES=1' && nested=1
  done
  if [ "$nested" = 1 ]; then
    grep -qF '${ACC_SKIP_GATEWAY:-0}' "$ra" && pass "$d gates its nested gateway on ACC_SKIP_GATEWAY" || fail "$d runs a nested gateway without the shared skip env"
  else pass "$d has no unskipped nested gateway run"; fi
done
finish
