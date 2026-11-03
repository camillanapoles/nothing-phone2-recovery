# nothing-phone2-recovery

Contrato vivo deste workspace: **[`AGENTS.md`](AGENTS.md)** (regras) + **[`agente.md`](agente.md)**
(procedimento). Comece por eles — não por documentos antigos.

## Estado atual (2026-11-01)

| Camada | Onde | Situação |
|---|---|---|
| Contrato | `AGENTS.md`, `agente.md`, `skills/` | vigente |
| FSM determinístico | `audit-fsm/` (read-only, evidência por transição) | vigente |
| Skills | 8 (`skills/registry.json`) | `validate` 0 falhas · `eval` APROVADO |
| Estado de sessões antigas | `state/quarantine/` (local, fora do Git) | isolado |

## Provas rápidas

```bash
bash tests/test_state_reset.sh      # 13 PASS — higiene de estado + banco do FSM
make -C skills check-all            # contrato + 13/8/8 PASS + eval
scripts/state_reset.sh              # dry-run: o que ainda é resíduo de sessão antiga
```

## Leitura proibida como contrato

`state/`, `docs/plans/`, `docs/ssot/`, `.pi/`, `.atl/`, `ci*/`, `archive/zeroharcoderd/`, `ak3/` —
memória e código antigo. Explicam o passado, não decidem o presente.
