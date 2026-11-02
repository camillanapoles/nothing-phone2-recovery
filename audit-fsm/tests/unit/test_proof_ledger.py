"""Camada de prova (S9) — ledger → domínio, sem hardcode e sem duplicar linha.

Contratos provados aqui:
  a) ids determinísticos: mesmas entradas → mesmos uuid5 (reimportar não duplica);
  b) cobertura derivada: value 1 só para `killed`, produto/complete calculados;
  c) origem diferente → run_id diferente, e `source_hash` muda quando o ledger muda;
  d) `veredito_dos_itens` recalcula das LINHAS e acusa run adulterada (tamper).
"""

from __future__ import annotations

import copy

import pytest

from audit_fsm.domain.metaclass import ValidationError
from audit_fsm.domain.models import ProofRunStatus
from audit_fsm.proof import build_items, build_run, source_hash, summarize
from audit_fsm.proof.ledger import (
    SEM_TIMESTAMP,
    divergencias,
    item_id_for,
    normalizar,
    valor_de,
    veredito_de,
)

LEDGER = {
    "started_at": "2026-11-02T17:40:00",
    "entries": {
        "M1": {"status": "killed", "value": 1, "file": "a.py", "test": "t1", "seconds": 2},
        "M2": {"status": "killed", "value": 1, "file": "a.py", "test": "t2", "seconds": 1},
        "M3": {"status": "survived", "value": 0, "file": "b.py", "test": "t3", "seconds": 4},
    },
}


@pytest.fixture
def ledger() -> dict:
    return copy.deepcopy(LEDGER)


# ── (a) determinismo / idempotência ─────────────────────────────────────


def test_run_id_is_deterministic(ledger):
    r1 = build_run(ledger, source_hash(ledger))
    r2 = build_run(copy.deepcopy(ledger), source_hash(copy.deepcopy(ledger)))
    assert r1.to_dict()["id"] == r2.to_dict()["id"]


def test_item_ids_are_deterministic_and_stable_in_order(ledger):
    sha = source_hash(ledger)
    run = build_run(ledger, sha)
    itens1 = [i.to_dict()["item_id"] for i in build_items(ledger, run)]
    # inverter a ordem de inserção não muda nada (ordenação estável por item_id)
    invertido = {"entries": dict(reversed(list(ledger["entries"].items())))}
    itens2 = [i.to_dict()["item_id"] for i in build_items(invertido, run)]
    assert itens1 == itens2 == sorted(ledger["entries"])
    assert [i.to_dict()["id"] for i in build_items(ledger, run)] == [
        item_id_for(run.to_dict()["id"], i) for i in itens1
    ]


def test_different_origin_gives_different_run_id(ledger):
    outro = copy.deepcopy(ledger)
    outro["entries"]["M3"]["status"] = "killed"
    assert source_hash(ledger) != source_hash(outro)
    assert (
        build_run(ledger, source_hash(ledger)).to_dict()["id"]
        != build_run(outro, source_hash(outro)).to_dict()["id"]
    )


def test_source_hash_ignores_key_order(ledger):
    reordenado = {k: ledger[k] for k in sorted(ledger, reverse=True)}
    reordenado["entries"] = dict(sorted(ledger["entries"].items(), reverse=True))
    assert source_hash(ledger) == source_hash(reordenado)


# ── (b) cobertura derivada ──────────────────────────────────────────────


def test_summary_is_derived_not_declared(ledger):
    res = summarize(ledger)
    assert res["total"] == len(ledger["entries"])
    assert res["killed"] == 2
    assert res["product"] == 0
    assert res["complete"] is False


def test_value_only_one_for_killed():
    assert valor_de("killed") == 1
    for status in ("survived", "invalid", "timeout", "not_run"):
        assert valor_de(status) == 0


def test_items_carry_evidence_hash_and_fields(ledger):
    run = build_run(ledger, source_hash(ledger))
    itens = build_items(ledger, run)
    assert len(itens) == 3
    m1 = next(i.to_dict() for i in itens if i.to_dict()["item_id"] == "M1")
    assert m1["value"] == 1
    assert m1["run_id"] == run.to_dict()["id"]
    assert m1["proof_kind"] == "mutation"
    assert len(m1["evidence_hash"]) == 64
    # hash reflete o conteúdo: mudar o arquivo muda o hash da evidência
    alterado = copy.deepcopy(ledger)
    alterado["entries"]["M1"]["file"] = "outro.py"
    novo = next(i.to_dict() for i in build_items(alterado, run) if i.to_dict()["item_id"] == "M1")
    assert novo["evidence_hash"] != m1["evidence_hash"]


