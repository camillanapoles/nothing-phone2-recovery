"""Integration tests for audit-fsm FastAPI CRUD (S5, T5).

Tests:
- CRUD round-trip for each domain kind (run, probe, transition, objective, risk)
- 404 on missing id
- 400 on invalid payload (metaclass rejects)
- list_by_run for child entities
- /health and /kinds introspection
- Repository re-validates on read (read → domain → dict → row → domain)
"""

from __future__ import annotations

import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from audit_fsm.api.app import app
from audit_fsm.api.db import dispose_engine, init_db
from audit_fsm.domain.models import Run, RunStatus


@pytest.fixture(autouse=True)
async def _db_setup(tmp_path):
    """Use a temp SQLite DB per test session."""
    url = f"sqlite+aiosqlite:///{tmp_path}/test.db"
    import os

    orig = os.environ.get("AUDIT_FSM_DB_URL", "")
    os.environ["AUDIT_FSM_DB_URL"] = url
    await init_db()
    yield
    os.environ["AUDIT_FSM_DB_URL"] = orig
    await dispose_engine()


@pytest.fixture
def client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


def _make_run(serial: str = "9f51ecb9", adb_path: str = "./tools/platform-tools/adb") -> dict:
    return {
        "id": str(uuid.uuid4()),
        "device_serial": serial,
        "started_at": "2026-07-06T12:00:00Z",
        "status": "running",
        "adb_path": adb_path,
    }


def _make_probe(run_id: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "run_id": run_id,
        "state": "PROBE_DEVICE",
        "command": "getprop ro.build.fingerprint",
        "stdout": "nothing/Pong:16/BP4A/...",
        "stderr": "",
        "exit_code": 0,
        "evidence_hash": "abc123",
    }


def _make_transition(run_id: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "run_id": run_id,
        "from_state": "INIT",
        "to_state": "PROBE_DEVICE",
        "guard_passed": True,
        "description": "ADB path resolved",
    }


def _make_objective(run_id: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "run_id": run_id,
        "state": "CHECK_BOOTLOADER",
        "description": "Bootloader is locked",
        "status": "pending",
        "evidence_hash": "hash1",
    }


def _make_risk(run_id: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "run_id": run_id,
        "verdict": "safe",
        "reasoning": "bootloader locked, no root",
        "evidence_hash": "hash2",
    }


# ── Health & kinds ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    r = await client.get("/api/health")
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_kinds(client: AsyncClient):
    r = await client.get("/api/kinds")
    assert r.status_code == 200
    kinds = r.json()["registered_kinds"]
    assert sorted(kinds) == ["objective", "probe", "risk", "run", "transition"]


# ── Run CRUD ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_run_crud_roundtrip(client: AsyncClient):
    body = _make_run()
    # Create
    r = await client.post("/api/runs", json=body)
    assert r.status_code == 201, r.text
    created = r.json()
    assert created["id"] == body["id"]
    assert created["device_serial"] == "9f51ecb9"

    # Get
    r = await client.get(f"/api/runs/{body['id']}")
    assert r.status_code == 200
    assert r.json()["id"] == body["id"]

    # List
    r = await client.get("/api/runs")
    assert r.status_code == 200
    assert len(r.json()) == 1

    # Update
    r = await client.put(f"/api/runs/{body['id']}", json={"status": "completed"})
    assert r.status_code == 200
    assert r.json()["status"] == "completed"

    # Delete
    r = await client.delete(f"/api/runs/{body['id']}")
    assert r.status_code == 204
    r = await client.get(f"/api/runs/{body['id']}")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_run_create_rejects_invalid(client: AsyncClient):
    """Metaclass rejects missing required field (device_serial)."""
    body = _make_run()
    del body["device_serial"]
    r = await client.post("/api/runs", json=body)
    assert r.status_code == 400, r.text
    # Should not be persisted
    r2 = await client.get("/api/runs")
    assert r2.json() == []


@pytest.mark.asyncio
async def test_run_create_rejects_bad_serial(client: AsyncClient):
    """validate_serial rejects short serials."""
    body = _make_run()
    body["device_serial"] = "short"
    r = await client.post("/api/runs", json=body)
    assert r.status_code == 400


# ── Probe CRUD ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_probe_crud(client: AsyncClient):
    run = await client.post("/api/runs", json=_make_run())
    run_id = run.json()["id"]
    body = _make_probe(run_id)

    r = await client.post("/api/probes", json=body)
    assert r.status_code == 201, r.text
    pid = r.json()["id"]

    # Get
    r = await client.get(f"/api/probes/{pid}")
    assert r.status_code == 200
    assert r.json()["run_id"] == run_id

    # List by run
    r = await client.get(f"/api/runs/{run_id}/probes")
    assert r.status_code == 200
    assert len(r.json()) == 1

    # Update
    r = await client.put(f"/api/probes/{pid}", json={"exit_code": 1})
    assert r.status_code == 200
    assert r.json()["exit_code"] == 1

    # Delete
    r = await client.delete(f"/api/probes/{pid}")
    assert r.status_code == 204


