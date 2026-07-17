#!/usr/bin/env sh
# Verify interactive boundary events are JSONL on stderr and contain correlation context.
set -eu

stdout=$(mktemp)
stderr=$(mktemp)
log_dir=$(mktemp -d)
cleanup() {
  rm -f "$stdout" "$stderr"
  rm -rf "$log_dir"
}
trap cleanup EXIT HUP INT TERM

# An empty submitted turn must not contact the provider; /exit is a local lifecycle exit.
printf '\n/exit\n' | env \
  OPENROUTER_API_KEY=test-key \
  HARNESS_CHAT_MODE=interactive \
  HARNESS_CHAT_MODEL=test/model \
  HARNESS_CHAT_MAX_ROUNDS=1 \
  HARNESS_CHAT_SESSION_ID=event-session-16 \
  HARNESS_LOG_DIR="$log_dir" \
  sbcl --noinform --load scripts/chat.lisp >"$stdout" 2>"$stderr"

for expected in \
  '"event":"session-started"' \
  '"event":"turn-submitted"' \
  '"event":"turn-empty"' \
  '"event":"session-exited"' \
  '"session_id":"event-session-16"' \
  '"turn":1' \
  '"reason":"local-exit"'; do
  grep -F "$expected" "$stderr" >/dev/null || {
    printf 'Test failed: missing interactive correlation event field %s\n' "$expected" >&2
    exit 1
  }
done

# JSONL events must occupy complete stderr lines: prompts/diagnostics cannot prefix
# an event, and this no-provider path must leave stdout free of assistant content.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    *'"event"'*)
      case "$line" in
        \{*\}) ;;
        *) printf 'Test failed: event is not a standalone JSONL line: %s\n' "$line" >&2; exit 1 ;;
      esac
      ;;
  esac
done <"$stderr"
[ ! -s "$stdout" ] || {
  printf '%s\n' 'Test failed: empty interactive input wrote assistant content to stdout.' >&2
  exit 1
}

# Per-session diagnostic log is $ISO-TIMESTAMP.jsonl (Claude-style). Non-timestamp correlation
# ids are normalized to an ISO timestamp basename; stderr still carries the bound session id.
session_log=$(find "$log_dir" -maxdepth 1 -type f -name '*.jsonl' | head -n 1)
[ -n "$session_log" ] || {
  printf '%s\n' 'Test failed: expected a per-session $ISO-TIMESTAMP.jsonl diagnostic log' >&2
  exit 1
}
case "$(basename "$session_log")" in
  chat.log) printf '%s\n' 'Test failed: legacy shared chat.log should not be written' >&2; exit 1 ;;
esac
for expected in '"sessionId":' '"turn":1' '"event":"turn-empty"' '"type":'; do
  grep -F "$expected" "$session_log" >/dev/null || {
    printf 'Test failed: missing log correlation field %s in %s\n' "$expected" "$session_log" >&2
    exit 1
  }
done

printf 'Interactive chat correlation event test passed.\n'
