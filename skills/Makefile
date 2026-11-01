# =============================================================================
# Harness de skills — validação de contrato, regressão e descoberta
# Uso: make -C skills help
# =============================================================================
SHELL := /usr/bin/env bash
CORE  ?= evox-rom-ci-optimizer

.PHONY: help validate test tree registry check-core check-all

help:
	@echo "======================================================================="
	@echo " skills harness — $(shell ls -d */ 2>/dev/null | wc -l) skills instaladas"
	@echo "======================================================================="
	@echo " make validate    -> front matter, name==dir, links, backticks, segredos, registry"
	@echo " make test        -> regressao das regras R00..R09 (13 cenarios) da skill core"
	@echo " make check-core  -> make check da skill core (bash -n, py_compile, JSON, auditor)"
	@echo " make check-all   -> validate + check-core + test"
	@echo " make registry    -> reimprime o registry.json resumido"
	@echo " make tree        -> arvore das skills"
	@echo "======================================================================="

validate:
	@python3 tools/validate_skills.py

test:
	@$(MAKE) -s -C $(CORE) test

check-core:
	@$(MAKE) -s -C $(CORE) check >/dev/null && echo "[core] make check OK"

check-all: validate check-core test
	@echo "[harness] tudo verde"

registry:
	@python3 -c "import json;d=json.load(open('registry.json'));\
print('\n'.join(f\"{s['name']:<32} v{s['version']:<8} {s['tier']:<8} {s.get('capabilities')}\" for s in d['skills']));\
print('\nexcluidas:'); [print(' -', e['name'], '->', e['reason']) for e in d['excluded']]"

tree:
	@find . -path ./tools/__pycache__ -prune -o -type f -print | sed 's|^\./||' | sort | awk -F/ '{indent=""; for(i=1;i<NF;i++) indent=indent"  "; print indent $NF}'
