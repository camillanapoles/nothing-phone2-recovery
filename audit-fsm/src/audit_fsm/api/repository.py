"""
Repository layer — bridges ValidatedModelBase objects and SQLAlchemy rows (S4, T5).

Every write goes through DomainFactory.create/update (metaclass validators),
then to_dict() → row insert. Every read re-validates via DomainFactory.create
(row → domain object). This guarantees the same validation on read and write.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import Table as SATable
from sqlalchemy import delete, insert, select, update

from ..domain.factory import DomainFactory
from ..domain.metaclass import ValidationError
from .db import get_engine


async def _table_for(kind: str) -> SATable:
    """Resolve the SQLAlchemy Table for a domain kind (lazy import avoids cycle)."""
    from ..domain.tables import TABLE_REGISTRY

    if kind not in TABLE_REGISTRY:
        raise ValidationError(
            "(repository)",
            kind,
            f"unknown domain kind; registered: {sorted(TABLE_REGISTRY)}",
        )
    return TABLE_REGISTRY[kind]


async def insert_one(kind: str, obj: Any) -> dict[str, Any]:
    """Insert a validated domain object as a row. Returns the row as dict."""
    table = await _table_for(kind)
    engine = get_engine()
    data = obj.to_dict()
    async with engine.begin() as conn:  # type: ignore[union-attr]
        await conn.execute(insert(table).values(**data))
    return data


async def get_by_id(kind: str, obj_id: str) -> dict[str, Any] | None:
    """Fetch a row by primary key and re-validate through DomainFactory."""
    table = await _table_for(kind)
    engine = get_engine()
    async with engine.connect() as conn:  # type: ignore[union-attr]
        result = await conn.execute(select(table).where(table.c.id == obj_id))
        row = result.mappings().first()
    if row is None:
        return None
    # Re-validate on read: row → DomainFactory.create → to_dict
    obj = DomainFactory.create(kind, **dict(row))
    return obj.to_dict()


async def list_all(kind: str) -> list[dict[str, Any]]:
    """List all rows for a kind, re-validated through DomainFactory."""
    table = await _table_for(kind)
    engine = get_engine()
    async with engine.connect() as conn:  # type: ignore[union-attr]
        result = await conn.execute(select(table).order_by(table.c.id))
        rows = result.mappings().all()
    return [DomainFactory.create(kind, **dict(r)).to_dict() for r in rows]


async def list_by_run(kind: str, run_id: str) -> list[dict[str, Any]]:
    """List all rows for a given run_id (for probe/transition/objective/risk)."""
    table = await _table_for(kind)
    engine = get_engine()
    async with engine.connect() as conn:  # type: ignore[union-attr]
        result = await conn.execute(
            select(table).where(table.c.run_id == run_id).order_by(table.c.id)
        )
        rows = result.mappings().all()
    return [DomainFactory.create(kind, **dict(r)).to_dict() for r in rows]


async def update_by_id(kind: str, obj_id: str, **kwargs: Any) -> dict[str, Any] | None:
    """Update a row: read → DomainFactory.update (validate) → write back."""
    table = await _table_for(kind)
    engine = get_engine()
    async with engine.connect() as conn:  # type: ignore[union-attr]
        result = await conn.execute(select(table).where(table.c.id == obj_id))
        row = result.mappings().first()
    if row is None:
        return None
    # Read → validate → update → write
    obj = DomainFactory.create(kind, **dict(row))
    DomainFactory.update(obj, **kwargs)
    updated = obj.to_dict()
    async with engine.begin() as conn:  # type: ignore[union-attr]
        await conn.execute(update(table).where(table.c.id == obj_id).values(**updated))
    return updated


async def delete_by_id(kind: str, obj_id: str) -> bool:
    """Delete a row by primary key. Returns True if a row was deleted."""
    table = await _table_for(kind)
    engine = get_engine()
    async with engine.begin() as conn:  # type: ignore[union-attr]
        result = await conn.execute(delete(table).where(table.c.id == obj_id))
    return result.rowcount > 0  # type: ignore[union-attr]
