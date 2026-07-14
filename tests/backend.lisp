(in-package #:self-improving-agent-harness/tests)

(defun ensure-true (value description)
  (unless value
    (error "Test failed: ~A" description)))

(defun run-tests ()
  (let ((backend (make-openrouter-backend :api-key "test-key"))
        (request (make-completion-request
                  :model "provider/model"
                  :messages '((:role "user" :content "hello")))))
    (ensure-true (string= "openrouter" (backend-name backend))
                 "backend has a stable name")
    (ensure-true (string= "https://openrouter.ai/api/v1"
                          (openrouter-backend-base-url backend))
                 "OpenRouter uses its default base URL")
    (ensure-true (string= "provider/model" (completion-request-model request))
                 "request retains the requested model")
    (handler-case
        (progn (complete backend request)
               (error "Test failed: unimplemented adapter must signal an error"))
      (error () t))
    (format t "Self-improving-agent-harness smoke tests passed.~%")
    t))
