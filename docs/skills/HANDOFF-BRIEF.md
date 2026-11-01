# Handoff — estado da stack de skills & próximo passo

**Data:** 2026-11-01 · **Branch:** `arena/863582fd-nothing-phone2-recovery` · **GitHub:** não utilizado
**Regra de leitura:** este briefing descreve *instrução e estado*, não o repositório. Onde o repo
divergir, vale o que está aqui + `skills/evox-rom-ci-optimizer/references/module-matrix-5w1h.md`.

---

## 1. O que foi feito (nesta ordem)

1. **Instalação** das 7 skills do Drive `SKILLS/` → `skills/` (duplicatas descartadas).
2. **Fusão** `evox-rom-ci-optimizer` v3.0 (spec) ⊕ v2.0 (pacote operacional) → **v3.1**.
3. **Exclusão de escopo:** `apex-talent-broker` removida (não faz parte do projeto).
4. **Consolidação:** `evox-pong-ci-architect` absorvida como
   `references/pong-hardware-matrix.md` (fim das duas fontes de verdade).
5. **Instrução materializada:** `references/module-matrix-5w1h.md` (Classes 1–6, 15 módulos,
   3 plataformas, 5W1H, mapa módulo→onda→gate) + `references/external-engines-arbitration.md`
   (R01–R09) + `references/ci-cost-locks.md`.
6. **Engine endurecido:** `static_conflict_scanner.py` reescrito (v3.1 → regras R00–R09,
   `--modules-dir/--out/--strict/--json`, status `CLEAN|WARN|CONFLICT`) + `tests/` com 13 cenários.
7. **Harness de skills:** `skills/Makefile`, `skills/tools/validate_skills.py`, `skills/registry.json`,
   `skills/BOOT.md` — descoberta e validação determinísticas.

## 2. Estado verificado (evidência, não promessa)

```text
make -C skills validate    -> [harness] OK (0 falhas) · 5 skills
make -C skills check-core  -> [core] make check OK     (8 scripts bash -n, py_compile, 2 JSONs, auditor)
make -C skills test        -> 13 PASS / 0 FAIL         (R00..R09)
snapshot_branch_manager.sh -> [OK] Snapshot registrado
```

## 3. Estrutura final

```text
skills/
├── BOOT.md · README.md · Makefile · registry.json
├── tools/validate_skills.py
├── evox-rom-ci-optimizer/            ★ v3.2
│   ├── SKILL.md · Makefile · install_local.sh
│   ├── assets/ (preset .prop, watchdog 120 s)
│   ├── references/
│   │   ├── module-matrix-5w1h.md            ← a instrução
│   │   ├── external-engines-arbitration.md  ← R01..R09
│   │   ├── pong-hardware-matrix.md          ← ex-evox-pong-ci-architect
│   │   ├── ci-cost-locks.md
│   │   ├── android16-evox-safelist.json · devcontainer.json · evox-ci-pipeline.yml
│   │   └── archive/ (v2.0 canônico 33 KB + resumo)
│   ├── scripts/ (8: extract, forge, patch-boot, bundle, audit, scanner, snapshot, runtime)
│   └── tests/test_scanner_rules.sh
├── android16-root-guardian/SKILL.md
├── agent-governance-orchestrator/SKILL.md
├── act-github-pat/SKILL.md
└── github/ (SKILL.md + 6 references + 3 scripts)
```

## 4. Lacunas remanescentes (honestas)

| # | Lacuna | Impacto | Ação sugerida |
|---|---|---|---|
| L1 | `fabrica-de-agentes` / `skill-updater` citadas e inexistentes | governança promete auto-evolução que não existe | trazer do Drive ou remover a promessa do texto |
| L2 | `android16-root-guardian` sem scripts | pós-flash depende de digitação manual | criar `scripts/collect_evidence.sh` (getprop/uname/dmesg/logcat/avc + hash) |
| L3 | Binários externos não embarcados | `make extract/forge/runtime-test` falham em máquina limpa | `install_local.sh` deve checar e reportar o que falta (já checa; falta bootstrap) |
| L4 | Kernel exato / hashes da build da usuária | `patch_boot_offline.sh` e KMI ficam em modo "esperado" | obter de `android-boot-hashs.txt` no Drive ou de `fastboot getvar` no device |
| L5 | Sem harness de eval das próprias skills | qualidade não medida ao longo do tempo | plugar no `audit-fsm` do repo (pytest) ou criar `skills/tools/eval_skills.py` |
| L6 | `docs/` do repo tem conteúdo legado divergente | risco de agente ler contrato antigo | `BOOT.md` declara a hierarquia; opcional marcar legados como `deprecated` |

## 5. Duas frentes prontas para executar (decisão da usuária)

1. **Parametrizar kernel/KMI + Device Profile para o `pong`** — precisa de: codename (já sabido:
   `pong` / SM8475), versão de kernel da Evolution X 11.11 instalada e, se possível, hashes de
   `boot_b`/`vendor_boot_b`/`vbmeta_b` (existem no arquivo `android-boot-hashs.txt` no Drive).
   Entrega: `references/pong-device-profile.json` + defaults seguros em `forge_patcher.sh`.
2. **Script de criação do repositório GitHub** (`gh repo create` + branches de snapshot
   `snapshot/rom-base`, `snapshot/kernel-kpm`, `snapshot/modules-wave1..4` + workflow Dual-Stage).
   Entrega: `scripts/bootstrap_github_repo.sh` — **não executar** até liberação explícita.

## 6. Regras que não mudam

- Sem flash físico, sem estágio A+B aprovados e sem `boot_stock_rollback.img` verificado.
- `persist` intocável; SELinux `Enforcing`; MaxManager com exclusividade de escrita.
- Nada de GitHub enquanto a usuária não liberar (hoje: Drive + local apenas).
- Instrução vence código; código errado se corrige, instrução não se reescreve para caber.
