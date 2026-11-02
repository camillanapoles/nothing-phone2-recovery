# =============================================================================
# EVOX-CI v3.1 — Makefile de Automacao Local, Pre-Validacao CI/CD e Snapshots
# (fusao do Makefile v2.0 + alvos v3.0: scan, forge, snapshot, runtime-test)
# =============================================================================
SHELL := /usr/bin/env bash
ROM_PATH ?= ./workspace/base_rom/evox_11_11.zip
EXTRACTED_DIR ?= ./workspace/extracted
MODULES_DIR ?= ./modules
KPM_DIR ?= ./kernel_patches
TWEAKS_DIR ?= ./tweaks
OUT_DIR ?= ./workspace/out
ENGINE ?= apatch
SUPERKEY ?= evox1111safe
LAYER ?= wave1
TAG ?= v11.11-w1-clean
SNAPSHOT_SRC ?= ./workspace/out

.PHONY: help check test test-preflight test-rom test-gates test-kernel test-fragment test-continuity test-closure test-debitos test-stage test-ci scan audit forge extract patch-boot bundle snapshot runtime-test run-act clean
JOBS ?= auto

help:
	@echo "======================================================================="
	@echo " EVOX-CI v3.1 — Evolution X 11.11 Pre-Flight ROM & CI Emulator Suite"
	@echo "======================================================================="
	@echo " make check        -> bash -n + py_compile + JSON schema + self-test do auditor"
	@echo " make test         -> regressao das regras R00..R09 do scanner (13 cenarios)"
	@echo " make test-preflight -> dependencias externas (8 cenarios, PATH controlado)"
	@echo " make test-rom     -> extracao da ROM + L4 (15 cenarios, stub, sem device)"
	@echo " make test-gates   -> kernel x ROM x device (10) + rollout (13) + cache/guard4 (13)"
	@echo " make test-kernel  -> plano do kernel: 20 de plano + 8 de pré-build (40 casos)"
	@echo " make test-fragment -> fragmento do pack derivado do contrato (11 casos)"
	@echo " make test-continuity -> instrução de continuidade íntegra (cláusulas Q01-Q20)"
	@echo " make test-closure -> plano de fechamento executável (K01-K16, 25 casos)"
	@echo " make test-debitos -> ledger de débitos derivado dos gates (29 casos)"
	@echo " make test-stage   -> logica dos estagios A/B e bundle (54 casos, stubs, sem device)"
	@echo " make scan         -> [M15/T3] scanner estatico dos 15 modulos (v3)"
	@echo " make audit        -> matriz de conflitos -> $(OUT_DIR)/conflict_matrix_report.md"
	@echo " make extract      -> payload.bin da Evolution X 11.11 + manifesto SHA-256"
	@echo " make patch-boot   -> patch offline boot.img/init_boot.img + backup stock"
	@echo " make forge        -> [Estagio A] patch Guard-4 + KPM + namespaces DroidSpaces"
	@echo " make bundle       -> modulo All-in-One + Watchdog Anti-Bootloop 120s"
	@echo " make snapshot     -> [M14] branch/tag snapshot + manifesto SHA-256"
	@echo " make runtime-test -> [Estagio B] injecao e soft-reboot via ADB/QEMU"
	@echo " make run-act      -> executa o workflow via nektos/act"
	@echo " make clean        -> limpa artefatos temporarios"
	@echo "======================================================================="

