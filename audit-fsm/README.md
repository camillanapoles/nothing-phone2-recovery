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
```

## Spec

See `../odd/tasks/fsm-recovery-audit.md` for the full specification (S1–S8, tasks, log).
