# Inventário & Avaliação — Skill Stack (Google Drive `SKILLS/`)

**Data:** 2026-11-01 (atualizado após exclusões + consolidação + 4º lote do Drive)
**Escopo:** instalação local a partir do Google Drive; **GitHub não utilizado**
**Destino:** `skills/` no repo `nothing-phone2-recovery`, branch `arena/863582fd-nothing-phone2-recovery`
**Origem:** pasta Drive `SKILLS` (ID `105yOkonl1tVXJZceY_zZslQXHa6VarjO`)

---

## 1. Proveniência

| Item no Drive | ID | Destino local | Situação |
|---|---|---|---|
| `evox-rom-ci-optimizer.zip` (v3.0, spec) | `1AERBRL3F2uGyYHvxtRFF9BTY0qRCFLyO` | corpo do `SKILL.md` v3.2 | ativo |
| `evox-rom-ci-optimizer/` (v2.0, diretório) | `159t6guozDs2cKN-Lb46bgEwurulLKW6B` | `scripts/`, `references/`, `assets/`, `Makefile` | ativo |
| `evox-rom-ci-optimizer-v2.0-full.zip` | `1dPTanP6heM83UQhbiMPzZMTM-Lp7DTPz` | `references/archive/evox-ci-v2.0-SKILL.md` | arquivado |
| `evox-pong-ci-architect.zip` | `13bpv4GPzmxHJW__ySLe6BjDbck1TMlOk` | `references/pong-hardware-matrix.md` | **absorvido** |
| `android16-root-guardian.zip` | `1DU5sOJeICqADMzNiPxL3rLCju5qImLZj` | `android16-root-guardian/` | ativo |
| `agent-governance-orchestrator.zip` | `1q3ZWzukbxf5xb735DlKtXmxBRBFJr3hB` | `agent-governance-orchestrator/` | ativo |
| `act-github-pat.zip` | `1Dcho4pvAFc2lBNe_NVKFq6JmYPyXAzYL` | `act-github-pat/` | ativo |
| `github.zip` (reupload 17:12) | `1JxKS4uahidXc_X1GcDjVCocXKCZo5sgP` | `github/` | **deduplicado** — `diff -r` idêntico ao instalado (`sha256 32a4cd01…43ed5`) |
| `fabrica-de-agentes.zip` (77 KB) | `1ek_VfaVmTsT4GdSJyj84IGNsMV6-erVp` | `fabrica-de-agentes/` | ativo — dividido (SKILL 49 KB + 3 references) |
| `cogni-synapse.zip` (33 KB) | `1DCDb-Be2erOc-ociykA6v26U8fLWm1I5` | `cogni-synapse/` | ativo |
| `sci-scientific-mindset.zip` (4,5 KB) | `1aVUqv3rLSjAsorbul8BYv40j3moVhfuJ` | `sci-scientific-mindset/` | ativo |
| `apex-talent-broker.zip` | `19bSWiLyKRj8pWu7VjMwZbsxRCSNFtELz` | — | **excluído** (fora do projeto) |
| `apex-talent-broker - 1.zip`, 2ª cópia do evox | `1VUwEFXYGEWgGl5_47bgwLvh4kLv5Ds4y`, `1lkDovb6StT3nSJRAEOf1a5P3Ly-6A1EH` | — | duplicatas |

---

## 2. Estrutura completa (estado atual)