check:
	@echo "[1/4] Verificando sintaxe Bash de todos os scripts..."
	@bash -n install_local.sh
	@for s in scripts/*.sh assets/*.sh; do bash -n "$$s" && echo "  OK: $$s"; done
	@echo "[2/4] Compilando scanners Python (py_compile)..."
	@for p in scripts/*.py; do python3 -m py_compile "$$p" && echo "  OK: $$p"; done
	@echo "[3/4] Validando schemas JSON (safelist + devcontainer)..."
	@python3 -m json.tool references/android16-evox-safelist.json > /dev/null && echo "  OK: references/android16-evox-safelist.json"
	@python3 -m json.tool references/devcontainer.json > /dev/null && echo "  OK: references/devcontainer.json"
	@echo "[4/4] Self-Test do Auditor de Conflitos (cenario limpo)..."
	@mkdir -p "$(MODULES_DIR)" "$(KPM_DIR)" "$(TWEAKS_DIR)" "$(OUT_DIR)"
	@./scripts/audit_rom_conflicts.sh \
		--modules-dir "$(MODULES_DIR)" \
		--kpm-dir "$(KPM_DIR)" \
		--tweaks-dir "$(TWEAKS_DIR)" \
		--extracted-dir "$(EXTRACTED_DIR)" \
		--safelist ./references/android16-evox-safelist.json \
		--report-out "$(OUT_DIR)/conflict_matrix_report.md"

scan:
	@mkdir -p "$(MODULES_DIR)" "$(OUT_DIR)"
	@python3 scripts/static_conflict_scanner.py --modules-dir "$(MODULES_DIR)" --out "$(OUT_DIR)/conflict_report.json" --json | tee "$(OUT_DIR)/static_conflict_scan.json"

test:
	@./tests/test_scanner_rules.sh

test-preflight:
	@./tests/test_preflight_deps.sh

test-rom:
	@./tests/test_extract_rom_assets.sh

test-closure:
	@./tests/test_closure_gate.sh

test-debitos:
	@./tests/test_debt_ledger.sh

test-continuity:
	@./tests/test_continuity_gate.sh

test-fragment:
	@./tests/test_kernel_fragment.sh

test-kernel:
	@./tests/test_kernel_build_gate.sh

test-stage:
	@./tests/test_stage_logic.sh
	@./tests/test_root_engine_gate.sh

test-guarantee:
	@./tests/test_success_guarantee.sh
	@./tests/test_legacy_scope.sh

test-droidspaces:
	@./tests/test_root_decision.sh
	@./tests/test_root_pair_solver.sh
	@./tests/test_droidspaces_preflight.sh

test-gates:
	@./tests/test_success_guarantee.sh
	@./tests/test_legacy_scope.sh
	@./tests/test_root_decision.sh
	@./tests/test_root_pair_solver.sh
	@./tests/test_droidspaces_preflight.sh
	@./tests/test_kernel_compat_check.sh
	@./tests/test_rollout_gate.sh
	@./tests/test_cache_and_guard4.sh
	@./tests/test_session_open.sh
	@./tests/test_slot_router.sh
	@./tests/test_abl_probe.sh
	@./tests/test_architecture_guard.sh
	@./tests/test_rom_artifact_fetch.sh
	@./tests/test_script_contracts.sh
	@./tests/test_stage_logic.sh
	@./tests/test_root_engine_gate.sh
	@./tests/test_contradiction_scan.sh
	@./tests/test_coverage_matrix.sh
	@./tests/test_audit_loop.sh
	@./tests/test_mutation_check.sh
	@./tests/test_proof_items.sh
	@./tests/test_prove_workflow.sh
	@./tests/test_vacuity_scan.sh
	@./tests/test_kernel_build_gate.sh
	@./tests/test_kernel_fragment.sh
	@./tests/test_continuity_gate.sh
	@./tests/test_closure_gate.sh
	@./tests/test_debt_ledger.sh

mutation:
	@python3 scripts/mutation_check.py --root ../.. --jobs $(JOBS)

vacuity:
	@python3 scripts/test_vacuity_scan.py --root ../..

test-ci:
	@./tests/test_sandbox_rollout.sh
	@./tests/test_ci_workflow_lint.sh

audit:
	@mkdir -p "$(OUT_DIR)"
	@./scripts/audit_rom_conflicts.sh \
		--modules-dir "$(MODULES_DIR)" \
		--kpm-dir "$(KPM_DIR)" \
		--tweaks-dir "$(TWEAKS_DIR)" \
		--extracted-dir "$(EXTRACTED_DIR)" \
		--safelist ./references/android16-evox-safelist.json \
		--report-out "$(OUT_DIR)/conflict_matrix_report.md"

extract:
	@./scripts/extract_evox_base.sh --rom "$(ROM_PATH)" --out "$(EXTRACTED_DIR)"

patch-boot:
	@mkdir -p "$(OUT_DIR)"
	@./scripts/patch_boot_offline.sh \
		--engine "$(ENGINE)" \
		--boot "$(EXTRACTED_DIR)/boot.img" \
		--init-boot "$(EXTRACTED_DIR)/init_boot.img" \
		--kpm-dir "$(KPM_DIR)" \
		--superkey "$(SUPERKEY)" \
		--out "$(OUT_DIR)"

forge:
	@mkdir -p "$(OUT_DIR)"
	@./scripts/forge_patcher.sh "$(ENGINE)" "$(EXTRACTED_DIR)" "$(MODULES_DIR)"

bundle:
	@mkdir -p "$(OUT_DIR)"
	@./scripts/build_safe_module_bundle.sh \
		--name "evox-11-11-camilla-prevalidated" \
		--prop ./assets/evox_tuning_preset.prop \
		--watchdog ./assets/watchdog_anti_bootloop_service.sh \
		--out "$(OUT_DIR)"

snapshot:
	@mkdir -p "$(OUT_DIR)"
	@./scripts/snapshot_branch_manager.sh --layer "$(LAYER)" --tag "$(TAG)" --source "$(SNAPSHOT_SRC)"

runtime-test:
	@./scripts/runtime_module_tester.sh "$(MODULES_DIR)"

run-act:
	@if command -v act >/dev/null 2>&1; then \
		act workflow_dispatch -W references/evox-ci-validator.yml; \
	else \
		echo "nektos/act nao encontrado. Instale o act ou acione a skill act-github-pat."; \
		exit 1; \
	fi

clean:
	@rm -rf ./workspace/out ./workspace/staging
	@echo "Diretorios temporarios limpos. Imagem base preservada."
