"""
CLI entrypoint for audit-fsm (S1-S8, T9).

Commands:
  audit-fsm run           — run a live audit against the device via the FSM
  audit-fsm consult       — ask a natural-language question about stored audit data
  audit-fsm proof-import  — importa um ledger de prova (mutação) para o banco, por run_id
  audit-fsm proof-show    — mostra a cobertura de uma execução (item a item)
  audit-fsm proof-verify  — recalcula o veredito das LINHAS (detecta run adulterada)
  audit-fsm proof-runs    — lista as execuções de prova guardadas
"""

from __future__ import annotations

import asyncio
import json
import re
import sys
from datetime import UTC
from typing import Any

import click

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
    from ..agents.consultation import AgentDeps, ConsultationAnswer, consultation_agent

    deps = AgentDeps(kind=kind, query=question)

    async def _run() -> ConsultationAnswer:
        result = await consultation_agent.run(question, deps=deps)
        return result.output

    answer = asyncio.run(_run())
    click.echo(json.dumps(answer.model_dump(), indent=2, default=str))


# ── Prova (S9): o ledger vira dado durável, auditável por run_id ─────────────
#
# Ciclo completo, tudo por comando do FSM:
#   proof-start    — execução INICIAL: abre a run (id determinístico da origem)
#   proof-import   — cada shard grava os SEUS itens na mesma run (paralelizável)
#   proof-finalize — execução FINAL: recalcula o veredito das linhas e grava
#   proof-verify   — AUDITORIA: compara declarado × linhas (pega run adulterada)
#   proof-show / proof-runs — consulta item a item / histórico


def _db_url_option(fn):
    """Decorator: --db sobrescreve AUDIT_FSM_DB_URL antes de abrir o engine."""
    return click.option(
        "--db", "db_url", default=None, help="URL do banco (default: AUDIT_FSM_DB_URL)"
    )(fn)


def _aplicar_db(db_url: str | None) -> None:
    """Aplica a URL escolhida antes de importar/abrir o engine."""
    import os

    if db_url:
        os.environ["AUDIT_FSM_DB_URL"] = db_url


def _txt(valor: Any) -> str:
    """Texto de um campo que pode ser enum (str-enum) ou str — nunca "ProofStatus.X"."""
    return str(getattr(valor, "value", valor))


def _abrir(ledger_path: str) -> tuple[dict, str, Any]:
    """Lê + canoniza + identifica a origem (hash) e monta a run declarada."""
    from ..proof import build_run, load_ledger, source_hash

    ledger = load_ledger(ledger_path)
    sha = source_hash(ledger)
    return ledger, sha, build_run(ledger, sha)


async def _abrir_run(ledger_path: str) -> dict:
    """Execução inicial: grava só a run (a cobertura vem dos shards)."""
    from ..api.db import init_db
    from ..api.repository import upsert_one

    await init_db()
    _, sha, run = _abrir(ledger_path)
    run_dict = await upsert_one("proof_run", run)
    return {
        "run_id": run_dict["id"],
        "target": run_dict["target"],
        "catalog_total": run_dict["catalog_total"],
        "source_hash": sha,
        "killed_declarados": run_dict["killed"],
        "status": run_dict["status"],
    }


async def _importar(ledger_path: str, run_id: str | None) -> dict:
    """Grava os itens do ledger — na run informada (shard) ou na run derivada da origem."""
    from ..api.db import init_db
    from ..api.repository import get_by_id, upsert_many, upsert_one
    from ..proof import build_items

    await init_db()
    ledger, sha, run = _abrir(ledger_path)
    alvo = run_id or run.to_dict()["id"]
    if run_id:
        existente = await get_by_id("proof_run", run_id)
        if existente is None:
            raise click.ClickException(f"run não encontrada: {run_id} (rode proof-start)")
    else:
        existente = await upsert_one("proof_run", run)
    itens = build_items(ledger, run, run_id=alvo)
    await upsert_many("proof_item", itens)  # um lote, uma transação
    return {
        "run_id": alvo,
        "source_hash": sha,
        "itens_gravados": len(itens),
        "catalog_total": existente["catalog_total"],
    }


