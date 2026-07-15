(in-package #:self-improving-agent-harness/tests)

(defclass scripted-backend (backend)
  ((responses :initarg :responses :accessor scripted-backend-responses)
   (received-requests :initform '() :accessor scripted-backend-received-requests)))

(defmethod complete ((backend scripted-backend) request)
  (push request (scripted-backend-received-requests backend))
  (or (pop (scripted-backend-responses backend))
      (error "Test backend exhausted its scripted responses.")))

(defun run-tool-loop-tests ()
  (let* ((tool-response
           (make-completion-response
            :text ""
            :model "test/model"
            :tool-calls '((:id "call-123" :type "function" :name "echo"
                           :arguments "{\"message\":\"hello\"}"))))
         (final-response
           (make-completion-response :text "done" :model "test/model"))
         (backend (make-instance 'scripted-backend
                                 :name "scripted"
                                 :responses (list tool-response final-response)))
         (handler-arguments nil)
         (result
           (self-improving-agent-harness:run-tool-loop
            backend
            (make-completion-request
             :model "test/model"
             :messages '((:role "user" :content "Say hello using echo.")))
            `(("echo" . ,(lambda (arguments)
                            (setf handler-arguments arguments)
                            (format nil "echoed: ~A" (gethash "message" arguments))))))))
    (ensure-equal "done" (completion-response-text result)
                  "tool loop returns the final assistant response")
    (ensure-equal "hello" (gethash "message" handler-arguments)
                  "tool handler receives decoded JSON arguments")
    (ensure-equal 2 (length (scripted-backend-received-requests backend))
                  "tool loop submits a continuation after executing a tool")
    (let* ((continuation
             (first (scripted-backend-received-requests backend)))
           (messages (completion-request-messages continuation))
           (assistant-message (second messages))
           (tool-message (third messages)))
      (ensure-equal "assistant" (getf assistant-message :role)
                    "continuation includes the assistant tool-call message")
      (ensure-equal "call-123" (getf (first (getf assistant-message :tool-calls)) :id)
                    "continuation retains the provider tool-call ID")
      (ensure-equal "tool" (getf tool-message :role)
                    "continuation includes a tool result message")
      (ensure-equal "call-123" (getf tool-message :tool-call-id)
                    "tool result references the matching tool call")
      (ensure-equal "echoed: hello" (getf tool-message :content)
                    "tool result contains handler output")))
  (format t "Tool-loop tests passed.~%")
  t)
