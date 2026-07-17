#!/usr/bin/env sh
# Failed turns are terminal protocol events, not a 300-second supervisor stall.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output=$(mktemp)
cleanup() { rm -f "$output"; }
trap cleanup EXIT HUP INT TERM

printf '%s\n' \
  '{"op":"turn","text":"will fail"}' \
  '{"op":"turn","text":"then works"}' \
  '{"op":"exit"}' |
  timeout 8 env HARNESS_CHAT_RUNNER="$repo_root/tests/fake-supervisor-protocol-runner.sh" \
    "$repo_root/bin/chat-supervisor" \
      --worktree "$repo_root" \
      --session-id supervised-failed-16 \
      --fake \
      --verify-command '/bin/true' >"$output"

python3 - "$output" <<'PY'
import json
import sys

records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
events = [record for record in records if record.get("type") == "event"]
assistant = [record for record in records if record.get("type") == "assistant"]
assert [event["event"] for event in events if event["event"] in ("turn-failed", "turn-completed")] == ["turn-failed", "turn-completed"], records
assert [(record["turn"], record["text"]) for record in assistant] == [(2, "two\nline")], records
assert records.index(next(event for event in events if event["event"] == "turn-completed")) < records.index(assistant[0]), records
PY

printf 'Chat supervisor failed-turn recovery and multiline-output test passed.\n'