(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:load-system :self-improving-agent-harness)
(in-package #:self-improving-agent-harness)
(let ((result (run-source-mutation-prototype "reports/source-mutation-v1/")))
  (format t "Outcome: ~A~%Diff: ~A~%JSON report: ~A~%HTML report: ~A~%"
          (getf result :outcome) (getf result :diff-path)
          (getf result :json-path) (getf result :html-path))
  (unless (eq :pass (getf result :outcome)) (uiop:quit 1)))
