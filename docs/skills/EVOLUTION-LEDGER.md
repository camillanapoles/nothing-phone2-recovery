<!-- contagens: histórico -->
# Ledger de evolução — cada item, do nascimento ao estado atual

**Data:** 2026-11-02 · **Branch:** `arena/e12a269b-nothing-phone2-recovery` (= `main` `d9dc14c` + esta auditoria)
**Objeto:** a sessão anexa (8 turnos) **no contexto de todo o histórico** — 118 commits, 17 PRs.
**Marcador `contagens: histórico` acima:** os números aqui são retrato datado (o `CT1` os ignora de propósito).
Medir de novo: `make -s contagens`.

> **Por que esta auditoria existe.** A anterior comparou *snapshot × snapshot* (branch × `main`) e
> concluiu "faltam 23 arquivos". Isso é verdade para a branch, mas **não é a história do projeto**:
> o repositório cresceu incrementalmente em 17 PRs, e a sessão anexa é apenas o **último quarto**
> dessa linha do tempo. Comparar o fim com o meio acusa "falta" onde houve **nascimento depois**.
> Este documento corrige o método: **cada item tem sua própria linha de vida**, com o commit que o
> criou, cada mudança e o estado de hoje.

---

## 0. O que foi realizado até aqui (recap verificável)

