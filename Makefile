.PHONY: build test test-docker

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

build:
	docker build -t fantastic-beasts "$(ROOT)"

test:
	cd "$(ROOT)src" && go build -o /dev/null .

test-docker:
	docker run --rm -v "$(ROOT)src:/src" -w /src golang:1.25-alpine go test ./...
