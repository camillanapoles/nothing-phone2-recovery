# `skills/` — Skill stack do nothing-phone2-recovery

Instalado a partir do **Google Drive → `SKILLS/`**. Nada aqui passou pelo GitHub.

> **Contrato:** `SKILL.md` é a fonte de verdade. Um subagente recebe o **caminho absoluto** do
> `SKILL.md`, nunca um resumo gerado. `make -C skills validate` é a porta de entrada.

## Índice

| # | Skill | Tier | Superfície de decisão | Entrada |
|---|---|---|---|---|
| 1 | `evox-rom-ci-optimizer` **v3.2** | core | ROM Evolution X 11.11 pré-flash, QEMU/KVM CI, snapshots, arbitragem das 3 plataformas | [`SKILL.md`](evox-rom-ci-optimizer/SKILL.md) |
| 2 | `android16-root-guardian` | core | pós-flash Safe-First: KMI, root, OTA A/B, bootloop | [`SKILL.md`](android16-root-guardian/SKILL.md) |
| 3 | `agent-governance-orchestrator` | meta | DAG, Ownership Ledger, Guard-4, 5W1H, gates | [`SKILL.md`](agent-governance-orchestrator/SKILL.md) |
| 4 | `act-github-pat` | support | PAT Classic/Fine-Grained + `nektos/act` | [`SKILL.md`](act-github-pat/SKILL.md) |
| 5 | `github` | support | `gh`: PR, issue, triage, Copilot, CI | [`SKILL.md`](github/SKILL.md) |

**Excluídas por decisão (registradas em [`registry.json`](registry.json)):**

- `apex-talent-broker` — fora do domínio do projeto (arbitragem de oportunidades).
- `evox-pong-ci-architect` — absorvida em
  [`evox-rom-ci-optimizer/references/pong-hardware-matrix.md`](evox-rom-ci-optimizer/references/pong-hardware-matrix.md)
  para eliminar duas fontes de verdade sobre o mesmo pipeline.

## Hierarquia de verdade (instrução > código)

1. `evox-rom-ci-optimizer/references/module-matrix-5w1h.md` — **a instrução** (15 módulos + 3 plataformas).
2. `evox-rom-ci-optimizer/references/external-engines-arbitration.md` — regras `R01..R09`.
3. `SKILL.md` — comportamento do agente.
4. `scripts/` — o que a máquina executa hoje.
5. Resto do repo — evidência histórica, não contrato.

Divergiu? **Corrige-se o script**, não a instrução.

## Harness (novo)

```bash
make -C skills validate     # front matter, name==dir, links, caminhos em backtick, segredos, registry
make -C skills check-core   # bash -n + py_compile + JSON schema + self-test do auditor
make -C skills test         # 13 cenários de regressão das regras R00..R09 do scanner
make -C skills check-all    # tudo acima em sequência
make -C skills registry     # imprime o estado do ecossistema
```

O validador (`tools/validate_skills.py`) falha em: `SKILL.md` ausente, `name` ≠ diretório,
descrição < 40 chars, link quebrado, `scripts/x` citado e inexistente, segredo exposto,
skill fora do `registry.json`.

## `evox-rom-ci-optimizer` v3.2 — o que mudou

| Fonte no Drive | Papel |
|---|---|
| `SKILLS/evox-rom-ci-optimizer.zip` (v3.0, spec) | corpo do `SKILL.md`: 4 sub-agentes, Waves 1–5, M01–M15, 10 gates |
| `SKILLS/evox-rom-ci-optimizer/` (v2.0, diretório) | 8 scripts, references, assets, `Makefile`, `install_local.sh`, doc canônico em `references/archive/` |
| `SKILLS/evox-rom-ci-optimizer-v2.0-full.zip` | resumo v2.0 arquivado |

Acrescentado na consolidação: `references/module-matrix-5w1h.md`,
`references/external-engines-arbitration.md`, `references/pong-hardware-matrix.md`,
`references/ci-cost-locks.md`, `tests/test_scanner_rules.sh`, alvos `test/scan/forge/snapshot/runtime-test`,
e o scanner reescrito com 9 regras (`R00`–`R09`) + `--strict/--json/--out`.

## Evidência coletada (2026-11-01)

| Verificação | Resultado |
|---|---|
| `make -C skills validate` | `OK` (5 skills, 0 falhas) |
| `make -C skills check-core` | `OK` |
| `make -C skills test` | `13 PASS / 0 FAIL` |
| Cenário negativo manual (2 módulos em `audio_effects.xml`) | `CONFLICT` exit 1 + veto do Inquisidor |
| `snapshot_branch_manager.sh --layer wave1 --tag v11.11-w1-test` | manifesto registrado |

## Descoberta pelo harness do agente

`.claude/skills` é symlink para esta pasta (`.claude/` é gitignored): Claude Code e agentes
compatíveis encontram as skills sem duplicar arquivos no Git. Briefing de retomada em
[`../docs/skills/HANDOFF-BRIEF.md`](../docs/skills/HANDOFF-BRIEF.md).