async def _finalizar(run_id: str) -> dict:
    """Execução final: recalcula das LINHAS, grava o veredito e devolve a auditoria."""
    from ..api.db import init_db
    from ..api.repository import get_by_id, list_by_run, upsert_one
    from ..domain.factory import DomainFactory
    from ..proof import divergencias, veredito_de

    await init_db()
    run = await get_by_id("proof_run", run_id)
    if run is None:
        raise click.ClickException(f"run não encontrada: {run_id}")
    itens = await list_by_run("proof_item", run_id)
    rec = veredito_de(run, itens)
    # o que a run DECLARAVA antes da reconciliação (depois de gravar, seria sempre vazio)
    correcoes = divergencias(run, itens)
    atualizada = DomainFactory.update(
        DomainFactory.create("proof_run", **run),
        killed=rec["killed"],
        catalog_total=rec["total"],
        product=rec["product"],
        complete=rec["complete"],
        status="complete" if rec["complete"] else "incomplete",
    )
    await upsert_one("proof_run", atualizada)
    return {
        "run_id": run_id,
        "recalculado": rec,
        "correcoes": correcoes,
        "itens": len(itens),
    }


async def _mostrar(run_id: str) -> dict:
    """Lê a run e os itens direto do banco (o repository revalida na leitura)."""
    from ..api.db import init_db
    from ..api.repository import get_by_id, list_by_run
    from ..proof import veredito_de

    await init_db()
    run = await get_by_id("proof_run", run_id)
    if run is None:
        return {}
    itens = await list_by_run("proof_item", run_id)
    return {"run": run, "items": itens, "recalculado": veredito_de(run, itens)}


def _sai_por_cobertura(rec: dict) -> None:
    """Exit 0 só com cobertura completa; 3 quando falta prova. Um lugar só, sem cópia."""
    sys.exit(0 if rec["complete"] else 3)


def _saida_final(res: dict, as_json: bool) -> None:
    """Final: a run foi reconciliada com as linhas — exit só olha a cobertura (0/3)."""
    if as_json:
        click.echo(json.dumps(res, indent=2, default=str))
    else:
        for c in res["correcoes"]:
            click.echo(f"::notice:: corrigido na reconciliação — {c}")
        rec = res["recalculado"]
        click.echo(
            f"[proof] {rec['killed']}/{rec['total']} provados · produto {rec['product']} · "
            f"{'COMPLETA' if rec['complete'] else 'INCOMPLETA'} · "
            f"{len(res['correcoes'])} correção(ões)"
        )
    _sai_por_cobertura(res["recalculado"])


def _sair(res: dict, as_json: bool) -> None:
    """Saída comum dos comandos de auditoria + código de saída por estado."""
    if as_json:
        click.echo(json.dumps(res, indent=2, default=str))
    else:
        for d in res["divergencias"]:
            click.echo(f"::error:: {d}", err=True)
        rec = res["recalculado"]
        click.echo(
            f"[proof] {rec['killed']}/{rec['total']} provados · produto {rec['product']} · "
            f"{'COMPLETA' if rec['complete'] else 'INCOMPLETA'} · "
            f"{'coerente' if not res['divergencias'] else 'INCOERENTE'}"
        )
    if res["divergencias"]:
        sys.exit(1)
    _sai_por_cobertura(res["recalculado"])


@cli.command("proof-start")
@click.argument("ledger", type=click.Path(exists=True, dir_okay=False))
@_db_url_option
@click.option("--json", "as_json", is_flag=True, help="Saída JSON")
def proof_start(ledger: str, db_url: str | None, as_json: bool) -> None:
    """Execução INICIAL: abre a run de prova para LEDGER e imprime o run_id."""
    _aplicar_db(db_url)
    res = asyncio.run(_abrir_run(ledger))
    if as_json:
        click.echo(json.dumps(res, indent=2, default=str))
        return
    click.echo(
        f"[proof] run {res['run_id']} aberta · catálogo {res['catalog_total']} · "
        f"importe os shards com proof-import --run-id {res['run_id']}"
    )


@cli.command("proof-import")
@click.argument("ledger", type=click.Path(exists=True, dir_okay=False))
@_db_url_option
@click.option("--run-id", default=None, help="Grava os itens nesta run (shards em paralelo)")
@click.option("--json", "as_json", is_flag=True, help="Saída JSON")
def proof_import(ledger: str, db_url: str | None, run_id: str | None, as_json: bool) -> None:
    """Importa os itens de LEDGER (ledger consolidado ou relatório de um slot)."""
    _aplicar_db(db_url)
    try:
        res = asyncio.run(_importar(ledger, run_id))
    except ValueError as exc:  # formato desconhecido é erro de uso, não de validação
        raise click.ClickException(str(exc)) from exc
    if as_json:
        click.echo(json.dumps(res, indent=2, default=str))
        return
    click.echo(
        f"[proof] {res['itens_gravados']} item(ns) na run {res['run_id']} · "
        f"catálogo {res['catalog_total']}"
    )


