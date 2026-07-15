(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:load-system :self-improving-agent-harness)

(let* ((request
         (self-improving-agent-harness:make-completion-request
          :model "openai/gpt-4.1-mini"
          :messages '((:role "system" :content "Reply exactly with integration-ok.")
                      (:role "user" :content "Return the required phrase."))
          :options '(:temperature 0.0 :max-tokens 16)))
       (backend
         (self-improving-agent-harness:make-openrouter-backend
          :api-key (uiop:getenv "OPENROUTER_API_KEY")))
       (response (self-improving-agent-harness:complete backend request)))
  (format t "LIVE_PROVIDER_RESPONSE~%model=~A~%text=~A~%"
          (self-improving-agent-harness:completion-response-model response)
          (self-improving-agent-harness:completion-response-text response)))
