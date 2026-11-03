# Log de execução dos lotes (o que foi implantado, como foi provado)

Registro cumulativo dos lotes da `EXECUTION-SEQUENCE.md`. **Sem números neste arquivo, de
propósito:** cada linha aponta o **comando** que produz o número. Número solto num log envelhece
igual aos relatórios — e o `counts_gate` existe para impedir isso.

---

## Lote 1 — `S-BASE` (E12) + carimbo de documento congelado (E06/E11)

**Data:** 2026-11-02 · **Base:** `main` @ `6481ff3`

### O que entrou

| item | arquivo | o que faz |
|---|---|---|
| **S-BASE** | `scripts/base_gate.py` (novo) + `make -s base` | reprova branch que **não contém** `origin/main`, listando os arquivos que um PR dali **apagaria**; em clone raso é `PENDENTE`, nunca verde |
| **CI** | `.github/workflows/proof.yml` | job de contrato com `fetch-depth: 0` + passo `make -s base` antes de tudo |
| **carimbo** | `scripts/counts_gate.py` | doc que declara histórico **tem de dizer a que commit** (`congelado em: <sha> (AAAA-MM-DD)`) — no topo do arquivo ou na própria linha |
| **relatórios** | 9 docs de auditoria | carimbados com o commit cujo estado descrevem |
| **prosa viva** | `INSTALL-SEQUENCE.md`, `RECTIFICATION-PLAN.md` | "15 invariantes"→16, "9 checagens"→11 (o número envelheceu **depois** da auditoria) |

### Como foi provado (comando → veredito)

```text
make -s base        → OK        (main @ 6481ff3 é ancestral de HEAD)
make -s test-base   → 12/12     (direção, atrás, raso, sem ref, não-repo, uso, JSON)
make -s contagens   → OK        (carimbo de arquivo e de linha cobertos; 18/18 no teste)
make -s arch        → OK        (AG21: ≥2 mutantes semânticos por script)
make -s refactor    → 11/11
make -s prove       → exit 0
make -s mutation    → 100% mortos, cobertura COMPLETA
```

Mutantes novos: `M200` (branch atrás deixa de reprovar), `M201` (doc congela sem referência no
topo), `M202` (clone raso deixa de ser PENDENTE), `M203` (marca histórico na linha escapa do
carimbo). Todos mortos por asserção.

### Três coisas que só apareceram porque o teste foi escrito antes

1. **A direção da ancestralidade é o erro fácil.** "Estar atualizado" é `origin/main` ser ancestral
   de `HEAD` — o inverso (`HEAD` ancestral de `main`) é justamente *estar atrás*. O primeiro rascunho
   usou a direção errada e teria dado **verde em branch atrasada**. O caso "branch ATRÁS = FALHA"
   existe para travar isso.
2. **Em clone raso o git mente.** Neste próprio sandbox, `merge-base --is-ancestor` respondeu "sim"
   para uma branch 25 commits atrás, porque o histórico é enxertado. Por isso clone raso é
   `PENDENTE` (exit 3) — a mesma regra do projeto: "não dá para provar" ≠ "verde".
3. **O teste tinha um bug de contabilidade:** usei `F` como nome de diretório num arquivo onde `F`
   já era o contador de falhas — o resumo acusava falha mesmo com tudo passando. Renomeado.

### O que ainda não está coberto (próximos lotes)

- `E05` classificar os docs restantes que não estão no mapa de caminhos (12 de 30).
- `F3` ampliar os padrões do `CT1` para "N invariantes", "N checagens", "(N) camadas" — com os
  falsos positivos de prosa controlados por teste.
- `E02` contador derivado de suítes/casos (hoje os docs afirmam números sem fonte).
- `E03` `prove` honesto: hoje ele **não** roda mutação nem vacuidade.
- `E07`/`F6` carimbo do resíduo em `ci-build-full` + `RC12`.
- `F5` `S02`/`S03` no ledger de débitos.
- `F7`/`F8`/`F9` PRs #17 e #13 (dependem do seu ok).

---

## Lote 2 — `RC12` (resíduo vetado) — fecha o N6/E07

**Data:** 2026-11-02

### O que entrou

| item | arquivo | o que faz |
|---|---|---|
| **RC12** | `scripts/refactor_gate.py` | artefato em `ci-build-full/` que cite módulo **vetado pelo contrato** e não esteja carimbado como histórico → FALHA |
| **carimbo** | `install-list.txt` + 3 JSONs de artefato | cabeçalho "HISTÓRICO — NÃO EXECUTAR" e campo `_historico`, com ponteiro para a fila vigente |

O carimbo não apaga o resíduo: ele **rotula**. O gate garante que resíduo novo não nasça sem rótulo.

### Limite honesto desta checagem

`RC12` só conhece os módulos vetados **pelo contrato** (`install-stack.json › forbidden`). O
`install-list.txt` também cita LSPosed, que **não** está nessa lista — portanto o gate não o pega.
Se LSPosed deve ser vetado, isso é decisão de contrato (e entra como camada proibida), não de gate.

### Como foi provado

```text
make -s refactor                    → OK (RC1…RC12)
test_refactor_gate.sh               → 23/23 (2 falsificações novas de RC12)
mutation --only M204,M205           → mortos
make -s prove                       → exit 0
make -s mutation                    → 100% mortos, cobertura COMPLETA
```