@cli.command("proof-finalize")
@click.argument("run_id")
@_db_url_option
@click.option("--json", "as_json", is_flag=True, help="Saída JSON")
def proof_finalize(run_id: str, db_url: str | None, as_json: bool) -> None:
    """Execução FINAL: recalcula o veredito das linhas e grava na run. Exit 0/3/1."""
    _aplicar_db(db_url)
    _saida_final(asyncio.run(_finalizar(run_id)), as_json)


@cli.command("proof-verify")
@click.argument("run_id")
@_db_url_option
@click.option("--json", "as_json", is_flag=True, help="Saída JSON")
def proof_verify(run_id: str, db_url: str | None, as_json: bool) -> None:
    """AUDITORIA (read-only): declarado × linhas. Exit 0 completa · 3 incompleta · 1 divergente."""
    from ..api.db import init_db
    from ..api.repository import get_by_id, list_by_run
    from ..proof import divergencias, veredito_de

    _aplicar_db(db_url)

    async def _go() -> dict:
        await init_db()
        run = await get_by_id("proof_run", run_id)
        if run is None:
            return {}
        itens = await list_by_run("proof_item", run_id)
        return {"recalculado": veredito_de(run, itens), "divergencias": divergencias(run, itens)}

    res = asyncio.run(_go())
    if not res:
        click.echo(f"execução não encontrada: {run_id}", err=True)
        sys.exit(1)
    _sair(res, as_json)


@cli.command("proof-show")
@click.argument("run_id")
@_db_url_option
@click.option("--json", "as_json", is_flag=True, help="Saída JSON")
def proof_show(run_id: str, db_url: str | None, as_json: bool) -> None:
    """Mostra a cobertura item a item de uma execução de prova."""
    _aplicar_db(db_url)
    res = asyncio.run(_mostrar(run_id))
    if not res:
        click.echo(f"execução não encontrada: {run_id}", err=True)
        sys.exit(1)
    if as_json:
        click.echo(json.dumps(res, indent=2, default=str))
        return
    rec = res["recalculado"]
    click.echo(
        f"[proof] {res['run']['target']} · {rec['killed']}/{rec['total']} provados · "
        f"produto {rec['product']} · {'COMPLETA' if rec['complete'] else 'INCOMPLETA'}"
    )

    # ordem natural por número do item: M2 antes de M12 (o alfabeto diria o contrário)
    def _chave(item: dict) -> tuple[int, int | str]:
        digitos = re.sub(r"\D", "", item["item_id"])
        return (0, int(digitos)) if digitos else (1, item["item_id"])

    for item in sorted(res["items"], key=_chave):
        marca = "OK   " if item["value"] == 1 else "FALTA"
        click.echo(
            f"  {marca} {item['item_id']:<6} {_txt(item['status']):<9} {item.get('file') or ''}"
        )


@cli.command("proof-runs")
@_db_url_option
@click.option("--json", "as_json", is_flag=True, help="Saída JSON")
def proof_runs(db_url: str | None, as_json: bool) -> None:
    """Lista as execuções de prova guardadas (histórico auditável)."""
    from ..api.db import init_db
    from ..api.repository import list_all

    _aplicar_db(db_url)

    async def _go() -> list:
        await init_db()
        return await list_all("proof_run")

    runs = asyncio.run(_go())
    if as_json:
        click.echo(json.dumps(runs, indent=2, default=str))
        return
    if not runs:
        click.echo("[proof] nenhuma execução guardada")
        return
    for r in sorted(runs, key=lambda x: x["started_at"]):
        click.echo(
            f"  {r['started_at']} · {_txt(r['target'])} · {r['killed']}/{r['catalog_total']} · "
            f"produto {r['product']} · {r['id']}"
        )


if __name__ == "__main__":
    cli()


def main():
    """Entry point for audit-fsm CLI."""
    from audit_fsm.cli import cli

    cli()