```text
skills/                                          8 skills ativas · 8 contratos SKILL.md
├── BOOT.md                     contrato de inicialização (ordem de carga + invariantes)
├── README.md                   índice, hierarquia de verdade, harness
├── Makefile                    validate · eval · test-all · check-core · check-all · registry · tree
├── registry.json               machine-readable: tier, classe, gatilhos, deps, entrypoints, excluídas
├── tools/
│   ├── validate_skills.py      11 checagens de contrato do harness
│   └── eval_skills.py          7 eixos falseáveis (E1..E7), limite por classe+tier
├── evox-rom-ci-optimizer/      ★ v3.2
│   ├── SKILL.md                spec v3 + backend v2 + regra de precedência instrução>repo
│   ├── Makefile                check·test·scan·audit·extract·patch-boot·forge·bundle·snapshot·runtime-test·run-act
│   ├── install_local.sh        instalador idempotente (Linux/Termux) + CLI evox-ci
│   ├── assets/
│   │   ├── evox_tuning_preset.prop
│   │   └── watchdog_anti_bootloop_service.sh
│   ├── references/
│   │   ├── module-matrix-5w1h.md            ← A INSTRUÇÃO (15 módulos, Classes 1–6, 5W1H)
│   │   ├── external-engines-arbitration.md  ← regras R01..R09 + 3 interseções
│   │   ├── pong-hardware-matrix.md          ← ex-evolution: evox-pong-ci-architect
│   │   ├── ci-cost-locks.md                 ← 4 travas de custo
│   │   ├── android16-evox-safelist.json · devcontainer.json · evox-ci-validator.yml (+ archive/evox-ci-pipeline.yml)
│   │   └── archive/evox-ci-v2.0-SKILL.md · archive/evox-ci-v2.0-canonical-drive-export.md
│   ├── scripts/
│   │   ├── audit_rom_conflicts.sh · extract_evox_base.sh · patch_boot_offline.sh
│   │   ├── build_safe_module_bundle.sh · forge_patcher.sh
│   │   ├── static_conflict_scanner.py (R00..R09) · snapshot_branch_manager.sh
│   │   └── runtime_module_tester.sh
│   ├── scripts/preflight_deps.sh  catálogo de 13 binários (--json/--require/--hints)
│   ├── scripts/extract_rom_assets.sh  L4 pelo .zip oficial (payload → hashes+kernel)
│   └── tests/
│       ├── test_scanner_rules.sh  13 cenários sintéticos, exit code contratual
│       ├── test_preflight_deps.sh 8 cenários com PATH mínimo + stubs
│       └── test_extract_rom_assets.sh 15 cenários (stub de payload-dumper-go)
├── android16-root-guardian/    ★ v2.1
│   ├── SKILL.md · Makefile
│   ├── scripts/collect_evidence.sh   evidence.json + MANIFEST.sha256 (exit 0/3/4)
│   └── tests/test_collect_evidence.sh 8 cenários com stub de adb
├── fabrica-de-agentes/         (meta) SKILL.md + references/{geracao-em-9-fases,
│                               multiagente-handoff-e-template,validacao-12-testes-e-erros-fatais}.md
├── sci-scientific-mindset/     (meta) crivo epistêmico — virou a base do eval
├── cogni-synapse/              (support) camada de saída (BLUF, vetor semiótico)
├── agent-governance-orchestrator/ (meta)
├── act-github-pat/             (support)
└── github/  SKILL.md · references/ (6) · scripts/ (3)
```

Atalho de descoberta: `.claude/skills -> ../skills` (o `.claude/` é gitignored).

---

## 3. Fusão `evox-rom-ci-optimizer`: v3.0 ⊕ v2.0 → v3.2

| Eixo | v2.0 | v3.0 | **v3.2** |
|---|---|---|---|
| Sub-agentes | 3 | 4 (+ SNAPSHOT-KEEPER) | 4, cada um com backend executável |
| Escopo | módulos genéricos | M01–M15 / 5 ondas | + matriz 5W1H rastreável (instrução) |
| Scripts | 4 | 0 | **8** |
| Regras do scanner | — | 2 parciais | **9 (R00–R09)** + status CLEAN/WARN/CONFLICT |
| Testes | — | — | **13 cenários** com exit code contratual |
| Estado | backup ad-hoc | `snapshot/<camada>/<tag>` | `snapshot_branch_manager.sh` + manifesto |
| Custo CI | `timeout-minutes` | trava dupla | trava quádrupla versionada |
| Hardware | genérico | genérico | matriz `pong` absorvida (fim da duplicidade) |

---

## 4. Avaliação por skill

