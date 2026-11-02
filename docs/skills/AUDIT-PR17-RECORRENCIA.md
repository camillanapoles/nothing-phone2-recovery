# Auditoria do PR #17 contra o `main` mesclado (#18 + #19) — recorrência completa

<!-- contagens: histórico — relatório datado: os números da §6 são a medição do head auditado -->

**Data:** 2026-11-02 · **Base comparada:** `origin/main` = `6481ff3` (merge do #19, que já contém o
#18 em `7df226e`) · **Head auditado:** branch `arena/d528b790-nothing-phone2-recovery`
**Autorização de merge:** **não houve**. Este documento audita; não integra.

Premissa de trabalho: o `main` recebeu correções de terceiros e **pode conter erros**. Tudo aqui
foi tratado como suspeito até o comando reprovar ou passar — inclusive o que este PR escreveu.

---

## 1. Método

1. `git fetch` + `git diff origin/main...HEAD` (três pontos: o que o PR acrescenta, sem o ruído do
   merge).
2. Reconstrução da **árvore de merge** do GitHub (`refs/pull/17/merge`) num worktree separado e
   execução dos gates nela — porque é essa árvore que o CI testa, não o head da branch.
3. Para cada conceito tocado: busca de **todas** as ocorrências no repo (docs, código, CI, catálogo,
   JSON de referência) para achar duplicação, colisão de identificador e texto que passou a mentir.
4. Cada correção só entrou com: teste que quebra de propósito, mutante no catálogo e `make -s prove`
   verde. Número em documento nunca é digitado — vem de `make -s contagens`.

---

## 2. O que o diff faz (escopo)

40 arquivos, +2020/−176 contra o `main`. Grupos:

| grupo | conteúdo | por que existe |
|---|---|---|
| `audit-fsm/` (novo módulo) | `proof/ledger.py`, `cli` (`proof-start/import/finalize/verify/show/runs`), tabelas `proof_run`/`proof_item`, repositório, factory/metaclass | levar a cobertura para o FSM: sobrevive à máquina e é auditável por `run_id` |
| `audit-fsm/tests/` | unit + integration + `test_proof_layer.sh` | contrato do ledger, CLI e API provados por asserção |
| CI | `.github/workflows/proof.yml` (shards, artefato `proof-ledger`, job de relatório) | a prova roda na nuvem e o ledger é publicado |
| gates | `scripts/counts_gate.py` (CT3), `mutation_check.py --verify`, `tests/*.sh` | nenhum número escrito à mão; mutante nunca fica órfão |
| docs | `AGENTS.md`, `RECTIFICATION-PLAN.md`, `EVOLUTION-LEDGER.md`, `CHANGELOG` | rastro da mudança, sem inventar número |

---

## 3. Recorrência — onde cada conceito aparece de fato

Nada disto foi assumido: cada linha foi localizada por busca no repo.

| conceito | ocorrências | observação da auditoria |
|---|---|---|
| caminho do banco da prova | `Makefile` (`FSM_DB`), `proof.yml`, `artifact-paths.json` (`ledger_paths.proof_db`), `AGENTS.md` §4.5, `CHANGELOG` | tem de ser **um** caminho: `state/proof/fsm.db`. `workspace/` é efêmero por política (RC11) |
| `run_id` / `item_id` (uuid5) | `proof/ledger.py` (única origem), CLI, testes, docs | derivado de `source_hash:target` — reprodutível entre máquinas, não aleatório |
| exit codes do ledger | `ledger.py`, `cli`, `proof.yml`, `test_proof_layer.sh` | 0 coerente · 1 divergente · 3 insumo ausente (INCOMPLETA) |
| total do catálogo | `counts_gate.py` (deriva), `mutation_check.py`, `proof.yml` (fatia), docs (nunca literal) | nenhum doc escreve o total: quem escreve é o gate |
| ids de mutante | `mutation-catalog.json` (única fonte) | colisão do merge resolvida; `--verify` agora também checa órfão |
| marcador `contagens: histórico` | `CLAIMS-AUDIT.md` (arquivo), `EXECUTION-SEQUENCE.md` (linha), `RECTIFICATION-PLAN.md` | mecanismo do próprio repo para número datado |

---

## 4. Defeitos encontrados — e o que cada um custava

| # | sintoma | causa raiz | correção | prova |
|---|---|---|---|---|
| 1 | merge "limpo" com **ids de mutante duplicados** (`M198`/`M199` usados pelo #18 e por este PR) | dois ramos pegaram o mesmo próximo id; texto não conflita | ids de main preservados, os seis da prova renumerados | `--verify` (numeração fechada) + mutantes reexecutados |
| 2 | cobertura morria junto com a máquina | banco em `workspace/audit/` — pasta **efêmera** pelo RC11 | `state/proof/fsm.db` em todos os pontos de uso | `make -s fsm-prova` recria e audita por `run_id` |
| 3 | três contagens velhas passavam verdes no `main` | CT1 só lia par `N/N`, `N camadas`, `até M###` — **não** lia célula de tabela | CT3: par `N/N` em linha que fala de mutação/refatoração/contrato tem de ser o derivado | 3 falsificações no harness |
| 4 | mutante M196 **vivo** (sobrevivia à própria mutação) | o caso do CT3 mascarava o caso do CT1 (mesma forma textual) | formas exclusivas por família + mutante novo para o CT3 | mutação completa |
| 5 | `egg-info` **versionado** | `git add -A` durante merge pegou sobra de `pip install -e` | `*.egg-info/` no `.gitignore` + `git rm --cached` | `git ls-files` sem lixo de build |
| 6 | `--db` em diretório novo morria com *"unable to open database file"* | SQLite não cria diretório | `_garantir_diretorio()` antes do engine | teste dedicado no unit |
| 7 | #19 trouxe **relatórios datados** e o gate reprovou | números medidos em `7df226e` (outra árvore) | marcador `contagens: histórico`: arquivo para o relatório inteiro, linha para a premissa do plano vivo | gate verde sem reescrever medição |
| 8 | `--verify` aceitava **mutante órfão**: refatorar o código deixava o `find` sem alvo, o mutante virava `invalid` e a prova não provava nada | não havia checagem estática do `find`; só a execução completa descobria, 15 min depois | `padroes_orfaos()` (find existe **exatamente uma vez**) + `mutacao-verifica` no `make -s prove` | 3 casos no harness + `M207` cobrindo a checagem |
| 9 | `.tmp_sg.py` — rascunho de patch **versionado** desde o #14, sem referência nenhuma | arquivo de trabalho commitado por engano | removido + `/.tmp_*` no `.gitignore` | `ruff format --check` na raiz sem ruído |

### 4.1 O achado que o CI pegou e o local não

O #8 é o mais grave e é o único que **passou verde aqui**. A reescrita do CT3 mudou a indentação
do trecho citado no `find` do `M206`; o mutante deixou de encontrar o alvo, virou `invalid` e a
execução completa local só não viu porque tinha rodado antes da reescrita. O CI, que roda na
árvore de merge a cada push, reprovou em segundos.

Lições que viraram mecanismo (não recomendação):

- **Mutante inválido é pior que mutante vivo**: vivo ao menos aparece no relatório; inválido
  parece cobertura e não exercita teste nenhum.
- Refatoração e catálogo **não podem** ser validados em execuções separadas no tempo:
  `--verify` agora checa o `find` de cada mutante em ~1 s, dentro do `prove`.
- O local não é a árvore do CI: para auditar de verdade, reproduzir a árvore de merge
  (`refs/pull/N/merge`), não o head da branch. Foi exatamente essa diferença que explicou o
  vermelho anterior, quando o `main` andou com o #19 depois do meu último `fetch`.

---

## 5. Implicações (declaradas, não escondidas)

1. **`proof.yml` depende de `pip install -e ./audit-fsm[dev]`** — se as dependências mudarem, a
   mutação reprova por ambiente, não por lógica. Mitigado pela mensagem explícita no job, não
   resolvido.
2. **SQLite single-writer**: os shards de mutação escrevem em bancos separados; se um dia
   paralelizarem o mesmo banco, há contenção. Hoje: sequencial por banco.
3. **`/api/proof_items` sem paginação** — item a item é barato hoje porque o catálogo é pequeno;
   não é argumento para amanhã.
4. **`fsm-prova` sai 3 quando a run está incompleta** — correto por contrato, mas exige que o
   chamador distinga "ausente" de "divergente" (1).
5. **Histórico entre runs** vive num artefato por execução, não em banco remoto: a durabilidade é
   a máquina. É o limite do desenho atual, e o desenho do CI.
6. **Contagens de casos de teste** ("N casos" em cabeçalho de harness) **não são derivadas** por
   nenhum gate — a auditoria removeu o número em vez de fingir que ele é fonte de verdade.
   Fica como lacuna conhecida: qualquer doc que diga "N casos" envelhece sozinho.
7. **Tabelas de status de PR** (`EVOLUTION-LEDGER`) não são deriváveis offline. Este PR corrigiu
   as linhas que o #18 deixou em aberto, mas cada merge futuro volta a envelhecê-las: a fonte de
   verdade é `gh pr list`, não o documento.

---

## 6. Verificação (tudo reexecutado no head auditado)

```text
make -s prove                → exit 0 · [workspace] tudo verde
make -s contagens            → CT1/CT2/CT3 OK (número derivado, nunca digitado)
make -s refactor             → 11/11 coerências
make -s mutation             → catálogo inteiro morto por asserção · COMPLETA · produto 1
make -s mutacao-verifica     → numeração fechada + nenhum mutante órfão
make -s fsm-prova            → 100% dos itens provados · produto 1 · 0 correções
pytest (audit-fsm)           → 113 passed
test_proof_layer.sh          → 33 passed
test_counts_gate.sh          → 18/18 PASS
test_mutation_check.sh       → 30 PASS / 0 FAIL
CI (16 checks)               → verde
```

Nenhum número acima é digitado à mão: `make -s contagens` reprova se algum for.

---

## 7. O que **não** foi feito

- **Nenhum merge em `main`.** O PR #17 continua aberto e a decisão é da usuária.
- Nenhuma reescrita do conteúdo do #18/#19: o que é medição datada ficou datado, com marcador.
- Nenhum limiar de gate foi afrouxado para ficar verde. Onde ficou vermelho, foi encontrado
  defeito — inclusive no que este PR tinha escrito.
