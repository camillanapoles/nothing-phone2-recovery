# Inventário & Avaliação — Skill Stack (Google Drive `SKILLS/`)

**Data:** 2026-11-01 · **Escopo:** instalação local a partir do Google Drive (GitHub intocado)
**Destino:** `skills/` (repo `nothing-phone2-recovery`, branch `arena/863582fd-nothing-phone2-recovery`)
**Origem:** pasta Drive `SKILLS` (ID `105yOkonl1tVXJZceY_zZslQXHa6VarjO`) — 8 zips + 1 skill em diretório

---

## 1. Proveniência e deduplicação

| Item no Drive | ID | Bytes | Destino local |
|---|---|---|---|
| `evox-rom-ci-optimizer.zip` (**v3.0**, spec) | `1AERBRL3F2uGyYHvxtRFF9BTY0qRCFLyO` | 2.964 | corpo do `SKILL.md` v3.1 |
| `evox-rom-ci-optimizer/` (**v2.0**, diretório) | `159t6guozDs2cKN-Lb46bgEwurulLKW6B` | ~52 KB | `scripts/`, `references/`, `assets/`, `Makefile`, `install_local.sh`, doc canônico em `references/archive/` |
| `evox-rom-ci-optimizer-v2.0-full.zip` | `1dPTanP6heM83UQhbiMPzZMTM-Lp7DTPz` | 11.891 | `references/archive/evox-ci-v2.0-SKILL.md` |
| `evox-pong-ci-architect.zip` | `13bpv4GPzmxHJW__ySLe6BjDbck1TMlOk` | 3.612 | `evox-pong-ci-architect/` |
| `android16-root-guardian.zip` | `1DU5sOJeICqADMzNiPxL3rLCju5qImLZj` | 7.003 | `android16-root-guardian/` |
| `agent-governance-orchestrator.zip` | `1q3ZWzukbxf5xb735DlKtXmxBRBFJr3hB` | 4.087 | `agent-governance-orchestrator/` |
| `act-github-pat.zip` | `1Dcho4pvAFc2lBNe_NVKFq6JmYPyXAzYL` | 2.216 | `act-github-pat/` |
| `github.zip` | `178UdD2zvCLisG4VXzkgp-9vIJddJfIP8` | 13.898 | `github/` |
| `apex-talent-broker.zip` | `19bSWiLyKRj8pWu7VjMwZbsxRCSNFtELz` | 15.691 | `apex-talent-broker/` |
| ~~`apex-talent-broker - 1.zip`~~ | `1VUwEFXYGEWgGl5_47bgwLvh4kLv5Ds4y` | 15.691 | descartado — byte-idêntico em tamanho ao original (duplicata) |
| ~~2ª cópia `evox-rom-ci-optimizer.zip`~~ | `1lkDovb6StT3nSJRAEOf1a5P3Ly-6A1EH` | 2.964 | descartado — duplicata |

> Não há mais nada acionável na pasta `SKILLS` além de `eftalyurtseven_skills.git` e
> `Banco de Prompts` (repositório e base de prompts, não skills empacotadas).

---

## 2. Estrutura de diretório completa (instalada)

