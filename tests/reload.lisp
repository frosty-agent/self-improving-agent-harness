(in-package #:self-improving-agent-harness/tests)

(defun reload-result-field (message key)
  "Extract a status=... field value from a structured reload tool result."
  (let* ((token (format nil "~A=" key))
         (start (search token message)))
    (when start
      (let* ((value-start (+ start (length token)))
             (value-end (or (position #\Space message :start value-start)
                            (position #\Newline message :start value-start)
                            (length message))))
        (subseq message value-start value-end)))))

(defun run-reload-tests ()
  (let ((message (self-improving-agent-harness:reload-harness-tool nil)))
    (ensure-true (search "Reloaded self-improving-agent-harness" message)
                 "reload tool reports a successful in-process reload")
    (ensure-true (search "self-improving-agent-harness.asd" message)
                 "reload tool names the project ASD")
    (ensure-true (search "status=" message)
                 "reload tool returns a structured status line")
    (ensure-equal "ok" (reload-result-field message "status")
                  "clean reload reports status=ok after filtering benign redefinitions")
    (ensure-true (search "files=" message)
                 "reload tool reports how many source files were loaded")
    (ensure-true (search "warnings=0" message)
                 "clean reload reports zero non-benign warnings")
    (ensure-true (search "notes=0" message)
                 "clean reload reports zero compiler notes")
    (ensure-true (search "benign_redefinitions=" message)
                 "reload tool counts expected redefinition warnings separately"))

  ;; Non-benign diagnostics are included in the structured tool result.
  (let ((message
          (self-improving-agent-harness::format-reload-tool-result
           :status "warning"
           :asd #P"/workspace/self-improving-agent-harness.asd"
           :file-count 8
           :warning-count 1
           :note-count 0
           :benign-count 12
           :diagnostics '("style-warning: src/example.lisp: The variable X is defined but never used.")
           :error-message nil)))
    (ensure-true (search "status=warning" message)
                 "warning status is encoded for the tool caller")
    (ensure-true (search "warnings=1" message)
                 "warning count is encoded for the tool caller")
    (ensure-true (search "style-warning: src/example.lisp:" message)
                 "non-benign diagnostic text is included for the tool caller"))

  ;; Load/read failures become status=error tool results with detail, not an empty failure.
  (let ((message
          (self-improving-agent-harness::format-reload-tool-result
           :status "error"
           :asd #P"/workspace/self-improving-agent-harness.asd"
           :file-count 0
           :warning-count 0
           :note-count 0
           :benign-count 0
           :diagnostics '()
           :error-message "error: src/broken.lisp: end of file on #<STREAM>")))
    (ensure-equal "error" (reload-result-field message "status")
                  "failed reload reports status=error")
    (ensure-true (search "error: src/broken.lisp:" message)
                 "failed reload includes the error detail for the tool caller"))

  (let* ((tool-response
           (make-completion-response
            :text ""
            :model "test/model"
            :tool-calls '((:id "call-reload" :type "function" :name "reload_harness"
                           :arguments "{}"))))
         (final-response
           (make-completion-response :text "reloaded in-process" :model "test/model"))
         (backend (make-instance 'scripted-backend
                                 :name "scripted"
                                 :responses (list tool-response final-response)))
         (result
           (self-improving-agent-harness:run-tool-loop
            backend
            (make-completion-request
             :model "test/model"
             :messages '((:role "user" :content "Reload the harness.")))
            `(("reload_harness" . ,#'self-improving-agent-harness:reload-harness-tool)))))
    (ensure-equal "reloaded in-process" (completion-response-text result)
                  "reload_harness participates in the normal tool loop")
    (let* ((continuation (first (scripted-backend-received-requests backend)))
           (tool-message (third (completion-request-messages continuation))))
      (ensure-equal "tool" (getf tool-message :role)
                    "reload tool result is returned as a tool message")
      (ensure-true (search "status=" (getf tool-message :content))
                   "structured reload status reaches the model")
      (ensure-true (search "Reloaded self-improving-agent-harness"
                           (getf tool-message :content))
                   "reload tool result content reaches the model")))
  (let ((session (make-chat-session :backend nil :model "test/model" :handlers '())))
    (ensure-equal 60 (chat-session-max-rounds session)
                  "session default max-rounds remains 60")
    (setf (chat-session-max-rounds session) 24)
    (ensure-equal 24 (chat-session-max-rounds session)
                  "session max-rounds can be updated in-process"))
  (ensure-true (boundp 'self-improving-agent-harness:+chat-input-prompt+)
               "chat CLI prompt parameter is part of the reloadable system")
  (ensure-true (fboundp 'self-improving-agent-harness:write-chat-prompt)
               "write-chat-prompt is reloadable")
  (ensure-true (fboundp 'self-improving-agent-harness:run-chat-cli)
               "run-chat-cli is reloadable")
  (ensure-true (fboundp 'self-improving-agent-harness:process-interactive-user-turn)
               "process-interactive-user-turn is reloadable for mid-session outcome changes")
  (ensure-true (fboundp 'self-improving-agent-harness:write-final-response-outcome)
               "write-final-response-outcome is reloadable")
  ;; Outcome formatting is dispatched by name from the interactive loop.
  (let ((stderr (make-string-output-stream)))
    (let ((*error-output* stderr))
      (self-improving-agent-harness:write-final-response-outcome
       :rounds 3 :duration-seconds 1.5d0))
    (let ((out (get-output-stream-string stderr)))
      (ensure-true (search "<<< DONE rounds=3 duration_seconds=1.500" out)
                   "final-response outcome reports rounds and duration")
      (ensure-true (not (search "model=" out))
                   "final-response outcome no longer embeds the model id")))
  (format t "Reload-hook tests passed.~%")
  t)
