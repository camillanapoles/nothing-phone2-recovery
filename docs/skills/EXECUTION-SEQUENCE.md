# Sequência de execução ampla — do gate verde ao aparelho provado

**Premissa:** cada passo abaixo é **mudança + gate falseável + teste que quebra de propósito + mutante
no catálogo**. Passo sem os três não entra. Nada é mesclado sem o seu ok.

**Ponto de partida medido (2026-11-02, `7df226e`):** 179/179 mutantes · 11/11 coerências · <!-- contagens: histórico — medição no commit `7df226e` -->
16/16 invariantes · 21 camadas · 47 passos de instalação · 13 passos de fechamento ·
débitos 6 abertos de 7 · garantia **0/5 provados** · 0 sessões com base atualizada por padrão.

---

## Grafo (o que destrava o quê)

```text
F0 base sincronizada ──┬─► F2 (N1 kptools) ──► F3 (N5 prosa) ──► F4 (números do ledger)
                       │
                       ├─► F5 (N3 S02/S03) ──► F6 (N6 install-list)
                       │
                       └─► F7 (#17 ledger durável) ──► F8 (mutação durável em main) ──► F9 (#13)

F1 decisão P1 (sua) ─────────────────────────────► F10 (prova real R9→R10→R11→garantia)
```

F1 pode rodar em paralelo a qualquer coisa. **F10 é a única fase cara** (CI de 60–90 min + aparelho).

---

## F0 — Base sincronizada, e travada por gate  ⚠️ *a falha que já se repetiu 3×*

| | |
|---|---|
| **Problema** | a branch de cada sessão nasce de `334c40a` (18 commits atrás). Um PR dali **remove** 23 arquivos e altera 34 — o "PR-reversão". Já aconteceu em 3 sessões seguidas, e **não existe gate** que olhe para `origin/main`. |
| **Mudança** | (1) `git fetch --unshallow && git merge --ff-only origin/main` no abrir de sessão (feito nesta sessão: branch em `7df226e`); (2) **S-BASE**: `scripts/base_gate.py` — reprova se `origin/main` não é ancestral de `HEAD`, listando os arquivos que seriam **apagados**; alvo `make -s base`; roda no `make -s prove` e no job de CI de contrato. |
| **Prova** | falsificação 1: numa cópia, `git checkout -B x 334c40a` → **FALHA** com a lista dos 23 arquivos; falsificação 2: repo sem `origin` → **PENDENTE** (exit 3), nunca "verde por ausência"; mutante: inverter o `is-ancestor`. |
| **Aceite** | `make -s base` verde em `main`; as 2 falsificações quebram; mutante morto; `prove` inclui o alvo. |
| **Custo / risco** | baixo. Risco: CI sem `fetch-depth: 0` → resolver com `fetch-depth: 0` no job (e o teste de PENDENTE cobre). |

## F1 — Fechar **P1** (Vanilla × GApps)  *— só você pode*

| | |
|---|---|
| **Por que primeiro** | `P1` trava download, flash e `M03`/`M07` (`debt_ledger`: "bloqueia download e flash de ROM"). É a única coisa que código nenhum resolve. |
| **Mudança** | preencher `references/decisions.json`: `build.flavor`, `build.flavor_source=user`, `build.zip_path`, `build.zip_sha256`. Depois `rom_artifact_fetch.sh --variant both` grava os pins no cache. |
| **Prova** | `session_open.py check` → **0 pendências**; `debt_ledger.py` deixa de listar `P1`. |
| **Aceite** | 0 pendências + `evox.env` com os 2 sha256. |
| **Custo / risco** | seu tempo de decisão. Nada é baixado antes disso. |

## F2 — **N1**: `kptools` sai da instrução viva e o `RC1` deixa de ser cego

| | |
|---|---|
| **Problema** | `session_open.py:34` pede `kptools` (APatch) ao usuário dentro de `P3`; o `RC1` (`refactor_gate.py:95-97`) só enxerga o token **entre aspas** — o texto vivo passa. Instrução errada com gate verde. |
| **Mudança** | (1) `P3` → `"payload-dumper-go, magiskboot, adb"`; (2) `RC1` casa o token por **palavra inteira** (`\b`), sem depender de aspas, e varre também `SKILL.md`/`session-opening.md`; (3) `TOKENS_APATCH` deixa de ser tupla de 1 item mágico e passa a derivar do `install-stack.json` (`forbidden` + `forbidden_tokens`). |
| **Prova** | falsificação: reintroduzir `kptools` em prosa → **FALHA**; falsificação: reintroduzir em `.md` vivo → **FALHA**; mutante **M200** (remover o `re.search`) e **M201** (voltar a exigir aspas). |
| **Aceite** | todas as checagens de coerência verdes, **incluindo as do RC1 reescrito**; os 2 mutantes mortos; `session_open.py` sem `kptools`. |
| **Custo / risco** | baixo (2 arquivos + 2 testes). |

