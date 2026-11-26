.PHONY: build test test-docker

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

build:
	docker build -t boilerplate "$(ROOT)"

test:
	@if [ ! -d "$(ROOT)src" ]; then echo "[+] skip test (no src/)"; exit 0; fi; \
	cd "$(ROOT)src" && go build -o /dev/null .

test-docker:
	# DinD on k8s runners often can't see /runner-work bind mounts; stream sources in.
	@if [ ! -d "$(ROOT)src" ]; then echo "[+] skip test-docker (no src/)"; exit 0; fi; \
	tar -C "$(ROOT)src" -cf - . | docker run --rm -i -w /src golang:1.25-alpine sh -c 'tar -xf - && go test ./...' 
