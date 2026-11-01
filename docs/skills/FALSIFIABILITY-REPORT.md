# Relatório de falseabilidade — os testes conseguem reprovar?

**Data:** 2026-11-01 · **Pergunta:** existe mascaramento de resultado, isto é, teste que passa
mesmo quando a lógica de negócio some? **Método:** mutação (Red de verdade) + análise estática de vício.

## 1. Como cada teste é cobrado

1. **Mutação (dinâmico).** O harness copia o workspace, injeta **uma** troca real de decisão
   (`references/mutation-catalog.json`) e roda o teste que deveria pegá-la:
   - teste falha → mutante **morto** (o teste é falseável);
   - teste passa → mutante **vivo** → teste viciado, o harness reprova (`exit 3`).
2. **Varredura de vício (estático).** `test_vacuity_scan.py` (V1–V6) procura asserção impossível,
   falha engolida (`|| true`), `2>/dev/null || echo 0` em comparação, suíte só-feliz e `sleep`.
3. **Meta-teste.** `test_mutation_check.sh` monta um workspace com teste viciado e exige que o
   harness **reprove** — o fiscal também é fiscalizado.

## 2. Resultado

| Métrica | Valor |
|---|---|
| Mutantes | **47** |
| Mortos | **47** (score **100%**) |
| Sobreviventes | **0** |
| Arquivos com mutante | **36** (todo script com teste tem ao menos um) |
| Vícios estruturais (V1–V6) | **0 erros, 0 avisos** em 20 suítes |
| Suítes / casos (skill) | 19 / 258 (+13 de estado) |

## 3. Mascaramentos que a auditoria **encontrou e corrigiu**

Estes cinco mutantes sobreviveram na primeira rodada. Ou seja: havia teste verde escondendo
lógica não verificada.

| # | Mutação aplicada | Por que passava | Correção no teste |
|---|---|---|---|
| M09 | marcas de boot ignoradas (`HANG` e `HANG_EARLY` colapsam) | o caso HANG só afirmava `exit 4`, que é igual nos dois | passou a afirmar a **classificação** `HANG` no JSON |
| M10 | `cache get` deixava de comparar sha256 | nenhum caso corrompia o cache e pedia `get` | novo caso: cache corrompido → `get` = exit 3 |
| M16 | `sem unzip` virava `|| true` | só havia teste de `payload-dumper` ausente | novo caso com `PATH` sem `unzip` → exit 3 |
| M43 | regra R8 (watchdog) virava `lambda t: True` | o lint era testado por outras regras, não por R8 | mutação `sem sys.boot_completed` → exit 3 **e** violação R8 no output |
| M46 | gate recusando o módulo imprimia e **seguia** | o teste olhava só o exit code | passou a exigir a mensagem `BLOQUEADO` e ledger com 0 `passed` |

## 4. Item a item (arquivo → mutantes → mortos)

| Arquivo | Mutantes | IDs | Mortos |
|---|---|---|---|
| `skills/evox-rom-ci-optimizer/scripts/guard4_verify.sh` | 1 | M01 | 1/1 |

## 5. Cobertura do workspace

- `coverage_matrix.py`: **40 scripts** → 36 testados + 4 isentos com motivo declarado
  (`references/audit-exemptions.json`), **0 lacunas**.
- `architecture_guard.py` **AG19** impede script testado sem mutante e **AG20** impede vício V1–V6.
- Todo o restante (docs, workflows, catálogos) é coberto por `contradiction_scan.py` (C1–C13) e
  pelos testes de contrato/lint.

## 6. Limites declarados (sem marketing)

1. Cada arquivo tem **1 a 3 mutantes**, não mutação exaustiva (isso exigiria dezenas por arquivo).
   A escolha prioriza decisões de negócio: rollback, gate, classificação de falha, hash, ordem.
2. Para os 13 scripts que hoje só têm **contrato CLI**, o mutante derruba o `--help` e quem o mata é
   `test_script_contracts.sh` — isso prova que o teste **distingue** comportamento, mas não exercita
   a lógica interna desses scripts (que exige ROM/binários/device).
3. `--help` de `runtime_module_tester.sh` mutado pode estourar timeout: conta como morto, mas o
   sinal é "não travou o contrato", não cobertura semântica.

## 7. Reprodução

```bash
make -s mutation    # 47/47 mortos (≈70 s)
make -s vacuity     # V1–V6: 0 erro, 0 aviso
make -s audit-loop  # AG + C + cobertura + vacuidade + suítes, em loop até convergir
```
