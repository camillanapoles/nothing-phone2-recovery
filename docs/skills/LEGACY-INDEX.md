# Índice de legado — o que NÃO é contrato (lacuna L6)

O repositório acumulou documentos de batalhas anteriores. Eles são **evidência histórica**:
úteis para entender por que uma regra existe, perigosos se lidos como contrato vigente.

## Regra de leitura

```text
CONTRATO VIGENTE                -> skills/*/SKILL.md + skills/*/references/*
EVIDÊNCIA HISTÓRICA (legado)    -> tudo o mais neste repositório
```

Se um documento de legado contradisser `skills/`, **vale `skills/`** (ver hierarquia no
`skills/BOOT.md`, seção 1).

## Inventário do legado

| Caminho | O que é | Status | Risco se lido como contrato |
|---|---|---|---|
| `AGENTS.md` | playbook pós-batalha do Nothing Phone 2: 6 erros, checklist pré-flash, comandos de diagnóstico | **legado útil** — as lições viraram regras R06/R08 e gates 2/7 | manda flashar com checklist próprio, sem estágio A/B |
| `"O advisory tinha razão — usar o boot.md"` | nota longa de sessão anterior sobre convenção de boot | legado | sugere outra ordem de boot que o `skills/BOOT.md` |
| `init_plan.md` | plano inicial do projeto | legado | escopo antigo, sem os 15 módulos |
| `modules.md` | lista antiga de módulos | legado | não tem as 3 plataformas externas nem ondas |
| `README.md` (raiz) | status de CI/CD de PR #1 | legado | descreve pipeline anterior ao v3.2 |
| `docs/GOVERNANCE.md`, `docs/wiki/`, `docs/plans/` | governança e wiki antigas | legado | regras de merge superadas pelo fluxo atual |
| `docs/ssot/` | estado/sessões gravadas | legado (dados) | pode conter hash/slot de builds anteriores |
| `.pi/tasks/*` | relatórios de harness/eval antigos | legado (evidência) | evidência de outra máquina, não deste repo |
| `ci/`, `ci-build/`, `ci-build-full/`, `zeroharcoderd/`, `ak3/`, `audit-fsm/` | código e experimentos de pipelines anteriores | legado (código) | implementações que não passam por `make check` do harness |
| `.atl/skill-registry.md` | índice de skills do **host** (`/home/cnmfs/...`) | legado de ambiente | caminhos que não existem aqui; o índice válido é `skills/registry.json` |

## O que fazer quando o legado for útil

1. Se a lição for operacional (erro que causou dano), ela vira **regra com ID** em
   `skills/evox-rom-ci-optimizer/references/` e **teste** em `tests/`.
2. Se for dado de build (hash, versão de kernel), vai para `references/pong-device-profile.json`
   quando **L4** for desbloqueada — nunca para dentro de `SKILL.md`.
3. Caso contrário, permanece intacto como memória. Não apagar: a história explica as travas.