```text
skills/
├── README.md  (3474 B)                            # índice + regra de composição v2/v3
├── act-github-pat/
│   └── SKILL.md  (4865 B)                         # PAT Classic/Fine-Grained + nektos/act
├── agent-governance-orchestrator/
│   └── SKILL.md  (8946 B)                         # DAG-SoC, Ownership Ledger, Guard-4, 5W1H
├── android16-root-guardian/
│   └── SKILL.md  (16540 B)                        # pós-flash Safe-First: KMI, APatch/KSU/Magisk, OTA A/B
├── apex-talent-broker/
│   ├── SKILL.md  (22313 B)                        # arbitragem de oportunidades (EHV/SLI)
│   ├── references/
│   │   └── playbooks-and-pitches.md  (6077 B)
│   └── scripts/
│       └── opportunity_harvester.py  (7080 B)
├── evox-pong-ci-architect/
│   └── SKILL.md  (8153 B)                         # CI/arquitetura dos 12 componentes no `pong`
├── evox-rom-ci-optimizer/                         # ★ skill completa v3.1 (v2 ⊕ v3)
│   ├── SKILL.md  (12179 B)                        # spec v3.0 + catálogo/recursos v2.0 fundidos
│   ├── Makefile  (4708 B)                         # check·scan·audit·extract·patch-boot·forge·bundle·snapshot·runtime-test·run-act
│   ├── install_local.sh  (3708 B)                 # instalador idempotente Linux/Termux + CLI `evox-ci`
│   ├── assets/
│   │   ├── evox_tuning_preset.prop  (783 B)
│   │   └── watchdog_anti_bootloop_service.sh  (1313 B)
│   ├── references/
│   │   ├── android16-evox-safelist.json  (1170 B) # whitelist RescueParty
│   │   ├── devcontainer.json  (274 B)             # trava de custo/idle em Codespaces
│   │   ├── evox-ci-pipeline.yml  (7669 B)         # workflow GH Actions (KVM API 36)
│   │   └── archive/
│   │       ├── evox-ci-v2.0-SKILL.md  (3258 B)    # v2.0 empacotado
│   │       └── evox-ci-v2.0-canonical-drive-export.md  (33119 B)  # doc canônico v2.0
│   └── scripts/
│       ├── audit_rom_conflicts.sh  (6747 B)       # CONFLICT-INQUISITOR (inode/Zygisk/KMI/RescueParty)
│       ├── extract_evox_base.sh  (3443 B)         # payload.bin + manifesto SHA-256 + kallsyms
│       ├── patch_boot_offline.sh  (4250 B)        # APatch/KSU/Magisk + rollback stock
│       ├── build_safe_module_bundle.sh  (2336 B)  # All-in-One + watchdog 120 s
│       ├── static_conflict_scanner.py  (3437 B)   # v3: scanner de 15 módulos (JSON/exit code)
│       ├── snapshot_branch_manager.sh  (1959 B)   # v3: SNAPSHOT-KEEPER (branch/tag + manifesto)
│       ├── runtime_module_tester.sh  (2071 B)     # v3: Estágio B via ADB/QEMU (soft-reboot)
│       └── forge_patcher.sh  (1847 B)             # v3: Estágio A Guard-4 + KPM + namespaces
└── github/
    ├── SKILL.md  (2973 B)                         # operações `gh` (PR/issue/CI/Copilot)
    ├── references/
    │   ├── cli-patterns.md  (3243 B)
    │   ├── copilot-review.md  (3244 B)
    │   ├── copilot-workflow.md  (2838 B)
    │   ├── pr-workflow.md  (3262 B)
    │   ├── review-checklist.md  (1378 B)
    │   └── triage-workflow.md  (7575 B)
    └── scripts/
        ├── copilot_activity.sh  (1652 B)
        ├── pr_details.sh  (1182 B)
        └── triage_gather.sh  (1445 B)

17 diretórios · 36 arquivos · ~112 KB de contrato + 74 KB de scripts/assets
Atalho de descoberta: .claude/skills -> ../skills  (symlink; .claude/ é gitignored)
```

---

## 3. Fusão `evox-rom-ci-optimizer` v2 ⊕ v3 → v3.1

| Eixo | v2.0 (diretório) | v3.0 (zip) | v3.1 instalada |
|---|---|---|---|
| Sub-agentes | 3 (FORGE, PROBE, INQUISITOR) | 4 (+ SNAPSHOT-KEEPER) | 4, **cada um com backend executável** |
| Escopo | “conjunto de módulos” | M01–M15 em 5 ondas | 15 módulos + 3 plataformas (MaxManager, Duck-ToolBox, GenieX) mapeados a alvos |
| Scripts | 4 | 0 (spec pura) | **8** |
| Gates | 10 testes binários | 10 testes binários | 10 testes + runner (`make`) + evidência por artefato |
| Estado | backup ad-hoc | `snapshot/<camada>/<tag>` | `snapshot_branch_manager.sh` + manifesto SHA-256 |
| Custo CI | `timeout-minutes` | trava dupla + `.devcontainer` | trava tripla versionada (`devcontainer.json`) |
| Rastreabilidade | README | narrativa | `Makefile` com 10 alvos + `references/archive` (nada descartado) |

---

## 4. Avaliação individual (força · limite · quando acionar)

