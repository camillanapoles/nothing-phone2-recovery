"""
Camada de prova (S9) — o ledger de validação vira dado durável no banco.

Problema que resolve: a cobertura de mutação vivia em `workspace/audit/mutation-latest.json`,
um artefato da máquina que rodou. Quem não rodou não audita, e a cobertura morria com o runner.

Aqui o ledger é **traduzido** para objetos de domínio validados (ProofRun + ProofItem) e
persistido pelo mesmo caminho de todo o resto: DomainFactory → repository → SQLAlchemy Core.

Regras:
  - ids determinísticos (uuid5): a mesma origem gera as mesmas linhas → reimportar não duplica;
  - `source_hash` = sha256 do ledger: origem editada muda o hash e a prova deixa de bater;
  - valor da cobertura é `1` (provado) / `0` (não executado ou sobreviveu) — produto sem hardcode.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any

from .ledger import (
    SEM_TIMESTAMP,
    build_items,
    build_run,
    divergencias,
    normalizar,
    resumo_de,
    veredito_de,
)

__all__ = [
    "SEM_TIMESTAMP",
    "build_items",
    "build_run",
    "divergencias",
    "load_ledger",
    "normalizar",
    "resumo_de",
    "source_hash",
    "summarize",
    "veredito_de",
]


def load_ledger(path: str) -> dict[str, Any]:
    """Lê um ledger (ou relatório de slot) do disco e canoniza no formato `entries`."""
    with open(path, encoding="utf-8") as fh:
        return normalizar(json.load(fh))


def source_hash(ledger: dict[str, Any]) -> str:
    """sha256 do ledger canônico (ordem de chaves estável) — a identidade da origem."""
    canon = json.dumps(ledger, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    """Resumo derivado do ledger normalizado (nada digitado): total, mortos, produto, completo."""
    return resumo_de(ledger.get("entries") or {}, catalog_total=len(ledger.get("entries") or {}))
