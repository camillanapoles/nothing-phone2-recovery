# Instrução de continuidade — como prosseguir exatamente como esta sessão

**Branch:** `arena/863582fd-nothing-phone2-recovery` · **Skill:** `evox-rom-ci-optimizer` v3.1
**Última prova publicada:** `fec48f8` → `make -s prove` **582 casos / 29 suítes** · mutação **139/139**
**Neste documento:** `make -s prove` **619 casos** (soma a suíte nova do plano de kernel) · mutação **145/145**
**Data:** 2026-11-01 · **Alvo:** root e kernel perfeitos para DroidSpaces, integridade, root oculto,
performance e estabilidade no Nothing Phone (2) `pong` / SM8475 / EvolutionX 11.11 (A16).

Este é o documento que uma **nova sessão lê primeiro**. Ele carrega memória, método, mandato,
aprendizados, anti-padrões, o que garantir e como resolver dúvida. Ele **não** autoriza decisão de
produto em nome da usuária e **não** substitui prova: `make -s prove` verde é a evidência; este
texto é o mapa.

---

## 1. Regra de autoridade (leia antes de qualquer coisa)

1. **"O passado era erro."** Plano, instrução ou conclusão de sessão anterior **não é autoridade**.
   Toda herança é confrontada com as regras vigentes e classificada: **vigente / arquivado / proibido**.
   Arquivo antigo que contradiz o método atual é **arquivado**, nunca seguido por inércia.
2. **Fonte de verdade é o workspace + teste executável**, não a lembrança de quem escreveu.
   Se o documento diz X e o gate diz Y, vale Y — e o documento é corrigido no mesmo turno.
3. **Ordem de leitura de uma nova sessão:**
   `AGENTS.md` → este documento → `docs/skills/HANDOFF-NEXT-AGENT.md` (P1/P2/P3 e operação) →
   `docs/skills/PACK-DETERMINISM.md` (modelo derivado) → `docs/skills/KERNEL-REQUIREMENTS.md` e
   `docs/skills/KERNEL-BUILD-TEST-PLAN.md` (kernel) → `make -s prove`.

---

## 2. A verdade absoluta inequívoca (preservar em todo refactor)

> **`engine-x` + `kernel-x` fictícios são selecionados pelo solver apenas por satisfazerem o dado —
> nenhuma linha de código muda.**

Isso não é slogan, é o desenho: o solver (`root_pair_solver.py`) recebe catálogos
(`root-engines.json`, `kernel-candidates.json`, `droidspaces-requirements.json`, `hiding-stack.json`,
`module-requirements.json`) e avalia **10 condições sobre o PAR**. Nenhuma condição nomeia motor ou
kernel; o resultado muda **quando o dado muda**. Prova executável:

- 4 motores × 4 kernels = **16 pares** avaliados por dado; 3 pares empatam com pendência única `C06`.
- Cada condição tem `breaker` declarado em `references/pack-conditions.json`; o selftest quebra uma
  por vez (`make -s pack-selftest`) e **só ela** cai.
- Se um par fictício satisfizer o dado, ele é escolhido — e nenhum `if engine == ...` existe para
  impedir. Proibição só existe como **consequência provada** de condição falsa.

**Consequência operacional:** ao adicionar um kernel novo (inclusive o `custom-build-pong-ksu-susfs-droidspaces`),
não se escreve código do solver. Escreve-se **dado** (candidato + evidência) e a decisão sai do gate.

---

## 3. O que está provado hoje × o que não está

Provado e reexecutável:

| Prova | Número | Comando |
|---|---|---|
| Suítes | 582 + 35 (kernel) | `make -s prove` |
| Mutações mortas por asserção | 139 + 6 (kernel) | `make -s mutation` |
| Condições do pack com contra-exemplo | 10/10 | `make -s pack-selftest` |
| Plano do kernel: regras de plano | 20/20 (`P01`–`P20`) | `make -s kernel` |
| Plano do kernel: pré-build | 5 OK / 4 PEND (26 itens) | `make -s kernel` |
| Escopo (legado que manda **não** usar) | limpo | `make -s escopo` |

Não provado (e por isso **PENDENTE**, exit 3 — nunca "pronto"):

- **`C06`**: as **12 CONFIG_\*** exigidas pelo DroidSpaces seguem **sem prova**. Trava 3 pares empatados
  (`apatch`, `kernelsu`, `sukisu` × `custom-build-pong-ksu-susfs-droidspaces`).
- **`B01`** source sem commit pinado (`a-fixar-no-primeiro-build`) · **`B03`** árvore do kernel ausente ·
  **`B05`** evidência de configs ausente · **`B06`** artefatos de build inexistentes.
- Nenhum build do kernel do pack foi executado; logo **nenhum módulo `M01`–`M15` tem PASS**.

---

## 4. Método de ação (o mesmo desta sessão — não improvise outro)

```
condição (falseável)  →  solver por dado  →  gate (executável)  →  prova (teste + mutante)  →  PASS do módulo
```

