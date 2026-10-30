"""
Consultation agent — Pydantic AI V2 agent for natural-language queries
over stored audit data (S5, T6).

Read-only tools only. No write operations are exposed to the agent.
Output is typed via ConsultationAnswer to guarantee structure.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from pydantic import BaseModel, Field
from pydantic_ai import Agent, RunContext, Tool


@dataclass
class AgentDeps:
    """Shared dependencies injected into every tool call."""

    kind: str
    query: str


# ── Output schema ───────────────────────────────────────────────────────────


class ConsultationAnswer(BaseModel):
    """Structured answer grounded in stored evidence."""

    verdict: str = Field(description="SAFE | UNSAFE | BLOCKED — the high-level assessment")
    evidence: list[dict[str, Any]] = Field(
        description="List of evidence dicts (probe/transition/risk records) cited"
    )
    risks: list[str] = Field(default_factory=list, description="Bulleted risk items")
    recommendation: str = Field(
        description="One-sentence action recommendation grounded in evidence"
    )


# ── Read-only tools ────────────────────────────────────────────────────────


async def get_latest_run(ctx: RunContext[AgentDeps]) -> str:
    """Return the most recent audit run as JSON, or 'no runs found'."""
    try:
        from ..api.repository import list_all  # lazy to avoid circular import

        runs = await list_all("run")
        if not runs:
            return json.dumps({"status": "no_runs_found"})
        # Sort by started_at descending; pick latest
        runs_sorted = sorted(runs, key=lambda r: r.get("started_at", ""), reverse=True)
        return json.dumps(runs_sorted[0], default=str)
    except Exception as exc:  # noqa: BLE001
        return json.dumps({"error": str(exc)})


async def list_probes(ctx: RunContext[AgentDeps]) -> str:
    """Return all probes for the latest run, or 'no data'."""
    try:
        from ..api.repository import list_all, list_by_run

        runs = await list_all("run")
        if not runs:
            return json.dumps({"status": "no_runs_found"})
        latest_run_id = runs[-1]["id"]
        probes = await list_by_run("probe", latest_run_id)
        return json.dumps(probes, default=str)
    except Exception as exc:  # noqa: BLE001
        return json.dumps({"error": str(exc)})


async def list_risks(ctx: RunContext[AgentDeps]) -> str:
    """Return all risks for the latest run, or 'no data'."""
    try:
        from ..api.repository import list_all, list_by_run

        runs = await list_all("run")
        if not runs:
            return json.dumps({"status": "no_runs_found"})
        latest_run_id = runs[-1]["id"]
        risks = await list_by_run("risk", latest_run_id)
        return json.dumps(risks, default=str)
    except Exception as exc:  # noqa: BLE001
        return json.dumps({"error": str(exc)})


async def list_objectives(ctx: RunContext[AgentDeps]) -> str:
    """Return all objectives for the latest run, or 'no data'."""
    try:
        from ..api.repository import list_all, list_by_run

        runs = await list_all("run")
        if not runs:
            return json.dumps({"status": "no_runs_found"})
        latest_run_id = runs[-1]["id"]
        objs = await list_by_run("objective", latest_run_id)
        return json.dumps(objs, default=str)
    except Exception as exc:  # noqa: BLE001
        return json.dumps({"error": str(exc)})


# ── Agent definition ───────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are a safety-first Android device audit consultant.

You answer natural-language questions about stored audit data ONLY.
You must ground every answer in concrete evidence from the store.
Never speculate or invent evidence. If no data exists, say so clearly.

Your output MUST be a ConsultationAnswer with these fields:
- verdict: one of "SAFE", "UNSAFE", or "BLOCKED"
- evidence: list of evidence dicts you are citing
- risks: list of specific risk strings
- recommendation: one-sentence actionable recommendation

Rules:
- Always cite evidence_hash from Probe/Risk objects when referencing evidence
- For bootloader questions: check probe outputs for "locked" / "unlocked"
- For partition questions: check Probe stdout for df/partition info
- For root questions: check Probe stdout for su/magisk/kernelsu presence
- For Play Integrity: check Probe outputs and Risk entries
- A run ending in TERMINAL_SAFE means the device passed all checks
- A run ending in TERMINAL_BLOCKED means a critical risk was found
- A run ending in TERMINAL_UNSAFE means risks were found but not blocking
"""

consultation_agent = Agent[AgentDeps, ConsultationAnswer](
    "test",
    output_type=ConsultationAnswer,
    system_prompt=_SYSTEM_PROMPT,
    tools=[
        Tool(get_latest_run, takes_ctx=True),
        Tool(list_probes, takes_ctx=True),
        Tool(list_risks, takes_ctx=True),
        Tool(list_objectives, takes_ctx=True),
    ],
    deps_type=AgentDeps,
)
