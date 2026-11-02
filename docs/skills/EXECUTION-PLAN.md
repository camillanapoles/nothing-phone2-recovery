# Execução incremental — do débito ao PASS, com validação assertiva

**Fonte executável:** `skills/evox-rom-ci-optimizer/references/closure-plan.json`
**Gates:** `make -s debitos` (o que está aberto agora) · `make -s closure` (o plano é executável)
**Levantamento dos débitos:** `docs/skills/CONTINUITY-INSTRUCTION.md` §18 · `DEBT` derivado, não escrito à mão.

## 1. Como o débito é levantado (e por que não é lista manual)

`debt_ledger.py` **deriva** o estado atual dos gates que já existem:

| Origem | Débito que produz |
|---|---|
| `kernel_build_gate --prebuild` | `B01`, `B03`, `B05`, `B06` (cada item `PEND` vira débito) |
| `root_pair_solver` (pares empatados) | `C06` e qualquer condição que impeça o par de vencer |
| `continuity_gate` | `CONTINUIDADE` (se uma cláusula da instrução quebrar) |
| `session_open.py check` | `P1` (decisão de variante da ROM não registrada) |
| ledger canário de rollout | `M-ROLLOUT` (nenhum módulo com PASS) |

Consequência: **débito que fecha some sozinho**; débito novo aparece sem editar lista; e débito sem
passo de fechamento no plano faz `make -s debitos` sair com **1** (inconsistência), não com **3**.

Estado em 2026-11-01: **7 débitos abertos de 7** — `B01`, `B03`, `B05`, `B06`, `C06`, `P1`, `M-ROLLOUT`.

## 2. Como o plano é validado (`make -s closure`)

| Item | O que o gate cobra |
|---|---|
| `K01`–`K03` | estrutura, ids de passos/débitos únicos |
| `K04`–`K05` | todo passo tem id, título, tipo, `needs`, `resolves`, `gate`, `stop_condition`, `rollback`; tipo válido |
| `K06`–`K08` | dependências existem, grafo **acíclico** e nenhum passo depende do futuro |
| `K09` | todo passo tem comando, `expect_exit` (0 ou 3) e **critério observável** |
| `K10`–`K11` | todo débito declarado tem passo; todo débito que os gates reportam está declarado |
| `K12` | decisão de produto marcada como **da usuária**, com pergunta objetiva |
| `K13` | script e flags citados no `gate` **existem** |
| `K14` | passo físico depende de staging com `guard4_verify` |
| `K15`–`K16` | sem placeholder; os passos estão documentados aqui |

## 3. A cadeia (ordem é dependência, não gosto)

```
P1 (decisão) ─────────────────────────────► E06 ──┐
                                                  ├─► E07 (staging) ─► E08 (M01) ─► E09 (M05) ─► E10 ─► E11 ─► E12
B01 ─► E01 pin ─► E02 árvore ─► E03 build ─► E04 configs ─► E05 C06 ─► E09 ┘
```

| Passo | Faz | Fecha | Gate assertivo (exit) |
|---|---|---|---|
| **E01** | pinar o source (commit de 40 hex) | `B01` | `kernel_build_gate --prebuild` → `B01` OK (exit 3 enquanto houver outra pendência) |
| **E02** | materializar árvore: fragmento do pack + patches `001`/`002` | `B03` | `--kernel-tree <árvore>` → `B03`/`B04` OK |
| **E03** | build no GitHub Actions (draft + hash + attestation) | `B06` | `--build-dir <artefatos>` → `B06` OK |
| **E04** | provar as CONFIG_* do `.config` | `B05` | `--config-json <evidência>` → pré-build inteiro OK (exit **0**) |
| **E05** | fechar `C06` e resolver o empate por dado | `C06` | `make -s pack` (exit 0, sem `C06` faltando) |
| **E06** | registrar a decisão da usuária (Vanilla × GApps) | `P1` | `session_open.py check` (exit 0, `flavor_source=user`) |
| **E07** | staging/AVD: hash, attestation, boot, M01 | — | `guard4_verify.sh` (exit 0) |
| **E08** | físico: `M01` com PASS | `M-ROLLOUT` | `rollout_gate.sh record --module M01` (exit 0) |
| **E09** | físico: `M05` (DroidSpaces) | — | `droidspaces_preflight.py --device` (exit 0) |
| **E10** | `M07`/`M08` (integridade e ocultação) | — | `rollout_gate.sh status` (exit 0, sem paralelo) |
| **E11** | `M02/M03/M04/M06/M09/M10/M11/M12A/M12B` | — | `rollout_gate.sh status` (exit 0, `M12A`≠`M12B`) |
| **E12** | `M13/M14/M15` + provas do workspace | `M-ROLLOUT` | `make -s prove` (exit 0) |

## 4. Regras de execução

1. **Um passo por vez.** O passo seguinte só abre quando todos os `needs` estão fechados com o gate
   no exit esperado — não por "parece que sim".
2. **Critério de fechamento é duplo:** o gate do passo no exit esperado **e** o débito sumindo de
   `make -s debitos`. Um dos dois falhando = passo aberto.
3. **Parada imediata** em qualquer `stop_condition`: patch que não aplica limpo, `CONFIG_*` ausente no
   `.config`, panic/bootloop, hash divergente, requisito do DroidSpaces faltando, detecção de root.
4. **Rollback declarado em todo passo** (reverter `source.pin`, descartar árvore, apagar draft,
   restaurar backup verificado). Nada é aplicado com `--force`/fuzz.
5. **Decisão de produto não se antecipa:** `E06` só abre com a resposta da usuária; o agente
   apresenta a tabela pinada e para.
6. **Físico nunca antes de staging** (`K14`) e **USB nunca antes de `M15`**.

## 5. O que "pronto" significa no fim da cadeia

`make -s debitos` sem débito aberto (exit 0) · `make -s closure` executável · `make -s prove`,
`make -s mutation` e `make -s audit-loop` verdes · `make -s pack` com veredito derivado (não empate por
falta de prova) · `M01`–`M15` com PASS próprio e backup verificado em cada flash.