1. **Condição antes de código.** Escreva a afirmação e o **contra-exemplo** dela. Se não há
   contra-exemplo, é decoração: **reprova** e não entra.
2. **Dado antes de regra.** Se o comportamento depende do insumo, o insumo vira arquivo JSON e a
   regra lê o JSON. Constante com nome de motor/kernel no código é defeito.
3. **Gate executável, não conselho.** Toda regra vira `check` com estado `ok`/`falha`/`pendente` e
   exit code: `0` pronto · `3` pendente · `1` falha · `4` entrada inválida.
4. **Prova em dois níveis.** (a) suíte que falha se a regra sumir; (b) **mutante** no catálogo que
   morre por asserção. Mutante que sobrevive = teste mascarado; corrige-se o teste, não o mutante.
5. **Um módulo por vez.** `M01` → PASS → `M02` → … Rollout nunca em lote. Antes do primeiro flash de
   teste: `guard4_verify.sh` (backup + sha256 do `boot.img` stock).
6. **Fechar o turno com prova.** `make -s prove && make -s mutation` verdes, commit, push, PR, merge.

---

## 5. Mandato (o que a sessão pode decidir × o que é da usuária)

**A sessão decide sozinha:** estrutura de dados, regras/gates, testes, refactor, documentação,
redação de requisito falseável, ordem técnica de execução **dentro** do que já foi autorizado.

**Depende da usuária (parar e perguntar, sem inferir):**

| Item | Estado | Regra |
|---|---|---|
| **P1** Vanilla × GApps | **aberta** | apresentar a tabela pinada e **parar**. Nunca escolher. |
| **P2** builds | fixado | exatamente as builds de **2026-09-15** (11.11). Outra build = fora de escopo. |
| **P3** | **"Sim"** (registrado) | autorização registrada; não re-perguntar. |
| **L4** | não pedir | nada de dado de L4 por parte do agente; `adb` só **read-only**. |
| **USB/físico** | gated | **nada no USB** antes de Release Artifact testado (M15) e staging AVD com PASS. |
| **"GARANTA"** | condicional | garantir = executar **condicionado à compatibilidade provada pelo gate** + decisão dela. |

---

## 6. Aprendizados (o que já custou tempo — reaproveite)

1. **`cmd | tail` mascara exit code.** Redirecione para arquivo e leia `$?`.
2. **Texto explicativo derruba o próprio gate.** Política de patch virou **enum**
   (`on_reject: fail_build|drop_patch`), não prosa varrida por `grep "force"`.
3. **`patch` só com `git apply --check`/`--dry-run`; rejeição = falha.** Exceção declarada e única:
   `004-susfs` com `on_reject: drop_patch` (build segue sem SUSFS e o fallback é anunciado).
4. **Cobertura tem que ser por item, não por grupo.** `M02/M04/...` num só item não cobre; um item
   por módulo, cada um com `check`/`expected`/`falsified_by`.
5. **Cobertura não pode vir "de graça".** No `P19`, um módulo só conta se **o plano** traz o critério
   dele com falsificação; config específica de módulo **não** vale como critério.
6. **Paridade com o pack é o antídoto do plano fossilizado.** `P06`/`B07` leem
   `droidspaces-requirements.json` como **fonte única** das 12 CONFIG_*; plano que "esquece" uma
   config morre no gate, não no device.
7. **GKI ≥5.4 sem os patches kABI (`001`, `002`) dá bootloop** ao ligar SYSVIPC/IPC/POSIX_MQUEUE —
   por isso `C07` existe separado de `C06`.
8. **Versão flutuante de action é bomba-relógio.** 7 ações pinadas por SHA de 40 hex (tag → commit
   conferido na API em 2026-11-01); `B02` reprova `@vN` sem SHA.
9. **Ferramenta genérica de "kernel build action" não serve** (`actions_avoided`): sem pin auditável,
   foco LKM ou genérica. O build vai por `run:` explícito sobre imagem DDK.
10. **Ausência de dado nunca vira "incompatível".** Kernel de terceiro sem prova é **PENDENTE**.

---

## 7. Anti-padrões — **não fazer** (lista fechada)

- ❌ **Não** escrever `if engine == "kernelsu"` / `if kernel == "..."` em solver, gate ou teste.
- ❌ **Não** criar lista de "motores/kernels proibidos". Proibição só como consequência provada.
- ❌ **Não** transformar insumo ausente em `FALHA` nem em `OK`: é **`PENDENTE` com exit 3**.
- ❌ **Não** afirmar "garantido" sem par que feche as 10 condições **e** decisão registrada.
- ❌ **Não** aplicar patch com `--force`/fuzz; **não** usar `releases/latest` como pin.
- ❌ **Não** rodar `mutation_check.py` em foreground de sessão longa sem `--only` (use `--only` para
  validar mutantes novos; o ciclo completo roda em `make -s mutation`).
- ❌ **Não** testar no físico, no USB, ou via HIL A/B como gate final (proibido). HIL só como
  diagnóstico depois de staging com PASS.
