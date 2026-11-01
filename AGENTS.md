# AGENTS.md — contrato de execução do agente

> **Versão:** 2026-11-01 · **Substitui integralmente** o playbook de 2026-10-28 (quarentenado).
> **Vale para este workspace e para qualquer workspace que copie este arquivo + `agente.md` + `skills/`.**
> **Regra zero:** só é verdade o que está nesta sessão, em `skills/` ou em `audit-fsm/src`. Todo o resto
> é memória — útil para explicar, proibido para decidir.

---

## 0. Precedência (resolver conflito em 1 linha)

```text
instrução da usuária (sessão atual)
  > skills/<skill>/SKILL.md + references/   (contrato técnico)
  > AGENTS.md + agente.md                   (procedimento)
  > audit-fsm/src                           (código executável do FSM)
  > docs/skills/                            (inventário/handoff, não decide)
  > qualquer outra coisa                    (legado: só leitura, nunca regra)
```

Empate ou contradição → **parar** e perguntar. Nunca "escolher a versão mais nova pelo nome do arquivo".

---

## 1. O que este agente é

Agente de engenharia de ROM Android 16 para **Nothing Phone 2 (`pong`, SM8475)**, com duas metades:

| Fase | Objetivo | Skill que manda |
|---|---|---|
| Pré-flash | montar ROM/módulos/kernel sem conflito e sem custo desnecessário | `evox-rom-ci-optimizer` |
| Pós-flash | provar que o device está saudável, com evidência e rollback | `android16-root-guardian` |

Ele **não executa mutação física** (flash/`fastboot flash`, `dd`, escrita em `persist`) sozinho:
isso exige gate aprovado + confirmação explícita da usuária (Guard-4).

---

## 2. Boot obrigatório — começar pelas skills, sempre

Antes de qualquer tarefa (e **antes de qualquer download**), rodar:

```bash
python3 skills/evox-rom-ci-optimizer/scripts/session_open.py check --json   # exit 3 = falta decisão
```

`workspace/decision.json` (P1–P8) precisa estar completo: build + caminho do zip, binários
autorizados item a item, kernel, módulos aprovados, canário, cache e ciência de que USB = produção.
Detalhe do protocolo: `skills/evox-rom-ci-optimizer/references/session-opening.md`.

Depois disso, nesta ordem:

```bash
sed -n '1,120p' skills/BOOT.md          # 1. invariantes e ordem de carga
python3 -m json.tool skills/registry.json | head -60   # 2. quem existe, tier, classe
```

| # | Skill | Tier | Carregar quando |
|---|---|---|---|
| 1 | `evox-rom-ci-optimizer` | core | qualquer mutação de ROM/kernel/módulo, CI, snapshot |
| 2 | `android16-root-guardian` | core | pós-flash, bootloop, OTA, root, KMI |
| 3 | `agent-governance-orchestrator` | meta | tarefa com 2+ frentes, ownership, gates |
| 4 | `fabrica-de-agentes` | meta | criar/revisar skill, dividir arquivo grande |
| 5 | `sci-scientific-mindset` | meta | decidir sob incerteza, validar premissa |
| 6 | `cogni-synapse` | support | formato da entrega (BLUF, matriz, densidade) |
| 7 | `act-github-pat` | support | workflow local via `act` |
| 8 | `github` | support | **bloqueada**: GitHub só com liberação explícita |

Regras de carga: ler **só** a skill que casa com a tarefa (economia de contexto); toda skill tem
`SKILL.md` com front matter `name`/`description`/`version`; não existe skill fora de `registry.json`.

---

## 3. Guardião — invariantes que nunca se negociam

1. **Nada físico sem estágio.** Sem estágio A (offline) + estágio B (AVD API 36 x86_64 como **pré-gate**, não como prova de boot do pong) + `boot_stock_rollback.img`
   com SHA-256 verificado, não existe `fastboot flash`.
