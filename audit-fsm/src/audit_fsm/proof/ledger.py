"""
Tradutores ledger → domínio (S9).

Funções puras: recebem o dicionário do ledger (ou o relatório de mutação) e devolvem
objetos validados pelo metaclass. Nenhum id, contagem ou veredito é escrito à mão.

Determinismo (o requisito de auditoria):
  uuid5(namespace, f"{source_hash}:{target}")     → id da execução
  uuid5(namespace, f"{run_id}:{item_id}")         → id do item
Logo, reimportar o mesmo ledger gera exatamente as mesmas linhas, e ledgers diferentes
nunca colidem. O `evidence_hash` de cada item é o sha256 do seu próprio registro.

Formatos aceitos (`normalizar`):
  - `{"started_at": ..., "entries": {M1: {...}}}`  — o ledger consolidado (mutation-latest)
  - `{"results": [{id, status, file, test, ...}]}`  — o relatório cru de um slot (mutation.json)
O segundo formato é o que os shards do CI produzem: o FSM come o artefato, não uma cópia.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from typing import Any

from ..domain.factory import DomainFactory
from ..domain.models import ProofItem, ProofRun, ProofRunStatus, ProofStatus

# Namespace fixo da camada de prova (uuid5 exige um namespace estável entre máquinas).
PROOF_NAMESPACE = uuid.UUID("6f9619ff-8b86-d011-b42d-00c04fc964ff")

# Origem sem timestamp declarado NÃO inventa data: usa o sentinela e diz isso em voz alta.
SEM_TIMESTAMP = "1970-01-01T00:00:00"


def _hash(obj: dict[str, Any]) -> str:
    canon = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()


def run_id_for(source_hash: str, target: str) -> str:
    """Id determinístico da execução de prova."""
    return str(uuid.uuid5(PROOF_NAMESPACE, f"{source_hash}:{target}"))


def item_id_for(run_id: str, item_id: str) -> str:
    """Id determinístico do item dentro da execução."""
    return str(uuid.uuid5(PROOF_NAMESPACE, f"{run_id}:{item_id}"))


def valor_de(status: str) -> int:
    """1 só para `killed`; 0 para não executado, sobrevivente, inválido ou timeout.

    Aceita o valor ou o nome do enum; NÃO valida (quem valida é o metaclass, no modelo).
    """
    if status == ProofStatus.KILLED.value or status == ProofStatus.KILLED.name:
        return 1
    return 0


def normalizar(payload: dict[str, Any]) -> dict[str, Any]:
    """Canoniza um ledger OU um relatório de mutação no formato `entries`."""
    if "entries" in payload:
        entries = payload["entries"] or {}
        iniciado = payload.get("started_at") or SEM_TIMESTAMP
    elif "results" in payload:
        entries = {}
        for r in payload["results"] or []:
            entries[r["id"]] = {
                "status": r.get("status"),
                "value": valor_de(r.get("status") or ""),
                "file": r.get("file"),
                "test": r.get("test"),
                "seconds": r.get("seconds") or 0,
            }
        iniciado = payload.get("started_at") or payload.get("generated_at") or SEM_TIMESTAMP
    else:
        raise ValueError("formato desconhecido: esperado 'entries' (ledger) ou 'results' (slot)")
    return {"started_at": iniciado, "entries": entries, "schema": payload.get("schema")}


def build_run(ledger: dict[str, Any], sha: str, alvo: str = "mutation") -> ProofRun:
    """Monta o ProofRun a partir do ledger normalizado + hash da origem."""
    entries = ledger.get("entries") or {}
    resumo = resumo_de(entries, catalog_total=len(entries))
    return DomainFactory.create(
        "proof_run",
        id=run_id_for(sha, alvo),
        target=alvo,
        started_at=ledger.get("started_at") or SEM_TIMESTAMP,
        finished_at=None,
        status=ProofRunStatus.COMPLETE if resumo["product"] else ProofRunStatus.INCOMPLETE,
        catalog_total=resumo["total"],
        killed=resumo["killed"],
        product=resumo["product"],
        complete=resumo["complete"],
        source_hash=sha,
    )


def build_items(
    ledger: dict[str, Any], run: ProofRun, run_id: str | None = None
) -> list[ProofItem]:
    """Monta um ProofItem por entrada do ledger (ordem estável por item_id).

    `run_id` permite importar um shard para uma execução JÁ aberta (`proof-start`),
    preservando o id declarado em vez do derivado do hash do shard.
    """
    entries = ledger.get("entries") or {}
    run_id = run_id or run.to_dict()["id"]
    out: list[ProofItem] = []
    for item_id in sorted(entries):
        e = entries[item_id] or {}
        status = e.get("status") or ProofStatus.NOT_RUN.value
        registro: dict[str, Any] = {
            "item_id": item_id,
            "proof_kind": "mutation",
            "status": status,
            "value": valor_de(status),
            "file": e.get("file"),
            "test": e.get("test"),
            "seconds": int(e.get("seconds") or 0),
        }
        out.append(
            DomainFactory.create(
                "proof_item",
                id=item_id_for(run_id, item_id),
                run_id=run_id,
                evidence_hash=_hash(registro),
                **registro,
            )
        )
    return out


# ── Veredito: recalculado das LINHAS do banco (nunca do que a run declara) ──


def resumo_de(entries: dict[str, Any], catalog_total: int) -> dict[str, Any]:
    """Resumo de cobertura a partir de um mapa item→valor.

    `total` é o MAIOR entre o catálogo declarado e as linhas existentes: importar um shard
    não pode encolher o catálogo (a cobertura continua incompleta até todas as linhas existirem).
    """
    total = max(catalog_total, len(entries))
    killed = sum(1 for e in entries.values() if (e.get("value") if isinstance(e, dict) else e) == 1)
    product = 1 if total and killed == total else 0
    return {"total": total, "killed": killed, "product": product, "complete": bool(product)}


def veredito_de(run: dict[str, Any], items: list[dict[str, Any]]) -> dict[str, Any]:
    """Verdade derivada das LINHAS gravadas + o total declarado pela run."""
    por_item = {i["item_id"]: int(i["value"]) for i in items}
    return resumo_de(por_item, catalog_total=int(run.get("catalog_total") or 0))


def divergencias(run: dict[str, Any], items: list[dict[str, Any]]) -> list[str]:
    """Divergências entre o que a run DECLARA e o que as linhas SUSTENTAM.

    Catálogo maior que as linhas é permitido (import parcial declarado); linhas acima do
    catálogo declarado não é (crescimento não declarado).
    """
    rec = veredito_de(run, items)
    achados: list[str] = []
    for campo, valor in (
        ("killed", rec["killed"]),
        ("product", rec["product"]),
        ("complete", rec["complete"]),
    ):
        if run.get(campo) != valor:
            achados.append(f"{campo}: declarado {run.get(campo)!r}, recalculado {valor!r}")
    if rec["total"] != run.get("catalog_total"):
        achados.append(
            f"catalog_total: declarado {run.get('catalog_total')!r}, "
            f"linhas sustentam {rec['total']!r}"
        )
    return achados
