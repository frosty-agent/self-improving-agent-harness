#!/usr/bin/env sh
# Exercise the supervised forced-interactive fake path with two persistent turns.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/tests/chat-supervisor-fixture.sh"
output=$(mktemp)
supervisor_fixture_create "$repo_root"
cleanup() { rm -f "$output"; supervisor_fixture_cleanup; }
trap cleanup EXIT HUP INT TERM

# The protocol is JSONL. The fake child is the real scripts/chat.lisp session
# with a deterministic backend, launched by the supervisor through ordinary pipes.
if ! printf '%s\n' \
  '{"op":"turn","text":"first request"}' \
  '{"op":"checkpoint"}' \
  '{"op":"turn","text":"second request"}' \
  '{"op":"exit"}' |
  env HARNESS_CHAT_RUNNER="$repo_root/tests/fake-supervised-chat-container.sh" \
    "$repo_root/bin/chat-supervisor" \
      --create-worktree --repo "$SUPERVISOR_FIXTURE_PRIMARY" --base-ref HEAD \
      --run-id supervised-test-16 --worktree-parent "$SUPERVISOR_FIXTURE_PARENT" \
      --session-id supervised-test-16 --fake --verify-command '/bin/true' \
      --report-dir "$SUPERVISOR_FIXTURE_REPORTS/multi-turn" >"$output"; then
  cat "$output" >&2
  exit 1
fi

# Use Python only for JSON parsing and exact field assertions; no provider is used.
python3 - "$output" "$repo_root/bin/chat-supervisor" <<'PY'
import importlib.machinery
import importlib.util
import json
import sys

loader = importlib.machinery.SourceFileLoader("chat_supervisor", sys.argv[2])
spec = importlib.util.spec_from_loader(loader.name, loader)
chat_supervisor = importlib.util.module_from_spec(spec)
loader.exec_module(chat_supervisor)

# Accounting comes from a child process. Its allow-list must additionally reject
# arbitrary provider/request-like labels and non-numeric cost fields.
def actual_measurements():
    return {
        "input_tokens": 0, "input_tokens_state": "actual", "input_tokens_reason": None,
        "output_tokens": 0, "output_tokens_state": "actual", "output_tokens_reason": None,
        "total_tokens": 0, "total_tokens_state": "actual", "total_tokens_reason": None,
        "cost_usd": 0, "cost_usd_state": "actual", "cost_usd_reason": None,
    }

valid_invocation = {
    "model": "openai/gpt-4.1-mini", "provider": "openrouter",
    "request_id_present": True, "outcome": "completed", **actual_measurements(),
}
valid = {"provider_call_count": 1, "invocations": [valid_invocation],
         "aggregate": actual_measurements()}
assert chat_supervisor.sanitized_accounting(valid)["aggregate"]["cost_usd"] == 0

unsafe_secret = {**valid, "invocations": [{**valid_invocation,
                                             "model": "provider secret: sk-test-123"}]}
assert chat_supervisor.sanitized_accounting(unsafe_secret)["state"] == "unavailable", unsafe_secret
unsafe_cost = {**valid, "aggregate": {**valid["aggregate"], "cost_usd": "0.0025"}}
assert chat_supervisor.sanitized_accounting(unsafe_cost)["state"] == "unavailable", unsafe_cost

records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
events = [record for record in records if record.get("type") == "event"]
assistant = [record for record in records if record.get("type") == "assistant"]
checkpoint = [record for record in records if record.get("type") == "checkpoint"]
assert [record["text"] for record in assistant] == ["fake assistant turn 1", "fake assistant turn 2"], records
assert [record["turn"] for record in assistant] == [1, 2], records
assert any(record.get("event") == "session-started" for record in events), records
assert [record["event"] for record in events if record.get("event") == "turn-completed"] == ["turn-completed", "turn-completed"], records
assert [record["assistant_bytes"] for record in events if record.get("event") == "turn-completed"] == [
    len("fake assistant turn 1".encode("utf-8")), len("fake assistant turn 2".encode("utf-8"))], records
assert any(record.get("event") == "session-exited" and record.get("reason") == "local-exit" for record in events), records
assert len(checkpoint) == 1, records
result = checkpoint[0]
# The test suite may run inside a source-only Docker mount or through the
# host-side supervisor. Assert only the documented sanitized alternatives.
assert result["git"]["status"] in ("clean", "changes-present", "unavailable"), result
if result["git"]["status"] == "unavailable":
    assert result["git"]["diff_check"] == "failed", result
    assert result["git"]["diff_check_exit_code"] == 128, result
else:
    assert result["git"]["diff_check"] == "passed", result
    assert result["git"]["diff_check_exit_code"] == 0, result
assert result["verification"] == {"command": "/bin/true", "status": "passed", "exit_code": 0}, result
assert result["provider_accounting"]["state"] == "actual", result
assert result["provider_accounting"]["aggregate"]["cost_usd"] == 0, result
assert result["provider_accounting"]["invocations"][0]["request_id_present"] is True, result
assert "chat.log" not in "\n".join(map(json.dumps, records)), records
PY

printf 'Chat supervisor multi-turn fake session test passed.\n'
