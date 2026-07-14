# Initial architecture questions

This document captures the initial design space. Decisions become durable only after an issue discussion and an accepted experiment or ADR.

## Runtime boundary

All Common Lisp code—tests, scripts, the REPL, and the harness entry point—runs through the Docker runtime described in [`runtime.md`](runtime.md). The repository source mount is read-only, compiled artifacts are isolated in a Docker volume, and test runs have no network access. This provides a repeatable runtime without relying on a host Lisp installation.

A provider-backed run may receive `OPENROUTER_API_KEY` at container runtime, but the image and source tree must never contain the value. The first transport implementation must preserve that boundary in traces, error messages, and reports.

## Core loop

A controlled improvement iteration should have explicit inputs and outputs:

1. Select a task and acceptance criteria.
2. Select the candidate harness configuration or proposed change.
3. Execute inside a defined capability boundary.
4. Persist trace, artifacts, provider/model identity, token use, cost, and outcome.
5. Judge against reproducible criteria.
6. Retain, reject, or queue the change with evidence.

The loop must be bounded by budgets and stop conditions; "self-improving" is not permission for unbounded execution.

## Backend boundary

The initial `backend` protocol exposes `complete`. Before implementing the OpenRouter transport, decide:

- Message and tool-call representation.
- Streaming semantics and cancellation.
- Normalized error taxonomy and retry policy.
- Trace schema, including model, provider, request ID, usage, and cost.
- Capability discovery (structured output, tools, reasoning controls, multimodal input).
- Secret handling and request redaction.

## Evaluation boundary

The harness must distinguish a model response from experiment success. Early work should specify:

- Task fixtures and deterministic inputs.
- Objective checks versus model-based judging.
- Baselines and comparison method.
- Regression detection and promotion thresholds.
- Artifact retention and report format.

## Safety boundary

- Default to read-only repository access and no shell/network tools unless a task grants them.
- Require explicit budgets for time, money, model calls, and retries.
- Persist approval and policy decisions with experiment reports.
- Never let a candidate modify its own evaluator, policy, or promotion rules in the same unreviewed run.
