<!-- contagens: histórico -->
# Auditoria de timeline: a conversa anexa × o repositório

**Data da auditoria:** 2026-11-02
**Branch desta sessão:** `arena/e12a269b-nothing-phone2-recovery`
**Objeto:** a conversa anexada (8 turnos da usuária) e o repositório
`camillanapoles/nothing-phone2-recovery`.
**Marcador `contagens: histórico` acima:** os números deste documento são um **retrato datado**;
por isso o gate `CT1` (`make -s contagens`) não os trata como afirmação viva. Para medir de novo:
`make -s contagens`.

---

## 0. Veredito (o erro de arquitetura, nomeado)

1. **O combo, a ordem e os gates que vocês decidiram existem, estão implementados e verdes — mas
   não estavam nesta branch.** Eles vivem em `main` @ `d9dc14c`. Esta sessão nasceu de `334c40a`,
   **18 commits atrás**.

2. **O erro de arquitetura tem nome e consequência medida:** a branch de trabalho foi cortada de um
   ponto **anterior** à formalização do contrato (`install-stack.json`). Entre `334c40a` e `main`
   existem **23 arquivos novos** e **34 modificados**. Portanto um PR desta branch para `main`
   **não "adicionaria" nada: apagaria** `install-stack.json`, `decisions.json`, `stack_gate.py`,
   `refactor_gate.py`, `counts_gate.py`, `proof.yml`, `kernel/`, `release/` e o `RECTIFICATION-PLAN.md`.
   Não é arquivo faltando — é **reversão silenciosa** do que já foi provado.

3. **A causa que você apontou (`workspace/` em ignore) é real e já foi corrigida — em `main`:**
   a decisão vivia em `workspace/decision.json`; `workspace/` está no `.gitignore`, então o arquivo
   **sumia a cada troca de branch** e o débito `P1` voltava a "decisão ausente". Corrigido em
   **#12 (R1)**: `references/decisions.json` (versionado) + invariante `decision_sync` no `stack_gate.py`.
   Hoje `.gitignore` continua ignorando `workspace/` — e isso está **certo**; o errado era morar lá.

4. **A mesma família de erro continua aberta em um ponto:** a cobertura de mutação mora em
   `workspace/audit/mutation-latest.json` (ignorado; reescrito do zero a cada rodada). O **PR #17**
   move isso para o FSM (`proof_run`/`proof_item`, auditável por `run_id`) — está **aberto,
   `MERGEABLE`/`CLEAN`, todos os checks verdes** e **não foi mesclado**. É o único trabalho da
   conversa que nunca entrou em `main`.

