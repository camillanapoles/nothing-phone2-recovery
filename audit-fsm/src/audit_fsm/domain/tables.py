"""
SQLAlchemy Core tables for persistence (S4, T4).

Uses Core Table definitions (not Declarative) to avoid metaclass conflicts
with ValidatedModelMetaclass. The domain models (domain/models.py) are
validated in-memory objects; these tables handle persistence.

A repository layer converts between domain objects and SQLAlchemy rows.
"""

from __future__ import annotations

from sqlalchemy import (
    Boolean,
    Column,
    Integer,
    MetaData,
    String,
    Table,
    Text,
)

metadata = MetaData()

# ── Tables (one per domain model) ───────────────────────────────────────

runs = Table(
    "runs",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("device_serial", String(32), nullable=False),
    Column("started_at", String(32), nullable=False),  # ISO 8601
    Column("status", String(16), nullable=False),
    Column("adb_path", Text, nullable=False),
)

probes = Table(
    "probes",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("run_id", String(36), nullable=False, index=True),
    Column("state", String(32), nullable=False),
    Column("command", Text, nullable=False),
    Column("stdout", Text, nullable=False),
    Column("stderr", Text, nullable=True),
    Column("exit_code", Integer, nullable=False),
    Column("evidence_hash", String(64), nullable=False),
)

transitions = Table(
    "transitions",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("run_id", String(36), nullable=False, index=True),
    Column("from_state", String(32), nullable=False),
    Column("to_state", String(32), nullable=False),
    Column("guard_passed", Boolean, nullable=False),
    Column("description", Text, nullable=True),
)

objectives = Table(
    "objectives",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("run_id", String(36), nullable=False, index=True),
    Column("state", String(32), nullable=False),
    Column("description", Text, nullable=False),
    Column("status", String(16), nullable=False),
    Column("evidence_hash", String(64), nullable=True),
)

risks = Table(
    "risks",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("run_id", String(36), nullable=False, index=True),
    Column("verdict", String(32), nullable=False),
    Column("reasoning", Text, nullable=False),
    Column("evidence_hash", String(64), nullable=False),
)

# ── Prova (evidence ledger) — cobertura sobrevive à máquina (S9) ────────
#
# `proof_runs`  — uma execução de prova (mutação hoje, outra amanhã) e o veredito declarado
# `proof_items` — uma linha por item provado (M[id]), com valor 1 (feito) / 0 (não feito)
# O `run_id` de `proof_items` aponta para `proof_runs.id`, reusando o helper list_by_run.

proof_runs = Table(
    "proof_runs",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("target", String(32), nullable=False),
    Column("started_at", String(32), nullable=False),  # ISO 8601
    Column("finished_at", String(32), nullable=True),
    Column("status", String(16), nullable=False),
    Column("catalog_total", Integer, nullable=False),
    Column("killed", Integer, nullable=False),
    Column("product", Integer, nullable=False),
    Column("complete", Boolean, nullable=False),
    Column("source_hash", String(64), nullable=False),
)

proof_items = Table(
    "proof_items",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("run_id", String(36), nullable=False, index=True),
    Column("item_id", String(16), nullable=False, index=True),
    Column("proof_kind", String(32), nullable=False),
    Column("status", String(16), nullable=False),
    Column("value", Integer, nullable=False),
    Column("file", Text, nullable=True),
    Column("test", Text, nullable=True),
    Column("seconds", Integer, nullable=False),
    Column("evidence_hash", String(64), nullable=False),
)

# ── Table registry (for repository layer) ───────────────────────────────

TABLE_REGISTRY = {
    "run": runs,
    "probe": probes,
    "transition": transitions,
    "objective": objectives,
    "risk": risks,
    "proof_run": proof_runs,
    "proof_item": proof_items,
}
