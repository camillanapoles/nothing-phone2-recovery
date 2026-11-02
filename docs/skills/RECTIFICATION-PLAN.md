# Pendências de retificação — o que ainda diverge da arquitetura nova, e em que ordem

> **Contexto:** o combo/sequência passou a ser contrato de dados (`references/install-stack.json`,
> `make stack`). Vários artefatos anteriores continuam descrevendo a arquitetura antiga
> (APatch como motor, Tricky Store como engine de atestação, Shamiko/Zygisk Assistant como
> ocultação, fila M01–M15). Este documento é o **diagnóstico com evidência** e a **ordem exata**
> de correção — cada item com o gate que o prova.
>
> Regra de ordenação: **decisão → gates que leem a decisão → documentos → plano de fechamento →
> build → medição**. Corrigir documento antes do gate que o cobra só cria texto solto.

---

## 0. Estado medido hoje (`make -s debitos`, `make -s kernel`, `make -s garantia`)

| Débito | Estado | Por que ainda está aberto |
|---|---|---|
| `B01` | **FECHADO** | pin real do source (`4ec5491f…`) |
| `B03` | aberto | falta `--kernel-tree`: não há árvore baixada para conferir |
| `B05` | aberto | falta `--config-json`: as 12 `CONFIG_*` seguem sem prova compilada |
| `B06` | aberto | falta `--build-dir`: os 7 artefatos ainda não existem |
| `C06` | aberto | 3 pares empatados; trava `M05` e o pack fica `FALTA_PROVA` |
| `M-ROLLOUT` | aberto | nada medido no staging nem no físico |
| `P1` | aberto | só falta `build.zip_path` + `build.zip_sha256` (a decisão em si já está registrada) |

Além disso, `make -s garantia` mostra `R3` citando **"M07/M08 declaram Tricky Store + PIFork"** —
texto que **contraria** a decisão vigente (Tricky Store é vetado; a engine é o TEESimulator-RS).

---

## 1. O defeito que custou uma sessão: decisão em caminho ignorado

**Evidência:** `workspace/decision.json` existia ao fim da rodada anterior e **desapareceu** na
troca de branch, porque `workspace/` está no `.gitignore` (linha 97). O ledger voltou a dizer
*"decisão ausente"* — um débito que já tinha sido respondido pela usuária.

**Causa-raiz:** decisão registrada em estado local, não em fonte versionada.

**Correção aplicada nesta rodada (R1):**

- `references/decisions.json` — registro **versionado**, gerado a partir do contrato.
- `session_open.py`: o caminho padrão do `check` passou a ser o registro versionado, com
  `workspace/decision.json` ainda aceito como override local.
- `stack_gate.py`: invariante **`decision_sync`** — o registro não pode divergir do contrato
  (flavor, contagem de módulos, pin de cada módulo, pin do kernel). Registro ausente = **PENDENTE (3)**.
- Mutante **M189** (desliga `decision_sync`) — morto por asserção.

---

## 2. Sequência exata das retificações restantes

| # | Item | Onde | Gate / prova | Por que nesta posição |
|---|---|---|---|---|
| **R1** | decisão em fonte versionada | `references/decisions.json`, `session_open.py`, `stack_gate.py` | `make stack` (16/16), `session_open check` | **feito** — é o insumo de todos os outros |
| **R2** | `success_guarantee.py`: `R3` dizia *Tricky Store + PIFork*; `R5` não conhece SUSFS userspace | script + `test_success_guarantee.sh` | `make garantia` deve citar TEESimulator-RS + PIFork e exigir `susfs4ksu` casado | gate que **avalia** a decisão — antes dos documentos |
| **R3** | `module-requirements.json`: `M03` (GApps A16), `M07` (fingerprint), `M08` (banking/Tricky) ainda descrevem a arquitetura antiga | JSON + testes que o leem | `make m05` + `test_script_contracts` | é o dado que o R2 consulta |
| **R4** | `hiding-stack.json` estrutural: camada `apatch-native` com `engine_only: apatch` e `zygisk-next.requires = [apatch-native]` — topologia APatch-first, agora errada | JSON + `root_pair_solver` | `make pack` tem de continuar `FALTA_PROVA`, com a topologia KSU-Next | muda o solver; por isso vem depois dos gates que só citam |
| **R5** | `session_open.py` `SKELETON`/`QUESTIONS`: 15 módulos legados e `kptools` (APatch) | script + `test_session_open.sh` | `session_open template` deve emitir as 20 camadas ativas do contrato | template alimenta decisão; depois da topologia estar certa |
| **R6** | `APPROVED-INSTALL-SEQUENCE.md` | docs + `legacy-sources.json` | `make escopo` (conflitos declarados continuam) | **feito parcial**: banner SUPERSEDIDO; falta apontar `replaced_by` no `legacy-sources.json` |
| **R7** | `closure-plan.json` não conhece `E13…` (retificações) nem cita `make stack` | JSON + `closure_gate` | `make closure` 16/16 com os novos passos | o plano de fechamento tem de cobrir o que a arquitetura nova criou |
| **R8** | débitos novos não aparecem no ledger: `S02` (zip+sha da ROM), `S03` (medição de integridade) | `debt_ledger.py` | `make debitos` listando `S02`/`S03` abertos | derivar débito é o último passo de contrato |
| **R9** | `E02` (árvore): baixar e pinar a árvore para `--kernel-tree` | `kernel_build_gate --kernel-tree` | `B03` fechado | **caminho de prova real** — depois dos contratos |
| **R10** | `E04`/`E03`: build no Actions → `--build-dir` e `--config-json` | `pong-build.yml` | `B05` e `B06` fechados, `C06` destravado | consome 60–90 min de CI |
| **R11** | medição no aparelho (staging → físico) | `rollout_gate.sh` | `M-ROLLOUT` fechado | só depois do build certificado |

### Regra de bloqueio entre itens

- `R2`…`R8` são **de contrato** e podem rodar em paralelo com `R9` (download), porque não tocam o
  aparelho nem o CI.
- `R10` **exige** `R9` (árvore pinada) e o plano do kernel já verde.
- `R11` **exige** `R10` — sem `boot.img` não há root, e sem root não há fase F3.
- Nenhum item de `R2`…`R8` fecha `C06`: ele só cai com as `CONFIG_*` provadas na build compilada.

---

## 3. O que **não** é retificação (não mexer)

- `root-decision.json` é **gerado** pelo solver — editar à mão seria forjar a decisão.
- `hiding-stack.json` continua sendo a fonte das **capacidades exigidas do par**; o
  `install-stack.json` é a **operação no aparelho**. São camadas diferentes, não duplicatas.
- `kernel/fragments/evox_pong_pack.config` é **gerado** (`make fragmento`) — mexer à mão quebra B08.

---

## 4. Critério de pronto desta frente

A frente de retificação está encerrada quando, ao mesmo tempo:

1. `make -s stack` = 16/16 e `decision_sync` verde;
2. `make -s garantia` cita apenas camadas que existem no `install-stack.json`;
3. `make -s pack` continua `FALTA_PROVA` **sem** mencionar APatch como única topologia;
4. `make -s closure` e `make -s debitos` conhecem `E13…` e `S02`/`S03`;
5. `prove` e `mutation` seguem verdes (hoje: 752+ casos / 35 suítes e 169 mutantes).

Nada disso promete `DEVICE` no aparelho: isso é `R11`, e depende de keybox não revogada.
