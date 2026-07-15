# Docker-first Common Lisp workflow. No host Lisp runtime is required.

.PHONY: image test run live-smoke repl clean

image:
	docker build --tag self-improving-agent-harness:dev .

test:
	./bin/test

run:
	./bin/run

live-smoke:
	./bin/live-smoke

repl:
	./bin/container --noinform

clean:
	docker volume rm self-improving-agent-harness-cache 2>/dev/null || true
