"""
FastAPI application for audit-fsm (S5, T5).

Provides CRUD endpoints for all 5 domain kinds via DomainFactory.
Each endpoint validates through the metaclass; rejected updates return 400.

Endpoints:
  GET  /api/{kind}s           — list all
  GET  /api/{kind}s/{id}      — get by id (404 if missing)
  POST /api/{kind}s           — create (validates via metaclass)
  PUT  /api/{kind}s/{id}      — update (validates via metaclass)
  DEL  /api/{kind}s/{id}      — delete
  GET  /api/kinds             — registered kinds
  GET  /health                — liveness

Helper routes:
  GET /api/runs/{run_id}/probes          — list probes for a run
  GET /api/runs/{run_id}/transitions     — list transitions for a run
  GET /api/runs/{run_id}/objectives      — list objectives for a run
  GET /api/runs/{run_id}/risks           — list risks for a run
"""

from __future__ import annotations

from fastapi import APIRouter, FastAPI, HTTPException

# Import models FIRST so the metaclass registry is populated before
# DomainFactory.registered_kinds() is called in _register_routes().
from ..domain import models  # noqa: F401 — triggers metaclass registration
from ..domain.factory import DomainFactory
from .repository import (
    delete_by_id,
    get_by_id,
    insert_one,
    list_all,
    list_by_run,
    update_by_id,
)

router = APIRouter(prefix="/api")


# ── Helper: build endpoint functions for a domain kind ─────────────────


def _make_endpoints(kind: str):
    """Return (list_fn, get_fn, create_fn, update_fn, delete_fn) for *kind*."""

    async def list_fn() -> list[dict]:
        return await list_all(kind)

    async def get_fn(item_id: str) -> dict | None:
        obj = await get_by_id(kind, item_id)
        if obj is None:
            raise HTTPException(status_code=404, detail=f"{kind} not found")
        return obj

    async def create_fn(body: dict) -> dict:
        try:
            obj = DomainFactory.create(kind, **body)
        except Exception as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        return await insert_one(kind, obj)

    async def update_fn(item_id: str, body: dict) -> dict:
        try:
            updated = await update_by_id(kind, item_id, **body)
        except Exception as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        if updated is None:
            raise HTTPException(status_code=404, detail=f"{kind} not found")
        return updated

    async def delete_fn(item_id: str) -> None:
        deleted = await delete_by_id(kind, item_id)
        if not deleted:
            raise HTTPException(status_code=404, detail=f"{kind} not found")

    return list_fn, get_fn, create_fn, update_fn, delete_fn


# ── Route registration (after models import ensures registry is populated) ──


def _register_routes() -> None:
    """Register CRUD routes for all registered domain kinds."""
    kinds = DomainFactory.registered_kinds()
    for _kind in kinds:
        list_fn, get_fn, create_fn, update_fn, delete_fn = _make_endpoints(_kind)

        router.add_api_route(
            f"/{_kind}s", list_fn, methods=["GET"], tags=[_kind], summary=f"List all {_kind}s"
        )
        router.add_api_route(
            f"/{_kind}s/{{item_id}}",
            get_fn,
            methods=["GET"],
            tags=[_kind],
            summary=f"Get {_kind} by id",
        )
        router.add_api_route(
            f"/{_kind}s",
            create_fn,
            methods=["POST"],
            status_code=201,
            tags=[_kind],
            summary=f"Create {_kind}",
        )
        router.add_api_route(
            f"/{_kind}s/{{item_id}}",
            update_fn,
            methods=["PUT"],
            tags=[_kind],
            summary=f"Update {_kind}",
        )
        router.add_api_route(
            f"/{_kind}s/{{item_id}}",
            delete_fn,
            methods=["DELETE"],
            status_code=204,
            tags=[_kind],
            summary=f"Delete {_kind}",
        )


# Pre-register list-by-run helpers (independent of domain kinds)
for _ck in ("probe", "transition", "objective", "risk"):

    async def _list_run(kind=_ck, run_id: str = "") -> list[dict]:
        return await list_by_run(kind, run_id)

    router.add_api_route(
        f"/runs/{{run_id}}/{_ck}s",
        _list_run,
        methods=["GET"],
        tags=[_ck],
        summary=f"List {_ck}s for a run",
    )


@router.get("/health", tags=["health"])
async def health() -> dict:
    return {"status": "ok"}


@router.get("/kinds", tags=["fsm"])
async def list_kinds() -> dict:
    return {"registered_kinds": DomainFactory.registered_kinds()}


# ── App factory ────────────────────────────────────────────────────────

app = FastAPI(
    title="audit-fsm — Safety-First FSM Recovery Audit API",
    description=(
        "CRUD API for a safety-first FSM that audits Android device recovery "
        "states. All writes validate through a zero-hardcode metaclass registry."
    ),
    version="0.1.0",
)

_register_routes()
app.include_router(router)
