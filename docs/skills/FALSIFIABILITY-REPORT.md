# Relatório de falseabilidade — os testes conseguem reprovar?

**Data:** 2026-11-01 · **Pergunta:** existe mascaramento de resultado, isto é, teste que passa
mesmo quando a lógica de negócio some? **Método:** mutação (Red de verdade) + análise estática de vício.

## 1. Como cada teste é cobrado

1. **Mutação (dinâmico).** O harness copia o workspace, injeta **uma** troca real de decisão
   (`references/mutation-catalog.json`) e roda o teste que deveria pegá-la:
   - teste falha com asserção → mutante **morto** (o teste é falseável);
   - teste passa → mutante **vivo** → teste viciado, o harness reprova (`exit 3`);
   - teste **trava** → classificado `timeout`, que **não conta como cobertura** (`--allow-timeout`
     existe, mas fica explícito no relatório quando usado).
2. **Varredura de vício (estático).** `test_vacuity_scan.py` (V1–V6) procura asserção impossível,
   falha engolida (`|| true`), `2>/dev/null || echo 0` em comparação, suíte só-feliz e `sleep`.
3. **Meta-teste.** `test_mutation_check.sh` monta um workspace com teste viciado **e** um teste que
   trava, e exige que o harness reprove os dois — o fiscal também é fiscalizado.
4. **Força declarada.** Cada mutante diz `strength`: `semantic` (mata por comportamento) ou
   `contract` (só o contrato CLI/`--help`). **AG21** exige `strength` válida e **≥2 mutantes
   semânticos por arquivo**.

## 2. Resultado

| Métrica | Valor |
|---|---|
| Mutantes | **123** |
| Mortos por asserção | **123** (score **100%**) |
| Sobreviventes | **0** |
| Mortos só por timeout | **0** |
| Arquivos com mutante | **36** — todos com **≥2 semânticos** |
| Força | 91 `semantic` · 15 `contract` |
| Vícios estruturais (V1–V6) | **0 erros, 0 avisos** em 22 suítes |
| Casos | **482** (427 na skill da ROM · 8 no guardian · 13 de estado · 34 wrappers) |

## 3. Os limites anteriores — como foram **resolvidos**

| Limite declarado antes | O que foi feito agora | Prova |
|---|---|---|
| "1 a 3 mutantes por arquivo, não exaustivo" | catálogo de 47 → **102**; nenhum arquivo abaixo de 2 semânticos; AG21 passa a **reprovar** catálogo magro | `make -s mutation` · AG21 |
| "13 scripts só com contrato CLI" | 8 scripts de estágio ganharam **testes semânticos com fixtures/stubs** (`test_stage_logic.sh`, 54 casos); 7 wrappers de release ganharam `test_wrapper_stages.sh` (34 casos); sobrou **0** script só-contrato entre os cobertos | `make -s test-stage` · `make -s test-wrappers` |
| "morto por timeout ≠ cobertura" | harness passou a classificar `timeout` e **reprovar**; o caso que dependia disso foi reescrito com asserção (`sleep 0` não trava o watchdog) | `test_mutation_check.sh` (8 casos) |

## 4. Mascaramentos que a auditoria **encontrou e corrigiu**

Havia teste verde escondendo lógica não verificada — e, pior, **scripts que se declaravam
concluídos sem fazer nada**. Cada linha abaixo é um defeito real, corrigido no código e travado
por um mutante.

