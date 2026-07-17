(in-package #:self-improving-agent-harness)

;;; Per-turn reporting helpers for the chat CLI.
;;;
;;; These live in their own file so outcome formatting can change under
;;; reload_harness. RUN-INTERACTIVE must call PROCESS-INTERACTIVE-USER-TURN by
;;; name on every iteration; an already-running loop then picks up new
;;; definitions without restarting the process. Editing the body of
;;; RUN-INTERACTIVE itself still requires re-entering that function.

(defun elapsed-seconds-since (start-internal-time)
  "Return fractional seconds elapsed since START-INTERNAL-TIME."
  (/ (float (- (get-internal-real-time) start-internal-time) 0d0)
     internal-time-units-per-second))

(defun count-tool-loop-rounds (provider-responses)
  "Count provider rounds used for one completed turn.

Each entry in PROVIDER-RESPONSES is one backend COMPLETE call from RUN-TOOL-LOOP,
including the final no-tool-call response. NIL/empty means zero rounds."
  (if (listp provider-responses)
      (length provider-responses)
      0))

(defun write-final-response-outcome (&key rounds duration-seconds)
  "Print the post-turn outcome line to stderr for human interactive/one-shot modes.

Format:
  <<< DONE rounds=N duration_seconds=S.SSS"
  (format *error-output*
          "~%<<< DONE rounds=~D duration_seconds=~,3F~%"
          rounds duration-seconds)
  (finish-output *error-output*))

(defun report-completed-chat-turn (session start-internal-time response
                                   &key (leading-newline t))
  "Print RESPONSE text and the structured final-response OUTCOME.

LEADING-NEWLINE is true for interactive turns (separate the answer from the
prompt chrome) and false for one-shot mode."
  (let ((duration (elapsed-seconds-since start-internal-time))
        (rounds (count-tool-loop-rounds
                 (chat-session-last-provider-responses session)))
        (text (completion-response-text response)))
    (if leading-newline
        (format t "~%~A~%" text)
        (format t "~A~%" text))
    (write-final-response-outcome :rounds rounds :duration-seconds duration)
    response))

(defun process-interactive-user-turn (session input)
  "Run one non-command interactive user turn and print its outcome.

Called by name from RUN-INTERACTIVE each loop iteration so reload_harness can
replace timing/outcome behavior mid-session. Errors are recorded on SESSION and
reported on stderr without aborting the interactive loop."
  (handler-case
      (let* ((start (get-internal-real-time))
             (response (chat-session-turn session input)))
        (report-completed-chat-turn session start response :leading-newline t))
    (error (condition)
      (note-chat-session-failure session)
      (format *error-output*
              "~%TURN_FAILED: ~A; session continues and prior history is retained.~%"
              condition)
      (finish-output *error-output*)
      nil)))
