;;;; Opt-in, billable Claude Code setup-token verification (issues #49/#57).
;;;; Never run from make test. Emits and persists sanitized evidence only.

(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:load-system :self-improving-agent-harness)

(defpackage #:claude-verify-script (:use #:cl))
(in-package #:claude-verify-script)

(defun getenv (name) (uiop:getenv name))

(defun opted-in-p ()
  (let ((value (getenv "HARNESS_LIVE_CLAUDE_SMOKE")))
    (and (stringp value) (string= value "1"))))

(defun claude-version-string ()
  (handler-case
      (string-trim '(#\Space #\Newline #\Return)
                   (uiop:run-program '("claude" "--version")
                                     :output :string :ignore-error-status t))
    (error () "unavailable")))

(defun iso-timestamp ()
  (multiple-value-bind (s min h d mon y) (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ" y mon d h min s)))

(defun evidence-artifact-path ()
  (let ((dir (or (getenv "HARNESS_CLAUDE_EVIDENCE_DIR")
                 (getenv "HARNESS_LOG_DIR") "agent-logs")))
    (ensure-directories-exist (merge-pathnames "" (uiop:ensure-directory-pathname dir)))
    (merge-pathnames (format nil "claude-verify-~A.txt"
                             (substitute #\_ #\: (iso-timestamp)))
                     (uiop:ensure-directory-pathname dir))))

(defun main ()
  (unless (opted-in-p)
    (format *error-output* "SKIP: set HARNESS_LIVE_CLAUDE_SMOKE=1 to run the billable Claude verification.~%")
    (uiop:quit 77))
  (unless (self-improving-agent-harness:claude-oauth-token-present-p)
    (format *error-output* "CLAUDE_VERIFY failed: CLAUDE_CODE_OAUTH_TOKEN is absent; generate one with claude setup-token and retry.~%")
    (uiop:quit 1))
  (let ((version (claude-version-string))
        (timestamp (iso-timestamp)))
    (multiple-value-bind (evidence success)
        (self-improving-agent-harness:verify-claude-oauth :claude-version version)
      (setf evidence (list* :timestamp timestamp evidence))
      (self-improving-agent-harness:format-claude-verification-evidence evidence *standard-output*)
      (handler-case
          (let ((path (evidence-artifact-path)))
            (with-open-file (out path :direction :output :if-exists :supersede
                                      :if-does-not-exist :create)
              (self-improving-agent-harness:format-claude-verification-evidence evidence out))
            (format *error-output* "CLAUDE_VERIFY evidence written to ~A~%" (namestring path)))
        (error (condition)
          (format *error-output* "CLAUDE_VERIFY warning: could not write evidence artifact (~A)~%"
                  (type-of condition))))
      (uiop:quit (if success 0 1)))))

(main)
