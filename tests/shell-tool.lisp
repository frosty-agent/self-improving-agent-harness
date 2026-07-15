(in-package #:self-improving-agent-harness/tests)

(defun run-shell-tool-tests ()
  (let* ((em-dash (string (code-char #x2014)))
         (expected (format nil "unicode ~A output" em-dash))
         (output
           (self-improving-agent-harness::run-shell-tool
            (let ((arguments (make-hash-table :test #'equal)))
              (setf (gethash "command" arguments)
                    "printf 'unicode \\342\\200\\224 output'")
              arguments))))
    (ensure-equal expected output
                  "shell tool decodes UTF-8 command output"))
  (let ((output
          (self-improving-agent-harness::run-shell-tool
           (let ((arguments (make-hash-table :test #'equal)))
             (setf (gethash "command" arguments)
                   "printf 'README was not found' >&2; exit 9")
             arguments))))
    (ensure-true (search "Command failed with exit status 9" output)
                 "shell tool returns a nonzero exit status to the model")
    (ensure-true (search "README was not found" output)
                 "shell tool returns combined failure output to the model"))
  (format t "Shell-tool tests passed.~%")
  t)