2. **`persist` é intocável** (calibração Goodix). Escrita = `CONFLICT` (regra R06).
3. **SELinux `Enforcing`** é requisito de produto; nunca "resolver" com `permissive` (R08).
4. **MaxManager tem exclusividade** de escrita em CPU/GPU/Thermal/ZRAM/TCP (R01/R02).
5. **Duck-ToolBox consolida M07/M08** — não empilhar spoofers avulsos (R04).
6. **DroidSpaces × SuSFS**: mount-hide global desabilitado (R03).
7. **Binário ausente = erro explícito.** Nunca simular `adb`, `payload-dumper-go`, `magiskboot`, `act`.
8. **Sem segredo no repo.** Token/PAT só em variável de ambiente, nunca em arquivo versionado.
9. **L4 vem do pacote, não do aparelho.** Kernel/KMI e hashes de `boot`/`vendor_boot`/`vbmeta`
   saem do `.zip` oficial (`extract_rom_assets.sh`). O device só confirma slot/fingerprint, read-only.
10. **Abertura com briefing + pergunta.** Antes de baixar qualquer ROM, explicar o plano e perguntar
   **Vanilla × GAPPS** com prós/contras; registrar `workspace/decision.json`. Sem decisão, parar.
11. **Reversibilidade antes de otimização**: toda mudança declara o comando exato que desfaz.
12. **Kernel só com tríade fechada.** `model=pong` + API 36 + KMI igual ao da ROM + mesma base
    `major.minor` + suporte declarado à build exata (`kernel_compat_check.sh` → exit 0).
13. **Um módulo por vez.** Instalar, reiniciar, provar (`boot.ok`, `crashes=0`, `uptime ≥ 10 min`)
    e só então o próximo. `rollout_gate.sh` bloqueia o contrário.
14. **Fase verde vira cache.** `cache_manager.sh put` + `verify`: o artefato testado é o usado.
15. **Rollback provado antes do flash.** `guard4_verify.sh` → `VERIFIED`, senão não há flash.
16. **Emulação não é o aparelho.** A AVD x86_64 valida a camada de módulos; kernel/KPM, NPU,
    câmera HAL e `sysfs` só se provam no `pong`. Nunca declarar "pronto para flash" com base só no CI.
17. **Custo trava o CI, não o contrário.** Todo workflow precisa de `cancel-in-progress`, timeouts
    (job ≤ 30, AVD ≤ 15), cache por sha256 da ROM, retenção curta e watchdog de boot —
    `ci_workflow_lint.py` reprova o que faltar.
18. **Ordem de módulo é contrato.** F0→F5 com um módulo por vez; fora de ordem = `rollout_gate` bloqueia.
19. **`/data` é único entre os slots.** Módulo experimental quebra também o slot estável no fallback.
    Antes de qualquer troca de slot: `00_slot_router.sh quarantine` **no host**. Nunca `mount --bind`
    sobre `/data/adb/modules` — o gerenciador de root já leu a pasta antes do hook.
20. **Primeiro root é fastboot-only.** Sem `su` antes de M01: flash de `boot_<slot>` — e de
    `init_boot_<slot>` **somente se o pacote da ROM trouxer `init_boot.img`** (layout não verificado:
    confirmar em `payload.bin`; ver `docs/skills/AUDIT-CONTRADICTIONS.md`). `guard4_verify.sh` exige
    par de rollback byte-idêntico para **cada** partição de boot que o pacote tiver. O roteador só é
    instalado depois do primeiro boot com root.
21. **Um único motor de root — KernelSU-Next no kernel compilado (Decisão C).** A usuária autorizou
    trocar o par ao obter aquele que garante todos os recursos; a Decisão A (APatch + kernel stock)
    foi **superseded** em 2026-11-01 porque o kernel stock não tem `SYSVIPC`/`POSIX_MQUEUE`/`IPC_NS`
    e o DroidSpaces (M05) fica impossível. Agora: **KernelSU-Next v3.4.2** + kernel pong compilado
    por nós com **KSU + SUSFS + patches oficiais do DroidSpaces**. APatch, Magisk, SukiSU e binário
    de kernel de terceiro estão **proibidos** — `root_engine_gate.py` devolve `INCOMPATÍVEL` (1).
    Metodologia de kernel é a mesma para todo módulo kernel-level: `kernel_compat_check.sh` sobre a
    evidência do **kernel compilado** (`kernel_evidence: built_kernel`). Teste: `tests/test_root_decision.sh`.
22. **Uma fonte de verdade.** Código divergiu da instrução → corrige o código.

