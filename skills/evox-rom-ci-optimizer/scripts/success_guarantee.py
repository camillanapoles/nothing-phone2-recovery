#!/usr/bin/env python3
"""success_guarantee.py — "garantia prévia de sucesso" como máquina, não como promessa.

Avalia as cinco solicitações da usuária sob a Decisão A e devolve, uma a uma:

  R1 motor único            APatch, exclusivo, ratificado
  R2 root oculto            pilha de ocultação (APatch + Zygisk Next + Zygisk Assistant)
  R3 integridade/fingerprint Tricky Store + PIFork sem spoofers concorrentes
  R4 zero conflito          varredura estática dos módulos reais
  R5 DroidSpaces oficial    instalação conforme doc do app + kernel com as CONFIG_*

Estados: PROVADO · FALTA_PROVA · IMPOSSIVEL (a Decisão A impede e não há prova que resolva).

Sem `--evidence`, NADA é declarado provado: o veredito é PENDENTE (exit 3).
Com `--evidence`, cada requisito só vira PROVADO se a evidência cobrir o que ele exige.

Uso:
  success_guarantee.py --root . [--evidence ev.json] [--json]
  success_guarantee.py --template        # esqueleto de evidência
Exit: 0 GARANTIA_CONFIRMADA · 3 PENDENTE · 1 IMPOSSÍVEL SOB A DECISÃO A · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
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

    dev = ev.get("device") or {}
    conf = ev.get("conflicts") or {}
    ker = ev.get("kernel") or {}
    dro = ev.get("droidspaces") or {}
    reqs: list[dict] = []

    def add(rid: str, name: str, state: str, detail: str, need: str = "") -> None:
        reqs.append({"id": rid, "requirement": name, "state": state,
                     "detail": detail, "to_prove": need})

    # R1 — motor único
    allow = [e["id"] for e in eng.get("engines") or [] if e.get("allowed")]
    if dec.get("ratified") is True and allow == [dec.get("engine")] == ["apatch"]:
        add("R1", "motor único: APatch exclusivo", "PROVADO",
            f"decisão {dec.get('decision')} ratificada; único motor permitido={allow[0]}")
    else:
        add("R1", "motor único: APatch exclusivo", "FALTA_PROVA",
            f"motores permitidos={allow} decisão={dec.get('engine')}",
            "root_engine_gate.py --engine apatch → exit 0")

    # R2 — root oculto
    layers = {l["id"]: l for l in hid.get("layers") or []}
    need_layers = ["apatch-native", "zygisk-next", "zygisk-assistant"]
    missing = [x for x in need_layers if x not in layers]
    if missing:
        add("R2", "root oculto para apps alvo", "FALTA_PROVA", f"camadas ausentes: {missing}",
            "declarar a pilha em hiding-stack.json")
    elif dev.get("hide_verified") is True and (dev.get("hide_tested_apps") or []):
        add("R2", "root oculto para apps alvo", "PROVADO",
            f"testado em {len(dev.get('hide_tested_apps'))} app(s): {', '.join(dev['hide_tested_apps'])}")
    else:
        stale = [x for x in need_layers if layers[x].get("status") == "stale_but_supported"]
        note = f"camada(s) antiga(s): {stale}" if stale else "pilha apoiada em fonte primária"
        add("R2", "root oculto para apps alvo", "FALTA_PROVA",
            f"pilha definida ({', '.join(need_layers)}); {note}; nada medido no aparelho",
            "APatch 'Exclude modifications' + Zygisk Next + Zygisk Assistant; medir com "
            "success_guarantee.py --evidence depois do teste por app")

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
        if hard and dec.get("custom_kernel_allowed") is not True:
            add("R5", "DroidSpaces conforme doc oficial", "IMPOSSIVEL",
                f"kernel stock sem {hard} e kernel próprio proibido pela Decisão A",
                "só resolve com nova decisão sua (revisar custom_kernel_allowed) — não com código")
        else:
            add("R5", "DroidSpaces conforme doc oficial", "FALTA_PROVA",
                f"kernel sem {lacking}", "kernel_compat_check.sh + preflight --kernel-evidence")
    elif dro.get("installed") is True and dro.get("proc_ok") is True and dro.get("paths_ok") is True:
        add("R5", "DroidSpaces conforme doc oficial", "PROVADO",
            "instalado, procfs IPC legível, caminhos do runtime presentes")
    else:
        add("R5", "DroidSpaces conforme doc oficial", "FALTA_PROVA",
            "sem evidência de kernel/instalação (L4 pendente)",
            "droidspaces_preflight.py --kernel-evidence … && --device --expect-installed")

    states = {r["state"] for r in reqs}
    if "IMPOSSIVEL" in states:
        verdict, code = "IMPOSSIVEL_SOB_DECISAO_A", 1
    elif states == {"PROVADO"}:
        verdict, code = "GARANTIA_CONFIRMADA", 0
    else:
        verdict, code = "GARANTIA_PENDENTE", 3

    payload = {"schema": "evox-guarantee/1", "decision": dec.get("decision"),
               "engine": dec.get("engine"), "verdict": verdict,
               "proved": sum(r["state"] == "PROVADO" for r in reqs),
               "pending": sum(r["state"] == "FALTA_PROVA" for r in reqs),
               "impossible": sum(r["state"] == "IMPOSSIVEL" for r in reqs),
               "requirements": reqs}
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"[garantia] decisão {payload['decision']} · motor {payload['engine']} → {verdict}")
        for r in reqs:
            print(f"  {r['state']:12} {r['id']} {r['requirement']}: {r['detail']}")
            if r["to_prove"]:
                print(f"               ↳ falta: {r['to_prove']}")
        print(f"  {payload['proved']} provado(s) · {payload['pending']} pendente(s) · "
              f"{payload['impossible']} impossível(is)")
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