| Skill | Força objetiva | Limite observado | Acionar quando |
|---|---|---|---|
| **evox-rom-ci-optimizer v3.2** | única com execução real e **teste de regressão**; 9 regras de arbitragem cobrem persist, priv-app, SELinux, MaxManager, Duck-ToolBox, GenieX, DroidSpaces; instrução separada do código com precedência declarada | depende de binários externos (`payload-dumper-go`, `kptools`, `magiskboot`, `adb`, `act`); emulador não reproduz sensor físico/TEE; sem eval de acurácia histórica | qualquer mutação de ROM/kernel/módulo antes do USB |
| **android16-root-guardian v2.1** | doutrina Safe-First forte (Two-Man Rule, KMI, OTA A/B, rollback) + **coletor de evidência** com manifesto SHA-256 | coleta depende de `adb`/root; não decide SoT sozinho | pós-flash, bootloop, OTA, troca de engine |
| **agent-governance-orchestrator** | amarra as demais: 5W1H, Ownership Ledger, wave DAG, 8 gates | não executa; sem script de ledger | orquestrar 2+ skills, arbitrar escrita |
| **act-github-pat** | resolve 403 rate-limit com matriz Classic vs Fine-Grained sem hardcode | exige `gh` autenticado; não cobre OIDC efêmero | rodar workflow local, PAT, GHCR |
| **github** | 6 references + 3 scripts de coleta JSON (não inflam contexto) | exige `gh`; merge/approve exigem confirmação | PR, issue, triage, Copilot, CI |
| **fabrica-de-agentes v2.0** | ciclo completo de criação de skill: 9 fases, 12 testes, handoff multiagente, economia de contexto | doutrina pura: não executa o ciclo, descreve o contrato | criar/revisar skill, dividir skill grande, definir handoff |
| **sci-scientific-mindset** | crivo epistêmico: hipótese falseável, contra-argumento, contrafactual, custo da crença errada | genérica por design; precisa de domínio para virar ação | validar premissa, decidir sob incerteza, revisar conclusão |
| **cogni-synapse** | camada de saída: BLUF, escolha de vetor (texto/matriz/checklist), densidade sem perda | não acrescenta verificação factual | empacotar entrega executiva, reduzir 20 páginas a 1 |

---

## 5. Qualidades incrementadas (delta acumulado)

1. **Evidência antes de opinião** — `sys.boot_completed=1`, hash ou JSON; `PASS` autodeclarado não vale.
2. **Reversibilidade determinística** — Guard-4 grava `boot_stock_rollback.img` + `.sha256` antes do kernel.
3. **Gêmeo digital antes do hardware** — Estágio B obrigatório em AVD (API 36).
4. **Governança de topologia** — Ownership Ledger + ondas eliminam dois escritores no mesmo alvo.
5. **Disciplina de custo** — 4 travas (concurrency, 25 min job, 10 min QEMU, poweroff 1800 s).
6. **Estado versionado** — snapshot por camada com manifesto SHA-256.
7. **Execução, não descrição** — 8 scripts, 12 alvos de `make`, exit codes vetoriais.
8. **Instrução é artefato de primeira classe** — `module-matrix-5w1h.md` com precedência sobre o repo.
9. **Arbitragem de plataformas externas** — R01–R09 codificam MaxManager/Duck-ToolBox/GenieX/DroidSpaces.
10. **Regressão de regra** — 13 cenários provam que cada gate dispara; gate sem teste é opinião.
11. **Anti-alucinação de ferramenta** — binário ausente gera erro explícito.
12. **Harness auto-validável** — `validate_skills.py` impede skill sem front matter, link quebrado,
    caminho inexistente, segredo exposto ou fora do registry.
13. **Proveniência preservada** — doc canônico v2.0 arquivado; nada foi reescrito em silêncio.
14. **Escopo honesto** — `apex-talent-broker` fora do projeto; `evox-pong-ci-architect` deixou de
    competir como segunda fonte de verdade.

---

## 6. Evidência de validação (2026-11-01)