## F3 — **N5**: o gate passa a ler prosa

| | |
|---|---|
| **Problema** | `INSTALL-SEQUENCE.md:5` diz "15 invariantes" (**16**), `RECTIFICATION-PLAN.md:101` diz "9 checagens" (**11**) e `:109` "(20)" camadas (**21**). O `CT1` só lê `N/N invariantes`, `RC1…RCn`, `N camadas`. |
| **Mudança** | (1) `counts_gate.py` ganha 3 padrões: `(?<!\d)(\d+)\s+invariantes\b`, `(?<!\d)(\d+)\s+checagens\b`, `\((\d+)\)\s*(?=camadas)`; (2) corrigir os 3 textos (16 / 11 / 21). |
| **Prova** | 3 falsificações (um número errado em cada formato) + 3 mutantes (um por padrão). |
| **Aceite** | `CT1` verde com prosa; mutantes mortos; nenhum número escrito à mão sobrevivendo. |
| **Custo / risco** | baixo. Risco: falso positivo em prosa legítima ("as 3 checagens de X") → o padrão exige número + palavra exata; teste cobre. |

## F4 — Corrigir números **não reproduzíveis** do próprio `EVOLUTION-LEDGER` (F1/F2 desta auditoria)

| | |
|---|---|
| **Problema** | coluna "suítes" (§1) não reproduz por nenhuma regra declarada (dá 40/42/43/44; a tabela diz 38/40/41/41); "7 versões de M03/M07/M08" não sai de `-S` (1) nem de `-G` (2). Relatório de auditoria com número sem método é o vício que o projeto combate. |
| **Mudança** | (1) declarar a regra no cabeçalho da tabela e **regerar** a coluna com ela (`tests/**/test_*.{sh,py}` sem `fixtures`); (2) trocar "7 versões" pelo número com o comando (`-G` = 2) **ou** remover a coluna; (3) anotar o comando em cada coluna derivada. |
| **Prova** | `make -s contagens` (não quebra) + revisão: cada número da tabela tem o comando ao lado. |
| **Aceite** | todo número do documento é reproduzível por um comando escrito ao lado. |
| **Custo / risco** | baixo, mas é o passo que mais protege a credibilidade dos outros. |

## F5 — **N3**: `S02`/`S03` (R8) existirem de verdade

| | |
|---|---|
| **Problema** | o R8 prometeu débitos de **slot/fingerprint** (`S02`) e **rollback** (`S03`) no `debt_ledger.py`; não existem. |
| **Mudança** | derivar os dois dos gates que já existem (`slot_router`, `guard4_verify`), com passo de fechamento no `closure-plan.json`; débito sem passo já é FALHA por desenho. |
| **Prova** | falsificação: apagar o passo `E14` → **FALHA** ("débito sem passo"); falsificação: forçar `S02` a fechado sem evidência → **FALHA**; mutantes **M202**/**M203**. |
| **Aceite** | `debt_ledger` lista `S02`/`S03` com estado real; 2 mutantes mortos. |
| **Custo / risco** | médio-baixo: exige entender o que conta como prova de slot e de rollback. |

## F6 — **N6**: carimbar o resíduo e impedir resíduo novo

| | |
|---|---|
| **Problema** | `ci-build-full/build-package/modules/install-list.txt` (último commit `4de39d5`, 31/10) manda instalar **TrickyStore** e **LSPosed**, os dois vetados no contrato. |
| **Mudança** | (1) cabeçalho **HISTÓRICO — não executar**, com data e ponteiro para `install-stack.json`; (2) **RC13**: artefato não histórico que cite módulo vetado → FALHA. |
| **Prova** | falsificação: remover o carimbo → **FALHA**; falsificação: citar `TrickyStore` num artefato vivo → **FALHA**; mutantes **M204**/**M205**. |
| **Aceite** | todas as checagens de coerência verdes, **incluindo o RC13 novo**; mutantes mortos. |
| **Custo / risco** | baixo. |

