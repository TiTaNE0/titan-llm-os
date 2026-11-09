#!/usr/bin/env bash
# DoD2: /close_task (Step 4.6, run verbatim from the kit runbook) refreshes CODEMAP.md when the
# commit adds, deletes or renames files, and leaves it untouched otherwise.
. "$(dirname "$0")/_lib.sh"
[ -n "$(step46_cmd)" ] && pass "runbook has a Step 4.6 command" || { fail "runbook has a Step 4.6 command"; done_; }
P="$(project p2)"; mkdir -p "$P/app"
echo 1 > "$P/app/a.py"; echo 2 > "$P/app/b.py"; echo 3 > "$P/app/c.py"; commit "$P" init
(cd "$P" && .vault_link/.scripts/codemap_refresh.sh >/dev/null)
sha() { git -C "$P" rev-parse HEAD; }

# Content-only close: map untouched (byte-identical, hand marker preserved).
echo MARK >> "$P/CODEMAP.md"; pre="$(cksum < "$P/CODEMAP.md")"
echo edit >> "$P/app/a.py"; commit "$P" edit; close_step46 "$P" "$(sha)"
eq "edit: rc 0" "$RC" 0; eq "edit: unchanged" "$OUT" "CODEMAP: unchanged (no add/delete/rename)"
eq "edit: file byte-identical" "$(cksum < "$P/CODEMAP.md")" "$pre"

# Add in a new subdirectory.
mkdir -p "$P/app/new"; echo x > "$P/app/new/d.py"; commit "$P" add; close_step46 "$P" "$(sha)"
eq "add: refreshed" "$OUT" "CODEMAP: refreshed"
grep -qxF '## app/new/' "$P/CODEMAP.md" && grep -qxF -- '- `app/new/d.py`' "$P/CODEMAP.md" && pass "add: new dir+path" || fail "add: new dir+path"
grep -qx MARK "$P/CODEMAP.md" && fail "add: stale content replaced" || pass "add: stale content replaced"
eq "add: count" "$(sed -n 3p "$P/CODEMAP.md")" "Files: 4"

# Rename combined with an edit (still detected as R under -M).
git -C "$P" mv app/b.py app/renamed.py; echo tweak >> "$P/app/renamed.py"; commit "$P" mv; close_step46 "$P" "$(sha)"
eq "rename: refreshed" "$OUT" "CODEMAP: refreshed"
grep -qF '`app/renamed.py`' "$P/CODEMAP.md" && ! grep -qF '`app/b.py`' "$P/CODEMAP.md" && pass "rename: paths" || fail "rename: paths"

# Delete.
git -C "$P" rm -q app/c.py; commit "$P" rm; close_step46 "$P" "$(sha)"
eq "delete: refreshed" "$OUT" "CODEMAP: refreshed"; grep -qF '`app/c.py`' "$P/CODEMAP.md" && fail "delete: gone" || pass "delete: gone"
eq "delete: count" "$(sed -n 3p "$P/CODEMAP.md")" "Files: 3"

# Close never commits the map and never touches HEAD.
head_before="$(sha)"; echo y > "$P/e.py"; commit "$P" add2; head_before="$(sha)"; close_step46 "$P" "$head_before"
eq "HEAD unchanged by refresh" "$(sha)" "$head_before"
eq "CODEMAP.md stays untracked" "$(git -C "$P" status --porcelain)" "?? CODEMAP.md"
[ ! -e "$P/.gitignore" ] && pass "no .gitignore written" || fail "no .gitignore written"

echo edit >> "$P/e.py"; commit "$P" edit2; close_step46 "$P" "$(sha)"
eq "edit after add: unchanged" "$OUT" "CODEMAP: unchanged (no add/delete/rename)"
done_
