# Auditoria das afirmações — uma a uma, com evidência

<!-- contagens: histórico — relatório datado (árvore `7df226e`): números medidos naquele commit, não no de hoje -->

**Data:** 2026-11-02 · **Árvore de referência:** `7df226e` (= `main`, merge do PR #18) · **Branch:** `arena/18ca102d-nothing-phone2-recovery`

Este documento não opina: ele pega **cada afirmação feita nas mensagens anteriores**, roda o comando
que a sustenta e classifica. Vocabulário usado:

| status | significado |
|---|---|
| **CONFIRMADO** | o comando reproduz exatamente o que foi dito |
| **PARCIAL** | parte reproduz, parte não (número, escopo ou data diferente) |
| **REFUTADO** | o comando contradiz a afirmação |
| **SUPERADO** | era verdade quando foi dito e foi corrigido depois |
| **OBSOLETO** | deixou de importar porque a decisão foi tomada |

### Placar (derivado, não estimado)

Regra: uma linha por afirmação com id `A#`/`B#`/`C#`/`D#`; a contagem abaixo é gerada do próprio
documento, não escrita à mão.

| status | quantas |
|---|---|
| CONFIRMADO (3 delas com ressalva: "não durável", "recorrente", "e pior hoje") | 40 |
| PARCIAL | 6 |
| REFUTADO | 1 |
| SUPERADO | 1 |
| OBSOLETO | 2 |
| PENDENTE | 1 |
| **total de afirmações** | **51** |


Referências de contexto: **121 commits**, **18 PRs** (`gh pr list --state all`), `main` = `7df226e`.

---

## Bloco 1 — mensagem da *timeline* (`TIMELINE-AUDIT`)

| # | afirmação | status | evidência | justificativa |
|---|---|---|---|---|
| **A1** | `main` tinha `install-stack.json`, `stack_gate.py`, `refactor_gate.py`, `counts_gate.py`, `proof.yml`, `decisions.json`, `kernel/`, `release/` | **CONFIRMADO** | os 8 caminhos existem em `7df226e` | é o que dá base para o resto da auditoria |
| **A2** | a sessão nasceu de `334c40a`, **18 commits atrás**; **23 arquivos novos e 34 modificados** ausentes | **CONFIRMADO** | `git diff --name-status 334c40a d9dc14c` → **57 arquivos: 23 `A` + 34 `M`** | número exato, não aproximado |
| **A3** | um PR daquela branch para `main` **apagaria** o refactor | **CONFIRMADO** | o diff acima mostra 23 arquivos que só existem em `main`; um merge a partir da base velha os remove | não é "faltou mesclar", é reversão silenciosa |
| **A4** | "corrigi agora" — fast-forward para `d9dc14c` | **CONFIRMADO, mas não durável** | `git reflog`/histórico do PR #18; **nesta sessão a branch nasceu de novo em `334c40a`** | ver **F4**: a correção não sobrevive a uma sessão nova |
| **A5** | causa 2 (decisão em `workspace/`) fechada no **#12** com o invariante `decision_sync` | **CONFIRMADO** | `scripts/stack_gate.py:245` (`i_decision_sync`), registrado em `:302` e na lista de `:308` | invariante existe e roda |
| **A6** | causa 3 (cobertura de mutação em arquivo ignorado) **resolvida** no PR #17 | **REFUTADO** | `gh pr view 17` → `OPEN`; em `main`, `workspace/audit/mutation-latest.json` ainda é citado **12×** (incl. `AGENTS.md`) | o PR está aberto: a cobertura **não** é durável em `main` |
| **A7** | âncoras: #14 `3d66f45`, #15 `c53894d`, #16 `d9dc14c`, #17 aberto | **CONFIRMADO** | `gh pr view N --json mergeCommit` → `3d66f45a`, `c53894df`, `d9dc14c8`; #17 `OPEN` | timeline reproduzível |
| **A8** | R8 prometido e não feito: débitos `S02`/`S03` ausentes | **CONFIRMADO** | `grep -n "S0[0-9]" skills/evox-rom-ci-optimizer/scripts/debt_ledger.py` → **vazio** | promessa sem código |
| **A9** | #17 não mesclado; #13 obsoleto e aberto | **CONFIRMADO** | `gh pr list --state all` → `13 OPEN`, `17 OPEN` | — |
| **A10** | o gate não lê prosa: "15 invariantes" (são 16), "9 checagens" (eram 10), "(20)" camadas (são 21) | **CONFIRMADO — e pior hoje** | `INSTALL-SEQUENCE.md:5` ("15 invariantes"); `RECTIFICATION-PLAN.md:101` ("9 checagens"), `:109` ("(20)"); derivado atual: **16 / 11 / 21** | o texto envelheceu **mais** desde a auditoria (RC11 nasceu: 10 → 11) |
| **A11** | `install-list.txt` ainda manda instalar TrickyStore/LSPosed | **CONFIRMADO** | `ci-build-full/build-package/modules/install-list.txt:6` (TrickyStore v1.4.1), `:8` (LSPosed) | resíduo de arquitetura vetada |
| **A12** | abertos: B03, B05, B06, C06, M-ROLLOUT, P1 (6 de 7); garantia 0/5; pack com 3 empates | **CONFIRMADO** | `debt_ledger.py` → `B01 FECHADO` + 6 `ABERTO`; `success_guarantee.py --root .` → **0 provado(s) · 5 pendente(s)** | números idênticos |
| **A13** | combo: **21 camadas**, **9 fases**, **47 passos**, NikGapps Core, KSU-Next sobre `kernel-build-e03`, PIFork→TEESimulator-RS→keybox→VBMeta Fixer, **10 vetados** | **CONFIRMADO** | `install-stack.json` → `21 layers`, `9 phases`, `10 forbidden`; `INSTALL-SEQUENCE.md` → **47** linhas de passo, **9** seções `F`; `:32` (E03), `:40` (vbmeta-fixer) | contrato e doc batem |
| **A14** | prova após a mudança: stack 16/16, refactor **10/10**, contagens OK, arch OK, prove exit 0 | **CONFIRMADO** | hoje `stack_gate` = 16 invariantes; `refactor_gate` era 10 e passou a **11** com o RC11 | coerente com o momento em que foi dito |
| **A15** | 3 decisões pendentes (mergear #17, fechar #13, fazer C3–C5) e "o PR #18 não foi mergeado" | **OBSOLETO** | `gh pr view 18` → `MERGED` em 2026-11-02T19:51Z (`7df226e`) | a usuária mandou mergear; as outras duas seguem pendentes |

---

## Bloco 2 — mensagem do *ledger de evolução* (`EVOLUTION-LEDGER`)

| # | afirmação | status | evidência | justificativa |
|---|---|---|---|---|
| **B1** | sem o ff-merge do turno anterior, o PR reverteria 57 arquivos | **CONFIRMADO** | mesma medição de A2/A3 | — |
| **B2** | método por linha de vida sobre **118 commits e 17 PRs** | **PARCIAL** | hoje: **121 commits, 18 PRs** | era o número do momento; cresceu com o #18 |
| **B3** | tabela de crescimento: suítes 38/40/41/41 · scripts 46/48/49/50 · mutantes 160/168/172/177 | **PARCIAL** | scripts e mutantes **exatos**; **suítes não reproduzem**: regra declarada (`.sh`/`.py` sob `tests/`, sem fixtures) dá **40/42/43/44** | ver **F1**: coluna sem regra reproduzível |
| **B4** | catálogo quadruplicou (**47 → 177**) e as **21 camadas nasceram no #11** | **CONFIRMADO** | catálogo nasce em `b5c5aed` com **47** mutantes; `install-stack.json` nasce em `1a2dc69` (PR #11) já com **21 camadas / 9 fases** | "quadruplicou" é literal |
| **B5** | motor: A (apatch+stock) `1d75f67` → C (kernelsu+build) `975b296` → derivado pelo solver `fec48f8` | **CONFIRMADO** | `git log -- root-decision.json` → exatamente esses 3 commits | linha de vida exata |
| **B6** | ocultação: 5 versões; camadas `susfs / ksu-app-profile / zygisk-next / nohello` em `3ecfe3b` | **CONFIRMADO** | `hiding-stack.json` tem **5** versões; `git show 3ecfe3b:…hiding-stack.json` → ids `['susfs','ksu-app-profile','zygisk-next','nohello']` | idem |
| **B7** | integridade: Tricky Store até `3ecfe3b`, vira TEESimulator-RS + `proof_token`; "**7 versões de M03/M07/M08**" | **PARCIAL** | `proof_token` aparece **4×** no `install-stack.json` de `3ecfe3b` ✔; "7 versões" **não reproduz**: `git log -S '"M03"'` = 1, `-G` = 2 | ver **F2**: o "7" não tem método que o devolva |
| **B8** | combo nasceu **completo** no #11 (21/9/47) e não mudou de conteúdo | **CONFIRMADO** | `1a2dc69` já traz 21 camadas e 9 fases; a sequência tem 47 passos hoje | o que mudou foram os **gates**, não o combo |
| **B9** | plano de fechamento: 12 → **13** passos (`E13`) | **CONFIRMADO** | `closure-plan.json` hoje: 13 passos, último `E13`; em `334c40a`: **12** | — |
| **B10** | template de sessão deixou a lista fixa e **deriva do contrato** | **CONFIRMADO** | `session_open.py:57` — "Os módulos do template vêm do CONTRATO (install-stack.json), não de lista fixa" | — |
| **B11** | `proof.yml`: 5 versões em **1h39** | **CONFIRMADO** | `git log --format='%h %ad'` → 5 commits de `15:20` a `16:59` | 1h39 exatos |
| **B12** | **N1**: `kptools` ainda é pedido ao usuário e o `RC1` é cego (compara **com aspas**) | **CONFIRMADO** | `session_open.py:34` — `"payload-dumper-go, kptools, magiskboot, adb"` (sem aspas); `refactor_gate.py:95-97` testa `f'"{t}"' in sis` | o token vivo **não** é visto pelo gate |
| **B13** | **N2**: causa-raiz "decisão em `workspace/`" apenas **mitigada**; `check` dava precedência ao arquivo ignorado (2 vs 12 pendências) | **SUPERADO** | `session_open.py` não cita mais `workspace/decision.json`; `:248` usa `DECISION_TRACKED`; teste cobre o caso (`test_session_open.sh`, 20/20) | fechado em `ec8e3cb` |
| **B14** | **N3**: `S02`/`S03` do R8 nunca implementados | **CONFIRMADO** | mesmo `grep` de A8 → vazio | segue aberto |
| **B15** | **N4**: o banner SUPERSEDIDO nasceu no **#12** (`4720006`), não no #14 | **CONFIRMADO** | `git merge-base --is-ancestor 4720006 e682d818` (`e682d818` = merge do #12) → **SIM** | atribuição corrigida |
| **B16** | **N5**: `CT1` não casa "$N invariantes", "$N checagens", "($N)" | **CONFIRMADO** | `scripts/counts_gate.py:99-120` — padrões só para `N/N invariantes`, `RC1…RCn`, `N camadas` | formatos de prosa ficam fora |
| **B17** | **N6**: `install-list.txt` congelado em 31/10 | **CONFIRMADO** | último commit do arquivo: `4de39d5`, **2026-10-31** | "congelado" é literal |
| **B18** | das 13 afirmações da sessão anexa: 9 confirmadas, 2 refutadas, 2 corrigidas | **PARCIAL** | o anexo não está versionado; a lista item a item não é reproduzível a partir do repo | número não auditável hoje — **não** deve ser citado como prova |
| **B19** | prova: contagens OK · stack 16/16 · refactor 10/10 · arch OK · prove exit 0 | **CONFIRMADO** | `make -s contagens` → `16 invariantes`; `make -s prove` exit 0 | — |
| **B20** | "preciso do seu ok para 5 correções + #17 + #13; nada foi mergeado" | **OBSOLETO** | #18 mesclado; as 5 correções **não** foram feitas | pedido substituído pelo desta mensagem |

---

## Bloco 3 — mensagem do *workspace*

| # | afirmação | status | evidência | justificativa |
|---|---|---|---|---|
| **C1** | nada de `workspace/` foi jamais versionado (log vazio, nenhuma ref, sem stash) | **CONFIRMADO** | `git log --all --diff-filter=A -- 'workspace/*'` → **0**; `git stash list` → **0** (repo já *unshallowed*: 121 commits) | não há o que recuperar |
| **C2** | os 7 arquivos do workspace eram regeneráveis; `evox.env` (pins) era a perda real | **CONFIRMADO (diagnóstico)** | `rom_artifact_fetch.sh` gera `evox.env`; `audit_loop.sh`/`mutation_check.py` geram os 6 JSONs | classe de risco, não valor recuperável |
| **C3** | `artifact-paths.json` classifica **todo** caminho do workspace | **CONFIRMADO** | arquivo existe; **11** caminhos em `work_paths` (`ephemeral`/`derived`), **7** nomes em `forbidden_in_work` | é o mapa que o RC11 consome |
| **C4** | decisão versionada; `check` sem precedência; `template` recusa sobrescrever (exit 4) | **CONFIRMADO** | `session_open.py:129,212,224,248`; `test_session_open.sh` 20/20 (2 casos novos) | regressão do P1 fica travada por teste |
| **C5** | ledger de rollout versionado, resolvido a partir do script (não do cwd) | **CONFIRMADO** | `rollout_gate.sh:26` (`$HERE/../references/rollout-ledger.json`); `test_rollout_gate.sh` 14/14 | PASS de módulo deixa de evaporar |
| **C6** | ROM + pins em `${EVOX_CACHE:-$HOME/.cache/evox}/` | **CONFIRMADO** | `rom_artifact_fetch.sh:22-23` | fora do repo e fora do workspace |
| **C7** | "22 consumidores/docs reescritos" | **PARCIAL** | `git show --name-only ec8e3cb` → **30 arquivos** (3 são testes) | subestimou; ver **F3** |
| **C8** | `RC11` reprova 3 coisas (não classificado, nome durável, alvo durável ausente) | **CONFIRMADO** | `refactor_gate.py` (`rc11_nada_duravel_no_workspace`); 11/11; teste 21/21 | — |
| **C9** | provas: prove exit 0 · mutação **179/179** · refactor 11/11 · testes 21/21, 20/20, 14/14 | **CONFIRMADO** | reexecutado em `7df226e` nesta sessão (ver §"Prova final") | — |
| **C10** | na 1ª versão o teste do RC11 **não matava** o M198 e o regex truncava caminhos aninhados | **CONFIRMADO** | mutante M198 hoje `MORTO`; regex atual inclui `/` (`workspace/[A-Za-z0-9_./\-]+`) | defeito pego pelo próprio mutante |
| **C11** | abertos N1/N3/N5/N6; "PR #18 atualizado, não mesclado" | **PARCIAL** | os 4 achados seguem abertos ✔; **#18 foi mesclado** | metade obsoleta |

---

## Bloco 4 — mensagem do *merge*

| # | afirmação | status | evidência | justificativa |
|---|---|---|---|---|
| **D1** | todos os checks passaram, 0 pendentes | **CONFIRMADO** | 8 shards de mutação + `prove` + contrato + relatório + lint + CVE verdes antes do merge | registrado no PR |
| **D2** | #18 `MERGED` em 19:51Z, merge `7df226e`, conteúdo `f45b822`/`3a72dd7`/`ec8e3cb` | **CONFIRMADO** | `gh pr view 18 --json state,mergedAt,mergeCommit` | — |
| **D3** | o `.git` voltou ao clone inicial (`334c40a`) e foi consertado com `reset --mixed` | **CONFIRMADO — e recorrente** | nesta sessão o clone **de novo** veio em `334c40a` (shallow, 1 commit visível) | ver **F4** |
| **D4** | `workspace/` deixou de ser ponto único de falha | **CONFIRMADO** | 143 ocorrências de `workspace/` em 41 caminhos, **todas classificadas**; `workspace/decision.json` só em 6 docs históricos + 2 testes | RC11 impede recaída |
| **D5** | oferta de começar pelo **N1** | **PENDENTE** | a usuária pediu auditoria completa antes | virou **F2** da sequência |

---

## Achados novos desta auditoria (F1–F7)

| # | achado | evidência | consequência |
|---|---|---|---|
| **F1** | a coluna **"suítes"** do `EVOLUTION-LEDGER` §1 **não é reproduzível** | regra declarada (`.sh`/`.py` sob `tests/`, sem fixtures) em `b2fee8d`…`f45b822` dá **38/40/41/42/42/43/43/44/44**; a tabela diz **36/38/39/40/40/41/41/41/41** | número sem regra é exatamente o que o `CT1` existe para impedir — **corrigir ou remover a coluna** |
| **F2** | "**7 versões** de M03/M07/M08" não tem método que devolva 7 | `-S '"M03"'` = 1 · `-G '"M03"'` = 2 · commits do catálogo inteiro = 6 | idem: ou se declara o comando, ou o número sai |
| **F3** | "22 consumidores/docs" foram, na verdade, **30 arquivos** | `git show --name-only ec8e3cb` | erro de contagem em relatório de entrega |
| **F4** | a **base velha é sistêmica**, não um acidente | 3ª vez que a branch nasce em `334c40a`; **nenhum gate** compara com `origin/main` (`grep -rn "origin/main\|merge-base" scripts/ …` → vazio) | precisa de **S-BASE**: gate que reprova branch sem `main` — senão o PR-reversão volta |
| **F5** | o texto do `RECTIFICATION-PLAN` envelheceu **depois** da auditoria | diz "9 checagens"; hoje são **11** (RC11 nasceu) | N5 é pior do que foi reportado |
| **F6** | a durabilidade da **cobertura de mutação** não existe em `main` | PR #17 `OPEN`; `AGENTS.md` e `proof.yml` leem `workspace/audit/mutation-*.json` (12 + 5 citações) | em sessão nova, "179/179" não é auditável a partir do repo |
| **F7** | **P1 aberto** não é a regressão do #12 | `debt_ledger.py`: P1 pede `build.zip_path`/`zip_sha256` — **conteúdo**, não mecanismo; o mecanismo está travado por teste | não confundir "decisão pendente da usuária" com "bug voltou" |

---

## Quais arquivos permanecem com segurança determinística

Pergunta direta: **o que sobrevive a uma sessão nova, e o que garante isso?**

| classe | arquivo(s) | onde vive | o que garante | o que quebraria |
|---|---|---|---|---|
| **durável versionado** | `references/decisions.json` · `references/rollout-ledger.json` · `references/install-stack.json` · `references/module-requirements.json` · `references/hiding-stack.json` · `references/closure-plan.json` · `references/artifact-paths.json` | Git (`main`) | `RC11` (alvo durável ausente = FALHA) + `RC9` (ledger aponta decisão versionada) + testes 20/20 e 14/14 | commit que mova esses arquivos para `workspace/` reprova o gate |
| **cache persistente** | zips vanilla/GApps (~2,4 GB) · `rom-artifacts.lock.json` (sha256/bytes/URL) · `evox.env` (pins) | `${EVOX_CACHE:-$HOME/.cache/evox}/` | `rom_artifact_fetch.sh` (drift = exit 4) + default resolvido por `EVOX_CACHE` | reset da **máquina** (não da sessão); aí o pin é refeito e conferido contra o sha256 conhecido |
| **derivado (reconstruível)** | `workspace/out` · `extracted` · `rom_assets` · `l4` · `backup` · `staging` · `kernels` | `workspace/` | classificados como `derived` no `artifact-paths.json`, com o comando de regeneração declarado | nada — por definição, voltam do cache |
| **efêmero (por execução)** | `workspace/audit/*.json` · `workspace/evidence/` · `workspace/conflict_report.json` | `workspace/` | classificados como `ephemeral`; o **veredito** deve ir para o ledger | hoje o veredito de mutação **só** existe aí → **F6** (depende do PR #17) |

Resumo do que **está** garantido: decisão, contrato, ledger de rollout, mapa de caminhos e pins — por
gate + teste + commit. O que **não** está: a cobertura de mutação (arquivo ignorado, PR #17 aberto) e
qualquer coisa que dependa do aparelho (garantia 0/5).

---

## Prova final (reexecutada em `7df226e`, nesta sessão)

```text
make -s contagens → OK · 179 mutantes · até M199 (próximo M200) · 21 camadas · 16 invariantes · 11 coerências · 13 passos
make -s stack     → 16/16 invariantes (verdict OK)
make -s refactor  → 11/11 coerências (verdict OK)
make -s prove     → exit 0  ([workspace] tudo verde)
make -s mutation  → 179/179 mortos por asserção · cobertura COMPLETA
```

> Nota de método: este documento cita caminhos sob `workspace/` de propósito — é um **relatório
> datado**. Ele está na lista `historical` do `artifact-paths.json` (junto de `TIMELINE-AUDIT`,
> `EVOLUTION-LEDGER`, `RECTIFICATION-PLAN`), portanto **não** é consumidor vivo e não é varrido pelo
> `RC11`. Documento vivo que cite esses caminhos **reprova** o gate.
