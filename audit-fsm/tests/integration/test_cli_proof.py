"""Ciclo de prova via CLI (S9): inicial → shards → final → auditoria.

Cada teste roda comandos de verdade (CliRunner) contra um SQLite temporário, e verifica
o CÓDIGO DE SAÍDA — porque um comando que "só imprime" não é prova de nada:

  0 = cobertura completa e coerente      3 = cobertura incompleta (fuga de validação)
  1 = run adulterada/divergente          1 = origem ilegível (erro de uso)
"""

from __future__ import annotations

import json

import pytest
from click.testing import CliRunner

from audit_fsm.cli import cli


@pytest.fixture
def ambiente(tmp_path, monkeypatch):
    monkeypatch.setenv("AUDIT_FSM_DB_URL", f"sqlite+aiosqlite:///{tmp_path}/proof.db")
    from audit_fsm.api import db as db_mod

    db_mod._engine = None  # cada teste com o SEU banco (sem vazamento entre casos)
    db_mod._engine_url = None
    yield tmp_path, CliRunner()
    db_mod._engine = None
    db_mod._engine_url = None


def _ledger(path, entries: dict):
    path.write_text(
        json.dumps(
            {"schema": "test/1", "started_at": "2026-11-02T18:00:00+0000", "entries": entries}
        ),
        encoding="utf-8",
    )
    return str(path)


def _slot(path, results: list[dict]):
    path.write_text(json.dumps({"results": results}), encoding="utf-8")
    return str(path)


def _run_id(runner: CliRunner, saida: str) -> str:
    assert saida.exit_code == 0, saida.output
    return json.loads(saida.output)["run_id"]


# ── caminho feliz: 3 itens, todos mortos ────────────────────────────────


def test_ciclo_completo_sai_zero(ambiente):
    tmp, runner = ambiente
    full = _ledger(
        tmp / "full.json",
        {
            "M1": {"status": "killed", "value": 1, "file": "a.py"},
            "M2": {"status": "killed", "value": 1, "file": "b.py"},
            "M3": {"status": "killed", "value": 1, "file": "c.py"},
        },
    )
    abertura = runner.invoke(cli, ["proof-start", full, "--json"])
    run_id = _run_id(runner, abertura)
    assert json.loads(abertura.output)["catalog_total"] == 3

    imp = runner.invoke(cli, ["proof-import", full, "--run-id", run_id])
    assert imp.exit_code == 0 and "3 item(ns)" in imp.output

    fim = runner.invoke(cli, ["proof-finalize", run_id])
    assert fim.exit_code == 0, fim.output
    assert "COMPLETA" in fim.output

    aud = runner.invoke(cli, ["proof-verify", run_id])
    assert aud.exit_code == 0 and "coerente" in aud.output


# ── paralelismo: dois "slots" na MESMA run ──────────────────────────────


def test_shards_paralelos_convergem_para_a_mesma_run(ambiente):
    tmp, runner = ambiente
    a = _slot(
        tmp / "slot-a.json", [{"id": "M1", "status": "killed"}, {"id": "M2", "status": "killed"}]
    )
    b = _slot(
        tmp / "slot-b.json", [{"id": "M3", "status": "killed"}, {"id": "M4", "status": "killed"}]
    )
    run_id = _run_id(runner, runner.invoke(cli, ["proof-start", a, "--json"]))

    assert runner.invoke(cli, ["proof-import", a, "--run-id", run_id]).exit_code == 0
    assert runner.invoke(cli, ["proof-import", b, "--run-id", run_id]).exit_code == 0

    runs = json.loads(runner.invoke(cli, ["proof-runs", "--json"]).output)
    assert len(runs) == 1, "um shard não pode abrir uma segunda execução"

    # 2 linhas no catálogo declarado, 4 linhas gravadas → crescimento não declarado
    aud = runner.invoke(cli, ["proof-verify", run_id])
    assert aud.exit_code == 1, aud.output
    assert "catalog_total" in aud.output


def test_shard_em_run_inexistente_reprova(ambiente):
    tmp, runner = ambiente
    a = _slot(tmp / "slot-a.json", [{"id": "M1", "status": "killed"}])
    res = runner.invoke(
        cli, ["proof-import", a, "--run-id", "00000000-0000-0000-0000-000000000000"]
    )
    assert res.exit_code != 0 and "run não encontrada" in res.output


