#!/usr/bin/env sh
# Test fixture for terminal event handling and fragmented multiline stdout.
set -eu

event() {
  if [ "$1" = turn-completed ]; then
    printf '{"event":"%s","session_id":"%s","turn":%s,"assistant_bytes":10}\n' "$1" "$HARNESS_CHAT_SESSION_ID" "$2" >&2
  else
    printf '{"event":"%s","session_id":"%s","turn":%s}\n' "$1" "$HARNESS_CHAT_SESSION_ID" "$2" >&2
  fi
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
        # Simulate cross-pipe delivery: the completion delimiter can arrive at
        # the parent before the stdout pipe exposes the already-completed turn.
        event turn-completed "$turn"
        # This intentional fixture delay creates the observed cross-pipe
        # arrival order; the production protocol must use assistant_bytes,
        # never a delay or a zero-time readiness guess.
        sleep 1
        printf 'two\n'
        printf 'πline'
      fi
      ;;
  esac
done