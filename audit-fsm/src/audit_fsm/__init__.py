"""
audit-fsm — Safety-first Android device recovery audit framework.

Package structure:
  domain/       — ValidatedModelMetaclass, FieldSpec, domain models, validators
  fsm/          — FSMState, FSMEngine, FSMContext, Evidence
  probes/       — Read-only ADB probe library + PROBE_REGISTRY
  safety/       — Safety guard: blocks mutating commands
  api/          — FastAPI app + CRUD endpoints via DomainFactory
  agents/       — Pydantic AI V2 agents (orchestrator + consultation)
  cli/          — CLI entrypoint (audit-fsm run / audit-fsm consult)
  config/       — Environment-based configuration
"""

from .domain.factory import DomainFactory
from .fsm.core import Evidence, FSMContext, FSMEngine, FSMError, FSMState
from .probes.catalog import PROBE_REGISTRY
from .safety import SafetyViolation, assert_safe, check_command

__all__ = [
    "PROBE_REGISTRY",
    "DomainFactory",
    "Evidence",
    "FSMContext",
    "FSMEngine",
    "FSMError",
    "FSMState",
    "SafetyViolation",
    "assert_safe",
    "check_command",
]
