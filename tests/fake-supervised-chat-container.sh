#!/usr/bin/env sh
# Test-only runner: use the Docker-resident SBCL when the full suite is already
# in its test container; otherwise enter the project Docker runtime so the
# host-side supervisor still exercises separate stdout/stderr pipes.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v sbcl >/dev/null 2>&1; then
  exec sbcl --noinform --load scripts/chat.lisp
fi
exec "$repo_root/bin/container" "$@"