5. **O que a conversa prometeu e o código não cumpre (1 item):** **R8** — os débitos `S02`
   (zip+sha da ROM) e `S03` (medição de integridade) foram mapeados no plano de retificação
   (PR #12) e **não existem** no `debt_ledger.py`. `make -s debitos` fecha 6 de 7 e não lista nenhum
   dos dois.

6. **O que nenhum código resolve daqui:** `R11` (prova no aparelho), `P1` (caminho+sha do zip),
   `C06`/`B03`/`B05`/`B06` (árvore e build do kernel), `R9`/`R10`.

---

## 1. Como esta auditoria foi feita (reprodutível)

| Evidência | Comando | O que prova |
|---|---|---|
| estado da branch vs. `main` | `git rev-list --count 334c40a..main` → `18` | o ponto de corte está atrás |
| o que existe só em `main` | `git diff --name-status 334c40a main` | 23 `A` + 34 `M`, 0 `D` |
| PRs e estados | `gh pr list --state all` | #14/#15/#16 `MERGED`; #13 e #17 `OPEN` |
| gate do contrato | `make -s stack` → `OK · 16/16 · 21 camadas · 9 fases · 47 passos` | o combo é dado verificável |
| coerência contrato × consumidores | `make -s refactor` → `OK · 10/10` | nenhum consumidor ficou na arquitetura velha |
| números derivados | `make -s contagens` → `177 mutantes · até M197 · 21 camadas · 16 invariantes · 10 coerências · 13 passos` | nada de limite digitado |
| débitos | `make -s debitos` → 6 abertos de 7 | o que trava de verdade |
| garantia | `make -s garantia` → 0 provados / 5 pendentes | nada é "aprovado por texto" |
| prova completa | `make -s prove` → exit 0 | a árvore em `main` está verde |

---

## 2. Timeline sequencial

> A conversa anexa é o **recorte final** (a partir de 2026-11-01). A pré-história (`T0`) não está no
> anexo, mas está no git. Onde a hora não é verificável, o documento **não inventa hora**: usa a
> âncora que existe (PR, commit, merge).

### T0 — pré-história (não está no anexo; está no `git log`)

| Âncora | Evento |
|---|---|
| `19:06`→`22:58` (11-01) | HIL A/B, contrato arquitetural AG1–AG21, protocolo P1–P8, M05 (DroidSpaces) com 26 testes |
| `1d75f67` (11-01 22:15) | **Decisão A ratificada** — APatch no kernel stock |
| `f4de7a9` (11-01 22:58) | DroidSpaces é **IMPOSSÍVEL** com kernel stock (doc oficial do app) |
| `975b296` (11-01 23:34) | **Decisão C ratificada** — KernelSU-Next + kernel próprio (KSU+SUSFS+patches kABI); A superseded |
| `fec48f8`, `fa5ecbe`, `bf972f9` | pack solver por 10 condições, plano do kernel, instrução de continuidade |
| `334c40a` (**o corte desta sessão**) | débitos derivados + plano de fechamento (12 passos E01–E12) |
| `3877158` (PR #10) | E01 fechado: pin real da árvore do kernel + material por sha256 |
| `1a2dc69` (PR #11) | **o combo vira contrato de dados**: `install-stack.json` + `stack_gate.py` |
| `4720006` (PR #12) | **R1**: `references/decisions.json` versionado (fim da regressão do P1) + plano R2–R11 |

### T1 — "FAÇA E GARANTA que toda refatoração seja feita, gate determinístico, teste falsificável"

* Âncora: a branch estava `pr_merged` → nada foi escrito nesse turno (só o desenho do gate).
* Decisão de desenho: o "sempre" não é promessa, é **gate** — `refactor_gate.py` comparando o
  contrato com **todos** os consumidores.

### T2 — mesmo pedido, em branch ativa

| Âncora | Evento |
|---|---|
| `3ecfe3b` | `scripts/refactor_gate.py` (RC1…RC9) + `tests/test_refactor_gate.sh` (16 PASS) + mutantes M190–M192 |
| `ebbc630` `66b726a` `f38929c` `9a4ee37` | correções exigidas pelo **CI novo** (GITHUB_OUTPUT, anotação de sobrevivente, teste viciado por `rsync`, JSON multilinha) |
| PR **#14** (15:20, merge `3d66f45` 15:40) | R2–R8 aplicados: `success_guarantee` sem "Tricky Store", M03=NikGapps Core, M07/M08 com PIFork+TEESimulator-RS, hiding-stack KSU-Next, template de sessão derivado do contrato, `E13` no plano, `proof.yml` |
| prova | `prove` 770 PASS / 36 suítes · `mutation` 172/172 · `refactor` 9/9 · `stack` 16/16 |

### T3 — "Please merge the pull request" → #14 mergeado

* `3d66f45` em `main`; 3 defeitos reais apareceram no CI e foram corrigidos (não contornados).

### T4 — "GARANTA QUE NÃO HAJA FUGA DE VALIDAÇÃO POR PADRÃO"

O buraco: `--only M186,M187,M188` com ids **fora do catálogo** devolvia `exit 0` — "0 de 0 executados"
virava "passei".

| Âncora | Evento |
|---|---|
| `4be0953` | escopo fechado (`exit 4` para id inválido, inclusive misturado), cobertura por `M[id]` em ledger zerado a cada rodada, auto-incremento de id, intervalos, `RC10` (todo script com mutante), CI item a item |
| `1e496e3` | o mutante M193 **sobreviveu no CI** → caso discriminante (mistura válido+inválido) |
| PR **#15** (16:21, merge `c53894d` 16:45) | prova: 792 PASS · 175/175 · refactor 10/10 |

### T5 — "Please merge" → #15 mergeado

### T6 — "Todos os limites são zero hardcoded? Se o catálogo virar 176, seria detectado? O FSM armazena isso?"

| Âncora | Evento |
|---|---|
| `78fb0a5` | `scripts/counts_gate.py` (`make -s contagens`): **nenhum número digitado**; todo limite derivado de catálogo/contrato/plano/gates. Crescer o catálogo **reprova** até o texto ser corrigido |
| resposta honesta | o FSM **não** guardava cobertura: tabelas eram `runs`, `probes`, `transitions`, `objectives`, `risks`. Registrado como **lacuna conhecida**, não como promessa |
| PR **#16** (16:59, merge `d9dc14c` 17:23) | prova: contagens OK · prove exit 0 · 177/177 · CI 16/16 <!-- contagens: histórico --> |

### T7 — "Please merge" → #16 mergeado (= `main` hoje)

### T8 — "levar o ledger para o FSM, auditável por `run_id`, seguindo os padrões (factory/DB), com comandos inicial/final/auditoria"

| Âncora | Evento |
|---|---|
| PR **#17** (18:25) — **ABERTO** | kinds `proof_run`/`proof_item` pela via padrão (metaclass → `FieldSpec` → `DomainFactory` → repository → rota → CLI), id determinístico `uuid5` (reimportar não duplica), comandos `proof-start` / `proof-import` (shards em paralelo) / `proof-finalize` / `proof-verify`, alvo `make fsm-prova`, integração no `proof.yml` |
| estado | `MERGEABLE` · `CLEAN` · **16 checks verdes** (contrato, prove, 8 shards de mutação, relatório) |

---

## 3. Matriz de aplicação — o que foi, o que não foi, o que está pendente

### 3.1 Aplicado **e** verificado (está em `main`)

| Entrega | Onde | Âncora | Quem cobra |
|---|---|---|---|
| Combo + sequência como contrato de dados | `references/install-stack.json` | `1a2dc69` (#11) | `make -s stack` (16/16) |
| Decisão em fonte versionada | `references/decisions.json` | `4720006` (#12) | invariante `decision_sync` |
| Gate contrato × consumidores | `scripts/refactor_gate.py` (RC1…RC10) | `3ecfe3b` (#14) | `make -s refactor` (10/10) |
| Escopo de validação fechado | `mutation_check.py` + `--only/--range/--shard` | `4be0953` (#15) | `test_mutation_check.sh` |
| Cobertura por `M[id]` (produto 1/0) | `workspace/audit/mutation-latest.json` | `4be0953` (#15) | relatório do CI |
| Nenhum limite digitado | `scripts/counts_gate.py` | `78fb0a5` (#16) | `make -s contagens` |
| CI de prova (contrato → prove → shards → relatório) | `.github/workflows/proof.yml` | `3ecfe3b` (#14) | o próprio CI |
| R2: `success_guarantee` sem Tricky Store | script | #14 | `make -s garantia` |
| R3: M03=NikGapps Core; M07/M08 com PIFork+TEESimulator-RS+keybox+VBMeta | `module-requirements.json` | #14 | `RC2` |
| R4: `hiding-stack.json` → `susfs`/`ksu-app-profile`/`zygisk-next`/`nohello` | JSON | #14 | `RC4` |
| R5: template de sessão derivado do contrato | `session_open.py` | #14 | `RC3` (⚠ `kptools` segue em `QUESTIONS` — ver `EVOLUTION-LEDGER.md` §5/N1) |
| R6: fila antiga com banner **SUPERSEDIDO** | `APPROVED-INSTALL-SEQUENCE.md` | **#12** (`4720006`) | `RC6` |
| R7: passo `E13` no plano (roda `stack_gate` + `refactor_gate`) | `closure-plan.json` | #14 | `RC5` |
| Regra "merge só com aprovação explícita" | `AGENTS.md:201` | #14 | `RC8` |
| Material do kernel pinado (fragmento, patches kABI, SHA256SUMS) | `kernel/`, `release/` | #10 | `make -s kernel` |
| "Nunca mergear sem prova" na boca do agente | `CONTINUITY-INSTRUCTION.md`, `HANDOFF-NEXT-AGENT.md` | #14/#16 | `make -s continuidade` |

### 3.2 **Não aplicado** (a conversa prometeu; o código não tem)

| Item | Evidência de ausência | Impacto |
|---|---|---|
| **R8** — débitos `S02` (zip+sha da ROM) e `S03` (medição de integridade) | `grep S02\|S03 debt_ledger.py` → **nada**; `make -s debitos` lista 6 abertos sem eles | dois trabalhos que a usuária precisa fazer ficam **invisíveis** no ledger |
| **PR #17** — ledger de prova durável no FSM | PR **aberto**, não mesclado | a cobertura de validação **não sobrevive** à máquina que rodou |
| **PR #13** — prova em nuvem item a item (774 itens) | PR aberto desde 15:10, **antes** de #14; `mergeable: UNKNOWN` | foi **superado** por #15 (escopo fechado + shards + relatório). Manter aberto confunde a fila |
| Documentos com números que o `CT1` **não sabe ler** | `INSTALL-SEQUENCE.md:5` diz "15 invariantes" (são 16); `RECTIFICATION-PLAN.md:101` diz "9 checagens" (são 10) e `:109` diz "(20)" camadas (são 21) | o gate cobre padrões (`N camadas`, `N/N mutantes`, `RC1…RCn`), **não** frases como "(20)" — número velho sobrevive em prosa |
| Texto de débito com nomenclatura antiga | `closure-plan.json:62` — "nenhum módulo **M01–M15** tem PASS" | a fila mudou de nomes; o débito fala a língua antiga |
| `ci-build-full/build-package/modules/install-list.txt` | ainda lista **ZygiskNext → TrickyStore → PIFork → LSPosed → Droidspaces** | o `install-guide.md` do mesmo pacote já tem carimbo HISTÓRICO e o `escopo` passa — **o `.txt` não**; é artefato de build, não instrução viva, mas continua citando item vetado |

### 3.3 **Pendente por natureza** (depende de insumo, não de código)

| Débito | Estado | O que falta (comando) | Fecha em |
|---|---|---|---|
| `B03` | aberto | `--kernel-tree` (árvore baixada e pinada) | `E02` |
| `B05` | aberto | `--config-json` (12 `CONFIG_*` provadas na build) | `E04` |
| `B06` | aberto | `--build-dir` (7 artefatos do kernel) | `E03` |
| `C06` | aberto | consequência de B05/B06; trava o `M05` | `E05` |
| `M-ROLLOUT` | aberto | nada medido em staging nem no físico | `E08`, `E12` |
| `P1` | aberto | `build.zip_path` + `build.zip_sha256` (a decisão **já** está registrada: vanilla + NikGapps Core) | `E06` |
| `R9` | pendente | baixar/pinar a árvore (`kernel_build_gate --kernel-tree`) | — |
| `R10` | pendente | build no Actions (`pong-build.yml`) → `--build-dir`, `--config-json` | — |
| `R11` | pendente | aparelho: keybox não revogada + `MEETS_DEVICE_INTEGRITY` medido | — |

Consequência medida hoje: `make -s garantia` = **0 provados / 5 pendentes** e `make -s pack` = **EMPATE
em 3 pares** (só `C06` aberto nos três). Nada disso é falha de código: é insumo ausente.

---

## 4. Causas-raiz (por que "não foi mesclado")

| # | Causa | Evidência | Já existe defesa? | Lacuna |
|---|---|---|---|---|
| 1 | **branch cortada de commit antigo** | `334c40a..main` = 18 commits; 23 arquivos novos ausentes | não — nada no repo impede cortar de base velha | um gate de "base atualizada" (`git rev-list --count HEAD..origin/main` > 0 → avisa) não existe |
| 2 | **decisão em diretório ignorado** | `workspace/decision.json` (`.gitignore: workspace/`) sumia na troca de branch | **sim** (#12): `references/decisions.json` + `decision_sync` | nenhuma — fechada |
| 3 | **prova de validação em diretório ignorado** | `workspace/audit/mutation-latest.json`, zerado a cada rodada | **em PR** (#17): tabelas do FSM | merge pendente (decisão da usuária) |
| 4 | **refatoração manual, sem gate** | antes do #14, cada consumidor era corrigido à mão e sobrava um | **sim** (#14): `refactor_gate` RC1…RC10 | RC não lê prosa: números em frase livre escapam (#3.2) |
| 5 | **número escrito à mão em doc/CI** | `AGENTS.md` dizia 175/175 com 177 no catálogo | **sim** (#16): `counts_gate` | padrões só cobrem formas conhecidas ("(20)" escapa) |

**Regra que sai desta auditoria:** *fonte de verdade só em caminho versionado; o resto é derivado e
cobrado por gate.* Tudo o que a conversa produziu e que **não** virou arquivo versionado foi perdido —
duas vezes (decisão, depois cobertura).

---

## 5. O combo ratificado (recuperado e agora na árvore)

> **Fonte única:** `skills/evox-rom-ci-optimizer/references/install-stack.json`
> **Leitura humana (sequência completa, 9 fases, 47 passos):** `docs/skills/INSTALL-SEQUENCE.md`
> **Quem cobra:** `make -s stack` (16 invariantes) e `make -s refactor` (10 coerências).
> Se o texto divergir do JSON, **o JSON vence** e o gate reprova.

### 5.1 Decisões registradas (`decided_by: user`, 2026-11-02)

| Chave | Valor | Por quê |
|---|---|---|
| `flavor` | **vanilla** | a variante GApps traz Chrome/Velvet/Wellbeing privilegiados no `/system`; debloat systemless volta na OTA |
| `gapps` | **nikgapps-core** (5 componentes) | GmsCore + Phonesky + GSF + sync de contatos e calendário; nada além |
| `integrity_engine` | **teesimulator-rs-enhanced** | substitui o TrickyStore (fechado, sem keybox válida embutida) |
| `keybox_automation` | **teesimulator-enhanced** (alternativa: specter) | um só dono da automação |
| `screen_search` | **circletosearch @ `e4f4614`** | motor de disparo próprio + OCR offline; tradução só neste ramo |
| `hiding` | **susfs + ksu app-profile + zygisk-next** | kernel-level primeiro; Shamiko e Zygisk Assistant fora |

### 5.2 As camadas (o "combo de aplicação × módulo")

| # | Camada | Pin | Papel | Status |
|---|---|---|---|---|
| 1 | `firmware-pong` | `pkg:nothingos-b4.0-251119-1654` | base de rádio/câmera do pin do kernel | required |
| 2 | `evox-vanilla` | `build:EvolutionX-16.0-20260915-Pong-11.11` | ROM A16 sem Google | required |
| 3 | `nikgapps-core` | `pkg:nikgapps-core-arm64-16` | os 5 componentes do Google | required |
| 4 | `webview-aosp` | `pkg:aosp-webview` | sem Chrome, o WebView é o AOSP | required |
| 5 | `kernel-build-e03` | `commit:4ec5491f…` | kernel com KSU-Next + SUSFS + namespaces | required |
| 6 | `ksu-next` | `tag:v3.4.2` | root no kernel (LKM) | required |
| 7 | `susfs-userspace` | `tag:v1.5.2+_R28` | `ksu_susfs` casado com o patch do kernel | required |
| 8 | `ksu-app-profile` | `pkg:ksu-next-app-profile` | *Umount modules* por app | required |
| 9 | `zygisk-next` | `tag:v1.5.2` | `just_umount` + `linker builtin` + memória anônima | required |
| 10 | `pifork` | `tag:v16` | props/fingerprint (BASIC) | required |
| 11 | `teesimulator-rs` | `tag:v6.0.1-360-enhanced` | engine de atestação (DEVICE) | required |
| 12 | `keybox` | `pkg:keybox-xml` | raiz de confiança; revogável | required |
| 13 | `vbmeta-fixer` | `pkg:vbmeta-fixer` | depois do PIFork e do motor | required |
| 14 | `nohello` | `tag:v0.0.8` | só se a matriz de detecção falhar | conditional |
| 15 | `hma-oss` | `tag:hma-oss` | só se algum app enumerar pacotes | optional |
| 16 | `gemini` | `pkg:…apps.bard` | pedido da usuária | required |
| 17 | `drive` | `pkg:…apps.docs` | opcional; sem ele não há backup de dispositivo | optional |
| 18 | `circletosearch` | `commit:e4f4614…` | seleção de texto + tradução por gesto | required |
| 19 | `morphe` | `tag:v2.3.0` | YouTube patcheado + detach | required |
| 20 | `gms-doze` | `tag:1.9.11` | Play Services dormindo, FCM intacto | required |
| — | `evox-gapps` | `build:…-gapps` | **não instalada** (decisão de flavor) | not_installed |

**Vetados com justificativa no JSON:** `shamiko` · `zygisk-assistant` · `yurikey` · `integrity-box` ·
`tricky-store` · `mindthegapps` · `microg` · `chrome` · `velvet` · `wellbeing`.

### 5.3 A sequência (9 fases / 47 passos, cada um com PASS falseável)

| Fase | Título | Passos | Critério de saída (resumo) |
|---|---|---|---|
| **F0** | contratos e cesta (nada no aparelho) | 6 | 7 artefatos do kernel com sha256 · hashes de ROM/GApps/módulos · backup stock · `prove`+`arch` verdes |
| **F1** | base do sistema (mesma sessão de recovery) | 5 | firmware nos dois slots → format data → ROM → NikGapps **sem reboot no meio** → primeiro boot sem loop |
| **F2** | saneamento do primeiro boot | 5 | setup sem restaurar backup · auto-update/auto-sync/Play Protect off · WebView AOSP · OTA congelada |
| **F3** | root | 3 | flash do `boot.img` com KSU-Next LKM → manager → **backup do boot com root** |
| **F4** | ocultação (um por reboot) | 7 | `ksu_susfs` casado → SUSFS (logs off, uname spoof) → *Umount modules* → Zygisk Next (3 comandos) → NoHello condicional → **matriz de detecção** → HMA-OSS opcional |
| **F5** | integridade (um por reboot) | 8 | PIFork (BASIC) → TEESimulator-RS → keybox **não revogada** → `target.txt` → `security_patch` ≤12 meses → VBMeta Fixer → checker (DEVICE) → app real |
| **F6** | apps | 4 | Gemini · Drive · CircleToSearch (7 critérios) · Morphe (patch + mount + detach) |
| **F7** | performance e bateria | 3 | GMS Doze · restrição de background · baseline de idle + OTP chegando |
| **F8** | fechamento por tópico | 6 | ausência dos vetados · ocultação · integridade · apps · notificações · backup/OTA declarados |

**Regra de execução:** um módulo por reboot, PASS antes do próximo (`rollout_gate.sh`).
**Regra de prova:** insumo ausente = **PENDENTE (exit 3)**, nunca "verde".

---

## 6. Plano de correção (ordem exata)

| Passo | Ação | Por que nesta ordem | Estado |
|---|---|---|---|
| **C0** | **atualizar esta branch para `main`** (`git merge --ff-only main`) — **feito nesta auditoria**: `HEAD` = `d9dc14c` | sem isso qualquer PR daqui **reverte** 57 arquivos | ✅ feito |
| **C1** | **mergear o PR #17** (verde/CLEAN) ou fechá-lo com justificativa | é o único trabalho da conversa fora da `main`; sem ele a cobertura não sobrevive à máquina | ⏳ decisão da usuária |
| **C2** | **fechar o PR #13** como superseded por #15 | ficou aberto apontando para um modelo (168 itens) que o #15 já substituiu | ⏳ decisão da usuária |
| **C3** | aplicar **R8**: `S02`/`S03` no `debt_ledger.py` | são os dois trabalhos que a usuária tem de fazer; hoje não aparecem no ledger | ⏳ |
| **C4** | corrigir os números em prosa que o `CT1` não lê ("15 invariantes" → 16, "9 checagens" → 10, "(20)" → 21) e trocar "M01–M15" pelo nome das camadas no texto do débito `M-ROLLOUT` | doc mentindo é o próximo "arquivo em `workspace/`": invisível ao gate | ⏳ |
| **C5** | carimbar `ci-build-full/.../install-list.txt` como HISTÓRICO (igual ao `install-guide.md`) ou regenerá-lo do contrato | é o último artefato citando TrickyStore como "instale na ordem" | ⏳ |
| **C6** | `R9` → `R10` (árvore pinada, build no Actions) → fecha `B03`/`B05`/`B06`/`C06` | é o que destrava F1…F5 | ⏳ depende de CI (~60–90 min de runner) |
| **C7** | `P1` (caminho + sha256 do zip) | destrava F1 | ⏳ depende da usuária |
| **C8** | `R11` (aparelho) | é a prova derradeira; nada acima substitui | ⏳ depende do físico |

**Não fazer:** abrir PR desta branch **antes** de C0. Depois de C0 o risco desaparece — a branch passa a
conter `main` + esta auditoria.

---

## 7. O que continua fora do alcance do código

- **`R11`** — keybox não revogada e `MEETS_DEVICE_INTEGRITY` **medidos**. Nenhum gate local produz isso.
- **`P1`** — o zip da ROM e o sha256; o sandbox não alcança o CDN.
- **`C06`** — 12 `CONFIG_*` provadas na build compilada; exige a árvore e o build.
- **Ocultação "perfeita"** — não é demonstrável; o que é demonstrável é a lista de apps testados com PASS
  (é o que `make -s garantia` cobra via `device.hide_tested_apps`).

---

## 8. Reauditar em 1 minuto

```bash
git rev-list --count HEAD..origin/main     # 0 = base atualizada (causa #1 fechada)
make -s stack                              # 16/16 · 21 camadas · 9 fases · 47 passos
make -s refactor                           # 10/10 (contrato × consumidores)
make -s contagens                          # todo número derivado da fonte viva
make -s debitos                            # 6 abertos de 7 (B03,B05,B06,C06,M-ROLLOUT,P1)
make -s garantia                           # 0/5 — honesto até haver evidência
make -s prove                              # exit 0
gh pr list --state open                    # #17 (merge pendente) · #13 (superseded)
```

Se algum desses números mudar sem o gate reprovar, **este documento envelheceu** — é para isso que
existe o `CT1`, e é por isso que o marcador `contagens: histórico` está na primeira linha.