| Skill | Força objetiva | Limite observado | Acionar quando |
|---|---|---|---|
| **evox-rom-ci-optimizer v3.1** | Única do pacote com **execução real**: 8 scripts, 10 gates com exit code, scanner JSON, snapshot com hash, watchdog de 120 s. Autossuficiente (instalador + Makefile + workflow pronto) | Depende de binários externos não embarcados (`payload-dumper-go`, `kptools`, `magiskboot`, `adb`, `act`); `runtime_module_tester.sh` exige device/QEMU acessível; o KVM do GitHub Actions é aproximação, não fidelidade de sensor físico | Qualquer mutação de ROM/kernel/módulo **antes** do cabo USB |
| **evox-pong-ci-architect** | Traduz o pipeline para o hardware real (`pong`, SM8475): matriz PASS/FAIL de 12 componentes, `privapp-permissions`, `persist` intocável, `concurrency`/`timeout` | Prescritiva (sem scripts); sobrepõe-se em ~70 % ao escopo da evox-rom-ci-optimizer (risco de duas fontes de verdade) | Revisão de arquitetura do workflow e checklist de release do `pong` |
| **android16-root-guardian** | Rigor Safe-First do lado físico: fingerprint de KMI, retenção de root em OTA A/B, Two-Man Rule, rollback por SHA-256 | Só texto; nenhum script de coleta incluído | Diagnóstico **após** o flash, bootloop, OTA, troca de engine de root |
| **agent-governance-orchestrator** | Meta-camada que amarra as outras: 5W1H, Ownership Ledger, wave DAG, Guard-4, 8 gates de governança — é o “compilador” de composição multi-skill | Não executa nada; sem scripts de ledger/gate (fica no protocolo) | Orquestrar 2+ skills, arbitrar conflito de escrita, auditar entrega |
| **act-github-pat** | Resolve o gargalo real do `act` (403 rate-limit) com matriz de escopos Classic vs Fine-Grained e injeção sem hardcode (`gh auth token`) | Depende de `gh` autenticado; nada sobre OIDC/`GITHUB_TOKEN` efêmero | Rodar workflow local, PAT para repro privado, GHCR |
| **github** | Superfície `gh` completa com 6 references + 3 scripts de coleta em JSON (não inflam contexto) | Assume `gh` autenticado; política de “require confirmation” em merge/approve/close | PR, issue, triage, Copilot review, status de CI |
| **apex-talent-broker** | Único vetor financeiro: EHV/SLI, funil de reputação, harvester Python + playbooks de pitch | Fricção com ToS de plataformas ao raspar; fora do domínio de engenharia do repo | Monetização/arbitragem de capital intelectual |

---

## 5. Quais qualidades foram incrementadas (delta real em capacidade)

1. **Evidência antes de opinião.** Todo gate agora exige `sys.boot_completed=1`, hash ou JSON —
   `PASS` autodeclarado deixa de ser aceitável (gate 3 e 7 da v3.1).
2. **Safety-first com reversibilidade determinística.** Guard-4 virou rotina executável
   (`forge_patcher.sh` salva `boot_stock_rollback.img` + `.sha256` **antes** de tocar o kernel).
3. **Gêmeo digital antes do hardware.** Estágio B obrigatório: nada de testar hipótese de módulo
   no slot de boot do celular; o runner efêmero absorve o erro.
4. **Governança de topologia.** Ownership Ledger + waves impedem que dois módulos escrevam no
   mesmo alvo (a causa-raiz histórica de bootloop registrada no `AGENTS.md`).
5. **Disciplina de custo.** `concurrency: cancel-in-progress`, `timeout-minutes`,
   `devcontainer.json` e `runtime-test` com `timeout 180` — CI deixou de ser recurso ilimitado.
6. **Estado versionado, não memória.** Snapshot por camada com manifesto SHA-256 em
   `snapshot/<camada>/<tag>`; rollback deixa de depender de lembrança.
7. **Execução, não descrição.** Antes: prosa. Agora: 8 scripts com contrato `--flag`, exit codes
   vetoriais (0/1) e um `Makefile` de 10 alvos — auditoria hostil automatizável em CI.
8. **Handoff explícito entre especialistas.** Pré-flash (`evox-*`) → credenciais (`act-github-pat`)
   → operação (`github`) → pós-flash (`android16-root-guardian`), arbitrado pelo
   `agent-governance-orchestrator`.
