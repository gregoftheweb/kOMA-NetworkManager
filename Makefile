# kOMA Network Manager — developer tasks.  `make setup` once, then `make check` before committing
# (the pre-commit hook runs it for you).

# Qt 6 tools; on Arch the plain names on PATH can be Qt 5 (qt5-declarative)
QT_BIN ?= /usr/lib/qt6/bin
export QT_BIN
export NPM_CONFIG_LOGLEVEL = warn
QMLLINT ?= $(QT_BIN)/qmllint
QMLTESTRUNNER ?= $(QT_BIN)/qmltestrunner
VENV := .venv
PY := $(VENV)/bin
SHELL_SCRIPTS := bin/install bin/dev-reload scripts/package.sh scripts/qmlformat-check.sh .githooks/pre-commit

.PHONY: setup lint format test check package install clean

setup:  ## dev tools into .venv and node_modules, and enable the git hook
	python3 -m venv $(VENV)
	$(PY)/pip install -q -r requirements-dev.txt
	npm install --silent --no-fund --no-audit
	git config core.hooksPath .githooks

lint:  ## every static gate
	$(PY)/ruff check .
	$(PY)/ruff format --check .
	$(QMLLINT) contents/ui/*.qml contents/ui/*.js
	scripts/qmlformat-check.sh
	npx --no-install prettier --check .
	npx --no-install shellcheck $(SHELL_SCRIPTS)
	python3 scripts/validate-metadata.py

format:  ## apply every formatter
	$(PY)/ruff check --fix .
	$(PY)/ruff format .
	scripts/qmlformat-check.sh --fix
	npx --no-install prettier --write .

test:  ## Python tests (CLI against a fake nmcli) and QML unit tests (headless)
	$(PY)/pytest
	QT_QPA_PLATFORM=offscreen $(QMLTESTRUNNER) -input tests

check: lint test  ## what CI and the pre-commit hook run

package: check  ## dist/<id>-<version>.plasmoid for the KDE Store
	scripts/package.sh

install:  ## install into this session (widget, CLI) and place it on the panels
	bin/install

clean:
	rm -rf dist .pytest_cache .ruff_cache