| # | Defeito | Por que passava | Correção |
|---|---|---|---|
| M09 | `abl_probe` colapsava `HANG` e `HANG_EARLY` | o caso só afirmava `exit 4` | passa a afirmar a **classificação** no JSON |
| M10 | `cache get` deixava de comparar sha256 | nenhum caso corrompia o cache | novo caso: cache corrompido → exit 3 |
| M16 | `extract` engolia ausência de `unzip` (`\|\| true`) | só havia teste de `payload-dumper` ausente | `PATH` sem `unzip` → exit 3 |
| M43 | regra R8 do lint virava `lambda t: True` | R8 não tinha caso próprio | mutação sem `sys.boot_completed` → exit 3 **e** violação R8 |
| M46 | gate recusando módulo imprimia e **seguia** | teste olhava só o exit code | exige mensagem `BLOQUEADO` + ledger sem `passed` |
| M48–M50 | `forge_patcher` "concluía" sem `boot.img`, sem `kptools`, e copiava imagem stock como se fosse patch | não havia teste de estágio | exit 3/4/5 explícitos + `cmp` do kernel extraído |
| M51–M53 | `patch_boot_offline` saía **0** sem boot.img e chamava dry-run de sucesso | idem | exit 3 (sem insumo) / 4 (sem ferramenta) / 4 (sem imagem para empacotar) |
| M54–M56 | `extract_evox_base` gerava manifesto **sem** dumper e **inventava** KMI (`gki-2.0-detected`) | nada olhava o conteúdo | exit 3 sem dumper; KMI `unknown` quando não há match; sha256 real por partição |
| M57–M60 | `audit_rom_conflicts` dava **PASS** em KPM não verificado (sem `kptools`) | relatório não era lido nos testes | linha `PENDENTE` + exit 3; Zygisk e `sleep` com casos próprios |
| M61–M63 | `build_safe_module_bundle` gerava bundle **sem** watchdog e sem preset | `if [ -f ]` silencioso | dependências obrigatórias (exit 3) + verificação do conteúdo do zip; `id` do módulo conferido |
| M64–M67 | watchdog podia girar para sempre (`sleep 0`) e não desativar o módulo | nenhum teste executava o script | timeout/sleep por env, guarda de `sleep`, `disable` e `reboot` observados |
| M68–M69 | `runtime_module_tester` aprovava com `FATAL EXCEPTION` | stub devolvia crash mas o padrão não era verificado | stub emula o `grep`; crash → exit 1 |
| M70–M72 | `snapshot_branch_manager` aceitava branch `arena/*`, worktree sujo e `git add -A` | só havia teste de contrato | exit 4 nos dois casos; commit só do manifesto |
| M73–M74 | `session_open` aceitava variante **herdada** como decisão da usuária | nenhum caso cobria `flavor_source` | `check` exige `flavor_source=user`; `auto` **limpa** variante herdada |
| M75–M80 | lint/guard/loop/cobertura/gate/harness com regra desligável | 1 mutante por arquivo | segundo mutante semântico por arquivo |
| M81–M85 | auditor de ZIP **gerava o próprio sha256** e imprimia "Complete" com `updater-script` faltando; Cuttlefish tratava *skip* como sucesso | não havia teste dos wrappers | hash ausente → exit 3; ZIP inválido → exit 1; skip → exit 3 |
| M86–M89 | `extract_rom_assets` ignorava hash esperado; `preflight` omitia dependência; V5 nunca disparava; `persist` sem regra própria | sem caso de regressão | cada um com caso dedicado |
| M90–M102 | `patch-manager` "aplicava patch" sem árvore de kernel; matriz/resolução só testadas por `--help`; `package-anykernel3` apagava o `release/` **antes** de validar e inventava template AK3; `build-kernel-pong` saía 0 sem código | contratos não exercitam lógica | exit 3/1 explícitos, template falso recusado, `set -u` de toolchain corrigido |

## 5. Item a item (arquivo → mutantes → força)

