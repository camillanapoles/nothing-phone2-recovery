# Índice de legado — o que NÃO é contrato

**Atualizado em 2026-11-01**, após a higiene executada por `scripts/state_reset.sh --apply`
(27 arquivos quarentenados · 0 linhas de FSM removidas porque o banco não existia).

## Regra de leitura

```text
CONTRATO VIGENTE              -> AGENTS.md · agente.md · skills/*/SKILL.md + references/
CONTRATO EXECUTÁVEL           -> audit-fsm/src (FSM determinístico, read-only)
EVIDÊNCIA (não decide)        -> docs/skills/
MEMÓRIA (proibida como regra) -> state/quarantine/<UTC>/ · archive/ · ci*/
```

Precedência completa em `AGENTS.md` §0. Em caso de contradição: **vale `skills/`**.

## O que saiu do índice ativo (quarentena)

Tudo abaixo foi movido para `state/quarantine/<UTC>/` (gitignored) com `MANIFEST.json` +
`SHA256SUMS`, e permanece recuperável por `git show <commit>:<caminho>`.

| Caminho original | O que era | Por que saiu |
|---|---|---|
| `AGENTS.md` (2026-10-28) | playbook pós-batalha (6 erros, checklist próprio) | substituído pelo contrato atual; as lições viraram R06/R08 e gates |
| `"O advisory tinha razão — usar o boot.md"` | nota de sessão com convenção de boot alternativa | conflitava com `skills/BOOT.md` |
| `init_plan.md` · `modules.md` | plano inicial e lista antiga de módulos | sem os 15 módulos, 3 plataformas e ondas |
| `.atl/skill-registry.md` (+cache) | índice de skills de **outra máquina** (`/home/cnmfs/...`) | caminhos inexistentes aqui; o índice válido é `skills/registry.json` |
| `.pi/tasks/*` | evidência de harness/eval de outro host | evidência de outra máquina não prova nada aqui |
| `.claude/kpi/events-camilla.jsonl` | telemetria de sessões de 2026-10-28 | dado de sessão encerrada |
| `docs/plans/*` (6 arquivos) | planos de recuperação 2026-10-20/29 | superados pela matriz 5W1H das skills |
| `docs/ssot/session-log/`, `docs/ssot/state/` | estado consolidado de 2026-10-30 | estado de sessão antiga |
| `docs/GOVERNANCE.md` | governança anterior à stack de skills | regras de merge superadas |
| `docs/wiki/.pending/changes.jsonl` | fila de mudanças da wiki antiga | não é fonte de verdade |

## O que continua no repositório, mas **não decide**

| Caminho | Natureza | Uso permitido |
|---|---|---|
| `archive/zeroharcoderd/knowledge/**` | base de conhecimento de módulos/frameworks | consulta; nunca substitui `SKILL.md` |
| `ci/`, `ci-build/`, `ci-build-full/`, `ak3/` | experimentos de pipeline anteriores | não executar como pipeline atual |
| `config/managers.json` | catálogo de root managers/toolchains | dado de gerência (não é regra) |
| `docs/skills/*` | inventário, handoff, este índice | descreve o estado; não decide |

## Banco do FSM (backends)

`audit-fsm.db` (SQLite) é **runtime**, nunca versionado. Regra:

```bash
scripts/state_reset.sh            # inspeciona: existe banco com dado de sessão antiga?
scripts/state_reset.sh --apply    # copia para quarentena, remove e regenera schema vazio
```

Banco ausente é estado saudável: `init_db()` cria as tabelas vazias na próxima execução.