## F7 — PR **#17** (ledger de prova durável no FSM)  *— precisa do seu ok*

| | |
|---|---|
| **Por que** | é o único trabalho fora da `main` que resolve **F6 desta auditoria** (cobertura de mutação em arquivo ignorado). |
| **Mudança** | rebase em `7df226e`; rodar `prove` + `mutation` completos; se o schema do FSM conflitar com o `artifact-paths.json` (tabelas × arquivos), o `RC11` passa a cobrir também o caminho do ledger; merge com squash ou merge commit — você escolhe. |
| **Prova** | CI do PR verde (16/16 checks na última leitura); `prove` local exit 0. |
| **Aceite** | merge aprovado e `make -s mutation` reportando cobertura **do ledger**, não do arquivo. |
| **Custo / risco** | médio: é o PR mais antigo aberto; pode precisar resolver conflito em `proof.yml`. |

## F8 — Cobertura de mutação **durável** em `main` (consequência de F7)

| | |
|---|---|
| **Problema** | hoje `AGENTS.md` (12×) e `proof.yml` (5×) leem `workspace/audit/mutation*.json`. Em sessão nova, "179/179" **não é auditável a partir do repo**. |
| **Mudança** | `mutation_check.py` grava o veredito no ledger durável (FSM/`references/`), e os consumidores passam a ler de lá; o arquivo em `workspace/` vira só cache de execução. |
| **Prova** | falsificação: rodar com `workspace/` vazio → relatório **continua** completo; falsificação: adulterar um `M[id]` no ledger → **FALHA**; mutante novo. |
| **Aceite** | `rm -rf workspace && make -s mutation` deixa prova legível e verificável. |
| **Custo / risco** | médio. Depende de F7 estar mesclado; se não estiver, F8 faz o mesmo caminho "na mão". |

## F9 — Fechar **#13** (superado pelo #15)

`gh pr close 13 --comment "superado pelo #15 (escopo fechado + cobertura por M[id]); nada exclusivo aqui"`. Custo: zero. Só precisa do seu ok.

## F10 — A cadeia de prova real (a única fase caras)

| passo | o que faz | fecha | custo |
|---|---|---|---|
| **R9** | pinar a árvore do kernel (E02) e passar `--kernel-tree` | **B03** (+B04) | download + pin |
| **R10** | build no Actions → `--build-dir` e `--config-json` | **B05**, **B06**, destrava **C06** | 60–90 min de CI |
| **R11** | rollout no staging → físico, 1 módulo por vez, com evidência | **M-ROLLOUT** | aparelho + janelas de 10 min |
| **garantia** | medir R2–R5 no aparelho e registrar | **0/5 → 5/5** | decorre de R11 |

Cada um com evidência **versionada** (nunca em `workspace/`), e cada um com gate próprio já existente
(`kernel_build_gate`, `success_guarantee`, `rollout_gate`). R11 exige R10; R10 exige R9. É a ordem
que o próprio `RECTIFICATION-PLAN` §"por insumo" já declara.

---

## Definition of done da sequência

1. `make -s base` · `contagens` · `stack` · `refactor` · `arch` · `prove` · `mutation` — todos verdes, com o número de coerências **crescendo** a cada RC novo (nunca cravado em texto).
2. Zero número escrito à mão: todo número de documento tem o comando ao lado.
3. Zero débito sem passo de fechamento; `S02`/`S03` existem.
4. Nenhum artefato vivo cita módulo vetado; nenhum caminho durável em `workspace/`.
5. `debt_ledger` sem `P1` e com `M-ROLLOUT` fechado; `success_guarantee` com 5/5 medidos.
6. PRs: #17 mesclado, #13 fechado, #18 já mesclado — nenhuma branch órfã.

## O que **não** faço sem o seu ok explícito

- F7 (merge do #17) e F9 (fechar #13).
- F1 (é decisão sua: Vanilla × GApps).
- F10 (gasta CI e exige o aparelho).
- Qualquer merge, por hábito.

**Sugestão de ordem de custo-benefício:** F0 → F2 → F3 → F4 → F6 → F5 → F9 → F7 → F8 → F1 → F10.
Os cinco primeiros (F0, F2, F3, F4, F6) são baratos, fecham 3 dos 6 achados e **aumentam** o número de
coisas que o gate pega sozinho — inclusive a classe de erro que já voltou três vezes.
