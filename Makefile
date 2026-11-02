# Raiz do workspace — atalhos de prova. A verdade está em AGENTS.md.
SHELL := /usr/bin/env bash

.PHONY: help escopo garantia pack pack-selftest kernel continuidade debitos closure fragmento m05 state state-reset test-state test-wrappers arch skills test prove

help:
	@echo "make state        -> dry-run da higiene de estado (nada é alterado)"
	@echo "make state-reset  -> aplica a higiene (quarentena + limpa banco do FSM)"
	@echo "make test-state   -> regressão da higiene (13 casos)"
	@echo "make test-wrappers -> wrappers de release: auditoria de ZIP/Cuttlefish/build (34 casos)"
	@echo "make arch         -> travas de arquitetura (AG1..AG21)"
	@echo "make audit-loop   -> auditoria em loop até convergir (AG + contradições + cobertura + suítes)"
	@echo "make mutation     -> falseabilidade: 168 mutantes mortos por asserção (JOBS=auto)"
	@echo "make vacuity       -> análise estática de testes viciados (V1–V6)"
	@echo "make skills       -> harness completo das 8 skills (validate+testes+eval)"
	@echo "make pack         -> solver: qual par (motor × kernel) fecha as 10 condições, por dado"
	@echo "make pack-selftest -> prova de falseabilidade das 10 condições (cada uma cai só por ela)"
	@echo "make m05          -> DroidSpaces: contrato estático do M05"
	@echo "make kernel        -> plano do kernel (P01–P20) e pré-build (B01–B07): 0 pronto / 3 pendente"
	@echo "make continuidade  -> a instrução de continuidade ainda contém todas as cláusulas (Q01–Q20)"
	@echo "make debitos       -> débitos derivados dos gates + o passo que fecha cada um (0 fechado / 3 aberto / 1 inconsistente)"
	@echo "make closure       -> o plano de fechamento é executável? (DAG, gates, comandos, staging antes do físico)"
	@echo "make fragmento     -> o fragmento do pack bate com o contrato do DroidSpaces?"
	@echo "make garantia     -> garantia prévia: 5 requisitos, com prova ou PENDENTE (exit 3)"
	@echo "make escopo       -> o que é deste workspace × legado que manda NÃO usar""
	@echo "make prove        -> tudo: test-state + wrappers + arch + skills"

state:
	@scripts/state_reset.sh

state-reset:
	@scripts/state_reset.sh --apply

test-state:
	@tests/test_state_reset.sh

test-wrappers:
	@tests/test_wrapper_stages.sh

escopo:
	@python3 skills/evox-rom-ci-optimizer/scripts/legacy_scope.py --root .

garantia:
	@python3 skills/evox-rom-ci-optimizer/scripts/success_guarantee.py --root .

fragmento:
	@python3 scripts/kernel-fragment.py --root . --check

debitos:
	@python3 skills/evox-rom-ci-optimizer/scripts/debt_ledger.py --root .

closure:
	@python3 skills/evox-rom-ci-optimizer/scripts/closure_gate.py --root .

continuidade:
	@python3 skills/evox-rom-ci-optimizer/scripts/continuity_gate.py --root .

kernel:
	@python3 skills/evox-rom-ci-optimizer/scripts/kernel_build_gate.py --root . --prebuild

m05:
	@python3 skills/evox-rom-ci-optimizer/scripts/droidspaces_preflight.py --root . --static

pack:
	@python3 skills/evox-rom-ci-optimizer/scripts/root_pair_solver.py --root .

pack-selftest:
	@python3 skills/evox-rom-ci-optimizer/scripts/root_pair_solver.py --root skills/evox-rom-ci-optimizer/tests/fixtures/pack-complete --selftest

arch:
	@python3 skills/evox-rom-ci-optimizer/scripts/architecture_guard.py

audit-loop:
	@skills/evox-rom-ci-optimizer/scripts/audit_loop.sh

JOBS ?= auto

mutation:
	@python3 skills/evox-rom-ci-optimizer/scripts/mutation_check.py --root . --jobs $(JOBS)

vacuity:
	@python3 skills/evox-rom-ci-optimizer/scripts/test_vacuity_scan.py --root .

skills:
	@$(MAKE) -s -C skills check-all

test: test-state

prove: test-state test-wrappers arch skills
	@echo "[workspace] tudo verde"
