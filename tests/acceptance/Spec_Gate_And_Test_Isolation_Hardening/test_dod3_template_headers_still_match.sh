#!/usr/bin/env bash
# DoD 3: emoji/marker-prefixed and plain template headers still match, and the exact raw
# heading text still matches (so a caller passing "Spec: Validator Report" finds it).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
for hdr in '✅ Validator Report' 'Validator Report' '🔬 Validator Report' '-> Validator Report' 'Validator Report  '; do
  g="$TMP/h.md"
  printf '# T\n\n## %s\nSHIP.\n\n## 📊 Verification Output\n' "$hdr" > "$g"
  expect "'## $hdr' populated" 0 "$(gsec "$G" "$g" "Validator Report" populated)"
done
g="$TMP/raw.md"; printf '# T\n\n## Spec: Validator Report\nx\n' > "$g"
expect "raw text 'Spec: Validator Report' matches literally" 0 "$(gsec "$G" "$g" "Spec: Validator Report" present)"
f="$TMP/full.md"; task "$f" "$PROSE$MAP$PACK$FILES$OQ_NONE"
for s in "Declarative Objective" "Definition of Done (Success Criteria)" "Verification Gateway" "Spec" "Validator Report" "Verification Output" "COMPLETION SUMMARY (Post-Mortem)" "Related Context"; do
  expect "template '$s' present" 0 "$(gsec "$G" "$f" "$s" present)"
done
finish
