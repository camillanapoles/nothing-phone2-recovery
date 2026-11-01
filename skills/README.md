# `skills/` — Skill stack do nothing-phone2-recovery

Pacote de skills instalado a partir da pasta **Google Drive → `SKILLS/`** (fonte: apenas Drive,
sem GitHub). Cada skill segue o *Skill Design Pattern*: `SKILL.md` (contrato de runtime) +
`scripts/` + `references/` + `assets/` quando aplicável.

> Regra de uso (herdada do `AGENTS.md`): `SKILL.md` é a fonte de verdade. Um subagente recebe o
> **caminho exato** do `SKILL.md`, nunca um resumo gerado.

## Índice

| # | Skill | Tipo | Superfície de decisão | Entrada |
|---|---|---|---|---|
| 1 | `evox-rom-ci-optimizer` **v3.1** | Orquestração Dual-Stage (4 sub-agentes) | ROM Evolution X 11.11 (A16) pré-flash, QEMU/KVM CI, snapshots | [`SKILL.md`](evox-rom-ci-optimizer/SKILL.md) |
| 2 | `evox-pong-ci-architect` | Arquitetura CI | 12 componentes + release artifact no Nothing Phone 2 (`pong`) | [`SKILL.md`](evox-pong-ci-architect/SKILL.md) |
| 3 | `android16-root-guardian` | Guardião Safe-First pós-flash | Kernel/root/KMI, OTA A/B, bootloop, Termux/ADB | [`SKILL.md`](android16-root-guardian/SKILL.md) |
| 4 | `agent-governance-orchestrator` | Meta-governança | DAG, Ownership Ledger, Guard-4, 5W1H, gates binários | [`SKILL.md`](agent-governance-orchestrator/SKILL.md) |
| 5 | `act-github-pat` | Credenciais/CLI | PAT Classic/Fine-Grained, `.actrc`, `nektos/act` | [`SKILL.md`](act-github-pat/SKILL.md) |
| 6 | `github` | Operações `gh` | PR, issue, triage, Copilot review, CI | [`SKILL.md`](github/SKILL.md) |
| 7 | `apex-talent-broker` | Arbitragem de oportunidades | Raspagem, EHV/SLI, propostas, reputação | [`SKILL.md`](apex-talent-broker/SKILL.md) |

## Composição: `evox-rom-ci-optimizer` v3.1

O Drive tem duas gerações da mesma skill; esta instalação **funde as duas sem descartar nada**:

| Fonte no Drive | Papel na fusão |
|---|---|
| `SKILLS/evox-rom-ci-optimizer.zip` (**v3.0**, spec) | corpo do `SKILL.md` v3.1: 4 sub-agentes, Waves 1–5, M01–M15, 10 testes binários, trava de custo |
| `SKILLS/evox-rom-ci-optimizer/` (**v2.0**, pacote em diretório) | `scripts/` (8), `references/` (3), `assets/` (2), `Makefile`, `install_local.sh`, README, doc canônio v2.0 (`references/archive/`) |
| `SKILLS/evox-rom-ci-optimizer/evox-rom-ci-optimizer-v2.0-full.zip` | resumo v2.0 arquivado em `references/archive/evox-ci-v2.0-SKILL.md` |

Alvos novos do `Makefile` v3.1 (não existiam em nenhuma das duas versões isoladas):
`scan` (scanner estático Python), `forge` (Estágio A Guard-4), `snapshot` (SNAPSHOT-KEEPER),
`runtime-test` (Estágio B via ADB), além de `check` agora compilar Python e validar 2 JSONs.

## Verificação rápida

```bash
cd skills/evox-rom-ci-optimizer && make check     # 4 blocos: bash -n, py_compile, JSON, self-test
make scan                                         # scanner dos módulos (exit 1 se CONFLICT)
```

Evidência coletada na instalação (2026-11-01):

- `make check` → `PASS` (8 scripts + 1 Python + 2 JSONs + auditor com 0 conflitos).
- Cenário negativo forjado (2 módulos disputando `system/etc/audio_effects.xml`) →
  `static_conflict_scanner.py` = `CONFLICT` (exit 1) e `audit_rom_conflicts.sh` =
  `[VETO DO INQUISITOR] 1 conflito(s) fatal(is)`.
- `snapshot_branch_manager.sh --layer wave1 --tag v11.11-w1-test` → manifesto registrado.

## Harness

`.claude/skills` é um symlink para esta pasta (o `.claude/` é gitignored); assim Claude Code e
agentes compatíveis descobrem as skills sem duplicar arquivos no Git.