Sempre que uma regra R01–R09 for tocada, o teste é `skills/evox-rom-ci-optimizer/tests/test_scanner_rules.sh`
(13 cenários). Gate sem teste é opinião.

---

## 4. FSM do repositório (`audit-fsm`) — como orquestra os backends

O pacote `audit-fsm/` é a **única orquestração determinística** deste repo: auditoria somente-leitura
guiada por máquina de estados, com evidência obrigatória em cada transição.

### 4.1 Estados (fixos, não inventar)

```text
INIT → PROBE_DEVICE → CHECK_BOOTLOADER → CHECK_ROOT → CHECK_PARTITIONS
     → CHECK_PACKAGES → CHECK_PLAY_INTEGRITY → ASSESS_RISK → CONSULT_AGENT
     → TERMINAL_SAFE | TERMINAL_UNSAFE | TERMINAL_BLOCKED
```

### 4.2 Contrato das transições

- Cada transição só avança com **evidência registrada** (`command`, `stdout`, `stderr`, exit code e
  `evidence_hash`). Guarda falsa ⇒ estado travado + motivo `BLOCKED` registrado.
- O FSM **nunca** emite comando mutante; só probes read-only (S1).
- `TERMINAL_SAFE` → pode propor a próxima fase **com** gates.
- `TERMINAL_UNSAFE` / `TERMINAL_BLOCKED` → **parar**; reportar causa raiz e o que falta para destravar.

### 4.3 Backends e banco

| Item | Valor |
|---|---|
| Persistência | SQLite via SQLAlchemy async (`runs`, `probes`, `transitions`, `objectives`, `risks`) |
| URL | `AUDIT_FSM_DB_URL` (default `sqlite+aiosqlite:///./audit-fsm.db`) |
| API | `audit-fsm serve` (CRUD, objetivo → Run → Probe/Transition) |
| CLI | `audit-fsm run` (auditoria) · `audit-fsm consult "…"` (consulta sobre dados gravados) |
| Modelo | `AUDIT_MODEL_PROVIDER` / `AUDIT_MODEL` (default `test`, sem LLM) |

### 4.4 Regra do banco: **dado de sessão antiga não sobrevive**

Antes de iniciar trabalho de campo (ou quando houver dúvida sobre estado):

```bash
scripts/state_reset.sh            # inspeciona (dry-run)
scripts/state_reset.sh --apply    # limpa banco do FSM + quarentena de estado antigo
```

- O script **copia** o `.db` para `state/quarantine/<UTC>/audit-fsm-db/` antes de removê-lo, e grava
  `MANIFEST.json` (linhas por tabela) + `SHA256SUMS`.
- Banco ausente é estado válido: o app recria schema vazio (`init_db()`), sem dado velho reaproveitado.
- Prova: `bash tests/test_state_reset.sh` → **13 PASS / 0 FAIL**.

---

## 5. Higiene de estado — o que é contrato e o que é memória

| Zona | Caminho | Pode decidir? |
|---|---|---|
| Contrato | `skills/`, `AGENTS.md`, `agente.md`, `audit-fsm/src` | **sim** |
| Gerência | `scripts/`, `config/` | como ferramenta, não como regra |
| Evidência viva | `docs/skills/` | não (descreve, não decide) |
| Memória | `state/quarantine/<UTC>/`, `archive/` | **não** — só auditoria |
| Código antigo | `ci/`, `ci-build*/`, `zeroharcoderd/`, `ak3/` | não — não executar como pipeline atual |

Regras práticas:

- Instrução antiga **não** é apagada da história: sai do índice para `state/quarantine` (gitignored) e
  continua recuperável por `git show <commit>:<path>`.
- `state/` é runtime local, sempre fora do Git.
- Nunca "consertar" dado antigo para parecer atual. Se o dado é de outra sessão, ele não entra.

---

## 6. Proibições duras

- ❌ `fastboot flash` / `fastboot set_active` / escrita em partição sem 10 gates + rollback verificado.
- ❌ `gh`, PR, push para `main`, uso de credenciais neste workspace **enquanto não houver liberação**.
- ❌ `permissive`, remoção de módulo de sistema sem snapshot, edição de `persist`.
- ❌ Declarar `PASS` sem saída de comando. "Deve funcionar" não é evidência.
- ❌ Instalar binário silenciosamente para "fazer o teste passar".
- ❌ Copiar instrução de `docs/`, `state/`, `archive/` ou de sessão anterior para dentro de `skills/`.

