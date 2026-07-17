(in-package #:self-improving-agent-harness)

(defparameter *reload-diagnostic-limit* 20
  "Maximum number of non-benign reload diagnostics included in the tool result.")

(defun harness-asd-path ()
  "Locate the project ASD file from the loaded system or the working directory."
  (or (let ((system (asdf:find-system :self-improving-agent-harness nil)))
        (when system
          (asdf:system-source-file system)))
      (probe-file (merge-pathnames "self-improving-agent-harness.asd"
                                   (uiop:getcwd)))
      (error "Could not locate self-improving-agent-harness.asd")))

(defun harness-source-files (system)
  "Return absolute pathnames of CL source files in SYSTEM in serial order."
  (let ((files '()))
    (labels ((walk (component)
               (typecase component
                 (asdf:cl-source-file
                  (push (asdf:component-pathname component) files))
                 (asdf:module
                  (mapc #'walk (asdf:component-children component))))))
      (walk system))
    (nreverse files)))

(defun reload-condition-source-path (condition)
  "Best-effort source path for a compiler note/warning, or NIL."
  (declare (ignore condition))
  (or (ignore-errors *compile-file-pathname*)
      (ignore-errors *load-pathname*)))

(defun reload-condition-kind (condition)
  "Return a compact diagnostic kind keyword for CONDITION."
  (cond
    ((typep condition 'error) :error)
    ((and (find-symbol "COMPILER-NOTE" :sb-ext)
          (typep condition (find-symbol "COMPILER-NOTE" :sb-ext)))
     :note)
    ((typep condition 'style-warning) :style-warning)
    ((typep condition 'warning) :warning)
    (t :diagnostic)))

(defun benign-reload-condition-p (condition)
  "True for expected noise from in-process redefinition and foreign ASDFs.

Reload intentionally LOADs every harness source file into a live image, so
SBCL redefinition warnings are normal success signals rather than problems to
surface to the tool caller."
  (or (typep condition 'sb-kernel:redefinition-with-defun)
      (typep condition 'sb-kernel:redefinition-with-defmacro)
      (typep condition 'sb-kernel:redefinition-with-defgeneric)
      (typep condition 'sb-kernel:redefinition-with-defmethod)
      (let ((text (ignore-errors (princ-to-string condition))))
        (and (stringp text)
             (or (search "redefining" text :test #'char-equal)
                 (search "BAD-SYSTEM-NAME" text :test #'char-equal)
                 (search "contains definition for system" text :test #'char-equal))))))

(defun sanitize-reload-diagnostic-text (text)
  "Return a single-line, length-capped diagnostic string safe for tool results."
  (let* ((flattened (if (stringp text)
                        (substitute #\Space #\Newline
                                    (substitute #\Space #\Return text))
                        (prin1-to-string text)))
         (trimmed (string-trim '(#\Space #\Tab) flattened))
         (limit 240))
    (if (<= (length trimmed) limit)
        trimmed
        (concatenate 'string (subseq trimmed 0 (- limit 3)) "..."))))

(defun format-reload-diagnostic (kind condition &optional source-path)
  "Format one collected diagnostic for inclusion in the tool result."
  (let* ((path-string
           (when source-path
             (namestring source-path)))
         (relative
           (when path-string
             (let* ((marker "/workspace/")
                    (pos (search marker path-string)))
               (if pos
                   (subseq path-string (+ pos (length marker)))
                   path-string))))
         (text (sanitize-reload-diagnostic-text
                (ignore-errors (princ-to-string condition)))))
    (if relative
        (format nil "~(~A~): ~A: ~A" kind relative text)
        (format nil "~(~A~): ~A" kind text))))

(defun collect-reload-diagnostics (thunk)
  "Run THUNK while collecting non-benign warnings/notes.

Returns five values: primary value of THUNK, warning messages, note messages,
benign-count, and error message or NIL. Soft warnings/notes are muffled after
collection so reload can continue; serious errors are captured and abort THUNK."
  (let ((warnings '())
        (notes '())
        (benign 0)
        (error-message nil)
        (primary nil))
    (handler-bind
        ((warning
          (lambda (condition)
            (if (benign-reload-condition-p condition)
                (incf benign)
                (push (format-reload-diagnostic (reload-condition-kind condition)
                                                condition
                                                (reload-condition-source-path condition))
                      warnings))
            (muffle-warning condition)))
         #+#.(cl:if (cl:find-symbol "COMPILER-NOTE" :sb-ext) '(and) '(or))
         (sb-ext:compiler-note
          (lambda (condition)
            (if (benign-reload-condition-p condition)
                (incf benign)
                (push (format-reload-diagnostic :note condition
                                                (reload-condition-source-path condition))
                      notes)))))
      (handler-case
          (setf primary (funcall thunk))
        (error (condition)
          (setf error-message
                (format-reload-diagnostic :error condition
                                         (reload-condition-source-path condition))
                primary nil))))
    (values primary
            (nreverse warnings)
            (nreverse notes)
            benign
            error-message)))

(defun reload-status-for-counts (error-message warning-count note-count)
  "Map collected diagnostic counts to a compact status token."
  (cond
    (error-message "error")
    ((plusp warning-count) "warning")
    ((plusp note-count) "note")
    (t "ok")))

(defun format-reload-tool-result (&key status asd file-count warning-count note-count
                                    benign-count diagnostics error-message)
  "Build the structured reload_harness tool result string."
  (with-output-to-string (stream)
    (format stream
            "status=~A files=~D warnings=~D notes=~D benign_redefinitions=~D asd=~A"
            status file-count warning-count note-count benign-count (namestring asd))
    (format stream
            "~%Reloaded self-improving-agent-harness from ~A. Function definitions now match disk. Existing chat-session history, max-rounds, and handler list were not reset."
            asd)
    (when error-message
      (format stream "~%error: ~A" error-message))
    (let ((limit *reload-diagnostic-limit*)
          (emitted 0))
      (dolist (item diagnostics)
        (when (< emitted limit)
          (format stream "~%~A" item)
          (incf emitted)))
      (let ((remaining (- (length diagnostics) emitted)))
        (when (plusp remaining)
          (format stream "~%... ~D more diagnostic(s) omitted" remaining))))))

(defun reload-harness-source-files ()
  "Reload every Lisp source file in the harness ASDF system from source.

The Docker runtime mounts /workspace read-only, so COMPILE-FILE cannot safely
write FASLs beside sources. Loading the source files directly redefines the
running image without mutating the checkout or relying on ASDF's outer
operation state.

Returns the list of loaded pathnames."
  (let* ((system (asdf:find-system :self-improving-agent-harness t))
         (files (harness-source-files system)))
    (dolist (file files)
      (load file :verbose nil :print nil))
    files))

(defun reload-harness-tool (arguments)
  "Reload harness sources into the current Lisp image.

ARGUMENTS is the decoded tool-argument object (hash-table or NIL) and is
ignored: reload always reloads the full ASDF system sources. This runs
in-process, so redefined functions and parameters (including chat CLI prompt
bindings in src/chat-cli.lisp) are visible to later turns of the same chat.
Existing CHAT-SESSION slot values (history, max-rounds, captured handler list)
are not reset; use interactive /max-rounds to change the live session limit.

The tool result is a structured status summary:

  status=ok|note|warning|error files=N warnings=N notes=N benign_redefinitions=N asd=...

followed by a human sentence and any non-benign diagnostics. Expected SBCL
redefinition warnings from LOAD are counted as benign and omitted. Soft
warnings/notes do not abort the reload; load/read errors set status=error and
still return a tool result string so the model can see the failure detail."
  (declare (ignore arguments))
  (log-interaction :info "tool-call" :tool "reload_harness")
  (format *error-output* "TOOL_CALL name=reload_harness~%")
  (let ((asd (harness-asd-path)))
    (multiple-value-bind (files warnings notes benign error-message)
        (collect-reload-diagnostics
         (lambda ()
           (asdf:load-asd asd)
           ;; Refresh system definition so newly added components (e.g. chat-cli) appear.
           (asdf:find-system :self-improving-agent-harness t)
           (reload-harness-source-files)))
      (let* ((file-count (if (listp files) (length files) 0))
             (warning-count (length warnings))
             (note-count (length notes))
             (status (reload-status-for-counts error-message warning-count note-count))
             (diagnostics (append warnings notes))
             (message
               (format-reload-tool-result
                :status status
                :asd asd
                :file-count file-count
                :warning-count warning-count
                :note-count note-count
                :benign-count benign
                :diagnostics diagnostics
                :error-message error-message)))
        (if (string= status "error")
            (log-interaction :error "tool-failed" :tool "reload_harness")
            (log-interaction :info "tool-completed" :tool "reload_harness"))
        (format *error-output* "TOOL_DONE name=reload_harness status=~A warnings=~D notes=~D~%"
                status warning-count note-count)
        message))))
