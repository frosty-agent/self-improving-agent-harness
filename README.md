# Self-Improving Agent Harness

A Common Lisp research harness for running, observing, judging, and iteratively improving agent workflows. The first provider adapter will target the OpenRouter API; the harness is designed so providers can be replaced without changing core orchestration.

> **Status:** design and exploration. This repository intentionally starts with a small, dependency-free protocol rather than a committed agent architecture.

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

## Repository layout

- `src/` — Common Lisp packages and backend protocol.
- `tests/` — dependency-free smoke tests.
- `docs/` — architecture decisions and research notes.
- `.github/ISSUE_TEMPLATE/` — issues for progress and documentation.

## Local setup

Install a Common Lisp implementation with ASDF (SBCL is the initial reference implementation), then load the ASDF system:

```lisp
(asdf:load-asd #P"self-improving-agent-harness.asd")
(asdf:load-system :self-improving-agent-harness)
```

Run the smoke tests:

```lisp
(asdf:test-system :self-improving-agent-harness)
```

There are no third-party dependencies yet. The OpenRouter adapter must read its API key from `OPENROUTER_API_KEY` at runtime and must never commit credentials.

## How we use GitHub Issues

Issues are the project record for research decisions, documentation, experiments, and implementation progress.

- Open an issue before beginning a meaningful workstream.
- Use **research**, **documentation**, **architecture**, **backend**, **experiment**, and **progress** labels.
- Record: hypothesis/goal, scope, result, evidence (commands, traces, or reports), and follow-up work.
- Link commits and pull requests with `Refs #<issue>`; use `Closes #<issue>` only when the stated acceptance criteria are met.
- Keep design decisions in `docs/` and link the corresponding issue.

See [`docs/initial-architecture.md`](docs/initial-architecture.md) for the first set of open questions.

## License

MIT. See [LICENSE](LICENSE).
