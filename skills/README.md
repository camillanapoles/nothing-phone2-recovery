# `skills/` — Skill stack do nothing-phone2-recovery

Instalado a partir do **Google Drive → `SKILLS/`**. Nada aqui passou pelo GitHub.

> **Contrato:** `SKILL.md` é a fonte de verdade. Um subagente recebe o **caminho absoluto** do
> `SKILL.md`, nunca um resumo gerado. `make -C skills validate` é a porta de entrada.

## Índice

| # | Skill | Tier | Classe | Superfície de decisão | Entrada |
|---|---|---|---|---|---|
| 1 | `evox-rom-ci-optimizer` **v3.2** | core | executable | ROM Evolution X 11.11 pré-flash, AVD API 36 no CI + HIL local A/B, snapshots, arbitragem R01–R09 | [`SKILL.md`](evox-rom-ci-optimizer/SKILL.md) |
| 2 | `android16-root-guardian` **v2.1** | core | executable | pós-flash Safe-First + coletor de evidência com manifesto SHA-256 | [`SKILL.md`](android16-root-guardian/SKILL.md) |
| 3 | `agent-governance-orchestrator` | meta | doctrine | DAG, Ownership Ledger, Guard-4, 5W1H, gates | [`SKILL.md`](agent-governance-orchestrator/SKILL.md) |
| 4 | `fabrica-de-agentes` **v2.0** | meta | doctrine | criação/validação de skill: 9 fases, 12 testes, economia de contexto | [`SKILL.md`](fabrica-de-agentes/SKILL.md) |
| 5 | `sci-scientific-mindset` | meta | doctrine | crivo epistêmico: hipótese falseável, contra-argumento, contrafactual | [`SKILL.md`](sci-scientific-mindset/SKILL.md) |
| 6 | `cogni-synapse` | support | doctrine | entrega executiva: BLUF, escolha de vetor, densidade | [`SKILL.md`](cogni-synapse/SKILL.md) |
| 7 | `act-github-pat` | support | doctrine | PAT Classic/Fine-Grained + `nektos/act` | [`SKILL.md`](act-github-pat/SKILL.md) |
| 8 | `github` | support | executable | `gh`: PR, issue, triage, Copilot, CI | [`SKILL.md`](github/SKILL.md) |

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
make -C skills validate     # contrato: front matter, name==dir, links, segredos, registry
make -C skills eval         # qualidade: 7 eixos falseáveis, limite por classe+tier
make -C skills test-core    # R00..R09 (13) + preflight (8) + extração da ROM/L4 (15)
make -C skills test-guard   # coletor de evidência pós-flash (8, com stub de adb)
make -C skills check-all    # validate + check-core + test-all + eval
make -C skills registry     # estado do ecossistema (tiers, excluídas, deduplicadas)
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
| `make -C skills validate` | `OK` (8 skills, 0 falhas) |
| `make -C skills eval` | `APROVADO` (8/8 acima do limite) |
| `make -C skills test-core` | `13 PASS` (regras) · `8 PASS` (preflight) · `15 PASS` (ROM/L4) |
| `make -C skills test-guard` | `8 PASS / 0 FAIL` (evidência) |
| Cenário negativo manual (2 módulos em `audio_effects.xml`) | `CONFLICT` exit 1 + veto do Inquisidor |
| `snapshot_branch_manager.sh --layer wave1 --tag v11.11-w1-test` | manifesto registrado |

## Descoberta pelo harness do agente

`.claude/skills` é symlink para esta pasta (`.claude/` é gitignored): Claude Code e agentes
compatíveis encontram as skills sem duplicar arquivos no Git. Briefing de retomada em
[`../docs/skills/HANDOFF-BRIEF.md`](../docs/skills/HANDOFF-BRIEF.md).

## Skills adicionadas em 2026-11-01T17:12 (4º lote do Drive)

| Zip no Drive | Destino | Observação |
|---|---|---|
| `fabrica-de-agentes.zip` (77 KB) | `fabrica-de-agentes/` | `SKILL.md` reduzido a 49 KB + 3 `references/` verbatim (limite de 64 KB do contrato). Resolve a lacuna **L1** |
| `cogni-synapse.zip` (33 KB) | `cogni-synapse/` | camada de saída (BLUF/vetor semiótico) |
| `sci-scientific-mindset.zip` (4,5 KB) | `sci-scientific-mindset/` | camada epistêmica; virou o crivo do `tools/eval_skills.py` |
| `github.zip` (13,8 KB) | — | **reupload idêntico** ao já instalado (mesmo conteúdo, verificado por `diff -r`); mantida a versão existente |
