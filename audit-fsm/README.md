# audit-fsm

Safety-first FSM recovery audit for the Nothing Phone 2 (codename **Pong**).

Read-only audit driven by a deterministic Finite State Machine. Every probe
records evidence (command, stdout, stderr, exit code, evidence hash) before
the FSM transitions. Results are stored objective-oriented via FastAPI CRUD.

## Architecture

- **S1** Safety-first: no mutating commands during audit (enforced at code level).
- **S2** FSM with evidence-guarded transitions; terminal states: SAFE/UNSAFE/BLOCKED.
- **S3** Objective-oriented storage: Run → Probe/Transition/Objective/Risk tree.
- **S4** FastAPI CRUD over SQLite (SQLAlchemy 2.0 async).
- **S5** Agentic query layer: natural-language consultations grounded in stored data.
- **S7** Factory + metaclass: `ValidatedModelMetaclass` enforces zero-hardcode,
  validated CRUD, update guarantee proven by four-case tests per domain class.
- **S8** Deterministic agents via Pydantic AI V2 (chosen over Instructor per 2026 trend).
- **S9** Proof ledger: a cobertura de mutação vira dado durável (`proof_runs` + `proof_items`),
  auditável por `run_id`, com ids determinísticos e veredito recalculado das linhas.

## Quick start

```bash
cd audit-fsm
python -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"

# run the test suite (proves the update guarantee)
pytest

# run a live audit (read-only — device must be online via ADB)
audit-fsm run

# ask a question about stored audit data
audit-fsm consult "É seguro fazer unlock do bootloader?"

# serve the CRUD API
audit-fsm serve

# sem instalar (Makefile/CI): o mesmo CLI a partir do checkout
PYTHONPATH=src python3 -m audit_fsm proof-runs
```

## Prova (S9): a cobertura sobrevive à máquina

O ledger de mutação (`workspace/audit/mutation-latest.json`) deixa de ser um artefato local e
passa a ser uma **tabela** do FSM, criada pelo mesmo padrão de todo o resto (metaclass →
`FieldSpec` → `DomainFactory` → repository → rota → CLI). Dois kinds novos, sem `register()` manual:

| Kind | O que guarda |
|---|---|
| `proof_run` | alvo, início, catálogo declarado, mortos, produto, `complete`, `source_hash` |
| `proof_item` | um `M[id]`: status, valor `1`/`0`, arquivo, teste, hash da evidência |

Ciclo completo, tudo por comando:

```bash
# 1) inicial: abre a execução e imprime o run_id
audit-fsm proof-start ../workspace/audit/mutation-latest.json

# 2) shards em paralelo, todos na MESMA execução (idempotente: reimportar não duplica)
audit-fsm proof-import slot-a.json --run-id "$RUN_ID"
audit-fsm proof-import slot-b.json --run-id "$RUN_ID"

# 3) final: recalcula o veredito das LINHAS e grava (exit 3 se incompleta)
audit-fsm proof-finalize "$RUN_ID"

# 4) auditoria read-only: declarado × linhas (exit 1 se alguém adulterou a run)
audit-fsm proof-verify "$RUN_ID"

# consulta item a item / histórico
audit-fsm proof-show "$RUN_ID"
audit-fsm proof-runs
```

Regras que fazem disso prova, e não relatório:

- **ids determinísticos** (`uuid5`): a mesma origem gera as mesmas linhas, então reimportar é seguro;
- **`source_hash`** (sha256 do ledger canônico): origem editada muda a identidade da execução;
- **veredito derivado das linhas**: `complete`/`killed` declarados sem lastro viram divergência;
- **formatos aceitos**: ledger consolidado (`entries`) **e** relatório cru de slot (`results`);
- **nenhum número digitado**: `catalog_total` é o maior entre o declarado e as linhas gravadas.

Prova de execução: `tests/integration/test_cli_proof.py` (ciclo real, códigos de saída
`0`/`3`/`1`, dois shards convergindo para uma run) e `tests/unit/test_proof_ledger.py`
(determinismo, formato de slot, divergência por adulteração).

## Spec

See `../odd/tasks/fsm-recovery-audit.md` for the full specification (S1–S8, tasks, log).
