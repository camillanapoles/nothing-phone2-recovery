# Autorização do PR — pedido em 5W1H

**Status:** aguardando seu "autorizo" · **PR:** não aberto · **Branch:** `arena/863582fd-nothing-phone2-recovery`

---

## What — o que exatamente vai no PR

| Grupo | Arquivos | O que é |
|---|---|---|
| Contrato | `AGENTS.md`, `agente.md`, `README.md`, `Makefile` | precedência, invariantes, procedimento, atalhos de prova |
| Skills | `skills/` (8 skills, 58 arquivos) | stack completa com harness `validate`/`eval` |
| Gates | 8 scripts + 8 suítes em `skills/evox-rom-ci-optimizer/tests/` | kernel, rollout, cache, rollback, L4, sandbox, lint, abertura |
| CI | `references/evox-ci-validator.yml` | workflow de 3 estágios (referência, não ativado) |
| Docs | `docs/skills/*` (6 documentos) | inventário, handoff, relatórios, visão do projeto, este pedido |
| Higiene | `scripts/state_reset.sh`, `tests/test_state_reset.sh`, `.gitignore` | quarentena do passado + banco do FSM limpo |

**Fora do PR:** nenhum `.zip` de ROM, nenhum `.img`, nenhum binário de terceiro, nenhum segredo,
nenhum token. Só texto, shell e Python auditáveis.

Escala: **110 arquivos, +10.947 / −3.779 linhas**, 7 commits.

---

## Why — por que abrir agora

1. A preparação está **verificada**: 13 suítes, 98 asserções, `validate` 0 falhas, `eval` aprovado.
2. Sem PR, o trabalho fica preso numa branch: se a sessão expirar, você perde o ponto de revisão.
3. O PR é o **lugar de revisão** antes de qualquer execução real (Stage A). Depois dele, a próxima
   sessão parte de `main` — e não de uma branch efêmera.

---

## Who — quem faz o quê

| Papel | Quem | Responsabilidade |
|---|---|---|
| Autor | agente (esta sessão) | abrir o PR com o corpo padrão, sem auto-merge |
| Revisor | **você** | ler o resumo, conferir os checks, aprovar ou pedir ajuste |
| Merge | **você** | `gh pr merge <n> --merge` (nunca automático) |
| Executor | próxima sessão | Stage A depois do merge + P1–P3 respondidos |

---

## When — quando

- **Abrir:** assim que você responder "autorizo o PR" (P9).
- **Mergear:** depois de você ler o diff-resumo e os checks; **antes** de qualquer Stage A.
- **Executar:** sessão seguinte, com `session_open.py` completo.

---

## Where — onde

- Repositório: `camillanapoles/nothing-phone2-recovery`
- Origem: `arena/863582fd-nothing-phone2-recovery` → Destino: `main`
- Nenhum workflow é disparado pelo PR (o `evox-ci-validator.yml` fica em `references/`, não em
  `.github/workflows/` — é referência até você autorizar a ativação).

---

## How — como

1. `gh pr create --base main --head arena/863582fd-nothing-phone2-recovery` com corpo contendo:
   BLUF, o que muda, o que **não** muda, tabela de provas, riscos e o checklist de ratificação.
2. Checks esperados no corpo (rodados localmente):
   `make prove` · `validate` · `eval` · 13/8/15/10/13/15/9/12/8/10 PASS.
3. **Sem** `--auto`, **sem** merge automático, **sem** push em `main`.
4. Se algo no review pedir ajuste: commit na mesma branch (o PR atualiza sozinho).

---

## Riscos do PR (declarados)

| Risco | Mitigação |
|---|---|
| PR grande (110 arquivos) dificulta review linha a linha | corpo com mapa por grupo + 6 docs de leitura curta |
| Workflow de referência pode ser confundido com ativo | está em `references/`, e o lint roda local; ativar exige mover para `.github/workflows/` |
| Remoção de 27 arquivos legados parece perda | quarentena em `state/` + histórico do Git (`git show <sha>:<path>`) |
| Skills de doutrina sem execução | `eval` separa classes `executable` × `doctrine` |

**Reversão:** `git revert <merge-sha>` restaura o estado anterior; nada em `main` é irreversível.

---

## Pendências que ainda existem (depois das suas respostas)

| # | Pendência | Estado | O que falta |
|---|---|---|---|
| **P1** | Vanilla × GAPPS | **respondida como protocolo** | o agente explica e recomenda na abertura; a escolha é sua na hora |
| **P2** | Caminho do `.zip` | **respondida como protocolo** | solicitado após a decisão de build |
| **P3** | Autorizar binários | **respondida como protocolo** | pedido item a item, com justificativa |
| **P4** | Kernel | **respondida como princípio** | recomendação = stock + APatch; candidato externo só com gate 1 verde |
| **P5** | Lista de módulos | **respondida como protocolo** | aprovação módulo a módulo na abertura |
| **P6** | Canário/AVC "melhor performance" | **proposta pendente de OK** | AVD 60 s · device 10 min · 0 AVC novo |
| **P7** | Cache "melhor performance" | **proposta pendente de OK** | inline ≤ 25 MB · retention 5 d · prune 90 d |
| **P8** | USB | **respondida** | produção: só após 10/10 no emulador |
| **P9** | **Abrir o PR** | **AGUARDANDO** | sua palavra: "autorizo o PR" |
| **P10** | Duck-ToolBox cobre fingerprint + banking (7+8)? | **AGUARDANDO** | "consolidado" (recomendado) ou "separados" |
| **P11** | Kernel de terceiro: você quer tentar algum? | **AGUARDANDO** | nome/URL ou "só stock" (padrão) |
| **P12** | Ativar o workflow em `.github/workflows/`? | **AGUARDANDO** | sim/não — hoje ele é referência, não roda |

> **P9 é a única que trava o PR.** P10–P12 podem ser respondidas depois, sem bloquear.

---

## Texto para responder (copie e ajuste)

```text
P9:  autorizo o PR
P10: consolidado (Duck-ToolBox cobre 7+8)
P11: só stock + APatch
P12: não ativar o workflow ainda
P6/P7: ok com a proposta
```
