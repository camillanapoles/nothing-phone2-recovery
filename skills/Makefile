# =============================================================================
# Harness de skills — validação de contrato, regressão, avaliação e descoberta
# Uso: make -C skills help
# =============================================================================
SHELL := /usr/bin/env bash
CORE  ?= evox-rom-ci-optimizer
GUARD ?= android16-root-guardian

.PHONY: help validate eval test test-core test-guard test-all check-core check-all registry tree

help:
	@echo "======================================================================="
	@echo " skills harness — $(shell ls -d */ 2>/dev/null | wc -l) skills instaladas"
	@echo "======================================================================="
	@echo " make validate    -> contrato: front matter, name==dir, links, segredos, registry"
	@echo " make eval        -> qualidade: 7 eixos falseáveis, limite por classe+tier"
	@echo " make test-core   -> R00..R09 (13) + preflight (8) + ROM/L4 (15) + gates (36)"
	@echo " make test-guard  -> coletor de evidencia pos-flash (8) com stub de adb"
	@echo " make test-all    -> test-core + test-guard"
	@echo " make check-core  -> make check da skill core (bash -n, py_compile, JSON, auditor)"
	@echo " make check-all   -> validate + check-core + test-all + eval"
	@echo " make registry    -> estado do ecossistema (tiers, excluidas, deduplicadas)"
	@echo " make tree        -> arvore das skills"
	@echo "======================================================================="

validate:
	@python3 tools/validate_skills.py

eval:
	@python3 tools/eval_skills.py

test-core:
	@$(MAKE) -s -C $(CORE) test
	@$(MAKE) -s -C $(CORE) test-preflight
	@$(MAKE) -s -C $(CORE) test-rom
	@$(MAKE) -s -C $(CORE) test-gates

test-guard:
	@$(MAKE) -s -C $(GUARD) test

test-all: test-core test-guard

check-core:
	@$(MAKE) -s -C $(CORE) check >/dev/null && echo "[core] make check OK"

check-all: validate check-core test-all eval
	@echo "[harness] tudo verde"

registry:
	@python3 -c "import json;d=json.load(open('registry.json'));\
print('\n'.join(f\"{s['name']:<32} v{s['version']:<8} {s['tier']:<8} {s.get('capabilities')}\" for s in d['skills']));\
print('\nexcluidas:'); [print(' -', e['name'], '->', e['reason']) for e in d.get('excluded',[])];\
print('deduplicadas:'); [print(' -', e['name'], '->', e['reason']) for e in d.get('deduplicated',[])]"

tree:
	@find . -path ./tools/__pycache__ -prune -o -type f -print | sed 's|^\./||' | sort | awk -F/ '{indent=""; for(i=1;i<NF;i++) indent=indent"  "; print indent $NF}'