- ❌ **Não** reaproveitar variante de ROM herdada (`session_open.py auto` limpa, não herda).
- ❌ **Não** "consertar" um teste verde que passou com a lógica removida: o teste está errado.
- ❌ **Não** editar fixture por `assert old in s` sem `grep -n` do texto real; **não** heredoc bash
  com heredoc Python aninhado; **não** nome de variável de shell com acento.
- ❌ **Não** apresentar plano de kernel sem `falsified_by` por requisito e por módulo.
- ❌ **Não** misturar `M12A`/`M12B` num único PASS: CPU/GPU/thermal e NPU são provas distintas.

---

## 8. O que garantir (checklist de encerramento)

Antes de dizer "pronto":

1. `make -s prove` → tudo verde (suítes + contrato + arquitetura + skills).
2. `make -s mutation` → **todos** os mutantes mortos por asserção (0 vivo, 0 inválido, 0 só-timeout).
3. `make -s pack` → estado honesto do pack (`FALTA_PROVA` continua sendo resposta legítima).
4. `make -s kernel` → `P01`–`P20` OK; `B*` com PEND listado e **nomeado** (nunca "quase pronto").
5. `make -s audit-loop` → sem contradição, sem escopo sujo.
6. Todo número citado em documento **confere** com a execução da mesma sessão.
7. Commit + push na branch da sessão + **PR aberto e mergeado**; depois, nova sessão.

---

## 9. Como resolver dúvida (escala de decisão — nesta ordem)

1. **É dado ausente?** → `PENDENTE` (exit 3), dizendo **qual** dado falta e **onde** ele entra
   (arquivo/campo). Nunca preencher por estimativa.
2. **Está escrito no workspace?** → a resposta está no arquivo; cite caminho e linha. Não "lembre".
3. **É contradição entre dois artefatos?** → o mais novo **provado por teste** vence; o outro é
   corrigido no mesmo turno e a divergência é registrada em `docs/skills/AUDIT-CONTRADICTIONS.md`.
4. **É decisão de produto (variante, aceitar perda de performance, subir físico)?** → **perguntar**
   com dados pinados e **parar**. Não inferir por conveniência técnica.
5. **É dúvida de escopo (usar legado? outro repo?)?** → `make -s escopo`; legado listado é **proibido**
   até prova nova em contrário.
6. **Sobrou ambiguidade real e nenhuma das acima resolve?** → registrar em
   `docs/skills/PENDING-DECISIONS.md` com as opções, o custo de cada uma e a pergunta objetiva; seguir
   com o que **não** depende da resposta.

**Regra de ouro:** na dúvida entre "afirmar" e "marcar pendente", **marcar pendente** — o custo de um
pendente honesto é um turno; o custo de uma afirmação falsa é um device brickado.

---

## 10. Próximos passos ordenados (retomada imediata)

1. **Fechar `B01`**: pinar o commit (40 hex) do source escolhido no primeiro build real.
2. **Decidir o box de kernel** (`kernel-source/`, `zeroharcoderd/knowledge/`) — ver
   `KERNEL-BUILD-TEST-PLAN.md` §3: **validar × fork × descartar**, com justificativa e rollback.
   Se virar fork: entra como **candidato com pin próprio**, nunca como "mais um" kernel do pack.
3. **Buildar `custom-build-pong-ksu-susfs-droidspaces` no GitHub Actions** (draft release, SHA256SUMS,
   attestation). Só então `--build-dir` fecha `B06`.
4. **Provar as 12 CONFIG_\*** a partir do `.config` do build (ou da L4 via leitura) → `B05` fecha `C06`.
5. **Re-rodar o solver**: com `C06` provado, o empate de 3 pares se resolve **por dado**.
6. **Validar módulo a módulo** (`M01` → … → `M15`, incluindo `M12A`/`M12B`), estático → AVD → físico,
   com PASS antes do próximo e `guard4_verify.sh` antes de cada flash.
7. **P1** antes de qualquer download/flash de ROM: perguntar Vanilla × GApps e parar.
8. **Encerrar**: `make -s prove`, `make -s mutation`, commit, push, **PR + merge**, handoff.

---

## 11. Comandos de retomada

```bash
make -s prove                 # 619 casos / 30 suítes (inclui a suíte do plano de kernel)
make -s mutation              # 145 mutantes, todos mortos por asserção
make -s pack                  # solver: estado do par (motor × kernel) por dado
make -s pack-selftest         # as 10 condições caem uma por vez
make -s kernel                # plano do kernel P01–P20 + pré-build B01–B07 (exit 0/3)
make -s m05                   # contrato estático do DroidSpaces (M05)
make -s escopo                # legado que manda NÃO usar
make -s audit-loop            # AG + contradições + cobertura + suítes até convergir

python3 skills/evox-rom-ci-optimizer/scripts/kernel_build_gate.py --root . --prebuild \
  --kernel-tree <árvore> --config-json <evidência> --build-dir <artefatos>
```