**Turno anterior desta sessão (PR #18):**
1. Diagnóstico do "erro de arquitetura": a branch nasceu de `334c40a`, 18 commits atrás de `main`.
2. **Correção aplicada:** `git merge --ff-only main` → a árvore passou a conter o contrato
   (`install-stack.json`), os gates (`stack_gate`, `refactor_gate`, `counts_gate`), o CI de prova e o
   material do kernel. Sem isso, qualquer PR daqui **reverteria** 57 arquivos.
3. Documento `docs/skills/TIMELINE-AUDIT.md` (timeline + aplicado/não aplicado/pendente).
4. Prova: `stack` 16/16 · `refactor` 10/10 · `contagens` OK · `arch` OK · `prove` exit 0.

**Este turno (auditoria de evolução):** reconstrução da linha de vida de 14 itens a partir do
`git log` (sem opinião: `--diff-filter=A`, `-S`, `git show <sha>:<path>`), verificação das afirmações
da sessão anexa e **6 achados novos** (§5). Dois deles mostram que uma "correção" registrada como
pronta é **parcial** — o tipo de coisa que só a evolução item a item revela.

---

## 1. Por que "comparar snapshots" mentiria — o crescimento medido

| marco | PR | suítes `.sh`/`.py` | scripts | mutantes | camadas | passos |
|---|---|---|---|---|---|---|
| `b2fee8d` | #8 continuidade | 36 | 44 | 150 | — | — |
| `cf2389d` | #9 débitos + plano | 38 | 46 | 160 | — | — |
| `ec1d886` | #10 pin do kernel | 39 | 47 | 165 | — | — |
| `0681b19` | #11 contrato | 40 | 48 | 168 | **21** | **47** |
| `e682d81` | #12 decisão versionada | 40 | 48 | 169 | 21 | 47 |
| `3d66f45` | #14 refactor gate | 41 | 49 | 172 | 21 | 47 |
| `c53894d` | #15 escopo fechado | 41 | 49 | 175 | 21 | 47 |
| `d9dc14c` | #16 zero hardcoded | 41 | 50 | 177 | 21 | 47 |
| `f45b822` | #18 auditoria | 41 | 50 | 177 | 21 | 47 |

Leitura: o catálogo de mutação **quadruplicou** (47 → 177); as camadas do contrato **nasceram no #11**
(`—` antes disso). Um documento escrito antes do #11 que fale de "fila M01–M15" não está *errado* —
está **anterior**. É exatamente a confusão que a usuária pediu para evitar.

---

## 2. Espinha dorsal: o que cada PR criou

| PR | criado → mergeado (UTC) | commits | O que nasceu neste PR (evidência) |
|---|---|---|---|
| #7 | 11-01 21:16 → 11-02 02:30 | 24 | plano do kernel P01–P20/B01–B07, pack por 10 condições, Decisão A→C, `success_guarantee`, `hiding-stack`, `module-requirements` |
| #8 | 11-02 02:49 | 1 | instrução de continuidade v1.1 + `continuity_gate` |
| #9 | 11-02 03:06 | 1 | `debt_ledger.py`, `closure-plan.json` (**12 passos E01–E12**) |
| #10 | 11-02 11:19 | 1 | E01/E02: pin real da árvore (`4ec5491f…`), `kernel/` + `release/` pinados por sha256 |
| #11 | 11-02 14:44 | 1 | **`install-stack.json` + `stack_gate.py`** (21 camadas · 9 fases · 47 passos) e a leitura humana `INSTALL-SEQUENCE.md` |
| #12 | 11-02 14:50 | 1 | **`decisions.json`** (versionado) + invariante `decision_sync` + `RECTIFICATION-PLAN.md` + banner SUPERSEDIDO + M189 |
| #13 | 11-02 15:10 → **aberto** | — | prova em nuvem item a item (774 itens) — **superado pelo #15** |
| #14 | 11-02 15:20 → 15:40 | 5 | **`refactor_gate.py` RC1–RC9**, **`proof.yml`**, R2–R8, `proof_token` nas camadas de integridade, `E13` no plano, M190–M192 |
| #15 | 11-02 16:21 → 16:45 | 2 | escopo fechado (`--only` inválido = exit 4), ledger por `M[id]`, **RC10**, auto-id, M193–M195 |
| #16 | 11-02 16:59 → 17:23 | 1 | **`counts_gate.py`** (`make -s contagens`), M196–M197, CI com `shards` como input |
| #17 | 11-02 18:25 → **aberto** | — | ledger de prova durável no FSM (`proof_run`/`proof_item`, `run_id`) — **não mesclado** |
| #18 | 11-02 19:23 → **aberto** | 1 | esta auditoria (timeline) |

*(#1–#6 são de 2026-10-30, correções de CI/docs por Copilot — não tocam a arquitetura.)*

---

## 3. Evolução item a item

### 3.1 Motor de root e kernel — a decisão mudou duas vezes e depois virou derivada

`references/root-decision.json`:

| quando | `decision` | `engine` | `kernel` | commit |
|---|---|---|---|---|
| 11-01 22:15 | **A** | `apatch` | `stock-rom` | `1d75f67` |
| 11-01 23:34 | **C** | `kernelsu` | `custom-build` | `975b296` (A superseded) |
| 11-02 00:10 | — (gerado) | — | — | `fec48f8` |

**Estado atual:** o arquivo é **derivado** (`generated_by: root_pair_solver.py`), sem decisão escrita à
mão; hoje `verdict: FALTA_PROVA` com **3 pares empatados** (apatch/kernelsu/sukisu × build próprio),
todos só com `C06` aberto. A decisão operacional vive no contrato (§3.2), não aqui — de propósito.

### 3.2 O combo/sequência — nasceu completo no #11 e não mudou de conteúdo desde então

`references/install-stack.json` (3 versões):

| quando | camadas | fases | passos | vetados | engine | hiding |
|---|---|---|---|---|---|---|
| `1a2dc69` (#11) | 21 | 9 | 47 | 10 | `teesimulator-rs-enhanced` | `susfs+ksu-app-profile+zygisk-next` |
| `4720006` (#12) | 21 | 9 | 47 | 10 | idem | idem |
| `3ecfe3b` (#14) | 21 | 9 | 47 | 10 | idem | idem |

O que mudou no #14 foi **forma, não conteúdo**: `proof_token` entrou nas 4 camadas de integridade
(`1a2dc69`: 0 ocorrências → `3ecfe3b`: 4) e o JSON foi reformatado. **Conclusão:** o combo ratificado
é estável desde 11-02 14:43; o que evoluiu depois foram **os gates que o cobram**.

### 3.3 Ocultação — topologia APatch → KSU-Next (mudança estrutural real)

`references/hiding-stack.json`:

| quando | camadas | commit |
|---|---|---|
| 11-01 22:39 | `apatch-native`, `zygisk-next`, `zygisk-assistant` | `cdb960f` |
| 11-01 23:34 (Decisão C) | `susfs`, `apatch-native`, `zygisk-next`, `zygisk-assistant` | `975b296` |
| 11-02 14:50 (R1, só diagnóstico) | idem | `4720006` |
| 11-02 15:20 (**R4**) | `susfs`, `ksu-app-profile`, `zygisk-next`, `nohello` | `3ecfe3b` |

### 3.4 Integridade — Tricky Store morre no #14, não antes

`module-requirements.json` (M07/M08) e `success_guarantee.py`:

| quando | M07 `compliance_base` | M08 `compliance_base` | `success_guarantee` cita |
|---|---|---|---|
| 11-01 22:26–23:34 | `["PlayIntegrityFork (custom.pif.json)"]` | `["Zygisk Next","Tricky Store","PlayIntegrityFork"]` | **"Tricky Store"** = True |
| 11-02 15:20 | `["PlayIntegrityFork","TEESimulator-RS","keybox.xml","VBMeta Fixer"]` | idem | "Tricky Store" = **False**, "TEESimulator" = **True** |

M03: `"GApps A16 (serviços Google)"` → `"NikGapps Core (5 componentes)"` no mesmo commit.
**Aqui está a prova de que o R2/R3 do plano rodou — e de quando.**

### 3.5 Template de abertura de sessão — passou a derivar do contrato, mas não em tudo

`session_open.py`:

| quando | módulos do template | `kptools` |
|---|---|---|
| 11-01 18:43 → 11-02 14:50 | lista fixa `M01…M15` (16 itens) | **sim** (P3 e SKELETON) |
| 11-02 15:20 | **deriva de `install-stack.json`** (`_modulos_do_contrato`) | **sim** (`QUESTIONS` P3, linha 33) |

⚠ **Parcial** — ver §5/N1: os módulos deixaram de ser lista fixa, mas a pergunta P3 continua pedindo
autorização para instalar `kptools` (ferramenta de patch do **APatch**), sob decisão KSU-Next.

### 3.6 Plano de fechamento — 12 → 13 passos

`closure-plan.json`: `E01…E12` (`334c40a`) → `E01…E13` (`3ecfe3b`), onde `E13` roda
`stack_gate.py` + `refactor_gate.py`. `make -s closure` hoje valida **13** passos (K16 documentado).

### 3.7 Catálogo de mutação — 47 → 177, com numeração fechada

| quando | ativos | aposentados | último id |
|---|---|---|---|
| 11-01 20:18 | 47 | 0 | M47 |
| 11-01 21:15 | 102 | 0 | M102 |
| 11-01 23:34 | 134 | 0 | M134 |
| 11-02 00:10 | 139 | 19 | M159 |
| 11-02 03:06 (`334c40a`) | 160 | 19 | M180 |
| 11-02 14:50 (`4720006`) | 169 | 19 | M189 |
| 11-02 15:20 (`3ecfe3b`) | 172 | 19 | M192 |
| 11-02 16:20 (`4be0953`) | 175 | 20 | M195 |
| 11-02 16:59 (`78fb0a5`) | **177** | 20 | **M197** |

Os 19 → 20 aposentados marcam a **lacuna M158** fechada no #15 (`--verify` a encontrou).
Os 5 saltos de 160→177 vêm dos mutantes dos próprios gates novos (M190–M197).

### 3.8 Escopo de validação — "0 de 0 executados" deixou de ser "passei"

| antes do #15 | depois do #15 |
|---|---|
| `--only M186,M187,M188` (fora do catálogo) → `exit 0` | id inválido → `exit 4`; misturado com válido → `exit 4`; parte sem `--shard` → `exit 3` |
| rodada sem ledger | `workspace/audit/mutation-latest.json` reescrito do zero, `value` 1/0 por `M[id]`, `product`, `missing` |

### 3.9 "Zero hardcoded" — o gate nasceu no #16 e já pagou no dia do nascimento

`scripts/counts_gate.py` (`78fb0a5`): deriva `len(mutants)`, `max(ids)`, `len(layers)`,
`len(stack_gate.checks)`, `len(refactor_gate.checks)`, `len(steps)` e compara com o texto de
`AGENTS.md`, `docs/**` e `.github/workflows/*`. No PR #16 ele reprovou 3 documentos no ato.

### 3.10 A decisão saiu do diretório ignorado — mas só na leitura (§5/N2)

| quando | evento | commit |
|---|---|---|
| 11-01 18:43 | `session_open.py` nasce escrevendo `workspace/decision.json` | `0ad9b97` |
| 11-01 21:15 | `.gitignore` ganha `work/` + `workspace/` (ignora tudo) → arquivo fica **invisível** | `6c5b7a3` |
| 11-02 03:06 | `debt_ledger` passa a reportar `P1` como "decisão ausente" a cada troca de branch | `334c40a` |
| 11-02 14:50 | **R1**: `references/decisions.json` versionado + `decision_sync` | `4720006` |
| 11-02 15:20 | `success_guarantee`/`module-requirements` passam a consultar o contrato (não o arquivo local) | `3ecfe3b` |

### 3.11 CI de prova — 5 versões em 1h39

`proof.yml`: `3ecfe3b` (nascimento) → `ebbc630` (só a linha `shards=` em `$GITHUB_OUTPUT`) →
`66b726a` (anota sobrevivente e falha) → `4be0953` (escopo por plano) → `78fb0a5` (`shards` como input).
Todas as quatro correções nasceram de **falha real no runner**, não de revisão de estilo.

### 3.12 Artefatos que **nunca** evoluíram (e deviam)

| artefato | nasce | mudanças | conteúdo hoje |
|---|---|---|---|
| `ci-build-full/.../install-list.txt` | 10-31 03:32 (`4de39d5`) | **1** (nunca editado) | manda instalar **ZygiskNext → TrickyStore → PIFork → LSPosed → Droidspaces** |
| `debt_ledger.py` com `S02`/`S03` (R8) | 11-02 03:06 | 2 | `S02=False S03=False` — **nunca implementado** |

### 3.13 Fila antiga marcada como histórica — no #12, não no #14

`APPROVED-INSTALL-SEQUENCE.md`: 136 → 224 linhas ao longo de 6 commits; **`SUPERSEDIDO` aparece em
`4720006` (#12)**, um commit antes do refactor gate. Correção de atribuição em relação à auditoria
anterior (que creditava o banner ao #14).

### 3.14 Documentos vivos × retratos

Nasceram/atualizaram no mesmo período, mas com papéis diferentes: `ARCHITECTURE-DECISION.md`
(14 mudanças, Decisão A → C), `CONTINUITY-INSTRUCTION.md` (7), `RECTIFICATION-PLAN.md` (4, é o
plano R1–R11), `INSTALL-SEQUENCE.md` (**1 mudança: nasceu pronto no #11**). Onde o item é retrato,
ele **deve** envelhecer — mas então precisa do marcador de histórico.

---

## 4. Verificação das afirmações da sessão anexa

| Afirmação da sessão | Evidência no git | Veredito |
|---|---|---|
| "`success_guarantee` não cita mais Tricky Store" | `3ecfe3b`: `'Tricky Store'` False, `'TEESimulator'` True | **CONFIRMADO** |
| "M03 = NikGapps Core; M07/M08 = PIFork + TEESimulator-RS + keybox + VBMeta" | idem, mesmo commit | **CONFIRMADO** |
| "hiding-stack → susfs/ksu-app-profile/zygisk-next/nohello" | `3ecfe3b` | **CONFIRMADO** |
| "template de sessão = camadas do contrato" | `_modulos_do_contrato` em `3ecfe3b` | **CONFIRMADO** (para módulos) |
| "**sem kptools**" | `session_open.py:33` (QUESTIONS P3) ainda cita `kptools` | **REFUTADO** (§5/N1) |
| "R6: fila antiga SUPERSEDIDA (#14)" | banner em `4720006` (#12) | **CONFIRMADO com correção de atribuição** |
| "R8: S02/S03 no ledger" | `debt_ledger.py`: `S02=False S03=False` nas 2 versões | **REFUTADO** (§5/N3) |
| "172/172 mortos" | catálogo em `3ecfe3b`: 172 ativos | **CONFIRMADO** (hoje 177 — superado) |
| "`prove` 770 PASS / 36 suítes" | #14 | **CONFIRMADO** no marco (hoje maior) |
| "RC1 cobre Tricky Store, Zygisk Assistant **e kptools**" | `forbidden` tem 10 ids **sem** `kptools`; RC1 procura `"kptools"` **com aspas** | **PARCIAL/REFUTADO** (§5/N1) |
| "`--only` inválido → exit 4" | `mutation_check.py` pós-`4be0953` | **CONFIRMADO** |
| "limites derivados, nada digitado" | `counts_gate.py` | **CONFIRMADO** (com a ressalva §5/N5) |

---

## 5. Achados novos desta rodada (o que só a evolução mostra)

**N1 · `kptools` continua pedido ao usuário — e o gate não vê.**
`session_open.py:33` (`QUESTIONS`, P3) diz: *"Autorizo instalar (item a item…): payload-dumper-go,
**kptools**, magiskboot, adb"*. `kptools` é ferramenta de patch do **APatch**, decisão revogada.
O `RC1` deveria pegar (`TOKENS_APATCH = ("kptools",)`), mas compara `f'"{t}"'` — **com aspas** — e a
ocorrência viva está dentro de uma frase. Além disso `kptools` **não está** na lista `forbidden`
do contrato (10 ids), então `RC1` também não o herdaria por lá. **Gate verde com instrução viva
errada** — o caso mais perigoso de todos, porque é silencioso.

**Provado por experimento** (duas cópias da árvore, mesmo gate):

| variante | `RC1` |
|---|---|
| `INSTALLS_EXTRA = ["kptools"]` (com aspas) | **FALHA** — `session_open.py: instala 'kptools' (APatch) sem decisão que o adote` |
| texto real do repo (`… payload-dumper-go, kptools, magiskboot, adb`, sem aspas) | **OK** — passa |

Ao corrigir, o mutante tem de reproduzir **esse** caso: sem aspas, RC1 reprova.

**N2 · A causa-raiz "decisão em caminho ignorado" está mitigada, não fechada.**
- `session_open.py template|auto` **ainda escreve** por padrão em `workspace/decision.json` (linhas
  211 e 219).
- `check` usa o registro versionado **mas dá precedência** ao arquivo ignorado se ele existir
  (`elif os.path.exists("workspace/decision.json")`).
- **5 documentos** ainda mandam ler `workspace/decision.json`
  (`ARCHITECTURE-DECISION.md:176`, `HANDOFF-NEXT-AGENT.md:59`, `NEXT-SESSION-REPORT.md:77,86,211`,
  `FINAL-ORCHESTRATION-REPORT.md:59`).
Ou seja: a regressão do `P1` **pode voltar** na próxima sessão que rodar `auto`. O `decision_sync`
protege a leitura do contrato, não a escrita.

**Provado por experimento** (mesma árvore, dois estados):

| estado | `session_open.py check` |
|---|---|
| só o registro versionado | `PENDENTE — 2 itens: build.zip_path, build.zip_sha256` |
| com `workspace/decision.json` presente (stub de 1 linha) | `PENDENTE — **12 itens**` — `flavor` volta a "ausente" e o `P1` **regride** |
| `check --json` | `"file": "workspace/decision.json"` — confirma a precedência |

É o mesmo defeito do #12, ainda reproduzível: arquivo ignorado **sobrescreve** a fonte versionada.

**N3 · R8 nunca foi aplicado** — `S02`/`S03` seguem fora do `debt_ledger.py` (2 versões, zero
ocorrências). O plano de retificação os anuncia como "débito novo a aparecer no ledger".

**N4 · Atribuição corrigida:** o banner SUPERSEDIDO nasceu no #12, não no #14 (§3.13).

**N5 · O `CT1` cobre padrões, não prosa.** `INSTALL-SEQUENCE.md:5` diz "confere **15** invariantes"
(são 16); `RECTIFICATION-PLAN.md:101` diz "**9** checagens" (são 10) e `:109` diz "(**20**)" camadas
(são 21). Os regex do gate casam `N camadas`, `N/N mutantes`, `RC1…RCn`, `até MNNN` — **não** casam
"(20)" nem "9 checagens". Documento pode mentir em formato que o gate não lê.

**N6 · `install-list.txt` congelado em 2026-10-31** — único artefato que ainda apresenta
TrickyStore/LSPosed como **fila ativa**. O `install-guide.md` do mesmo pacote tem carimbo
"HISTÓRICO — NÃO EXECUTAR" (o `make -s escopo` valida isso) — o `.txt` não tem.

---

## 6. Estado verificado hoje (não é promessa)

```
[stack]     OK · 16/16 invariantes · 21 camadas · 9 fases · 47 passos
[refactor]  OK · 10/10 coerências
[contagens] OK · 177 mutantes · até M197 · 21 camadas · 16 invariantes · 10 coerências · 13 passos
[closure]   OK · 13 passos (K16 documentado)
[arch]      OK · AG1..AG21
[debitos]   6 abertos de 7 — B03, B05, B06, C06, M-ROLLOUT, P1
[garantia]  0 provados / 5 pendentes
[pack]      EMPATE em 3 pares (C06 aberto nos três)
[prove]     exit 0
```

---

## 7. Como reauditar a evolução (comandos que geraram este documento)

```bash
git rev-list --count 334c40a..main                 # 18 (o corte antigo)
git log --diff-filter=A --format='%h %ad %s' --date=short -- <arquivo>   # quando o item nasceu
git log --format='%h %ad %s' -- <arquivo>          # todas as mudanças do item
git log -S 'workspace/' -- .gitignore              # quando o ignore entrou
git show <sha>:<arquivo>                           # o valor do item naquele commit
gh pr list --state all --json number,title,state,createdAt,mergedAt
```

---

## 8. O que eu recomendo, na ordem (nada disso foi feito sem seu ok)

| # | Correção | Arquivo | Por que agora |
|---|---|---|---|
| 1 | remover `kptools` de `QUESTIONS` **e** ampliar o `RC1` para casar o token sem aspas | `session_open.py`, `refactor_gate.py`, `test_refactor_gate.sh`, 2 mutantes | é instrução viva errada com gate verde (N1) |
| 2 | `template`/`auto` escrevem **no registro versionado** por padrão; `check` deixa de preferir o arquivo ignorado; 5 docs atualizados | `session_open.py` + docs | fecha a causa-raiz #2 em vez de mitigar (N2) |
| 3 | `S02`/`S03` no `debt_ledger.py` | `debt_ledger.py` + `test_debt_ledger.sh` | prometido no R8, nunca feito (N3) |
| 4 | "15 invariantes"→16, "9 checagens"→10, "(20)"→21; ampliar os regex do `CT1` para `(N)` e `N checagens` | docs + `counts_gate.py` | doc pode mentir em formato não lido (N5) |
| 5 | carimbar `install-list.txt` como HISTÓRICO | `ci-build-full/...` | último artefato apontando fila vetada (N6) |
| 6 | mergear **#17** / fechar **#13** | GitHub | únicos trabalhos fora da `main` |
