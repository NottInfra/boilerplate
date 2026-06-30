.PHONY: build test

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

build:
	docker build -t fantastic-beasts "$(ROOT)"

test:
	cd "$(ROOT)src" && go build -o /dev/null .
