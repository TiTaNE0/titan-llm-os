#!/usr/bin/env bash
# osascript_stub.sh — offline stand-in for osascript/Mail.app in the v3.2 tests. Never sends mail.
#
# Called exactly like osascript: osascript_stub.sh -e <script> <action> [args...]. Every pipeline
# AppleScript takes an action tag as argv item 1, so this stub answers by tag:
#   send SUBJECT BODY ADDR   counts the call in $STUB_DIR/sends.count; STUB_MAIL_MODE decides:
#                            deliver (default) -> subject into Sent; stuck -> Outbox and Drafts (I-9);
#                            hang -> sleep $STUB_HANG_S (default 30); error -> exit 1
#   query SUBJECT            prints "sent=N outbox=N drafts=N" for the exact subject; STUB_QUERY_MODE:
#                            ok (default); error -> exit 1; hang -> sleep $STUB_HANG_S;
#                            error_after_send / hang_after_send -> the same, once a send was made
#   accounts                 prints "iCloud" (exit 1 when STUB_MAIL_DEAD=1)
#   outbox_count             number of messages in the Outbox
#   drafts_pipeline          number of Drafts whose subject contains "Twitter repl" and is not in Sent
#   trash_leftovers          moves every "Twitter repl" draft whose subject is in Sent to mail_trash;
#                            prints "trashed=N"
#   STUB_MAIL_MODE=deliver_leftover: like deliver, plus a draft copy of the message (the 2026-11-24 case)
#   feedback ADDR            prints $STUB_FEEDBACK (canned replies in the <<<MSG>>> format)
# Mailboxes are plain files in $STUB_DIR: mail_sent, mail_outbox, mail_drafts (one subject per line).
set -uo pipefail
D="${STUB_DIR:?osascript_stub: STUB_DIR not set}"
mkdir -p "$D"; touch "$D/mail_sent" "$D/mail_outbox" "$D/mail_drafts"
[ "${1:-}" = "-e" ] && shift 2
action="${1:-}"; shift || true
count() { grep -cxF -- "$2" "$D/$1" 2>/dev/null || true; }
case "$action" in
  send)
    n=$(cat "$D/sends.count" 2>/dev/null || echo 0); echo $((n+1)) > "$D/sends.count"
    case "${STUB_MAIL_MODE:-deliver}" in
      deliver) printf '%s\n' "$1" >> "$D/mail_sent" ;;
      deliver_leftover) printf '%s\n' "$1" >> "$D/mail_sent"; printf '%s\n' "$1" >> "$D/mail_drafts" ;;
      stuck)   printf '%s\n' "$1" >> "$D/mail_outbox"; printf '%s\n' "$1" >> "$D/mail_drafts" ;;
      hang)    sleep "${STUB_HANG_S:-30}" ;;
      error)   echo "Mail got an error: AppleEvent timed out." >&2; exit 1 ;;
    esac ;;
  query)
    qm="${STUB_QUERY_MODE:-ok}"
    if [ "${qm%_after_send}" != "$qm" ]; then
      [ "$(cat "$D/sends.count" 2>/dev/null || echo 0)" -gt 0 ] && qm="${qm%_after_send}" || qm=ok
    fi
    case "$qm" in
      error) echo "Mail got an error: Can't get mailbox." >&2; exit 1 ;;
      hang)  sleep "${STUB_HANG_S:-30}" ;;
    esac
    echo "sent=$(count mail_sent "$1") outbox=$(count mail_outbox "$1") drafts=$(count mail_drafts "$1")" ;;
  accounts) [ "${STUB_MAIL_DEAD:-0}" = "1" ] && { echo "Not authorized to send Apple events to Mail." >&2; exit 1; }; echo "iCloud" ;;
  outbox_count) grep -c . "$D/mail_outbox" 2>/dev/null || true ;;
  drafts_pipeline) grep "Twitter repl" "$D/mail_drafts" 2>/dev/null | grep -cvxF -f "$D/mail_sent" 2>/dev/null || true ;;
  trash_leftovers)
    touch "$D/mail_trash"; n=0; keep=""
    while IFS= read -r l; do
      if [[ "$l" == *"Twitter repl"* ]] && grep -qxF -- "$l" "$D/mail_sent"; then printf '%s\n' "$l" >> "$D/mail_trash"; n=$((n+1))
      else keep+="$l"$'\n'; fi
    done < "$D/mail_drafts"
    printf '%s' "$keep" > "$D/mail_drafts"; echo "trashed=$n" ;;
  feedback) cat "${STUB_FEEDBACK:?osascript_stub: STUB_FEEDBACK not set}" ;;
  *) echo "osascript_stub: unknown action '$action'" >&2; exit 1 ;;
esac
exit 0
