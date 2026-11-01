# Inventário & Avaliação — Skill Stack (Google Drive `SKILLS/`)

**Data:** 2026-11-01 (atualizado após exclusões + consolidação)
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
| `github.zip` | `178UdD2zvCLisG4VXzkgp-9vIJddJfIP8` | `github/` | ativo |
| `apex-talent-broker.zip` | `19bSWiLyKRj8pWu7VjMwZbsxRCSNFtELz` | — | **excluído** (fora do projeto) |
| `apex-talent-broker - 1.zip`, 2ª cópia do evox | `1VUwEFXYGEWgGl5_47bgwLvh4kLv5Ds4y`, `1lkDovb6StT3nSJRAEOf1a5P3Ly-6A1EH` | — | duplicatas |

---

## 2. Estrutura completa (estado atual)

```text
skills/                                          5 skills ativas · 13 arquivos de contrato
├── BOOT.md                     contrato de inicialização (ordem de carga + invariantes)
├── README.md                   índice, hierarquia de verdade, harness
├── Makefile                    validate · test · check-core · check-all · registry · tree
├── registry.json               machine-readable: tier, gatilhos, deps, entrypoints, excluídas
├── tools/
│   └── validate_skills.py      11 checagens de contrato do harness
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
│   │   ├── android16-evox-safelist.json · devcontainer.json · evox-ci-pipeline.yml
│   │   └── archive/evox-ci-v2.0-SKILL.md · archive/evox-ci-v2.0-canonical-drive-export.md
│   ├── scripts/
│   │   ├── audit_rom_conflicts.sh · extract_evox_base.sh · patch_boot_offline.sh
│   │   ├── build_safe_module_bundle.sh · forge_patcher.sh
│   │   ├── static_conflict_scanner.py (R00..R09) · snapshot_branch_manager.sh
│   │   └── runtime_module_tester.sh
│   └── tests/
│       └── test_scanner_rules.sh  13 cenários sintéticos, exit code contratual
├── android16-root-guardian/SKILL.md
├── agent-governance-orchestrator/SKILL.md
├── act-github-pat/SKILL.md
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
| **android16-root-guardian** | doutrina Safe-First forte (Two-Man Rule, KMI, OTA A/B, rollback) | 100 % texto, sem coletor de telemetria | pós-flash, bootloop, OTA, troca de engine |
| **agent-governance-orchestrator** | amarra as demais: 5W1H, Ownership Ledger, wave DAG, 8 gates | não executa; sem script de ledger | orquestrar 2+ skills, arbitrar escrita |
| **act-github-pat** | resolve 403 rate-limit com matriz Classic vs Fine-Grained sem hardcode | exige `gh` autenticado; não cobre OIDC efêmero | rodar workflow local, PAT, GHCR |
| **github** | 6 references + 3 scripts de coleta JSON (não inflam contexto) | exige `gh`; merge/approve exigem confirmação | PR, issue, triage, Copilot, CI |

---

## 5. Qualidades incrementadas (delta acumulado)

1. **Evidência antes de opinião** — `sys.boot_completed=1`, hash ou JSON; `PASS` autodeclarado não vale.
2. **Reversibilidade determinística** — Guard-4 grava `boot_stock_rollback.img` + `.sha256` antes do kernel.
3. **Gêmeo digital antes do hardware** — Estágio B obrigatório no QEMU/KVM.
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
| Contrato do harness | `make -C skills validate` | `OK` (5 skills, 0 falhas) |
| Sintaxe/compilação/JSON/auditor | `make -C skills check-core` | `OK` |
| Regressão das 9 regras | `make -C skills test` | **13 PASS / 0 FAIL** |
| Cenário negativo manual | 2 módulos em `audio_effects.xml` | `CONFLICT` exit 1 + veto |
| Snapshot/estado | `snapshot_branch_manager.sh` | `[OK] Snapshot registrado` |
| Segredos / links / nome↔dir | `tools/validate_skills.py` | 0 violações |

> Nenhum `push`, PR, workflow ou secret foi tocado. Tudo local.

---

## 7. Gaps e próximo passo

Ver [`HANDOFF-BRIEF.md`](HANDOFF-BRIEF.md): 6 lacunas (L1–L6) e as duas frentes prontas —
(1) parametrizar kernel/KMI + device profile do `pong`; (2) `bootstrap_github_repo.sh`
(**não executar** até liberação).
