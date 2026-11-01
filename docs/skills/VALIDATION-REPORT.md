# Relatório de validação — worktree `arena/863582fd-nothing-phone2-recovery`

**Data:** 2026-11-01 · **Escopo:** confirmar, arquivo por arquivo, que as correções da arquitetura
ratificada estão **aplicadas neste worktree** e que nenhuma instrução ativa ainda manda fazer o que
foi abandonado.

Complementos: [`ARCHITECTURE-DECISION.md`](ARCHITECTURE-DECISION.md) (contrato) ·
[`PENDING-DECISIONS.md`](PENDING-DECISIONS.md) (o que falta decidir).

---

## 1. Resultado global

| Verificação | Comando | Resultado |
|---|---|---|
| Trava de arquitetura | `make -s arch` | **AG1–AG20 OK** (0 violações) |
| Auto-teste da trava | `architecture_guard.py --self-test` | 10 violações simuladas detectadas |
| Sintaxe de shell | `bash -n` em **35** scripts | OK |
| Compilação Python | `py_compile` em **6** módulos | OK |
| Harness das 8 skills | `make -s skills` | `[harness] OK (0 falhas)` |
| Avaliação | `make -s prove` | `[eval] APROVADO (0 abaixo do limite)` · **exit 0** |

## 2. Suítes (todas verdes, contagem por arquivo)

| Suíte | PASS | Suíte | PASS |
|---|---|---|---|
| `test_state_reset.sh` | 13 | `test_session_open.sh` | 15 |
| `test_scanner_rules.sh` | 13 | `test_slot_router.sh` | 13 |
| `test_preflight_deps.sh` | 8 | `test_abl_probe.sh` | **12** (novo) |
| `test_extract_rom_assets.sh` | 15 | `test_architecture_guard.sh` | 6 |
| `test_rom_artifact_fetch.sh` | 18 |
| `test_script_contracts.sh` | **55** (novo) |
| `test_contradiction_scan.sh` | **7** (novo) |
| `test_coverage_matrix.sh` | **6** (novo) |
| `test_audit_loop.sh` | **5** (novo) |
| `test_mutation_check.sh` | **5** (novo) |
| `test_vacuity_scan.sh` | **5** (novo) |
| `test_kernel_compat_check.sh` | 10 | `test_sandbox_rollout.sh` | 9 |
| `test_rollout_gate.sh` | 13 | `test_ci_workflow_lint.sh` | 15 |
| `test_cache_and_guard4.sh` | **20** | `test_collect_evidence.sh` (guardian) | 8 |

**Total executado por `make -s prove`: 271 casos** (258 na skill de ROM + 13 de estado), 0 falhas.
Falseabilidade: `make mutation` → **47/47 mortos, 0 sobreviventes** · `make vacuity` → 0 erro, 0 aviso
(ver `FALSIFIABILITY-REPORT.md`).
Loop de convergência: `audit_loop.sh` → `guard=0 scan=0 cov=0 tests=0` em 2 iterações.

## 3. Arquivo por arquivo (o que foi corrigido e como está provado)

