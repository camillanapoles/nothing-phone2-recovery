# Raiz do workspace — atalhos de prova. A verdade está em AGENTS.md.
SHELL := /usr/bin/env bash

.PHONY: help state state-reset test-state skills test prove

help:
	@echo "make state        -> dry-run da higiene de estado (nada é alterado)"
	@echo "make state-reset  -> aplica a higiene (quarentena + limpa banco do FSM)"
	@echo "make test-state   -> regressão da higiene (13 casos)"
	@echo "make skills       -> harness completo das 8 skills (validate+testes+eval)"
	@echo "make prove        -> tudo: test-state + skills"

state:
	@scripts/state_reset.sh

state-reset:
	@scripts/state_reset.sh --apply

test-state:
	@tests/test_state_reset.sh

skills:
	@$(MAKE) -s -C skills check-all

test: test-state

prove: test-state skills
	@echo "[workspace] tudo verde"
