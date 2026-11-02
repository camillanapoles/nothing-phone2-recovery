# O pack é determinado por condição — não por preferência

**Pergunta:** "valide o pack inteiro (método root + kernel + features) de forma determinística, sem
nada hardcoded para método root/kernel, e sem proibidos: o que existe é a condição encontrada do par
root × kernel (próprio, legado, de terceiro, qualquer) que torna verdadeiras as 10 condições, com
teste de falseabilidade."

**Resposta implementada:** `scripts/root_pair_solver.py` + `references/pack-objective.json` +
`references/pack-conditions.json`. O código não conhece nenhum motor nem kernel pelo nome.

---

## 1. Como a decisão é tomada

```
pack-objective.json   →  o que se quer (todas as condições verdadeiras, UM único par)
pack-conditions.json  →  as 10 condições, cada uma com regra declarada + contra-exemplo (breaker)
root-engines.json     →  fatos de cada motor   (artefato, capacidades, rollback, OTA, nível do root)
kernel-candidates.json→  fatos de cada kernel  (build, manutenção, configs provadas, patches, rollback)
droidspaces-*.json    →  o contrato do M05     (motores aceitos, CONFIG_*, patches de kABI)
hiding-stack.json     →  camadas com as capacidades que exigem
module-requirements   →  o que cada módulo precisa (root/Zygisk/SUSFS)
                ↓
        root_pair_solver.py  →  avalia TODOS os pares (motor × kernel)
                ↓
  PAR_GARANTIDO (0) · FALTA_PROVA (3) · IMPOSSIVEL (1) · AMBIGUO (1)
```

Nada de `forbidden_engines`. Um motor "proibido" agora é apenas um motor cujo par reprova em alguma
condição — e o solver diz **qual**. Se o dado mudar (novo motor, kernel certificado, patch aplicado,
config provada), o par selecionado muda sozinho, sem tocar em código.

## 2. As 10 condições (todas sobre o PAR)

| # | Condição | Regra (dado que a decide) | Se falhar |
|---|---|---|---|
| **C01** | o motor entrega root de verdade | `artifact.version` pinado, não-EOL | falta prova / impossível |
| **C02** | o kernel serve o motor escolhido | `engine.id ∈ candidate.kernel_supports` (quando o motor exige kernel próprio) | falta prova |
| **C03** | o kernel declara build, modelo e API | `supported_rom_builds`, `model`, `android_api` vs `rom_target` | falta prova |
| **C04** | o kernel é mantido | `status != rejected_eol`, `developer_support.declared`, `stale_days ≤ 365` | impossível |
| **C05** | o DroidSpaces aceita o motor | `constraints.supported_engines` do contrato do app | impossível |
| **C06** | o kernel tem as CONFIG_* exigidas | `configs_proven` (evidência) ⊇ contrato do M05 + isolamento | falta prova (stock: impossível) |
| **C07** | os patches de kABI estão aplicados | `patches_present` ⊇ `patches_required` (GKI) | falta prova |
| **C08** | há camada de ocultação utilizável | `layer.needs ⊆ capabilities(par)` e `engine_only` | impossível |
| **C09** | os módulos têm as capacidades que pedem | `root_required`/`needs_zygisk`/`requires_susfs` vs capacidades | impossível |
| **C10** | há rollback e plano de OTA | `engine.rollback`, `candidate.rollback`, `engine.ota_plan` | falta prova |

**`configs_extra` não conta.** Intenção de build não é prova: só `configs_proven` (lido da L4 ou do
kernel compilado) fecha C06. É isso que impede "declarar e passar".

## 3. Determinismo (o que é verificado, não prometido)

- motores e kernels são ordenados por `id`; condições na ordem do arquivo;
- JSON de saída com `sort_keys`, sem timestamp: **duas execuções = bytes idênticos**;
- trocar a ordem das chaves dos JSONs de entrada **não** altera o veredito;
- empate não é desempatado por gosto: se dois pares fecham as 10, o veredito é **`AMBIGUO` (1)** e o
  solver se recusa a escolher (`single_method: true` no objetivo);
- `references/root-decision.json` é **gerado** (`--write-decision`) e `--check-decision` reprova se
  alguém editar à mão.

## 4. Falseabilidade (o teste do teste)

Cada condição traz um `breaker`: uma perturbação declarada do dado (set/remove num JSON). O
`--selftest` roda sobre um pack completo de fixture e exige que, para **cada** condição:

1. o par de referência saía de `PAR_GARANTIDO`;
2. a queda fosse **exatamente** por aquela condição (`failed == [Cxx]`).

Condição que não cai com o próprio contra-exemplo é decoração → `selftest` sai 1. Conjunto de
condições vazio, ralo (`< min_conditions`), id duplicado, regra desconhecida ou condição sem
`breaker` → **exit 4** (vacuidade recusada). Ou seja: "passar em tudo" nunca acontece por ausência de
teste.

## 5. Estado atual (dado real do `pong`)

```
$ make pack
[pack] FALTA_PROVA · 16 pares (4 motores × 4 kernels) · garantidos=0 pendentes=6
  PEND apatch   × custom-build-pong-ksu-susfs-droidspaces  falta: C06
  PEND kernelsu × custom-build-pong-ksu-susfs-droidspaces  falta: C06
  PEND sukisu   × custom-build-pong-ksu-susfs-droidspaces  falta: C06
  NAO  ... (magisk: C05; stock: C06 impossível; Meteoric: C03/C04; NP²: C03)
[pack] EMPATE determinístico em 3 pares com as mesmas pendências ['C06']
```

Tradução: **a única coisa que separa o pack de `PAR_GARANTIDO` é C06** — as 13 `CONFIG_*` provadas no
kernel compilado. Enquanto elas não vierem de evidência, nenhum par é declarado garantido, e o empate
entre três motores é **nomeado**, não resolvido por preferência.

Quando o build sair com as configs e o `kernel_compat_check` passar:

```
root_pair_solver.py --root .            # 0 (PAR_GARANTIDO) com exatamente 1 par
root_pair_solver.py --root . --write-decision
make garantia                           # R1 deixa de ser FALTA_PROVA
```

## 6. Comandos

```bash
make pack                 # avalia todos os pares (exit 0/3/1)
make pack-selftest        # prova que cada uma das 10 condições é load-bearing
python3 …/root_pair_solver.py --root . --json | jq '.pairs[] | select(.failed|length<3)'
python3 …/root_pair_solver.py --root . --break C06      # mostra o efeito do contra-exemplo
python3 …/root_pair_solver.py --root . --check-decision # decisão no disco ≠ solver → 1
python3 …/root_engine_gate.py --engine <id> --candidate <id> [--kernel-evidence f]
```
