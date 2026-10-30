"""
CLI entrypoint for audit-fsm (S1-S8, T9).

Commands:
  audit-fsm run      — run a live audit against the device via the FSM
  audit-fsm consult — ask a natural-language question about stored audit data
"""

from __future__ import annotations

import asyncio
import json
import sys
from datetime import UTC

import click

from ..agents.consultation import AgentDeps, ConsultationAnswer, consultation_agent
from ..config import get_adb_path, get_serial
from ..domain.factory import DomainFactory
from ..domain.models import RunStatus
from ..fsm.core import Evidence, FSMContext, FSMEngine, FSMState
from ..probes.catalog import PROBE_REGISTRY

# ── Helpers ──────────────────────────────────────────────────────────────────


def _make_run(adb_path: str, serial: str):
    """Create a new Run domain object via DomainFactory."""
    import uuid
    from datetime import datetime

    return DomainFactory.create(
        "run",
        id=str(uuid.uuid4()),
        device_serial=serial,
        started_at=datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        status=RunStatus.RUNNING,
        adb_path=adb_path,
    )


def _record_evidence(ctx: FSMContext, state: FSMState, ev: Evidence) -> None:
    """Record evidence in the FSM context."""
    ctx.record_evidence(state, ev)


def _run_audit(adb_path: str, serial: str, max_steps: int = 50) -> dict:
    """Execute the audit FSM against the device.

    Returns a dict with the run summary.
    """
    # Create run record
    run = _make_run(adb_path, serial)

    # Initialize FSM
    ctx = FSMContext(device_serial=serial, adb_path=adb_path)
    engine = FSMEngine(ctx)

    # Run the FSM
    states_visited = [engine.state]
    for _ in range(max_steps):
        if engine.state.is_terminal:
            break

        # First: advance the FSM (handles INIT -> PROBE_DEVICE transition)
        if not engine.can_advance():
            engine.context.blocked_reason = (
                f"stalled at {engine.state.value}: no available transition"
            )
            break
        engine.advance()
        states_visited.append(engine.state)

        # Handle decision states (ASSESS_RISK, CONSULT_AGENT)
        if engine.state == FSMState.ASSESS_RISK:
            # Simple risk assessment based on evidence
            ctx.risk_verdict = _assess_risk(ctx)
            continue
        elif engine.state == FSMState.CONSULT_AGENT:
            # Call consultation agent for final verdict
            ctx.agent_answer = _consult_agent(ctx)
            continue

        # For probe states: get probes and execute
        probes = PROBE_REGISTRY.get(engine.state, [])
        if not probes:
            engine.context.blocked_reason = f"no probes registered for state {engine.state.value}"
            break

        # Execute each probe for the current state
        for probe_fn in probes:
            try:
                ev = probe_fn(adb_path, serial)
                _record_evidence(ctx, engine.state, ev)
            except Exception as exc:  # noqa: BLE001
                ev = Evidence(
                    command=f"probe error: {exc}",
                    stdout="",
                    stderr=str(exc),
                    exit_code=-1,
                )
                _record_evidence(ctx, engine.state, ev)

    # Determine final status
    final_state = engine.state
    if final_state == FSMState.TERMINAL_SAFE:
        status = "completed"
    elif final_state == FSMState.TERMINAL_UNSAFE:
        status = "unsafe"
    elif final_state == FSMState.TERMINAL_BLOCKED:
        status = "blocked"
    else:
        status = "incomplete"

    return {
        "run_id": run.to_dict()["id"],
        "device_serial": serial,
        "states_visited": [s.value for s in states_visited],
        "final_state": final_state.value,
        "status": status,
        "blocked_reason": engine.context.blocked_reason,
        "evidence_count": len(ctx.evidence),
    }


def _assess_risk(ctx: FSMContext) -> str:
    """Simple risk assessment based on evidence."""
    risks = []

    # Check bootloader
    if ctx.evidence.get(FSMState.CHECK_BOOTLOADER):
        boot_ev = ctx.evidence[FSMState.CHECK_BOOTLOADER]
        if "locked" in boot_ev.stdout:
            risks.append("bootloader_locked")

    # Check root
    if ctx.evidence.get(FSMState.CHECK_ROOT):
        root_ev = ctx.evidence[FSMState.CHECK_ROOT]
        if "found" in root_ev.stdout.lower() or "me.bmax.apatch" in root_ev.stdout:
            risks.append("root_detected")

    # Check partitions
    if ctx.evidence.get(FSMState.CHECK_PARTITIONS):
        part_ev = ctx.evidence[FSMState.CHECK_PARTITIONS]
        if "100%" in part_ev.stdout:
            risks.append("partition_full")

    # Check Play Integrity
    if ctx.evidence.get(FSMState.CHECK_PLAY_INTEGRITY):
        integrity_ev = ctx.evidence[FSMState.CHECK_PLAY_INTEGRITY]
        if "FAIL" in integrity_ev.stdout or "false" in integrity_ev.stdout.lower():
            risks.append("integrity_fail")

    if risks:
        return f"risk_detected: {', '.join(risks)}"
    return "no_risk"


def _consult_agent(ctx: FSMContext) -> str:
    """Call consultation agent for final verdict."""
    # For now, return a simple verdict based on risk assessment
    if "risk_detected" in ctx.risk_verdict or ctx.risk_verdict is None:
        return "blocked"
    return "safe"


# ── Commands ─────────────────────────────────────────────────────────────────


@click.group()
@click.version_option()
def cli() -> None:
    """audit-fsm — safety-first Android device audit."""


@cli.command()
@click.option("--adb", "adb_path", default=None, help="Path to adb binary")
@click.option("--serial", default=None, help="Device serial")
@click.option("--max-steps", default=50, type=int, help="Max FSM steps")
def run(adb_path: str | None, serial: str | None, max_steps: int) -> None:
    """Run a live audit against the device via the FSM."""
    adb = adb_path or get_adb_path()
    s = serial or get_serial()

    if not s:
        click.echo("Error: no device serial provided (set AUDIT_SERIAL or use --serial)", err=True)
        sys.exit(1)

    if not adb:
        click.echo("Error: no adb path resolved", err=True)
        sys.exit(1)

    result = _run_audit(adb, s, max_steps=max_steps)
    click.echo(json.dumps(result, indent=2, default=str))


@cli.command()
@click.argument("question")
@click.option(
    "--kind", "kind", default="run", help="Query kind: run | probe | risk | objective | transition"
)
def consult(question: str, kind: str) -> None:
    """Ask a natural-language question about stored audit data."""
    deps = AgentDeps(kind=kind, query=question)

    async def _run() -> ConsultationAnswer:
        result = await consultation_agent.run(question, deps=deps)
        return result.output

    answer = asyncio.run(_run())
    click.echo(json.dumps(answer.model_dump(), indent=2, default=str))


if __name__ == "__main__":
    cli()


def main():
    """Entry point for audit-fsm CLI."""
    from audit_fsm.cli import cli

    cli()
