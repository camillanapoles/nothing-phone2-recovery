"""
Domain models — validated CRUD objects on ValidatedModelMetaclass (S7, T4).

Each model inherits ValidatedModelBase (metaclass=ValidatedModelMetaclass).
The metaclass collects FieldSpecs, enforces zero-hardcode, and registers
the class with DomainFactory. No manual register() calls.

Models:
  Run         — an audit run (device_serial, status, adb_path)
  Probe       — a probe result (state, command, stdout, stderr, exit_code, hash)
  Transition  — an FSM transition (from_state, to_state, guard_passed)
  Objective   — an audit objective (state, description, status, hash)
  Risk        — a risk verdict (verdict, reasoning, hash)
  ProofRun    — uma execução de prova (mutação), com o veredito declarado
  ProofItem   — uma linha de cobertura por item provado (1 = feito, 0 = não feito)

Persistence: SQLAlchemy Core tables (domain/tables.py) map the validated
domain fields to columns. The DomainFactory creates validated objects; a
repository layer converts to/from SQLAlchemy rows.
"""

from __future__ import annotations

import enum

from ..fsm.core import FSMState
from .metaclass import (
    FieldSpec,
    SourcePolicy,
    ValidatedModelBase,
    validate_bool,
    validate_enum_factory,
    validate_exit_code,
    validate_nonempty,
    validate_optional_str,
)
from .validators import (
    validate_item_id,
    validate_nonneg_int,
    validate_serial,
    validate_timestamp,
    validate_uuid,
    validate_zero_or_one,
)

# ── Status enums ────────────────────────────────────────────────────────


class RunStatus(str, enum.Enum):
    """Status of an audit run."""

    RUNNING = "running"
    COMPLETED = "completed"
    BLOCKED = "blocked"
    FAILED = "failed"


class ObjectiveStatus(str, enum.Enum):
    """Status of an audit objective."""

    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    SATISFIED = "satisfied"
    VIOLATED = "violated"
    BLOCKED = "blocked"


class ProofStatus(str, enum.Enum):
    """Estado de um item de prova (mutação)."""

    KILLED = "killed"
    SURVIVED = "survived"
    INVALID = "invalid"
    TIMEOUT = "timeout"
    NOT_RUN = "not_run"


class ProofRunStatus(str, enum.Enum):
    """Estado agregado de uma execução de prova."""

    COMPLETE = "complete"
    INCOMPLETE = "incomplete"


# ── Reusable validator factories ────────────────────────────────────────

_validate_run_status = validate_enum_factory(RunStatus)
_validate_objective_status = validate_enum_factory(ObjectiveStatus)
_validate_fsm_state = validate_enum_factory(FSMState)
_validate_proof_status = validate_enum_factory(ProofStatus)
_validate_proof_run_status = validate_enum_factory(ProofRunStatus)


# ── Domain models ───────────────────────────────────────────────────────


class Run(ValidatedModelBase):
    """An audit run against a specific device."""

    _kind_ = "run"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("device_serial", validate_serial, SourcePolicy.ARG),
        FieldSpec("started_at", validate_timestamp, SourcePolicy.ARG),
        FieldSpec("status", _validate_run_status, SourcePolicy.ARG),
        FieldSpec("adb_path", validate_nonempty, SourcePolicy.ARG),
    ]


class Probe(ValidatedModelBase):
    """A probe result with evidence hash (S3)."""

    _kind_ = "probe"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("run_id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("state", _validate_fsm_state, SourcePolicy.ARG),
        FieldSpec("command", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("stdout", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("stderr", validate_optional_str, SourcePolicy.ARG, required=False),
        FieldSpec("exit_code", validate_exit_code, SourcePolicy.ARG),
        FieldSpec("evidence_hash", validate_nonempty, SourcePolicy.ARG),
    ]


class Transition(ValidatedModelBase):
    """An FSM transition record (S2)."""

    _kind_ = "transition"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("run_id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("from_state", _validate_fsm_state, SourcePolicy.ARG),
        FieldSpec("to_state", _validate_fsm_state, SourcePolicy.ARG),
        FieldSpec("guard_passed", validate_bool, SourcePolicy.ARG),
        FieldSpec("description", validate_optional_str, SourcePolicy.ARG, required=False),
    ]


class Objective(ValidatedModelBase):
    """An audit objective with evidence (S3)."""

    _kind_ = "objective"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("run_id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("state", _validate_fsm_state, SourcePolicy.ARG),
        FieldSpec("description", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("status", _validate_objective_status, SourcePolicy.ARG),
        FieldSpec("evidence_hash", validate_optional_str, SourcePolicy.ARG, required=False),
    ]


class Risk(ValidatedModelBase):
    """A risk verdict with reasoning and evidence (S3)."""

    _kind_ = "risk"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("run_id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("verdict", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("reasoning", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("evidence_hash", validate_nonempty, SourcePolicy.ARG),
    ]


class ProofRun(ValidatedModelBase):
    """Uma execução de prova (S9) — o veredito fica no banco, não na máquina de quem rodou.

    `source_hash` é o sha256 do ledger de origem: reimportar o mesmo ledger é idempotente,
    e um ledger editado à mão muda o hash (a prova deixa de bater com a origem).
    """

    _kind_ = "proof_run"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("target", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("started_at", validate_timestamp, SourcePolicy.ARG),
        FieldSpec("finished_at", validate_optional_str, SourcePolicy.ARG, required=False),
        FieldSpec("status", _validate_proof_run_status, SourcePolicy.ARG),
        FieldSpec("catalog_total", validate_nonneg_int, SourcePolicy.ARG),
        FieldSpec("killed", validate_nonneg_int, SourcePolicy.ARG),
        FieldSpec("product", validate_zero_or_one, SourcePolicy.ARG),
        FieldSpec("complete", validate_bool, SourcePolicy.ARG),
        FieldSpec("source_hash", validate_nonempty, SourcePolicy.ARG),
    ]


class ProofItem(ValidatedModelBase):
    """Cobertura de UM item (M[id]) em uma execução de prova (S9).

    `value` é 1 quando o item foi provado (mutante morto por asserção) e 0 quando não foi
    executado ou sobreviveu — o produto dos valores responde "rodou tudo?" sem hardcode.
    """

    _kind_ = "proof_item"
    _fields_ = [  # noqa: RUF012
        FieldSpec("id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("run_id", validate_uuid, SourcePolicy.ARG),
        FieldSpec("item_id", validate_item_id, SourcePolicy.ARG),
        FieldSpec("proof_kind", validate_nonempty, SourcePolicy.ARG),
        FieldSpec("status", _validate_proof_status, SourcePolicy.ARG),
        FieldSpec("value", validate_zero_or_one, SourcePolicy.ARG),
        FieldSpec("file", validate_optional_str, SourcePolicy.ARG, required=False),
        FieldSpec("test", validate_optional_str, SourcePolicy.ARG, required=False),
        FieldSpec("seconds", validate_nonneg_int, SourcePolicy.ARG),
        FieldSpec("evidence_hash", validate_nonempty, SourcePolicy.ARG),
    ]
