"""Integração da camada de prova (S9): ledger → banco → API → auditoria por run_id.

Prova o caminho completo, sem atalho:
  1. importa o ledger pelo mesmo repository do resto do FSM (revalidando na leitura);
  2. reimporta e confirma idempotência (1 run, N itens — não 2N);
  3. lê a cobertura pela API (`/proof_runs`, `/proof_items`, `/runs/{id}/proof_items`);
  4. recalcula o veredito das LINHAS e acusa run adulterada no banco.
"""

from __future__ import annotations

import copy

import pytest
from httpx import ASGITransport, AsyncClient

from audit_fsm.api.app import app
from audit_fsm.api.db import dispose_engine, init_db
from audit_fsm.api.repository import list_all, list_by_run, update_by_id
from audit_fsm.domain.metaclass import ValidationError
from audit_fsm.proof import build_items, build_run, source_hash
from audit_fsm.proof.ledger import veredito_de

LEDGER = {
    "started_at": "2026-11-02T17:40:00",
    "entries": {
        "M1": {"status": "killed", "value": 1, "file": "a.py", "test": "t1", "seconds": 1},
        "M2": {"status": "survived", "value": 0, "file": "a.py", "test": "t2", "seconds": 2},
        "M3": {"status": "killed", "value": 1, "file": "b.py", "test": "t3", "seconds": 3},
    },
}


@pytest.fixture(autouse=True)
async def _db_setup(tmp_path):
    import os

    orig = os.environ.get("AUDIT_FSM_DB_URL", "")
    os.environ["AUDIT_FSM_DB_URL"] = f"sqlite+aiosqlite:///{tmp_path}/proof.db"
    await init_db()
    yield
    os.environ["AUDIT_FSM_DB_URL"] = orig
    await dispose_engine()


@pytest.fixture
def client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _importar(ledger: dict) -> tuple[str, int]:
    """Importa pelo caminho do domínio (build → repository), como o CLI faz."""
    from audit_fsm.api.repository import upsert_one

    sha = source_hash(ledger)
    run = build_run(ledger, sha).to_dict()
    await upsert_one("proof_run", build_run(ledger, sha))
    itens = build_items(ledger, build_run(ledger, sha))
    for item in itens:
        await upsert_one("proof_item", item)
    return run["id"], len(itens)


async def test_import_is_idempotent():
    run_id, n = await _importar(LEDGER)
    await _importar(copy.deepcopy(LEDGER))
    runs = await list_all("proof_run")
    itens = await list_by_run("proof_item", run_id)
    assert len(runs) == 1 and len(itens) == n == len(LEDGER["entries"])


async def test_coverage_survives_and_is_auditable_by_run_id():
    run_id, _ = await _importar(LEDGER)
    runs = await list_all("proof_run")
    assert [r["id"] for r in runs] == [run_id]
    itens = await list_by_run("proof_item", run_id)
    rec = veredito_de(runs[0], itens)
    assert rec == {"total": 3, "killed": 2, "product": 0, "complete": False}
    # o veredito declarado na run bate com as linhas
    assert runs[0]["killed"] == rec["killed"] and runs[0]["complete"] is rec["complete"]


async def test_api_serves_proof_kinds(client):
    run_id, n = await _importar(LEDGER)
    async with client as c:
        kinds = (await c.get("/api/kinds")).json()["registered_kinds"]
        assert {"proof_run", "proof_item"} <= set(kinds)

        resp = await c.get("/api/proof_runs")
        assert resp.status_code == 200 and len(resp.json()) == 1

        por_run = await c.get(f"/api/runs/{run_id}/proof_items")
        assert por_run.status_code == 200 and len(por_run.json()) == n

        item = (await c.get("/api/proof_items")).json()[0]
        detalhe = await c.get(f"/api/proof_items/{item['id']}")
        assert detalhe.status_code == 200 and detalhe.json()["value"] in (0, 1)


async def test_read_revalidates_against_registry(client):
    """Linha adulterada no banco não passa na leitura (repository re-valida)."""
    run_id, _ = await _importar(LEDGER)
    itens = await list_by_run("proof_item", run_id)
    alvo = itens[0]["id"]
    # grava direto no banco, furando o domínio
    import sqlalchemy as sa

    from audit_fsm.api.db import get_engine
    from audit_fsm.domain.tables import TABLE_REGISTRY

    engine = get_engine()
    async with engine.begin() as conn:  # type: ignore[union-attr]
        await conn.execute(
            sa.update(TABLE_REGISTRY["proof_item"])
            .where(TABLE_REGISTRY["proof_item"].c.id == alvo)
            .values(value=7)
        )
    with pytest.raises(ValidationError):
        await list_by_run("proof_item", run_id)


async def test_tampered_run_is_caught_by_rows():
    run_id, _ = await _importar(LEDGER)
    await update_by_id("proof_run", run_id, killed=3, product=1, complete=True)
    run = (await list_all("proof_run"))[0]
    rec = veredito_de(run, await list_by_run("proof_item", run_id))
    assert run["complete"] is True and run["killed"] == 3
    assert rec["complete"] is False and rec["killed"] == 2  # divergência detectável
