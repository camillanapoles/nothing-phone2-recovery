"""
FSM core — states, transitions, guards, engine (S2).

Safety-first audit Finite State Machine. Every transition is guarded by
evidence (a probe result with evidence_hash). Terminal states: SAFE / UNSAFE /
BLOCKED. The engine never executes a mutating command — that is enforced by the
safety guard (T8) at the command level, and by the FSM only ever emitting
read-only probe requests.

Flow::

    INIT
      → PROBE_DEVICE       (guard: adb path resolved)
      → CHECK_BOOTLOADER   (guard: device_state evidence recorded)
      → CHECK_ROOT         (guard: bootloader evidence recorded)
      → CHECK_PARTITIONS   (guard: root evidence recorded)
      → CHECK_PACKAGES     (guard: partition evidence recorded)
      → CHECK_PLAY_INTEGRITY(guard: package evidence recorded)
      → ASSESS_RISK        (guard: integrity evidence recorded)
      → CONSULT_AGENT      (guard: risk verdict recorded)
      → TERMINAL_SAFE | TERMINAL_UNSAFE | TERMINAL_BLOCKED
"""

from __future__ import annotations

import enum
from collections.abc import Callable
from dataclasses import dataclass, field

from ..domain.metaclass import evidence_hash

# ── States (S2) ─────────────────────────────────────────────────────────


class FSMState(str, enum.Enum):
    """All reachable FSM states. Terminal states are prefixed TERMINAL_."""

    # transient
    INIT = "init"
    PROBE_DEVICE = "probe_device"
    CHECK_BOOTLOADER = "check_bootloader"
    CHECK_ROOT = "check_root"
    CHECK_PARTITIONS = "check_partitions"
    CHECK_PACKAGES = "check_packages"
    CHECK_PLAY_INTEGRITY = "check_play_integrity"
    ASSESS_RISK = "assess_risk"
    CONSULT_AGENT = "consult_agent"

    # terminal
    TERMINAL_SAFE = "terminal_safe"
    TERMINAL_UNSAFE = "terminal_unsafe"
    TERMINAL_BLOCKED = "terminal_blocked"

    @property
    def is_terminal(self) -> bool:
        return self.value.startswith("terminal_")

    @property
    def is_transient(self) -> bool:
        return not self.is_terminal


# ── Guards (S2) ──────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Guard:
    """A transition guard. Returns True if the transition is permitted.

    Guards check that evidence exists before allowing a transition — the
    "evidence-guarded transitions" contract (S2). A guard that returns False
    blocks the transition; the engine stays in the current state and records a
    BLOCKED reason.
    """

    name: str
    check: Callable[[FSMContext], bool]


# ── Transition (S2) ─────────────────────────────────────────────────────


@dataclass(frozen=True)
class Transition:
    """A single edge in the FSM: from → to, gated by a guard."""

    from_state: FSMState
    to_state: FSMState
    guard: Guard
    description: str = ""


# ── Evidence (S2, S3) ────────────────────────────────────────────────────


@dataclass
class Evidence:
    """A probe result with provenance hash. The FSM only transitions when
    evidence for the current objective has been recorded."""

    command: str
    stdout: str
    stderr: str
    exit_code: int

    @property
    def hash(self) -> str:
        return evidence_hash(self.command, self.stdout, self.stderr, self.exit_code)


# ── FSM context ──────────────────────────────────────────────────────────


@dataclass
class FSMContext:
    """Mutable context carried through the audit. Evidence is keyed by the
    state that produced it."""

    device_serial: str | None = None
    adb_path: str | None = None
    evidence: dict[FSMState, Evidence] = field(default_factory=dict)
    risk_verdict: str | None = None  # set by ASSESS_RISK
    agent_answer: str | None = None  # set by CONSULT_AGENT
    blocked_reason: str | None = None  # set when a guard blocks

    def has_evidence(self, state: FSMState) -> bool:
        return state in self.evidence

    def record_evidence(self, state: FSMState, ev: Evidence) -> None:
        self.evidence[state] = ev


# ── Transition table (S2) ───────────────────────────────────────────────


