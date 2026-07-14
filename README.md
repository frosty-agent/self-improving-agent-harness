# Self-Improving Agent Harness

A Common Lisp research harness for running, observing, judging, and iteratively improving agent workflows. The first provider adapter will target the OpenRouter API; the harness is designed so providers can be replaced without changing core orchestration.

> **Status:** design and exploration. The project starts with a small, dependency-free protocol and a portable Docker runtime rather than a committed agent architecture.

## Goals

- Define a small, swappable backend protocol for model providers.
- Implement an OpenRouter backend using API-key authentication.
- Run reproducible agent experiments with durable prompts, configuration, traces, outcomes, and costs.
- Evaluate candidate changes against explicit tasks and acceptance criteria.
- Support controlled improvement loops: propose, execute, judge, retain or reject.
- Keep policies and dangerous capabilities explicit and auditable.

## Non-goals (initially)

- Autonomous production deployment or unbounded self-modification.
- A dependency on one model, provider, or agent framework.
- Hiding provider calls, tool execution, or evaluation decisions.

## Architecture direction

```text
experiment/task -> harness -> backend protocol -> OpenRouter (first adapter)
                      |              |
                      |              +-> future providers / local inference
                      +-> trace store, tool boundary, evaluator, improvement policy
```

The core protocol is introduced in `src/backend.lisp`. It separates a request from the backend used to complete it. A concrete OpenRouter transport, persistence layer, tool sandbox, and evaluation loop are deliberately tracked as GitHub issues.

## Docker-first runtime

**Docker is the required Common Lisp runtime.** Do not install or invoke a host Lisp implementation for project code, tests, or harness runs. The project image provides SBCL and ASDF; the repository source is mounted read-only, and compiled artifacts live in a named Docker volume.

Prerequisite: Docker Engine. No host SBCL, Quicklisp, or system package installation is required.

```bash
# Build the runtime image and run all tests with networking disabled.
make test

# Build the image and run the current harness entry point.
make run

# Start an interactive SBCL REPL in the same container environment.
make repl
```

The equivalent direct commands are `./bin/test`, `./bin/run`, and `./bin/container --noinform`. `bin/container` rebuilds the image before each invocation, mounts the repository at `/workspace:ro`, and keeps ASDF's cache in the `self-improving-agent-harness-cache` volume.

For the future OpenRouter adapter, place a real key in an untracked `.env` file or explicitly export it before invoking `./bin/run`:

```bash
cp .env.example .env
# Set OPENROUTER_API_KEY in .env; do not commit it.
```

The wrapper forwards the variable to the container without printing it or copying it into the image. Tests run with `--network none`; a real provider-backed harness run has network access by design.

See [`docs/runtime.md`](docs/runtime.md) for runtime guarantees and [`docs/initial-architecture.md`](docs/initial-architecture.md) for design questions.

## Repository layout

- `src/` — Common Lisp packages, backend protocol, and harness entry point.
- `tests/` — dependency-free smoke tests.
- `scripts/` — Lisp load scripts invoked only through the container wrappers.
- `bin/` — Docker-only commands for the harness and test system.
- `docs/` — architecture decisions and research notes.
- `.github/ISSUE_TEMPLATE/` — issues for progress and documentation.

## How we use GitHub Issues

Issues are the project record for research decisions, documentation, experiments, and implementation progress.

- Open an issue before beginning a meaningful workstream.
- Use **research**, **documentation**, **architecture**, **backend**, **experiment**, and **progress** labels.
- Record: hypothesis/goal, scope, result, evidence (commands, traces, or reports), and follow-up work.
- Link commits and pull requests with `Refs #<issue>`; use `Closes #<issue>` only when the stated acceptance criteria are met.
- Keep design decisions in `docs/` and link the corresponding issue.

## License

MIT. See [LICENSE](LICENSE).