| Verificação | Comando | Resultado |
|---|---|---|
| Contrato do harness | `make -C skills validate` | `OK` (**8 skills**, 0 falhas) |
| Qualidade (7 eixos) | `make -C skills eval` | **APROVADO** — 8/8 acima do limite da classe |
| Sintaxe/compilação/JSON/auditor | `make -C skills check-core` | `OK` |
| Regressão das 9 regras | `make -C skills test-core` | **13 PASS / 0 FAIL** |
| Preflight de dependências | `make -C skills test-core` | **8 PASS / 0 FAIL** |
| Coletor de evidência (stub de adb) | `make -C skills test-guard` | **8 PASS / 0 FAIL** |
| Gate kernel × ROM × device | `test_kernel_compat_check.sh` | **10 PASS / 0 FAIL** |
| Rollout canário (1 módulo/vez) | `test_rollout_gate.sh` | **13 PASS / 0 FAIL** |
| Cache versionado + rollback (Guard-4, inclui par de `init_boot`) | `test_cache_and_guard4.sh` | **20 PASS / 0 FAIL** |
| Stage B (injeção via adb) | `test_sandbox_rollout.sh` | **9 PASS / 0 FAIL** |
| Travas de custo do workflow | `test_ci_workflow_lint.sh` | **12 PASS / 0 FAIL** |
| Protocolo de abertura (P1–P8) | `test_session_open.sh` | **10 PASS / 0 FAIL** |
| Roteador A/B (HIL) | `test_slot_router.sh` | **13 PASS / 0 FAIL** |
| Cenário negativo manual | 2 módulos em `audio_effects.xml` | `CONFLICT` exit 1 + veto |
| Snapshot/estado | `snapshot_branch_manager.sh` | `[OK] Snapshot registrado` |
| Segredos / links / nome↔dir | `tools/validate_skills.py` | 0 violações |

> Nenhum `push`, PR, workflow ou secret foi tocado. Tudo local.

---

## 7. Gaps e próximo passo

Ver [`HANDOFF-BRIEF.md`](HANDOFF-BRIEF.md): 6 lacunas (L1–L6) e as duas frentes prontas —
(1) parametrizar kernel/KMI + device profile do `pong`; (2) `bootstrap_github_repo.sh`
(**não executar** até liberação).

### 6.1 Notas do `eval_skills.py` (2026-11-01)

| Skill | Classe | Tier | Nota | Limite |
|---|---|---|---|---|
| evox-rom-ci-optimizer | executable | core | **100** | 70 |
| cogni-synapse | doctrine | support | 81 | 45 |
| android16-root-guardian | executable | core | 83 | 70 |
| agent-governance-orchestrator | doctrine | meta | 75 | 50 |
| fabrica-de-agentes | doctrine | meta | 75 | 50 |
| sci-scientific-mindset | doctrine | meta | 63 | 50 |
| github | executable | support | 58 | 55 |
| act-github-pat | doctrine | support | 57 | 45 |

Eixos: **E1** evidência · **E2** reversibilidade · **E3** testabilidade · **E4** custo ·
**E5** handoff · **E6** executabilidade · **E7** falseabilidade.

O eixo **E6** só pontua skills de classe `executable`: penalizar doutrina por não ter `scripts/`
mediria a categoria, não a qualidade — foi o erro da primeira calibração, corrigido e registrado.

---

## 7. Débitos (L1–L6)

| # | Débito | Estado | Artefato |
|---|---|---|---|
| L1 | `fabrica-de-agentes` citada e ausente | **fechada** | skill v2.0.0 instalada e fatiada |
| L2 | guardian sem scripts | **fechada** | `collect_evidence.sh` + `8 PASS` |
| L3 | binários externos não verificados | **fechada** | `preflight_deps.sh` + `8 PASS` |
| L4 | kernel/hashes da build | **pronta, aguarda o .zip** | `extract_rom_assets.sh` + 15 PASS (fonte = pacote oficial) |
| L5 | sem eval das skills | **fechada** | `eval_skills.py` → APROVADO |
| L6 | `docs/` legado divergente | **fechada** | `docs/skills/LEGACY-INDEX.md` |
