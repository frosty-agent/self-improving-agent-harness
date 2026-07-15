(require :asdf)
(asdf:load-asd (truename "self-improving-agent-harness.asd"))
(asdf:load-system :self-improving-agent-harness)

(defun required-environment (name)
  (let ((value (uiop:getenv name)))
    (unless (and value (plusp (length value)))
      (error "~A must be supplied by bin/chat." name))
    value))

(defun shell-tool (arguments)
  (let ((command (gethash "command" arguments)))
    (unless (and (stringp command) (plusp (length command)))
      (error "run_shell requires a non-empty command."))
    (format *error-output* "TOOL_CALL name=run_shell~%")
    (uiop:run-program (list "/bin/sh" "-lc" command)
                      :output :string
                      :error-output :output)))

(let* ((prompt (required-environment "HARNESS_CHAT_PROMPT"))
       (model (required-environment "HARNESS_CHAT_MODEL"))
       (max-rounds (parse-integer (required-environment "HARNESS_CHAT_MAX_ROUNDS")))
       (backend (self-improving-agent-harness:make-openrouter-backend
                 :api-key (uiop:getenv "OPENROUTER_API_KEY")))
       (request
         (self-improving-agent-harness:make-completion-request
          :model model
          :messages `((:role "system"
                       :content "Use run_shell when it helps answer the user. When finished, return a final response without tool calls.")
                      (:role "user" :content ,prompt))
          :options
          '(:temperature 0.2
            :max-tokens 512
            :tools ((:type "function"
                     :function (:name "run_shell"
                                :description "Run a shell command in the harness container and return combined output."
                                :parameters (:type "object"
                                             :properties (:command (:type "string"))
                                             :required ("command"))))))))
       (response
         (self-improving-agent-harness:run-tool-loop
          backend request `(("run_shell" . ,#'shell-tool)) :max-rounds max-rounds)))
  (format t "~A~%" (self-improving-agent-harness:completion-response-text response))
  (format *error-output* "OUTCOME final-response model=~A~%"
          (self-improving-agent-harness:completion-response-model response)))
