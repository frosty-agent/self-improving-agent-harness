(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:test-system :self-improving-agent-harness)
