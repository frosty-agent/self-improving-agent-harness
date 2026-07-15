(in-package #:self-improving-agent-harness)

(defun run-shell-tool (arguments)
  "Run the non-empty `command` field from decoded tool ARGUMENTS in the container.

Return combined stdout/stderr as UTF-8 text.  A command failure remains an
error so the tool loop can report a safe, redacted failure outcome."
  (let ((command (gethash "command" arguments)))
    (unless (and (stringp command) (plusp (length command)))
      (error "run_shell requires a non-empty command."))
    (log-interaction :info "tool-call" :tool "run_shell" :command command)
    (format *error-output* "TOOL_CALL name=run_shell~%")
    (multiple-value-bind (output ignored-error-output exit-status)
        (uiop:run-program (list "/bin/sh" "-lc" command)
                          :output :string
                          :error-output :output
                          :external-format :utf-8
                          :ignore-error-status t)
      (declare (ignore ignored-error-output))
      (if (zerop exit-status)
          (progn
            (log-interaction :info "tool-completed" :tool "run_shell"
                             :command command :output-length (length output))
            output)
          (progn
            (log-interaction :error "tool-failed" :tool "run_shell"
                             :command command :exit-status exit-status)
            (format nil "Command failed with exit status ~D.~%~A"
                    exit-status output))))))
