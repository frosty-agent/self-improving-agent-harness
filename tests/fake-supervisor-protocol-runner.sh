#!/usr/bin/env sh
# Test fixture for terminal event handling and fragmented multiline stdout.
set -eu

event() {
  printf '{"event":"%s","session_id":"%s","turn":%s}\n' "$1" "$HARNESS_CHAT_SESSION_ID" "$2" >&2
}

printf '{"event":"session-started","session_id":"%s"}\n' "$HARNESS_CHAT_SESSION_ID" >&2
turn=0
while IFS= read -r input; do
  case "$input" in
    /exit)
      printf '{"event":"session-exited","session_id":"%s","reason":"local-exit"}\n' "$HARNESS_CHAT_SESSION_ID" >&2
      exit 0
      ;;
    *)
      turn=$((turn + 1))
      event turn-submitted "$turn"
      if [ "$turn" -eq 1 ]; then
        event turn-failed "$turn"
      else
        # Two writes model partial assistant output; the delimiter follows both.
        printf 'two\n'
        printf 'line'
        event turn-completed "$turn"
      fi
      ;;
  esac
done