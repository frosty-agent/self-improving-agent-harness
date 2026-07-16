(in-package #:self-improving-agent-harness)

(defun parse-source-mutation (text)
  "Read one data-only structured mutation representation from TEXT."
  (unless (stringp text)
    (error "Structured mutation text must be a string."))
  (let ((*read-eval* nil)
        (*package* (or (find-package "SELF-IMPROVING-AGENT-HARNESS/SOURCE-MUTATION-CANDIDATE")
                       *package*)))
    (multiple-value-bind (form position) (read-from-string text nil :end)
      (when (eq form :end)
        (error "Structured mutation text is empty."))
      (unless (every (lambda (character) (find character " \t\n\r"))
                     (subseq text position))
        (error "Structured mutation text must contain exactly one form."))
      form)))

(defparameter *source-mutation-reader-package*
  (or (find-package "SELF-IMPROVING-AGENT-HARNESS/SOURCE-MUTATION-CANDIDATE")
      (make-package "SELF-IMPROVING-AGENT-HARNESS/SOURCE-MUTATION-CANDIDATE" :use '(#:cl)))
  "Isolated package used only while reading generated candidate source forms.")

(defun validate-source-mutation (mutation)
  "Validate the deliberately small, data-only replace-function-body mutation language."
  (unless (and (listp mutation) (evenp (length mutation))
               (eq (getf mutation :operation) :replace-function-body)
               (stringp (getf mutation :target))
               (plusp (length (getf mutation :target)))
               (consp (getf mutation :body)))
    (error "Mutation must be (:operation :replace-function-body :target STRING :body LIST)."))
  mutation)

(defun read-source-forms (source)
  (unless (stringp source)
    (error "Candidate source must be a string."))
  (let ((*read-eval* nil)
        (*package* *source-mutation-reader-package*))
    (with-input-from-string (stream source)
      (loop for form = (read stream nil :end)
            until (eq form :end)
            collect form))))

(defun print-source-forms (forms)
  (with-standard-io-syntax
    (with-output-to-string (stream)
      (dolist (form forms)
        (pprint form stream)))))

(defun target-defun-p (form target)
  (and (consp form) (eq (first form) 'defun)
       (symbolp (second form))
       (string-equal (symbol-name (second form)) target)))

(defun apply-source-mutation (source mutation)
  "Apply one validated named DEFUN body replacement and return canonical printed source."
  (validate-source-mutation mutation)
  (let* ((target (getf mutation :target))
         (body (getf mutation :body))
         (forms (read-source-forms source))
         (matched nil)
         (result
           (mapcar (lambda (form)
                     (if (target-defun-p form target)
                         (progn
                           (setf matched t)
                           (append (subseq form 0 3) (list body)))
                         form))
                   forms)))
    (unless matched
      (error "Mutation target ~S is not a top-level DEFUN." target))
    (print-source-forms result)))

(defparameter +source-mutation-fixture-source+
  "(defun fixture-score (value) (+ value 1))")

(defparameter +source-mutation-fixture-mutation+
  "(:operation :replace-function-body :target \"fixture-score\" :body (+ value 2))")

(defun source-mutation-candidate-header ()
  "(defpackage #:self-improving-agent-harness/source-mutation-candidate (:use #:cl))
(in-package #:self-improving-agent-harness/source-mutation-candidate)
")

(defun write-utf8-file (path content)
  (ensure-directories-exist path)
  (with-open-file (stream path :direction :output :if-exists :supersede
                              :if-does-not-exist :create :external-format :utf-8)
    (write-string content stream)))

(defun source-mutation-diff (original candidate)
  (multiple-value-bind (output ignored-status)
      (uiop:run-program (list "diff" "-u" (namestring original) (namestring candidate))
                        :output :string :ignore-error-status t)
    (declare (ignore ignored-status)) output))

(defun reportable-source-mutation (mutation)
  "Use a non-sensitive evidence name so report redaction retains the replacement form."
  (list :operation (getf mutation :operation) :target (getf mutation :target)
        :replacement-form (with-standard-io-syntax (prin1-to-string (getf mutation :body)))))

(defun evaluate-source-mutation-candidate (candidate-path)
  "SBCL-specific compile/load step; evaluator identity is fixed by this function."
  (handler-case
      (progn
        (load (compile-file candidate-path))
        (let ((function (symbol-function
                         (find-symbol "FIXTURE-SCORE"
                                      "SELF-IMPROVING-AGENT-HARNESS/SOURCE-MUTATION-CANDIDATE"))))
          (if (= 5 (funcall function 3)) :pass :fail)))
    (error () :execution-failure)))

(defun run-source-mutation-prototype (&optional (directory "reports/source-mutation-v1/"))
  "Materialize, diff, compile, and independently evaluate one offline candidate."
  (let* ((output (uiop:ensure-directory-pathname directory))
         (workspace (merge-pathnames "candidate/" output))
         (original (merge-pathnames "fixture-original.lisp" workspace))
         (candidate (merge-pathnames "fixture-candidate.lisp" workspace))
         (diff-path (merge-pathnames "fixture.diff" workspace))
         (mutation (parse-source-mutation +source-mutation-fixture-mutation+))
         (header (source-mutation-candidate-header))
         (candidate-source (apply-source-mutation +source-mutation-fixture-source+ mutation)))
    (validate-source-mutation mutation)
    (write-utf8-file original (concatenate 'string header +source-mutation-fixture-source+))
    (write-utf8-file candidate (concatenate 'string header candidate-source))
    (write-utf8-file diff-path (source-mutation-diff original candidate))
    (let* ((outcome (evaluate-source-mutation-candidate candidate))
           (report
             (list :schema-version "1" :report-type "run-trace"
                   :run-id "source-mutation-v1/offline" :task (list :prompt "Held-out fixture-score(3) = 5"
                                                                     :criteria '((:name "held-out-score")))
                   :candidate (list :id "source-mutation-v1/candidate" :parent-id "source-mutation-v1/original"
                                    :configuration (list :mutation (reportable-source-mutation mutation)
                                                         :diff-path (namestring diff-path)))
                   :model-history (list :available '() :invoked '()) :tool-metadata '()
                   :source-mutation (reportable-source-mutation mutation)
                   :validation "passed" :compilation "sbcl:compile-file/load"
                   :evaluation (list :evaluator "pinned-offline-evaluator-v1"
                                     :evidence (list (list :fixture "held-out-score-v1" :status outcome)))
                   :outcome (string-downcase (symbol-name outcome))
                   :decision (list :action "reject" :rationale "Research prototype: normal repository patches remain preferred.")))
           (artifacts (write-run-report-artifacts report output)))
      (list :outcome outcome :diff-path diff-path :json-path (getf artifacts :json-path)
            :html-path (getf artifacts :html-path)))))
