"""
Audit orchestrator agent — Pydantic AI V2 agent that drives the FSM (S8, T7).

The orchestrator agent is responsible for:
  1. Observing the current FSM state and available probes
  2. Deciding which probe to execute next (or declaring terminal if complete)
  3. Returning a typed `NextProbe(name, rationale, is_terminal)` output

The FSM engine loop (see `fsm/engine.py`) calls the agent at each state,
executes the chosen probe via the probe library (T3), records evidence, and
advances the FSM. The agent itself never touches the DB or filesystem — it
only emits the next probe decision.

Model config is read from env vars via `config.py` (default: "test" provider).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field

from pydantic import BaseModel, Field
from pydantic_ai import Agent, RunContext, Tool

from ..fsm.core import FSMState

# ── Output schema ────────────────────────────────────────────────────────────


class NextProbe(BaseModel):
    """The orchestrator's decision: which probe to run next."""

    name: str = Field(
        description="Name of the probe function to execute (must match a key in PROBE_REGISTRY for the current state)"
    )
    rationale: str = Field(
        description="Why this probe is the right next step given the current FSM state and prior evidence"
    )
    is_terminal: bool = Field(
        default=False,
        description="True if no more probes are needed and the FSM should advance to assessment/consultation",
    )


# ── Dependencies ─────────────────────────────────────────────────────────────


@dataclass
class OrchestratorDeps:
    """Shared dependencies injected into every tool call."""

    current_state: FSMState
    available_probes: list[str] = field(default_factory=list)
    prior_results: dict[str, str] = field(default_factory=dict)
    adb_path: str = ""
    serial: str = ""


# ── Read-only tools ──────────────────────────────────────────────────────────


async def get_state_info(ctx: RunContext[OrchestratorDeps]) -> str:
    """Return the current FSM state and the list of available probes for it."""
    state_info = {
        "current_state": ctx.deps.current_state.value,
        "available_probes": ctx.deps.available_probes,
        "prior_probe_names": list(ctx.deps.prior_results.keys()),
    }
    return json.dumps(state_info, default=str)


async def get_probe_result(ctx: RunContext[OrchestratorDeps], probe_name: str) -> str:
    """Return the stdout/stderr of a previously executed probe, or 'not yet run'."""
    if probe_name in ctx.deps.prior_results:
        return ctx.deps.prior_results[probe_name]
    return json.dumps({"status": "not_yet_run", "probe": probe_name})


# ── System prompt ────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are the audit orchestrator for a safety-first Android device recovery audit.

Your job is to decide which read-only ADB probe to run NEXT, based on:
  - The current FSM state (where we are in the audit pipeline)
  - The list of available probes for that state
  - The results of probes already executed

FSM pipeline order (always follow this sequence):
  1. PROBE_DEVICE        → get device properties (fingerprint, kernel, slot)
  2. CHECK_BOOTLOADER    → check bootloader lock, verified boot, slot, SELinux
  3. CHECK_ROOT          → check for su, Magisk, KernelSU, APatch, Droidspaces
  4. CHECK_PARTITIONS    → check partition sizes, especially /vendor and /data
  5. CHECK_PACKAGES      → list third-party and Google packages
  6. CHECK_PLAY_INTEGRITY → check Play Store and GMS state, crash logs

Rules:
- Always pick a probe that HAS NOT been run yet (check prior_probe_names).
- If all probes for the current state have been run, set is_terminal=true.
- Your rationale must reference specific evidence from prior probe results.
- Never suggest a probe outside the available_probes list.
- Be deterministic: same state + same prior results → same choice.
- The output MUST be a valid NextProbe JSON object.
"""


# ── Agent definition ─────────────────────────────────────────────────────────

orchestrator_agent = Agent[OrchestratorDeps, NextProbe](
    "test",
    output_type=NextProbe,
    system_prompt=_SYSTEM_PROMPT,
    tools=[
        Tool(get_state_info, takes_ctx=True),
        Tool(get_probe_result, takes_ctx=True),
    ],
    deps_type=OrchestratorDeps,
)
