# Shortcuts for contributors. `make` with no target runs `make test`.
.PHONY: build test lint install uninstall doctor clean
.DEFAULT_GOAL := test

BIN := build/wispr-teamviewer-fix

build:
	@mkdir -p build
	xcrun swiftc -O wispr-teamviewer-fix.swift -o $(BIN)

test: build
	./$(BIN) --selftest
	./$(BIN) --version

lint:
	shellcheck --severity=info install.sh uninstall.sh doctor.sh lib/ui.sh

install:
	./install.sh

uninstall:
	./uninstall.sh

doctor:
	./doctor.sh

clean:
	rm -rf build