| Arquivo | Correção aplicada | Prova |
|---|---|---|
| `skills/evox-rom-ci-optimizer/assets/00_slot_router.sh` | quarentena por marcador, **marcas de boot** (`marks/<slot>_<n>.mark` com `uptime`), lock, 20 marcas, sem `mount`/`rm -rf` | `test_slot_router.sh` 13 PASS · AG3/AG10 |
| `…/scripts/abl_fallback_probe.sh` | classifica `OK`/`ABL_FALLBACK`/`HANG`/`HANG_EARLY`/`BOOTLOADER`/`NO_DEVICE`, coleta pstore/dmesg/logcat, `--rollback` | `test_abl_probe.sh` 12 PASS · AG4 |
| `…/scripts/architecture_guard.py` | trava AG1–AG20 sobre o repositório | `test_architecture_guard.sh` 6 PASS · `make arch` |
| `…/scripts/rom_artifact_fetch.sh` | coleta determinística das duas variantes: pin sha256, atômico, retomável, drift exit 4, env absoluto | `test_rom_artifact_fetch.sh` 18 PASS · AG16 |
| `…/references/rom-artifacts.json` | manifesto pinado (Vanilla + GApps, build 2026-09-15), URLs com `/download` | AG16 |
| `…/scripts/session_open.py` | novo `auto` preenche P10–P14 (`decided_by: agent-context`) e mantém P1/P2/P3 bloqueantes | `test_session_open.sh` 15 PASS |
| `workflows-local/pong-ab-hil.yml` | quarentena → gate de slot → ledger `passed` → `promote`; `bootctl` removido, agora exige `sys.boot_completed=1` **e** slot esperado | AG2/AG14 · `test_ci_workflow_lint.sh` 15 PASS |
| `…/references/evox-ci-validator.yml` | AVD API 36, cache por sha256, timeouts, sem `fastboot flash` | AG1 · lint R00–R13 |
| `…/references/archive/evox-ci-pipeline.yml` | pipeline antigo movido para `archive/` com cabeçalho SUPERSEDIDO; refs atualizadas (SKILL, Makefile, `install_local.sh`, `ci-cost-locks.md`) | AG15 |
| `…/scripts/runtime_module_tester.sh` | “QEMU/KVM” → “AVD (API 36)”, declara que não prova boot do pong | grep sem “QEMU/KVM” |
| `.github/workflows/boot-test.yml` | guia gerado marcado **LEGADO/SUPERSEDIDO**; passo 5 e rollback apontam para o HIL A/B | AG13 (nenhum `run: fastboot`) |
| `AGENTS.md` | “estágio B (QEMU/KVM)” → “AVD como pré-gate” | AG7 · §1 |
| `agente.md`, `skills/README.md` | mesma correção de premissa | grep sem “QEMU/KVM” |
| `skills/BOOT.md` | abertura passa a exigir `make -s arch` + leitura do ADR | inspeção |
| `skills/evox-rom-ci-optimizer/SKILL.md` | índice com os 2 scripts e 2 suítes novos; `modules_stable` marcado inexistente | AG5/AG9 |
| `Makefile` (raiz + skill) | `arch` dentro de `prove`; `test-gates` roda slot/probe/guard | AG12 |

## 4. Varredura de instruções obsoletas

Termos procurados em `skills/`, `docs/`, `AGENTS.md`, `agente.md`, `workflows-local/`, `.github/`:
`modules_stable`, `mount --bind`, `cp -rn`, `bootctl mark`, `staging_b`, `127.0.0.1`, `QEMU/KVM`.

| Termo | Ocorrências restantes | Situação |
|---|---|---|
| `mount --bind` | só em **avisos** (“nunca faça”) no router, SKILL e AGENTS | correto · AG10 |
| `modules_stable` | só no índice do SKILL como “inexistente” | correto · AG9 |
| `bootctl mark` | zero em workflow (só no ADR como item abandonado) | eliminado · AG14 |
| `cp -rn` | zero | eliminado |
| `staging_b` | só no ADR/review como item abandonado | eliminado |
| `127.0.0.1` | só em fixture de teste (`test_scanner_rules.sh`) | ok |
| `QEMU/KVM` | zero em AGENTS/agente/README/BOOT | corrigido |

## 5. Limites desta validação (declarados, não “simulados”)

1. **Sem egress** para `cdn.evolution-x.org` → o `.zip` real não foi baixado nem verificado.
2. **Sem binários** `payload-dumper-go`/`magiskboot`/`kptools`/`adb`/`go` no sandbox → L4 e patch
   offline só foram exercitados com fixtures; `extract_rom_assets.sh` continua saindo **3** quando falta binário.
3. **Nenhum device USB** aqui → `abl_fallback_probe.sh` foi validado com stubs de `adb`/`fastboot`.
   O comportamento real do ABL do Pong só se confirma no HIL local.
4. **`support_level` do Pong** (nível de suporte da build) segue como suposição até a confirmação
   na página oficial — está marcado como tal nos documentos.

## 6. Reprodução

```bash
make -s prove
python3 skills/evox-rom-ci-optimizer/scripts/architecture_guard.py --self-test
python3 skills/evox-rom-ci-optimizer/scripts/session_open.py check --file workspace/decision.json --json
```
