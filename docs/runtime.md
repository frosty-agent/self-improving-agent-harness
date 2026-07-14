# Portable Docker runtime

## Decision

All project Common Lisp code runs in the repository's Docker environment. The host supplies Docker Engine only; it is not a supported runtime for SBCL, ASDF, tests, scripts, or the harness.

## Runtime contract

`Dockerfile` builds a Debian Bookworm image with SBCL and ASDF. The source tree is not copied into the image. Every wrapper mounts the checked-out repository read-only at `/workspace`, so a run cannot write source, test fixtures, or documentation through the project mount.

Compiled FASLs and ASDF cache data are written to the Docker named volume `self-improving-agent-harness-cache`. This makes the runtime portable while preserving compilation performance between invocations.

## Commands

- `make test` / `./bin/test`: build the image and execute `asdf:test-system`. The container has no network.
- `make run` / `./bin/run`: build the image and execute the harness entry point. This permits network access for the future OpenRouter adapter.
- `make repl` / `./bin/container --noinform`: build the image and start an interactive SBCL session.

The wrapper rebuilds before every command, relying on Docker layer caching when inputs are unchanged. Set `HARNESS_IMAGE` to use an alternative local tag.

## Credential handling

`OPENROUTER_API_KEY` is runtime configuration only. `bin/container` optionally forwards it from an untracked repository `.env` file or an explicitly exported host environment variable. It does not echo the value, write it into a trace, or bake it into the image.

`.dockerignore` excludes `.env`, Git metadata, and local artifacts from the Docker build context. It is still the caller's responsibility to never pass credentials on a command line or commit them.

## Current boundary

`bin/run` is a readiness check, not a provider call: the OpenRouter transport has not been implemented. Its Docker execution verifies that the actual harness entry point, rather than a host-only script, can load and construct its configured backend. Provider requests, tools, evaluators, and improvement loops remain subject to their linked GitHub issues.
