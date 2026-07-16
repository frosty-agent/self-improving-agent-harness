(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:load-system :self-improving-agent-harness)

(let ((artifacts (self-improving-agent-harness:write-scripted-baseline-report)))
  (format t "JSON report: ~A~%HTML report: ~A~%"
          (getf artifacts :json-path)
          (getf artifacts :html-path))
  (unless (and (probe-file (getf artifacts :json-path))
               (probe-file (getf artifacts :html-path)))
    (uiop:quit 1)))
