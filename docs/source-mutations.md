# Structured source mutation prototype

Issue #15 is a deliberately small, offline research prototype.  Its mutation language is one data-only plist:

```lisp
(:operation :replace-function-body :target "fixture-score" :body (+ value 2))
```

It targets a top-level named `DEFUN`; it is not text replacement and it cannot mutate the harness source at runtime.  The runner parses with reader evaluation disabled, validates the sole supported operation before creating files, reads/forms/pretty-prints in an isolated candidate package, and writes only `reports/source-mutation-v1/candidate/` (ignored by Git).

Run it only through Docker:

```sh
sg docker -c './bin/source-mutation'
```

The command produces `fixture.diff`, `run.json`, and `run.html` under `reports/source-mutation-v1/`. It compiles and loads the generated candidate, then uses the separately pinned `pinned-offline-evaluator-v1` against held-out `fixture-score(3) = 5`. The candidate does not supply evaluator identity or promotion decision; the report records the fixed reject decision. This is evidence gathering, not a product policy or capability boundary.

## Portability boundary

* **ANSI Common Lisp:** list forms, `READ` with `*READ-EVAL*` disabled, package creation, `DEFUN` shape inspection, and printer output are the portable core. The prototype makes no MOP calls and depends on no portable MOP/introspection claim.
* **SBCL-specific:** the verified Docker image uses SBCL, and candidate compilation/evaluation uses `COMPILE-FILE` followed by `LOAD`. Other implementations may differ in compiled-file paths, warnings, and package/load behavior and need their own verification.
* **MOP:** intentionally not a dependency. If future mutations need generic-function/class metadata, select and document an implementation-specific MOP library rather than claiming ANSI portability.

## Decision

Do **not** extend this yet beyond fixture-scale named-function body changes. It creates clear reviewable evidence but has less expressive coverage and more reader/package/compilation complexity than ordinary repository patches. Keep normal repository patches as the preferred mechanism unless repeated experiments show a measurable benefit.
