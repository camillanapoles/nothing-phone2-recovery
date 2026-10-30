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
from .validators import validate_serial, validate_timestamp, validate_uuid

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


# ── Reusable validator factories ────────────────────────────────────────

_validate_run_status = validate_enum_factory(RunStatus)
_validate_objective_status = validate_enum_factory(ObjectiveStatus)
_validate_fsm_state = validate_enum_factory(FSMState)


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