# ── incompleto tem de sair 3, não 0 ─────────────────────────────────────


def test_cobertura_incompleta_sai_tres(ambiente):
    tmp, runner = ambiente
    parcial = _ledger(
        tmp / "parcial.json",
        {
            "M1": {"status": "killed", "value": 1},
            "M2": {"status": "survived", "value": 0},
            "M3": {"status": "timeout", "value": 0},
        },
    )
    run_id = _run_id(runner, runner.invoke(cli, ["proof-start", parcial, "--json"]))
    assert runner.invoke(cli, ["proof-import", parcial, "--run-id", run_id]).exit_code == 0
    fim = runner.invoke(cli, ["proof-finalize", run_id])
    assert fim.exit_code == 3 and "INCOMPLETA" in fim.output


def test_run_adulterada_sai_um_com_divergencias(ambiente):
    tmp, runner = ambiente
    parcial = _ledger(
        tmp / "parcial.json",
        {"M1": {"status": "killed", "value": 1}, "M2": {"status": "survived", "value": 0}},
    )
    run_id = _run_id(runner, runner.invoke(cli, ["proof-start", parcial, "--json"]))
    runner.invoke(cli, ["proof-import", parcial, "--run-id", run_id])
    runner.invoke(cli, ["proof-finalize", run_id])

    import sqlite3

    banco = tmp / "proof.db"
    con = sqlite3.connect(banco)
    con.execute("update proof_runs set complete=1, killed=2, product=1")
    con.commit()
    con.close()

    aud = runner.invoke(cli, ["proof-verify", run_id, "--json"])
    assert aud.exit_code == 1
    divergencias = json.loads(aud.output)["divergencias"]
    assert any(d.startswith("killed:") for d in divergencias)


def test_import_idempotente_nao_duplica(ambiente):
    tmp, runner = ambiente
    full = _ledger(tmp / "full.json", {"M1": {"status": "killed", "value": 1}})
    for _ in range(3):
        assert runner.invoke(cli, ["proof-import", full]).exit_code == 0
    runs = json.loads(runner.invoke(cli, ["proof-runs", "--json"]).output)
    assert len(runs) == 1
    itens = json.loads(runner.invoke(cli, ["proof-show", runs[0]["id"], "--json"]).output)["items"]
    assert len(itens) == 1


def test_ledger_ilegivel_falha_com_erro_de_uso(ambiente):
    tmp, runner = ambiente
    ruim = tmp / "ruim.json"
    ruim.write_text(json.dumps({"nada": True}), encoding="utf-8")
    res = runner.invoke(cli, ["proof-import", str(ruim)])
    assert res.exit_code != 0 and "formato desconhecido" in res.output


def test_finalize_reconcilia_declaracao_otimista(ambiente):
    """Run que declara cobertura a mais é CORRIGIDA no final, e a correção fica registrada."""
    tmp, runner = ambiente
    a = _slot(
        tmp / "slot-a.json",
        [{"id": "M1", "status": "killed"}, {"id": "M2", "status": "survived"}],
    )
    run_id = _run_id(runner, runner.invoke(cli, ["proof-start", a, "--json"]))
    runner.invoke(cli, ["proof-import", a, "--run-id", run_id])

    import sqlite3

    con = sqlite3.connect(tmp / "proof.db")
    con.execute("update proof_runs set complete=1, killed=2, product=1")
    con.commit()
    con.close()

    fim = runner.invoke(cli, ["proof-finalize", run_id, "--json"])
    assert fim.exit_code == 3, fim.output  # 1/2 provados: continua incompleta, agora honesto
    correcoes = json.loads(fim.output)["correcoes"]
    assert any(c.startswith("killed:") for c in correcoes)
    assert any(c.startswith("complete:") for c in correcoes)

    # depois da reconciliação sobra só a incompletude — não há mais divergência
    assert runner.invoke(cli, ["proof-verify", run_id]).exit_code == 3


def test_show_de_run_inexistente_sai_um(ambiente):
    _, runner = ambiente
    res = runner.invoke(cli, ["proof-show", "00000000-0000-0000-0000-000000000000"])
    assert res.exit_code == 1 and "não encontrada" in res.output
