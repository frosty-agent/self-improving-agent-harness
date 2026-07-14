# Docker-first Common Lisp workflow. No host Lisp runtime is required.

.PHONY: image test run repl clean

image:
	docker build --tag self-improving-agent-harness:dev .

test:
	./bin/test

run:
	./bin/run

repl:
	./bin/container --noinform

clean:
	docker volume rm self-improving-agent-harness-cache 2>/dev/null || true
