(defpackage #:self-improving-agent-harness
  (:use #:cl)
  (:export
   #:backend
   #:backend-name
   #:complete
   #:completion-request
   #:make-completion-request
   #:completion-request-model
   #:completion-request-messages
   #:completion-request-options
   #:completion-response
   #:make-completion-response
   #:completion-response-text
   #:completion-response-model
   #:completion-response-raw
   #:openrouter-backend
   #:make-openrouter-backend
   #:openrouter-backend-base-url
   #:openrouter-backend-api-key))