| Arquivo | Mutantes | Semânticos | IDs |
|---|---|---|---|
| `scripts/audit-flashable-zip.sh` | 4 | 3 | M35, M81, M82, M83 |
| `scripts/build-kernel-pong.sh` | 3 | 2 | M36, M99, M100 |
| `scripts/generate-build-matrix.sh` | 3 | 2 | M26, M92, M101 |
| `scripts/package-anykernel3.sh` | 4 | 3 | M37, M96, M97, M98 |
| `scripts/patch-manager.sh` | 3 | 2 | M38, M90, M91 |
| `scripts/resolve-kernel-source.sh` | 3 | 2 | M39, M93, M102 |
| `scripts/state_reset.sh` | 2 | 2 | M41, M94 |
| `scripts/validate-cuttlefish.sh` | 3 | 2 | M40, M84, M85 |
| `skills/android16-root-guardian/scripts/collect_evidence.sh` | 2 | 2 | M42, M95 |
| `skills/evox-rom-ci-optimizer/assets/00_slot_router.sh` | 2 | 2 | M06, M07 |
| `skills/evox-rom-ci-optimizer/assets/watchdog_anti_bootloop_service.sh` | 5 | 4 | M34, M64, M65, M66, M67 |
| `skills/evox-rom-ci-optimizer/scripts/abl_fallback_probe.sh` | 3 | 3 | M08, M09, M25 |
| `skills/evox-rom-ci-optimizer/scripts/architecture_guard.py` | 2 | 2 | M18, M76 |
| `skills/evox-rom-ci-optimizer/scripts/audit_loop.sh` | 2 | 2 | M22, M77 |
| `skills/evox-rom-ci-optimizer/scripts/audit_rom_conflicts.sh` | 5 | 4 | M28, M57, M58, M59, M60 |
| `skills/evox-rom-ci-optimizer/scripts/build_safe_module_bundle.sh` | 4 | 3 | M29, M61, M62, M63 |
| `skills/evox-rom-ci-optimizer/scripts/cache_manager.sh` | 2 | 2 | M10, M11 |
| `skills/evox-rom-ci-optimizer/scripts/ci_workflow_lint.py` | 2 | 2 | M43, M75 |
| `skills/evox-rom-ci-optimizer/scripts/contradiction_scan.py` | 2 | 2 | M19, M20 |
| `skills/evox-rom-ci-optimizer/scripts/coverage_matrix.py` | 2 | 2 | M21, M78 |
| `skills/evox-rom-ci-optimizer/scripts/extract_evox_base.sh` | 4 | 3 | M30, M54, M55, M56 |
| `skills/evox-rom-ci-optimizer/scripts/extract_rom_assets.sh` | 2 | 2 | M16, M86 |
| `skills/evox-rom-ci-optimizer/scripts/forge_patcher.sh` | 4 | 3 | M31, M48, M49, M50 |
| `skills/evox-rom-ci-optimizer/scripts/guard4_verify.sh` | 3 | 3 | M01, M02, M03 |
| `skills/evox-rom-ci-optimizer/scripts/kernel_compat_check.sh` | 2 | 2 | M12, M13 |
| `skills/evox-rom-ci-optimizer/scripts/mutation_check.py` | 2 | 2 | M44, M80 |
| `skills/evox-rom-ci-optimizer/scripts/patch_boot_offline.sh` | 4 | 3 | M32, M51, M52, M53 |
| `skills/evox-rom-ci-optimizer/scripts/preflight_deps.sh` | 2 | 2 | M45, M87 |
| `skills/evox-rom-ci-optimizer/scripts/rollout_gate.sh` | 2 | 2 | M04, M05 |
| `skills/evox-rom-ci-optimizer/scripts/rom_artifact_fetch.sh` | 2 | 2 | M23, M24 |
| `skills/evox-rom-ci-optimizer/scripts/runtime_module_tester.sh` | 3 | 2 | M33, M68, M69 |
| `skills/evox-rom-ci-optimizer/scripts/sandbox_rollout.sh` | 2 | 2 | M46, M79 |
| `skills/evox-rom-ci-optimizer/scripts/session_open.py` | 4 | 4 | M14, M15, M73, M74 |
| `skills/evox-rom-ci-optimizer/scripts/snapshot_branch_manager.sh` | 4 | 3 | M27, M70, M71, M72 |
| `skills/evox-rom-ci-optimizer/scripts/static_conflict_scanner.py` | 2 | 2 | M17, M89 |
| `skills/evox-rom-ci-optimizer/scripts/test_vacuity_scan.py` | 2 | 2 | M47, M88 |

## 6. Cobertura do workspace

- `coverage_matrix.py`: **40 scripts** → testados ou isentos com motivo declarado
  (`references/audit-exemptions.json`), **0 lacunas**.
- `architecture_guard.py` **AG19** impede script testado sem mutante, **AG20** impede vício V1–V6 e
  **AG21** impede catálogo magro (`strength` + ≥2 semânticos por arquivo).
- Todo o restante (docs, workflows, catálogos) é coberto por `contradiction_scan.py` (C1–C13) e
  pelos testes de contrato/lint.

## 7. Limites que permanecem (honestos, pequenos e nomeados)

1. **Não é mutação exaustiva** (isso exigiria centenas de mutantes por arquivo). O critério é
   decisão de negócio + recusa de insumo: cada arquivo tem 2–4 mutantes semânticos.
2. **`build-kernel-pong.sh` não compila** dentro do sandbox (sem clang/bazel): os mutantes cobrem
   recusa e identidade, não o produto do build. A compilação é provada no runner, não aqui.
3. Ferramentas reais (`kptools`, `magiskboot`, `payload-dumper-go`, `adb`) são **stubs** nos testes:
   provam a decisão (falha/pendência), não a binária de terceiros.

## 8. Reprodução

```bash
make -s mutation     # 123 mutantes, 0 vivo, 0 timeout
make -s vacuity      # V1–V6: 0 erro, 0 aviso (22 suítes)
make -s test-stage   # 54 casos de lógica de estágio (stubs, sem device)
make -s test-wrappers# 34 casos dos wrappers de release
make -s audit-loop   # AG1–AG21 + C + cobertura + vacuidade + suítes, em loop até convergir
```
