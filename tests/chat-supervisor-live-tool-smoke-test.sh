#!/usr/bin/env sh
# Deterministic contract for the opt-in live smoke; never makes a provider call.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
smoke="$repo_root/tests/chat-supervisor-live-tool-smoke.sh"
tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT HUP INT TERM

# Missing credentials must produce a conventional, explicit skip without
# revealing a value.  Clear ambient .env lookup so this is deterministic.
set +e
env -u OPENROUTER_API_KEY HOME="$tmp/home" "$smoke" >"$tmp/stdout" 2>"$tmp/stderr"
status=$?
set -e
[ "$status" -eq 77 ] || {
  printf 'expected live smoke missing-credential skip status 77, got %s\n' "$status" >&2
  exit 1
}
grep -F 'SKIP: OPENROUTER_API_KEY is not set; live OpenRouter smoke not run.' "$tmp/stderr" >/dev/null
[ ! -s "$tmp/stdout" ] || { printf '%s\n' 'skip must not write stdout' >&2; exit 1; }

# Static safety setup checks cover the boundaries that cannot be exercised
# without credentials: independent clone, owned child worktree, parent-side
# verification, bounded model/round/turn/session runtime, and cleanup.
python3 - "$smoke" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
required = (
    'git clone --no-local --branch "$tested_branch" --single-branch',
    '--create-worktree --repo "$primary" --base-ref "$primary_before"',
    '--worktree-parent "$owned_parent"',
    '--report-dir "$reports"',
    '--verify-command "$verify_command"',
    '--model "$model"',
    '--max-rounds "$max_rounds"',
    '--turn-timeout-seconds "$turn_timeout_seconds"',
    'timeout "$session_timeout_seconds"',
    'OPENROUTER_API_KEY is not set; live OpenRouter smoke not run.',
    'rm -rf "${tmp:-}"',
    'git -C "$primary" status --porcelain',
    '"diff", "--check"',
    'provider_call_count',
    'fixtures/baseline-answer-v1.lisp',
)
for needle in required:
    assert needle in source, needle
assert '/home/ubuntu/code/self-improving-agent-harness' not in source
assert 'git merge' not in source and 'worktree remove' not in source
PY

printf 'Chat supervisor live-tool smoke deterministic contract test passed.\n'
