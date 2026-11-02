#!/usr/bin/env python3
"""root_engine_gate.py — o par (motor × kernel) fecha as 10 condições do pack?

Este gate NÃO tem opinião sobre motor nem sobre kernel: ele pergunta ao solver
(`root_pair_solver.py`) quais condições o par escolhido satisfaz e traduz isso em
veredito executável. Nenhum motor é "o certo" e nenhuma lista de proibidos existe aqui —
se o dado mudar (novo motor, kernel certificado, patch aplicado), o veredito muda sozinho.

Condições (references/pack-conditions.json): C01 root real · C02 kernel serve o motor ·
C03 build/modelo/API · C04 manutenção · C05 DroidSpaces aceita o motor · C06 CONFIG_* provadas ·
C07 patches de kABI · C08 camada de ocultação utilizável · C09 capacidades dos módulos ·
C10 rollback + OTA.

Uso:
  root_engine_gate.py [--root DIR] --engine <id> [--candidate <id>] [--kernel-evidence F] [--json]
  root_engine_gate.py [--root DIR] --show-policy
  root_engine_gate.py [--root DIR] --list-engines

Exit: 0 COMPATÍVEL (10/10) · 3 PENDENTE (falta prova) · 1 INCOMPATÍVEL · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import copy
import importlib.util
import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
HERE = os.path.dirname(os.path.abspath(__file__))


def load_solver():
    spec = importlib.util.spec_from_file_location("root_pair_solver", os.path.join(HERE, "root_pair_solver.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


STATE_TO_VERDICT = {"ok": "ok", "falta_prova": "pendente", "impossivel": "incompativel"}


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = argv[argv.index("--root") + 1] if "--root" in argv else "."
    as_json = "--json" in argv
    solver = load_solver()

    try:
        data = solver.load_all(root)
    except FileNotFoundError as exc:
        print(f"[ERRO] arquivo ausente: {exc}", file=sys.stderr)
        return 4
    except Exception as exc:
        print(f"[ERRO] JSON inválido: {exc}", file=sys.stderr)
        return 4

    problems = solver.validate(data)
    if problems:
        for p in problems:
            print(f"[ERRO] {p}", file=sys.stderr)
        return 4

    if "--list-engines" in argv:
        for e in sorted(data["engines"]["engines"], key=lambda x: x["id"]):
            print(f"{e['id']:12} custom_kernel={str(e.get('requires_custom_kernel')):5} "
                  f"caps={','.join(e.get('capabilities') or [])}")
        return 0

    res = solver.solve(data)
    if "--show-policy" in argv:
        print(f"[política] objetivo={res['objective']} · condições={','.join(res['conditions'])}")
        print(f"[política] {res['verdict']}: {len(res['selected'])} par(es) garantido(s) "
              f"de {res['counts']['pairs']} avaliados")
        for p in res["pairs"]:
            print(f"  {p['verdict']:13} {p['engine']:10} × {p['kernel']}"
                  + (f"  falta: {','.join(p['failed'])}" if p["failed"] else ""))
        return res["exit"]

    if len(argv) < 2:
        print("Uso: root_engine_gate.py --engine <id> [--candidate <id>] [--kernel-evidence F] [--json]",
              file=sys.stderr)
        return 2

    engine_id = argv[argv.index("--engine") + 1] if "--engine" in argv else ""
    cand_id = argv[argv.index("--candidate") + 1] if "--candidate" in argv else ""
    if not engine_id:
        print("[ERRO] --engine é obrigatório (o gate não escolhe por você: veja --show-policy)",
              file=sys.stderr)
        return 2

    engine = next((e for e in data["engines"]["engines"] if e["id"] == engine_id), None)
    if engine is None:
        print(f"[ERRO] motor desconhecido: {engine_id}", file=sys.stderr)
        return 4
    if cand_id:
        cand = next((c for c in data["candidates"]["candidates"] if c["id"] == cand_id), None)
        if cand is None:
            print(f"[ERRO] candidato de kernel desconhecido: {cand_id}", file=sys.stderr)
            return 4
    else:
        # sem candidato explícito: usa o único par garantido do motor, se existir
        own = [p for p in res["pairs"] if p["engine"] == engine_id and p["verdict"] == "PAR_GARANTIDO"]
        if own:
            cand_id = own[0]["kernel"]
            cand = next(c for c in data["candidates"]["candidates"] if c["id"] == cand_id)
        else:
            cand = None

    # evidência de kernel injetada (L4 ou build): substitui o que é declarado pelo que foi lido
    ev_path = argv[argv.index("--kernel-evidence") + 1] if "--kernel-evidence" in argv else ""
    ev_note = ""
    if ev_path:
        if not os.path.exists(ev_path):
            ev_note = f"evidência de kernel ausente: {ev_path}"
        else:
            try:
                ev_cfgs = (solver.load(ev_path) or {}).get("configs") or {}
            except Exception as exc:
                print(f"[ERRO] evidência inválida: {exc}", file=sys.stderr)
                return 4
            proven = sorted(c for c, v in ev_cfgs.items() if str(v) in ("y", "m"))
            data = copy.deepcopy(data)
            for c in data["candidates"]["candidates"]:
                if cand is not None and c["id"] == cand["id"]:
                    c["configs_proven"] = proven
            cand = next((c for c in data["candidates"]["candidates"] if cand is not None and c["id"] == cand["id"]), None)

    if cand is None:
        # motor sem par explícito e sem par garantido: avalia o motor contra o kernel "vazio"
        # para dizer exatamente o que falta, sem inventar um candidato.
        cand = {"id": "(nenhum kernel escolhido)", "origin": "none", "kernel_supports": [],
                "supported_rom_builds": [], "developer_support": {"declared": False},
                "configs_proven": [], "patches_present": [], "gki": True,
                "kernel_supports_susfs": False, "rollback": ""}

    pair = solver.evaluate_pair(data, engine, cand)
    if ev_note:
        for c in pair["conditions"]:
            if c["id"] == "C06":
                c["state"], c["detail"] = "falta_prova", ev_note
        pair["failed"] = [c["id"] for c in pair["conditions"] if c["state"] != "ok"]
        pair["verdict"] = "FALTA_PROVA"

    checks = [{"check": c["id"], "name": c["name"], "verdict": STATE_TO_VERDICT[c["state"]],
               "detail": c["detail"]} for c in pair["conditions"]]
    verdicts = {c["verdict"] for c in checks}
    if "incompativel" in verdicts:
        verdict, code = "INCOMPATÍVEL", 1
    elif "pendente" in verdicts:
        verdict, code = "PENDENTE", 3
    else:
        verdict, code = "COMPATÍVEL", 0

    payload = {
        "schema": "evox-root-engine-verdict/2",
        "engine": {"id": engine["id"], "capabilities": engine.get("capabilities") or [],
                   "requires_custom_kernel": engine.get("requires_custom_kernel")},
        "kernel_candidate": {"id": cand["id"], "origin": cand.get("origin")},
        "conditions": [c["id"] for c in pair["conditions"]],
        "verdict": verdict,
        "checks": checks,
        "reasons": [c["detail"] for c in checks if c["verdict"] != "ok"],
        "pack": {"verdict": res["verdict"], "selected": res["selected"]},
    }
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True))
    else:
        print(f"[gate] motor={engine['id']} kernel={cand['id']} → {verdict} "
              f"({len([c for c in checks if c['verdict'] == 'ok'])}/10 condições)")
        for c in checks:
            mark = {"ok": "OK  ", "pendente": "PEND", "incompativel": "NAO "}[c["verdict"]]
            print(f"  {mark} {c['check']} {c['name']}: {c['detail']}")
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
