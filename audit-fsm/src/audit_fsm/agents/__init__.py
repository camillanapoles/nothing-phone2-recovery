"""
Agents package — Pydantic AI V2 agents for the audit FSM (S8).

Exported:
  - consultation_agent: answers natural-language queries over stored data (S5)
  - orchestrator_agent: drives FSM state transitions by selecting next probe (S8, T7)
"""

from .consultation import (
    AgentDeps as ConsultationDeps,
)
from .consultation import (
    ConsultationAnswer,
    consultation_agent,
)
from .orchestrator import (
    NextProbe,
    OrchestratorDeps,
    orchestrator_agent,
)

__all__ = [
    "ConsultationAnswer",
    "ConsultationDeps",
    "NextProbe",
    "OrchestratorDeps",
    "consultation_agent",
    "orchestrator_agent",
]
