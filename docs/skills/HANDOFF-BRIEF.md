# Handoff — estado da stack de skills & próximo passo

**Data:** 2026-11-01 · **Branch:** `arena/863582fd-nothing-phone2-recovery` · **GitHub:** não utilizado
**Regra de leitura:** este briefing descreve *instrução e estado*, não o repositório. Onde o repo
divergir, vale o que está aqui + `skills/evox-rom-ci-optimizer/references/module-matrix-5w1h.md`.

---

## 1. O que foi feito (nesta ordem)

1. **Instalação** das skills do Drive `SKILLS/` → `skills/` (duplicatas descartadas).
2. **Fusão** `evox-rom-ci-optimizer` v3.0 (spec) ⊕ v2.0 (pacote operacional) → **v3.2**.
3. **Exclusão de escopo:** `apex-talent-broker` removida.
4. **Consolidação:** `evox-pong-ci-architect` absorvida como `references/pong-hardware-matrix.md`.
5. **Instrução materializada:** `module-matrix-5w1h.md` (15 módulos, 3 plataformas, 5W1H) +
   `external-engines-arbitration.md` (R01–R09) + `ci-cost-locks.md`.
6. **Engine endurecido:** `static_conflict_scanner.py` (R00–R09, `--strict/--json`) + 13 cenários.
7. **Harness de skills:** `make validate`, `make eval`, `make test-all`, `registry.json`, `BOOT.md`.
8. **4º lote do Drive (2026-11-01T17:12)** — `fabrica-de-agentes`, `cogni-synapse`,
   `sci-scientific-mindset`, `github` (reupload idêntico → deduplicado, não reinstalado).
   Stack passou de 5 → **8 skills**; `fabrica-de-agentes` (77 KB) foi dividida em `SKILL.md`
   + 3 `references/` para caber no teto de 64 KB.
9. **Débitos fechados com artefato + teste** (ver §4): L1, L2, L3, L5, L6.

## 2. Estado verificado (evidência, não promessa)

```text
make -C skills validate    -> [harness] OK (0 falhas) · 8 skills
make -C skills check-core  -> [core] make check OK
make -C skills test-core   -> 13 (R00..R09) · 8 (preflight) · 15 (ROM/L4) · 36 (gates) · 21 (CI/sandbox)
make -C skills test-guard  -> 8 PASS / 0 FAIL (coletor de evidência, stub de adb)
make -C skills eval        -> [eval] APROVADO · 8/8 acima do limite da classe
```

Notas do eval (7 eixos × classe × tier): evox 100 · cogni-synapse 81 · android16 83 ·
governança 75 · fabrica 75 · sci-mindset 63 · github 58 · act-github-pat 57.
Limites: `executable` core≥70/meta≥55/support≥55 · `doctrine` core≥60/meta≥50/support≥45.

## 3. Estrutura final (8 skills)

```text
skills/
├── BOOT.md · README.md · Makefile · registry.json
├── tools/validate_skills.py · tools/eval_skills.py
├── evox-rom-ci-optimizer/            ★ v3.2  (core, executable)
│   ├── SKILL.md · Makefile · install_local.sh
│   ├── references/ (module-matrix-5w1h, external-engines-arbitration, pong-hardware-matrix,
│   │                ci-cost-locks, safelist, devcontainer, pipeline, archive/)
│   ├── scripts/ (9: extract, forge, patch-boot, bundle, audit, scanner, snapshot, runtime, preflight)
│   └── tests/ (test_scanner_rules.sh · test_preflight_deps.sh)
├── android16-root-guardian/         ★ v2.1  (core, executable)
│   ├── SKILL.md · Makefile
│   ├── scripts/collect_evidence.sh
│   └── tests/test_collect_evidence.sh
├── agent-governance-orchestrator/    (meta, doctrine)
├── fabrica-de-agentes/               (meta, doctrine)  SKILL.md + 3 references/
├── sci-scientific-mindset/           (meta, doctrine)
├── cogni-synapse/                    (support, doctrine)
├── act-github-pat/                   (support, doctrine)
└── github/                           (support, executable)  SKILL.md + references + scripts
```

## 4. Lacunas — estado atual

| # | Lacuna | Estado | Evidência |
|---|---|---|---|
| L1 | `fabrica-de-agentes` citada e inexistente | **FECHADA** | skill instalada v2.0.0, dividida em 4 arquivos; `registry.json` registra "resolve L1" |
| L2 | `android16-root-guardian` sem scripts | **FECHADA** | `scripts/collect_evidence.sh` (exit 0/3/4) + `evidence.json` + `MANIFEST.sha256`; `8 PASS` |
| L3 | Binários externos não verificados | **FECHADA** | `scripts/preflight_deps.sh` (`--json/--require/--hints`, exit 0/1/2), catálogo de 12 binários; `8 PASS` |
| L4 | Kernel exato / hashes da build | **PRONTA, aguarda o .zip** | `extract_rom_assets.sh` (15 PASS) fecha pelo pacote oficial: kernel/KMI + sha256 de `boot`/`vendor_boot`/`vbmeta`/`init_boot`/`dtbo` |
| L5 | Sem harness de eval das próprias skills | **FECHADA** | `tools/eval_skills.py`, 7 eixos falseáveis, `[eval] APROVADO` |
| L6 | `docs/` legado divergente | **FECHADA** | `docs/skills/LEGACY-INDEX.md` marca o legado e fixa a regra de precedência |

**Único débito aberto: L4.** Não é código — é o `.zip` oficial da Evolution X 11.11 (o sandbox não
alcança `cdn.evolution-x.org`). Procedimento e teste já estão prontos; ver `NEXT-SESSION-REPORT.md`.

## 5. Duas frentes prontas para executar (decisão da usuária)

1. **Fechar L4 a partir da ROM** (não do device): `./scripts/extract_rom_assets.sh --zip <oficial>    --expect-sha256 <hash> --out ./workspace/rom_assets` → `rom_assets.json` com `l4_closed: true`.
   Só depois alimentar `pong-device-profile.json` e os defaults de `forge_patcher.sh`.
2. **Bootstrap do GitHub** (`scripts/bootstrap_github_repo.sh`) — **não executar** até liberação.

## 6. Regras que não mudam

- Sem flash físico, sem estágio A+B aprovados e sem `boot_stock_rollback.img` verificado.
- `persist` intocável; SELinux `Enforcing`; MaxManager com exclusividade de escrita.
- Nada de GitHub enquanto a usuária não liberar (hoje: Drive + local apenas).
- Instrução vence código; código errado se corrige, instrução não se reescreve para caber.
- Skill nova só entra no `registry.json` com `validate` + `eval` verdes.
