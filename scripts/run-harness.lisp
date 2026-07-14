(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:load-system :self-improving-agent-harness)

(let ((summary (self-improving-agent-harness:run-harness)))
  (format t "Harness status: ~(~A~)~%Backend: ~A~%"
          (getf summary :status)
          (getf summary :backend)))