def test_full_coverage_yields_complete_run(ledger):
    for entrada in ledger["entries"].values():
        entrada["status"] = "killed"
        entrada["value"] = 1
    run = build_run(ledger, source_hash(ledger)).to_dict()
    assert run["killed"] == run["catalog_total"] == len(ledger["entries"])
    assert run["product"] == 1 and run["complete"] is True
    assert run["status"] == ProofRunStatus.COMPLETE.value


def test_unknown_status_rejected_by_metaclass(ledger):
    """Status fora do enum é rejeitado — e rejeitado pelo METACLASS, não por um atalho."""
    run = build_run(ledger, source_hash(ledger))
    ruim = copy.deepcopy(ledger)
    ruim["entries"]["M1"]["status"] = "morto"
    with pytest.raises(ValidationError):
        build_items(ruim, run)


def test_enum_name_is_normalized_to_value(ledger):
    """Contrato herdado do validate_enum_factory: o NOME do membro também é aceito."""
    run = build_run(ledger, source_hash(ledger))
    por_nome = copy.deepcopy(ledger)
    por_nome["entries"]["M1"]["status"] = "KILLED"
    item = next(i for i in build_items(por_nome, run) if i.to_dict()["item_id"] == "M1")
    assert item.to_dict()["status"] == "killed" and item.to_dict()["value"] == 1


# ── (c) veredito recalculado das linhas → detecta adulteração ───────────


def test_veredito_recalcula_das_linhas(ledger):
    run = build_run(ledger, source_hash(ledger))
    itens = [i.to_dict() for i in build_items(ledger, run)]
    rec = veredito_de(run.to_dict(), itens)
    assert (rec["total"], rec["killed"], rec["product"], rec["complete"]) == (3, 2, 0, False)


def test_tamper_is_detected(ledger):
    """Run declarada COMPLETA, mas as linhas dizem 2/3: divergência detectável."""
    run = build_run(ledger, source_hash(ledger)).to_dict()
    itens = [i.to_dict() for i in build_items(ledger, build_run(ledger, source_hash(ledger)))]
    run.update({"killed": 3, "product": 1, "complete": True})
    achados = divergencias(run, itens)
    assert any(a.startswith("killed:") for a in achados)
    assert any(a.startswith("complete:") for a in achados)


def test_declared_catalog_larger_than_rows_is_allowed(ledger):
    """Import parcial: 3 linhas de um catálogo de 10 não é divergência (é incompleto)."""
    run = build_run(ledger, source_hash(ledger)).to_dict()
    run.update({"catalog_total": 10, "killed": 2, "product": 0, "complete": False})
    itens = [i.to_dict() for i in build_items(ledger, build_run(ledger, source_hash(ledger)))]
    assert divergencias(run, itens) == []


def test_rows_above_declared_catalog_is_divergence(ledger):
    """Crescimento não declarado do catálogo aparece como divergência explícita."""
    run = build_run(ledger, source_hash(ledger)).to_dict()
    run.update({"catalog_total": 2, "killed": 2, "product": 1, "complete": True})
    itens = [i.to_dict() for i in build_items(ledger, build_run(ledger, source_hash(ledger)))]
    achados = divergencias(run, itens)
    assert any(a.startswith("catalog_total:") for a in achados)


# ── (d) normalização de formatos (ledger consolidado × relatório de slot) ──


def test_normalizar_aceita_relatorio_de_slot():
    """O artefato cru do CI (`results`) é aceito — o FSM come o dado, não uma cópia."""
    slot = {
        "generated_at": "2026-11-02T18:00:00",
        "results": [
            {"id": "M1", "status": "killed", "file": "a.py"},
            {"id": "M2", "status": "survived", "file": "b.py"},
        ],
    }
    norm = normalizar(slot)
    assert norm["started_at"] == "2026-11-02T18:00:00"
    assert norm["entries"]["M1"]["value"] == 1
    assert norm["entries"]["M2"]["value"] == 0
    assert summarize(norm) == {"total": 2, "killed": 1, "product": 0, "complete": False}


def test_normalizar_sem_timestamp_usa_sentinela_e_diz_isso():
    norm = normalizar({"results": [{"id": "M1", "status": "killed"}]})
    assert norm["started_at"] == SEM_TIMESTAMP


def test_normalizar_formato_desconhecido_falha():
    with pytest.raises(ValueError):
        normalizar({"algo": 1})


def test_empty_ledger_is_not_complete(ledger):
    vazio = {"started_at": ledger["started_at"], "entries": {}}
    run = build_run(vazio, source_hash(vazio)).to_dict()
    assert run["catalog_total"] == 0 and run["product"] == 0 and run["complete"] is False