9. **Validação binária como contrato.** 10 testes com coluna “Ação se FAIL” — falha tem
   consequência prescrita (bisect, isolar módulo, bloquear release), não improviso.
10. **Anti-alucinação de ferramenta (KDI).** Cada skill declara o binário que precisa
    (`kptools`, `payload-dumper-go`, `act`, `gh`); ferramenta ausente vira erro explícito
    (`make run-act` → “act nao encontrado”), não promessa vazia.
11. **Rastreabilidade de proveniência.** Toda skill carrega `SKILL.md` como fonte de verdade e o
    doc canônico v2.0 preservado; nada foi silenciosamente reescrito.

---

## 6. Evidência de validação executada (2026-11-01)

| Verificação | Comando | Resultado |
|---|---|---|
| Sintaxe Bash (8 scripts + instalador + watchdog) | `make check` | `OK` em todos |
| Compilação Python | `python3 -m py_compile scripts/static_conflict_scanner.py` | `OK` |
| Schema JSON (safelist, devcontainer) | `python3 -m json.tool` | `OK` |
| Self-test limpo (0 módulos) | `scripts/audit_rom_conflicts.sh` | `[APROVADO] Zero conflitos estáticos fatais` |
| **Teste negativo** (2 módulos colidindo em `system/etc/audio_effects.xml`) | `static_conflict_scanner.py` | `status: CONFLICT` (exit 1), `FILE_OVERWRITE` apontado |
| **Veto do Inquisidor** (mesmo cenário) | `audit_rom_conflicts.sh` | `Colisao de Inode: FAIL` + `[VETO DO INQUISITOR] 1 conflito fatal` |
| Snapshot/estado | `snapshot_branch_manager.sh --layer wave1 --tag v11.11-w1-test` | `[OK] Snapshot registrado` |
| Front matter das 7 skills | `head -3 */SKILL.md` | 7/7 com `name:` + `description:` |
| Scripts das skills `github`/`apex` | `bash -n`, `py_compile` | `OK` |

> Nada foi enviado ao GitHub: nenhum `push`, PR, workflow ou secret tocado. Tudo local.

---

## 7. Gaps honestos (o que o pacote ainda não cobre)

1. **Duas fontes de verdade para o mesmo pipeline** (`evox-rom-ci-optimizer` vs
   `evox-pong-ci-architect`). Recomendação: `evox-pong-ci-architect` passa a ser
   `references/pong-hardware-matrix.md` dentro da v3.1, com uma matriz PASS/FAIL única.
2. **`fabrica-de-agentes` / `skill-updater`** são citadas pelo `agent-governance-orchestrator`
   (KDI → gap analysis) mas **não estão na pasta SKILLS** — a auto-evolução de skills está
   prometida e não instalada.
3. **Sem coletores de telemetria** no lado físico: `android16-root-guardian` é 100 % doutrina;
   falta `scripts/collect_evidence.sh` (getprop/uname/dmesg/logcat/avc) com hash de saída.
4. **Binários externos não embarcados** (`payload-dumper-go`, `kptools`, `magiskboot`, `adb`,
   `act`, `gh`): a instalação os detecta, não os instala.
5. **`apex-talent-broker`** não pertence ao domínio técnico do repo; útil, mas deve ficar fora do
  caminho de descoberta padrão para não competir por contexto.
6. **Nenhuma skill mede a própria taxa de acerto**: não há harness de eval (o `audit-fsm` do repo
   poderia hospedar isso).

---

## 8. Como acionar (caminho exato, para subagente)

```text
skills/evox-rom-ci-optimizer/SKILL.md          # pré-flash: ROM/kernel/módulos + CI + snapshot
skills/evox-pong-ci-architect/SKILL.md         # matriz de hardware do Nothing Phone 2
skills/android16-root-guardian/SKILL.md        # pós-flash, bootloop, OTA A/B
skills/agent-governance-orchestrator/SKILL.md  # orquestração/handoff entre as acima
skills/act-github-pat/SKILL.md                 # PAT + nektos/act
skills/github/SKILL.md                         # gh: PR/issue/CI/Copilot
skills/apex-talent-broker/SKILL.md              # monetização (fora do domínio técnico)
```