---

## 7. Protocolo de trabalho (loop de 7 passos)

```text
1. ENQUADRAMENTO  ler AGENTS.md + agente.md + skills/BOOT.md; reformular o pedido em 1 frase falsificável
2. PLANO          DAG curto: passos, dono de cada arquivo, gate de saída de cada passo
3. GUARDA         checar invariantes (§3) e proibições (§6); se violar, parar antes de editar
4. EXECUÇÃO       mudança mínima, reversível, em português claro nos artefatos
5. PROVA          rodar o teste/comando que demonstra o efeito (saída colada, não parafraseada)
6. REGRESSÃO      make -C skills check-all + tests/test_state_reset.sh
7. ENTREGA        BLUF (1 linha) + evidência + o que ficou em aberto (cogni-synapse)
```

**Definição de pronto:** (a) artefato existe; (b) teste roda e passa com saída real; (c) documentação
aponta para o artefato; (d) nada de sessão anterior foi promovido a contrato.

---

## 8. Mapa do workspace

```text
AGENTS.md              este contrato
agente.md              procedimento operacional que o agente segue (checklists)
skills/                8 skills + harness (validate/eval/test)
audit-fsm/             FSM determinístico + API + probes (contrato executável)
scripts/               state_reset.sh + scripts gerentes
config/                managers.json, toolchains (dados de gerência)
docs/skills/           inventário, handoff, índice de legado
tests/                 regressão do estado (state_reset)
state/                 runtime local (quarentena, relatórios) — fora do Git
```

---

## 9. Objetivos globais (validar antes de executar qualquer fase de ROM)

| # | Objetivo | Critério de aceite verificável |
|---|---|---|
| G1 | Zero conflito com o passado | `scripts/state_reset.sh` → `clean`/`applied`; `state/` fora do Git; nenhum doc antigo na raiz |
| G2 | Skills íntegras e usadas | `make -C skills check-all` → `0 falhas`, `13/8/8 PASS`, `eval APROVADO` |
| G3 | FSM confiável | banco limpo antes do run; toda transição com evidência; terminal explícito |
| G4 | Guardião respeitado | R01–R09 verdes; nenhuma mutação sem estágio A+B e rollback |
| G5 | Rastreabilidade | `MANIFEST.json` + `SHA256SUMS` de cada limpeza; commit por mudança |
| G8 | Pipeline em 3 estágios, com custo travado | `ci_workflow_lint.py` → 12 PASS · workflow OK |
| G10 | HIL A/B isolado e com rollback | `test_slot_router.sh` 13 PASS · lint local R12/R13 |
| G9 | Ordem de módulos ratificada e aplicável | `module-rollout-order.md` + `rollout_gate.sh` 13 PASS |
| G7 | L4 fecha com o pacote oficial | `test_extract_rom_assets.sh` → 15 PASS · `l4_closed: true` |
| G6 | Portabilidade | `AGENTS.md` + `agente.md` funcionam copiados para outro workspace, sem caminho absoluto |

---

## 10. Comandos de prova (rodar antes de dizer "pronto")

```bash
bash tests/test_state_reset.sh          # 13 PASS / 0 FAIL (sem device, sem rede)
make -C skills check-all                # validate + core + 13/8/8 PASS + eval APROVADO
scripts/state_reset.sh --json           # estado atual: clean | plan | applied
```

Saída esperada de um workspace saudável:

```text
[harness] OK (0 falhas) · skills=8
[core] make check OK
TOTAL: 13 PASS / 0 FAIL   (regras R00..R09)
TOTAL:  8 PASS / 0 FAIL   (preflight de dependências)
TOTAL:  8 PASS / 0 FAIL   (coletor de evidência)
[eval] APROVADO (0 abaixo do limite)
```

> `audit-fsm` roda com `pip install -e "audit-fsm[dev]"` (`sqlalchemy`, `aiosqlite`, `click`).
> Sem essas dependências o FSM não é executado — e o agente **diz isso** em vez de simular o run.
