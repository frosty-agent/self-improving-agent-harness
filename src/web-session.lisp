(in-package #:self-improving-agent-harness)

;;; In-memory UI adapter for the CLOG web interface (issue #24).
;;; This is deliberately separate from sanitized diagnostic JSONL: browser-visible
;;; events are transient session state and the underlying chat-session remains the
;;; sole source of provider conversation history.

(defstruct (web-session
            (:constructor %make-web-session
                (&key id chat-session events state turn-number)))
  id
  chat-session
  events
  state
  turn-number)

(defun web-session-record-event (session kind &rest fields)
  "Append one ordered, in-memory UI event to SESSION and return it.

FIELDS must contain only data deliberately intended for the local trusted UI.
No event is written to the diagnostic JSONL path from this function."
  (let ((event (append (list :kind kind
                             :sequence (1+ (length (web-session-events session)))
                             :turn (web-session-turn-number session))
                       fields)))
    (setf (web-session-events session)
          (append (web-session-events session) (list event)))
    event))

(defun make-web-session (&key backend model options handlers (max-rounds 60))
  "Create an isolated browser UI session around the normal chat-session seam."
  (let ((session (%make-web-session
                  :id (uuid-v4-string)
                  :chat-session (make-chat-session :backend backend :model model
                                                   :options options :handlers handlers
                                                   :max-rounds max-rounds)
                  :events '()
                  :state :ready
                  :turn-number 0)))
    (web-session-record-event session "session-started"
                              :session-id (web-session-id session)
                              :state "ready"
                              :model model
                              :backend (backend-name backend)
                              :max-rounds max-rounds)
    session))

(defun web-session-submit (session content)
  "Run one browser-submitted turn through the normal CHAT-SESSION-TURN path.

The first vertical slice exposes user, pending, provider, final, and lifecycle
state. Tool-level events are added by the observer integration without changing
this persistence boundary."
  (let ((trimmed (and (stringp content) (string-trim '(#\Space #\Tab #\Newline #\Return) content))))
    (when (or (null trimmed) (zerop (length trimmed)))
      (web-session-record-event session "turn-empty" :state "ready")
      (return-from web-session-submit nil))
    (when (eq (web-session-state session) :running)
      (error "A browser turn is already running for this session."))
    (incf (web-session-turn-number session))
    (setf (web-session-state session) :running)
    (web-session-record-event session "user-message" :text content)
    (web-session-record-event session "assistant-pending" :state "running")
    (handler-case
        (let ((response
                (chat-session-turn
                 (web-session-chat-session session)
                 content
                 :observer (lambda (kind &rest fields)
                             (apply #'web-session-record-event session kind fields)))))
          (web-session-record-event session "assistant-message"
                                    :text (completion-response-text response))
          (setf (web-session-state session) :ready)
          (web-session-record-event session "turn-completed"
                                    :state "ready"
                                    :text (completion-response-text response))
          response)
      (error (condition)
        (declare (ignore condition))
        (note-chat-session-failure (web-session-chat-session session))
        (setf (web-session-state session) :failed-turn)
        (web-session-record-event session "turn-failed"
                                  :state "failed-turn"
                                  :message "The turn failed. Retry is available.")
        nil))))
