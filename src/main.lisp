(in-package #:self-improving-agent-harness)

(defun run-harness (&key backend)
  "Prepare the harness runtime and return a non-secret readiness summary.

No model request is made here. The OpenRouter transport and experiment loop are
tracked separately, so this entry point is safe to use as a container-runtime
smoke check."
  (let ((effective-backend
          (or backend
              (make-openrouter-backend :api-key (uiop:getenv "OPENROUTER_API_KEY")))))
    (list :status :ready
          :backend (backend-name effective-backend)
          :api-key-present
          (not (null (openrouter-backend-api-key effective-backend))))))
