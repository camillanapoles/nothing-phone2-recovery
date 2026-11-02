#!/usr/bin/env python3
"""success_guarantee.py — "garantia prévia de sucesso" como máquina, não como promessa.

Avalia as cinco solicitações da usuária contra o PAR (motor × kernel) e devolve, uma a uma:

  R1 par único do pack      existe exatamente 1 par que fecha as 10 condições (root_pair_solver.py)
  R2 root oculto            camada de ocultação utilizável pelo par + medição por app
  R3 integridade/fingerprint Tricky Store + PIFork sem spoofers concorrentes
  R4 zero conflito          varredura estática dos módulos reais
  R5 DroidSpaces oficial    instalação conforme doc do app + kernel com as CONFIG_* e os patches

Estados: PROVADO · FALTA_PROVA · IMPOSSIVEL (nenhum par consegue, nem com prova nova).

Sem `--evidence`, NADA é declarado provado: o veredito é PENDENTE (exit 3).
Com `--evidence`, cada requisito só vira PROVADO se a evidência cobrir o que ele exige.

Uso:
  success_guarantee.py --root . [--evidence ev.json] [--json]
  success_guarantee.py --template        # esqueleto de evidência
Exit: 0 GARANTIA_CONFIRMADA · 3 PENDENTE · 1 IMPOSSÍVEL SOB A DECISÃO A · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
HERE = os.path.dirname(os.path.abspath(__file__))


def load_pack(root: str):
    """Roda o solver do pack (mesmas 10 condições do gate). Ausente/quebrado → (None, None)."""
    try:
        spec = importlib.util.spec_from_file_location(
            "root_pair_solver", os.path.join(HERE, "root_pair_solver.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        data = mod.load_all(root)
        if mod.validate(data):
            return None, None
        return mod, mod.solve(data)
    except Exception:
        return None, None


def c06_states(pack) -> set:
    if not pack:
        return set()
    return {c["state"] for p in pack.get("pairs") or []
            for c in p["conditions"] if c["id"] == "C06"}
DECISION = f"{SK}/references/root-decision.json"
ENGINES = f"{SK}/references/root-engines.json"
HIDING = f"{SK}/references/hiding-stack.json"
MODULES = f"{SK}/references/module-requirements.json"
DROID = f"{SK}/references/droidspaces-requirements.json"

TEMPLATE = {
    "schema": "evox-guarantee-evidence/1",
    "note": "preencha só com o que foi medido no aparelho/AVD; campo vazio = não provado",
    "device": {
        "hide_verified": False,
        "hide_tested_apps": [],
        "device_integrity": False,
        "integrity_tested_apps": []
    },
    "conflicts": {"scan_report": "", "conflicts": None},
    "kernel": {"configs": {}, "kmi": ""},
    "droidspaces": {"installed": False, "proc_ok": False, "paths_ok": False}
}


def load(p: str) -> dict:
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    if "--template" in argv:
        print(json.dumps(TEMPLATE, indent=2, ensure_ascii=False))
        return 0
    if "--root" not in argv and not any(a.endswith(".json") for a in argv):
        print("Uso: success_guarantee.py --root . [--evidence ev.json] [--json]", file=sys.stderr)
        return 2

    root = argv[argv.index("--root") + 1] if "--root" in argv else "."
    as_json = "--json" in argv
    paths = [os.path.join(root, p) for p in (DECISION, ENGINES, HIDING, MODULES, DROID)]
    for p in paths:
        if not os.path.exists(p):
            print(f"[ERRO] arquivo ausente: {p}", file=sys.stderr)
            return 4
    try:
        dec, eng, hid = load(paths[0]), load(paths[1]), load(paths[2])
        mods, droid = load(paths[3]).get("modules") or [], load(paths[4])
    except Exception as exc:
        print(f"[ERRO] JSON inválido: {exc}", file=sys.stderr)
        return 4

    ev: dict = {}
    if "--evidence" in argv:
        evp = argv[argv.index("--evidence") + 1]
        if not os.path.exists(evp):
            print(f"[ERRO] evidência ausente: {evp}", file=sys.stderr)
            return 4
        try:
            ev = load(evp)
        except Exception as exc:
            print(f"[ERRO] evidência inválida: {exc}", file=sys.stderr)
            return 4

    _, pack = load_pack(root)

    dev = ev.get("device") or {}
    conf = ev.get("conflicts") or {}
    ker = ev.get("kernel") or {}
    dro = ev.get("droidspaces") or {}
    reqs: list[dict] = []

    def add(rid: str, name: str, state: str, detail: str, need: str = "") -> None:
        reqs.append({"id": rid, "requirement": name, "state": state,
                     "detail": detail, "to_prove": need})

    # R1 — par único que fecha as 10 condições (nenhum motor preferido no código)
    if pack is None:
        add("R1", "par único do pack", "FALTA_PROVA",
            "solver do pack indisponível/inválido (pack-conditions.json, catálogos)",
            "root_pair_solver.py --root . → 0 (PAR_GARANTIDO)")
    elif pack.get("verdict") == "PAR_GARANTIDO":
        sel = pack["selected"][0]
        add("R1", "par único do pack", "PROVADO",
            f"1 par fecha as 10 condições: {sel['engine']} × {sel['kernel']}")
    elif pack.get("verdict") == "AMBIGUO":
        add("R1", "par único do pack", "FALTA_PROVA",
            f"{len(pack.get('selected') or [])} pares fecham as 10 condições — single_method exige 1",
            "registrar critério de desempate no pack-objective.json (ou reduzir o catálogo)")
    elif pack.get("verdict") == "IMPOSSIVEL":
        add("R1", "par único do pack", "IMPOSSIVEL",
            "nenhum par do catálogo consegue fechar as 10 condições",
            "mudar o dado (motor/kernel/evidência) — não o texto da decisão")
    else:
        best = pack.get("best")
        who = f"{best['engine']} × {best['kernel']}" if best else "empate sem escolha"
        falta = ",".join(best["failed"]) if best else "ver pack"
        add("R1", "par único do pack", "FALTA_PROVA",
            f"nenhum par fecha as 10 ainda; melhor={who}; aberto={falta}",
            "root_pair_solver.py --root . (detalha por condição) e fechar o que falta")

    # R2 — root oculto (a camada vem da capacidade do par, não de lista fixa)
    layers = {l["id"]: l for l in hid.get("layers") or []}
    if not layers:
        add("R2", "root oculto para apps alvo", "FALTA_PROVA", "nenhuma camada declarada",
            "declarar a pilha em hiding-stack.json")
    elif dev.get("hide_verified") is True and (dev.get("hide_tested_apps") or []):
        add("R2", "root oculto para apps alvo", "PROVADO",
            f"testado em {len(dev.get('hide_tested_apps'))} app(s): {', '.join(dev['hide_tested_apps'])}")
    else:
        c08 = None
        for pair in (pack or {}).get("pairs") or []:
            c = next((c for c in pair["conditions"] if c["id"] == "C08"), None)
            if c and c["state"] == "ok":
                c08 = c
                break
        camadas = c08["detail"] if c08 else "nenhum par entrega camada de ocultação"
        add("R2", "root oculto para apps alvo", "FALTA_PROVA",
            f"{camadas}; nada medido no aparelho",
            "medir por app (device.hide_verified + hide_tested_apps) na camada que o par entrega")

    # R3 — integridade/fingerprint
    m07 = next((m for m in mods if m["id"] == "M07"), {})
    m08 = next((m for m in mods if m["id"] == "M08"), {})
    base = ",".join((m07.get("compliance_base") or []) + (m08.get("compliance_base") or []))
    if "Tricky Store" in base and "PlayIntegrityFork" in base:
        if dev.get("device_integrity") is True:
            add("R3", "integridade/fingerprint sem conflito", "PROVADO",
                f"DEVICE_INTEGRITY medido em {len(dev.get('integrity_tested_apps') or [])} app(s)")
        else:
            add("R3", "integridade/fingerprint sem conflito", "FALTA_PROVA",
                "M07/M08 declaram Tricky Store + PIFork (fonte: config-map do aparelho)",
                "medir MEETS_DEVICE_INTEGRITY no aparelho e registrar em device.device_integrity")
    else:
        add("R3", "integridade/fingerprint sem conflito", "FALTA_PROVA",
            "contrato de M07/M08 sem a camada de atestação", "declarar compliance_base em M07/M08")

    # R4 — zero conflito
    n = conf.get("conflicts")
    if isinstance(n, int) and n == 0 and (conf.get("scan_report") or ""):
        add("R4", "zero conflito entre módulos", "PROVADO",
            f"varredura {conf['scan_report']} com 0 conflito(s)")
    elif isinstance(n, int) and n > 0:
        add("R4", "zero conflito entre módulos", "FALTA_PROVA",
            f"{n} conflito(s) no relatório {conf.get('scan_report') or '(sem path)'}",
            "resolver os conflitos e re-rodar static_conflict_scanner.py")
    else:
        add("R4", "zero conflito entre módulos", "FALTA_PROVA",
            "sem relatório de varredura dos ZIPs reais",
            "static_conflict_scanner.py --modules-dir … --out conflicts.json; registrar em "
            "conflicts.scan_report")

    # R5 — DroidSpaces conforme doc oficial
    cfgs_need = (droid.get("kernel") or {}).get("configs_required") or []
    iso = droid.get("isolation") or {}
    cfgs = ker.get("configs") or {}
    lacking = [c for c in cfgs_need if str(cfgs.get(c, "")).lower() not in ("y", "m")]
    abi_trio = (droid.get("kernel") or {}).get("abi_trio_not_in_stock_gki") or []
    after = (droid.get("install") or {}).get("after") or []
    order_ok = "M01" in after
    if order_ok is False:
        add("R5", "DroidSpaces conforme doc oficial", "FALTA_PROVA",
            f"ordem declarada: after={after}", "corrigir droidspaces-requirements.json")
    elif cfgs and lacking:
        hard = [c for c in lacking if c in ((iso.get("required_configs") or []) + abi_trio)]
        if hard and c06_states(pack) == {"impossivel"}:
            add("R5", "DroidSpaces conforme doc oficial", "IMPOSSIVEL",
                f"nenhum kernel do catálogo consegue {hard} (C06 impossível em todos os pares)",
                "mudar o dado: kernel candidato com as CONFIG_* (não o texto da decisão)")
        else:
            add("R5", "DroidSpaces conforme doc oficial", "FALTA_PROVA",
                f"kernel do build ainda sem {lacking}",
                "ligar as opções no defconfig do build + kernel_compat_check.sh + preflight --kernel-evidence")
    elif dro.get("installed") is True and dro.get("proc_ok") is True and dro.get("paths_ok") is True:
        add("R5", "DroidSpaces conforme doc oficial", "PROVADO",
            "instalado, procfs IPC legível, caminhos do runtime presentes")
    else:
        add("R5", "DroidSpaces conforme doc oficial", "FALTA_PROVA",
            "sem evidência de kernel/instalação (L4 pendente)",
            "droidspaces_preflight.py --kernel-evidence … && --device --expect-installed")

    states = {r["state"] for r in reqs}
    if "IMPOSSIVEL" in states:
        verdict, code = "IMPOSSIVEL_SEM_PAR", 1
    elif states == {"PROVADO"}:
        verdict, code = "GARANTIA_CONFIRMADA", 0
    else:
        verdict, code = "GARANTIA_PENDENTE", 3

    best = (pack or {}).get("best") or {}
    payload = {"schema": "evox-guarantee/2",
               "pack_verdict": (pack or {}).get("verdict"),
               "selected": (pack or {}).get("selected"),
               "best": ({"engine": best.get("engine"), "kernel": best.get("kernel"),
                         "failed": best.get("failed")} if best else None),
               "verdict": verdict,
               "proved": sum(r["state"] == "PROVADO" for r in reqs),
               "pending": sum(r["state"] == "FALTA_PROVA" for r in reqs),
               "impossible": sum(r["state"] == "IMPOSSIVEL" for r in reqs),
               "requirements": reqs}
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        who = (f"{best['engine']} × {best['kernel']}" if best else "sem par fechado")
        print(f"[garantia] pack {payload['pack_verdict']} · par {who} → {verdict}")
        for r in reqs:
            print(f"  {r['state']:12} {r['id']} {r['requirement']}: {r['detail']}")
            if r["to_prove"]:
                print(f"               ↳ falta: {r['to_prove']}")
        print(f"  {payload['proved']} provado(s) · {payload['pending']} pendente(s) · "
              f"{payload['impossible']} impossível(is)")
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