def _build_transitions() -> list[Transition]:
    """The static transition table. No hardcoded verdicts — terminal state is
    decided by the risk assessment + agent consultation results."""

    def _has(ctx: FSMContext, state: FSMState) -> bool:
        return ctx.has_evidence(state)

    return [
        Transition(
            FSMState.INIT,
            FSMState.PROBE_DEVICE,
            Guard("adb_path_resolved", lambda c: c.adb_path is not None),
            "Resolve ADB path before probing",
        ),
        Transition(
            FSMState.PROBE_DEVICE,
            FSMState.CHECK_BOOTLOADER,
            Guard("device_evidence", lambda c: _has(c, FSMState.PROBE_DEVICE)),
            "Record device state evidence",
        ),
        Transition(
            FSMState.CHECK_BOOTLOADER,
            FSMState.CHECK_ROOT,
            Guard("bootloader_evidence", lambda c: _has(c, FSMState.CHECK_BOOTLOADER)),
            "Record bootloader state evidence",
        ),
        Transition(
            FSMState.CHECK_ROOT,
            FSMState.CHECK_PARTITIONS,
            Guard("root_evidence", lambda c: _has(c, FSMState.CHECK_ROOT)),
            "Record root state evidence",
        ),
        Transition(
            FSMState.CHECK_PARTITIONS,
            FSMState.CHECK_PACKAGES,
            Guard("partition_evidence", lambda c: _has(c, FSMState.CHECK_PARTITIONS)),
            "Record partition health evidence",
        ),
        Transition(
            FSMState.CHECK_PACKAGES,
            FSMState.CHECK_PLAY_INTEGRITY,
            Guard("package_evidence", lambda c: _has(c, FSMState.CHECK_PACKAGES)),
            "Record package state evidence",
        ),
        Transition(
            FSMState.CHECK_PLAY_INTEGRITY,
            FSMState.ASSESS_RISK,
            Guard("integrity_evidence", lambda c: _has(c, FSMState.CHECK_PLAY_INTEGRITY)),
            "Record Play Integrity evidence",
        ),
        Transition(
            FSMState.ASSESS_RISK,
            FSMState.CONSULT_AGENT,
            Guard("risk_verdict", lambda c: c.risk_verdict is not None),
            "Assess risk and record verdict",
        ),
        # terminal transitions — decided by agent answer, not hardcoded
        Transition(
            FSMState.CONSULT_AGENT,
            FSMState.TERMINAL_SAFE,
            Guard("agent_says_safe", lambda c: c.agent_answer == "safe"),
            "Agent consultation verdict: safe",
        ),
        Transition(
            FSMState.CONSULT_AGENT,
            FSMState.TERMINAL_UNSAFE,
            Guard("agent_says_unsafe", lambda c: c.agent_answer == "unsafe"),
            "Agent consultation verdict: unsafe",
        ),
        Transition(
            FSMState.CONSULT_AGENT,
            FSMState.TERMINAL_BLOCKED,
            Guard("agent_says_blocked", lambda c: c.agent_answer == "blocked"),
            "Agent consultation verdict: blocked",
        ),
    ]


_TRANSITIONS: list[Transition] = _build_transitions()


# ── FSM engine (S2) ─────────────────────────────────────────────────────


class FSMEngine:
    """Drives the audit FSM. Does NOT execute commands — it emits probe
    requests that the orchestrator (T7) fulfills via the probe library (T3).
    Every transition is evidence-guarded."""

    def __init__(self, context: FSMContext | None = None) -> None:
        self.context = context or FSMContext()
        self.state: FSMState = FSMState.INIT
        self.history: list[tuple[FSMState, FSMState, bool, str]] = []

    def available_transitions(self) -> list[Transition]:
        """Return transitions from the current state whose guard passes."""
        result = []
        for t in _TRANSITIONS:
            if t.from_state is self.state and t.guard.check(self.context):
                result.append(t)
        return result

    def can_advance(self) -> bool:
        return bool(self.available_transitions())

    def advance(self) -> FSMState:
        """Advance one step. If no guard passes, stays in current state and
        records the blocked reason. Raises if already terminal."""
        if self.state.is_terminal:
            raise FSMError(f"cannot advance from terminal state {self.state}")
        available = self.available_transitions()
        if not available:
            self.context.blocked_reason = (
                f"no guard passed from {self.state.value}; missing evidence or prerequisite"
            )
            self.history.append((self.state, self.state, False, self.context.blocked_reason))
            return self.state
        # take the first available transition (deterministic order)
        t = available[0]
        prev = self.state
        self.state = t.to_state
        self.history.append((prev, self.state, True, t.description))
        return self.state

    def run_until_terminal(self, max_steps: int = 50) -> FSMState:
        """Drive the FSM until it reaches a terminal state or stalls.
        Safety: bounded by max_steps to prevent infinite loops."""
        for _ in range(max_steps):
            if self.state.is_terminal:
                return self.state
            if not self.can_advance():
                # stalled — record blocked and stop
                self.context.blocked_reason = (
                    f"stalled at {self.state.value}: no available transition"
                )
                return self.state
            self.advance()
        raise FSMError(f"FSM did not reach terminal state within {max_steps} steps")


class FSMError(RuntimeError):
    """FSM violation: advancing from terminal, infinite loop, etc."""