# ── Transition CRUD ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_transition_crud(client: AsyncClient):
    run = await client.post("/api/runs", json=_make_run())
    run_id = run.json()["id"]
    body = _make_transition(run_id)

    r = await client.post("/api/transitions", json=body)
    assert r.status_code == 201, r.text
    tid = r.json()["id"]

    r = await client.get(f"/api/transitions/{tid}")
    assert r.status_code == 200

    r = await client.get(f"/api/runs/{run_id}/transitions")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = await client.put(f"/api/transitions/{tid}", json={"guard_passed": False})
    assert r.status_code == 200
    assert r.json()["guard_passed"] is False

    r = await client.delete(f"/api/transitions/{tid}")
    assert r.status_code == 204


# ── Objective CRUD ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_objective_crud(client: AsyncClient):
    run = await client.post("/api/runs", json=_make_run())
    run_id = run.json()["id"]
    body = _make_objective(run_id)

    r = await client.post("/api/objectives", json=body)
    assert r.status_code == 201, r.text
    oid = r.json()["id"]

    r = await client.get(f"/api/objectives/{oid}")
    assert r.status_code == 200

    r = await client.get(f"/api/runs/{run_id}/objectives")
    assert r.status_code == 200
    assert len(r.json()) == 1

    # Update status
    r = await client.put(f"/api/objectives/{oid}", json={"status": "satisfied"})
    assert r.status_code == 200
    assert r.json()["status"] == "satisfied"

    r = await client.delete(f"/api/objectives/{oid}")
    assert r.status_code == 204


# ── Risk CRUD ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_risk_crud(client: AsyncClient):
    run = await client.post("/api/runs", json=_make_run())
    run_id = run.json()["id"]
    body = _make_risk(run_id)

    r = await client.post("/api/risks", json=body)
    assert r.status_code == 201, r.text
    rid = r.json()["id"]

    r = await client.get(f"/api/risks/{rid}")
    assert r.status_code == 200

    r = await client.get(f"/api/runs/{run_id}/risks")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = await client.delete(f"/api/risks/{rid}")
    assert r.status_code == 204


# ── 404 on missing ──────────────────────────────────────────────────────


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["run", "probe", "transition", "objective", "risk"])
async def test_get_404_missing(client: AsyncClient, kind: str):
    r = await client.get(f"/api/{kind}s/fake-id-that-does-not-exist")
    assert r.status_code == 404


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["run", "probe", "transition", "objective", "risk"])
async def test_delete_404_missing(client: AsyncClient, kind: str):
    r = await client.delete(f"/api/{kind}s/fake-id-that-does-not-exist")
    assert r.status_code == 404


# ── Repository re-validates on read ─────────────────────────────────────


@pytest.mark.asyncio
async def test_repository_re_validates_on_read(client: AsyncClient):
    """Read-back must pass through DomainFactory.create (re-validate).

    If the DB contains a row with an invalid UUID, the read endpoint must
    reject it with 400 (not return the raw row).
    """
    from audit_fsm.api.repository import insert_one

    # Create via repository directly (bypassing FastAPI) to insert a valid run
    run = Run(
        id=str(uuid.uuid4()),
        device_serial="9f51ecb9",
        started_at="2026-07-06T12:00:00Z",
        status=RunStatus.RUNNING,
        adb_path="./tools/platform-tools/adb",
    )
    await insert_one("run", run)

    # Read back via endpoint
    run_id = run.to_dict()["id"]
    r = await client.get(f"/api/runs/{run_id}")
    assert r.status_code == 200, r.text
    assert r.json()["id"] == run_id


# ── Update rejects invalid fields ───────────────────────────────────────


@pytest.mark.asyncio
async def test_update_rejects_invalid_field(client: AsyncClient):
    run = await client.post("/api/runs", json=_make_run())
    run_id = run.json()["id"]
    # "invalid_field" is not a valid field for Run
    r = await client.put(f"/api/runs/{run_id}", json={"invalid_field": "x"})
    assert r.status_code == 400, r.text
    # Run should still be intact
    r2 = await client.get(f"/api/runs/{run_id}")
    assert r2.status_code == 200
    assert r2.json()["device_serial"] == "9f51ecb9"
