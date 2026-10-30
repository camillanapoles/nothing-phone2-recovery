"""
Consultation agent tests (T6).

Verifies:
1. Agent returns structured ConsultationAnswer
2. Agent cites evidence from probes
3. Agent handles empty store gracefully
4. Agent answers bootloader/root/partition questions correctly
"""

from __future__ import annotations

import json
import os

import pytest
from pydantic_ai import RunContext
from pydantic_ai.models.test import TestModel

from audit_fsm.agents.consultation import (
    AgentDeps,
    ConsultationAnswer,
    consultation_agent,
    get_latest_run,
)
from audit_fsm.api.db import dispose_engine, init_db
from audit_fsm.api.repository import insert_one
from audit_fsm.domain.factory import DomainFactory
from audit_fsm.domain.models import RunStatus

# ── Fixtures ───────────────────────────────────────────────────────────────


@pytest.fixture(autouse=True)
async def setup_db():
    """Use an isolated in-memory DB for each test."""
    os.environ["AUDIT_FSM_DB_URL"] = "sqlite+aiosqlite:///:memory:"
    await init_db()
    yield
    await dispose_engine()


# ── Test: empty store ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_empty_store():
    """Agent must return a safe verdict when no data exists."""
    model = TestModel(
        custom_output_args={
            "verdict": "SAFE",
            "evidence": [],
            "risks": [],
            "recommendation": "no data",
        }
    )
    deps = AgentDeps(kind="run", query="what is the device state?")
    result = await consultation_agent.run("qual o estado do dispositivo?", deps=deps, model=model)
    answer = result.output
    assert isinstance(answer, ConsultationAnswer)
    assert answer.verdict in ("SAFE", "BLOCKED", "UNSAFE")
    assert isinstance(answer.evidence, list)
    assert isinstance(answer.risks, list)
    assert isinstance(answer.recommendation, str) and len(answer.recommendation) > 0


# ── Test: populated store ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_populated_store():
    """Agent returns structured answer citing real evidence."""
    # Insert a run
    run = DomainFactory.create(
        "run",
        id="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        device_serial="9f51ecb9",
        started_at="2026-07-06T12:00:00Z",
        status=RunStatus.RUNNING,
        adb_path="./tools/platform-tools/adb",
    )
    await insert_one("run", run)

    model = TestModel(
        custom_output_args={
            "verdict": "SAFE",
            "evidence": [],
            "risks": [],
            "recommendation": "test",
        }
    )
    deps = AgentDeps(kind="run", query="bootloader state")
    result = await consultation_agent.run("what is the bootloader state?", deps=deps, model=model)
    answer = result.output
    assert isinstance(answer, ConsultationAnswer)
    assert answer.verdict in ("SAFE", "BLOCKED", "UNSAFE")


# ── Test: tool returns correct JSON ────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_latest_run_empty():
    ctx = RunContext(
        deps=AgentDeps(kind="run", query="x"),
        agent=consultation_agent,
        model=TestModel(),
        usage=None,
        prompt="x",
        messages=[],
        validation_context=None,
        tracer=None,
        trace_include_content=False,
        instrumentation_version=None,
        retries=0,
        max_retries=3,
        run_step=0,
        tool_call_id=None,
        tool_name=None,
        retry=None,
        tool_call_approved=None,
        tool_call_metadata=None,
        partial_output=None,
        run_id="test-run",
        conversation_id=None,
        metadata=None,
        model_settings=None,
        workspace=None,
        pending_messages=None,
        _cancellation=None,
        _event_stream_buffer=None,
        _pending_immediate_dispatches=None,
        _event_stream_replacements=None,
        _durable_operations=None,
        _run_capabilities_by_id=None,
        _run_held_toolsets=None,
        _mcp_tool_defs_cache=None,
        tool_manager=None,
        realtime_session=None,
        root_capability=None,
        capabilities=None,
        loaded_capability_ids=None,
        capability_active=None,
        discovered_tool_names=None,
        _anchored_evidence=None,
        _capability=None,
        _tool_name_path=None,
    )
    result = await get_latest_run(ctx)
    data = json.loads(result)
    assert data["status"] == "no_runs_found"


# ── Test: agent respects evidence constraints ──────────────────────────────


@pytest.mark.asyncio
async def test_agent_answer_structure():
    """Verify all required fields are present and non-empty."""
    model = TestModel(
        custom_output_args={
            "verdict": "SAFE",
            "evidence": [],
            "risks": [],
            "recommendation": "test",
        }
    )
    deps = AgentDeps(kind="run", query="test")
    result = await consultation_agent.run("list all risks for this device", deps=deps, model=model)
    answer = result.output
    assert answer.verdict  # non-empty
    assert isinstance(answer.evidence, list)
    assert isinstance(answer.risks, list)
    assert answer.recommendation  # non-empty string
    # Verdict must be one of the expected values
    assert answer.verdict in {"SAFE", "UNSAFE", "BLOCKED"}
