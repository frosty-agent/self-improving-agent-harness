(in-package #:self-improving-agent-harness)

(defclass backend ()
  ((name :initarg :name :reader backend-name
         :documentation "Stable provider identifier used in experiment traces."))
  (:documentation "Abstract model-provider backend."))

(defgeneric complete (backend request)
  (:documentation "Return a COMPLETION-RESPONSE for REQUEST using BACKEND.

Concrete adapters own transport, authentication, error mapping, and raw provider
response capture. The core harness should depend only on this generic function."))

(defstruct (completion-request
            (:constructor make-completion-request
                (&key model messages options)))
  "A provider-neutral completion request.

MESSAGES is deliberately left as a provider-neutral data structure until the
first adapter's serialization contract is accepted. OPTIONS holds optional
provider-neutral controls such as temperature or maximum output tokens."
  model
  messages
  options)

(defstruct (completion-response
            (:constructor make-completion-response
                (&key text model raw)))
  "A provider-neutral response plus unmodified provider data in RAW."
  text
  model
  raw)

(defclass openrouter-backend (backend)
  ((base-url :initarg :base-url
             :initform "https://openrouter.ai/api/v1"
             :reader openrouter-backend-base-url)
   (api-key :initarg :api-key
            :reader openrouter-backend-api-key))
  (:documentation "Configuration for the first backend adapter.

The transport implementation is intentionally deferred until the request and
trace contracts are designed and tested. API keys are supplied at runtime,
typically from OPENROUTER_API_KEY, never committed to the repository."))

(defun make-openrouter-backend (&key api-key
                                  (base-url "https://openrouter.ai/api/v1"))
  "Construct an OpenRouter backend configuration without performing I/O."
  (make-instance 'openrouter-backend
                 :name "openrouter"
                 :api-key api-key
                 :base-url base-url))

(defmethod complete ((backend openrouter-backend) request)
  (declare (ignore backend request))
  (error "OpenRouter transport is not implemented yet; see the OpenRouter backend issue."))
