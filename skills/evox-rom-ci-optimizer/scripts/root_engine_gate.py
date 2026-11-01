#!/usr/bin/env python3
"""root_engine_gate.py — a combinação motor-de-root × kernel × módulos é executável?

Uma escolha só é "limpa" se as três peças fecharem juntas. Este gate responde com dado,
nunca com opinião:

  - KernelSU/SukiSU exigem kernel próprio: sem candidato **certificado**, o veredito é PENDENTE.
  - SUSFS só existe em kernel com patch: motor sem suporte ou kernel sem patch → INCOMPATÍVEL.
  - Módulo com requisito de motor explícito tem de casar com o motor escolhido.
  - Candidato marcado `rejected_eol` nunca passa (release parado não é "mais estável").
  - DroidSpaces (M05) + mount-hide global do SUSFS violam R03 → condição obrigatória.

Uso:
  root_engine_gate.py --engine apatch [--candidate stock-evolutionx] [--modules F] [--json]
  root_engine_gate.py --list-engines

Exit: 0 COMPATÍVEL · 3 PENDENTE (falta dado/certificação) · 1 INCOMPATÍVEL · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
ENGINES = f"{SK}/references/root-engines.json"
CANDIDATES = f"{SK}/references/kernel-candidates.json"
MODULES = f"{SK}/references/module-requirements.json"


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    if len(argv) < 2:
        print("Uso: root_engine_gate.py --engine <id> [--candidate <id>] [--modules F] [--json]",
              file=sys.stderr)
        return 2
    root = "."
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    as_json = "--json" in argv
    eng_p = os.path.join(root, ENGINES)
    cand_p = os.path.join(root, CANDIDATES)
    mod_p = argv[argv.index("--modules") + 1] if "--modules" in argv else os.path.join(root, MODULES)
    for p in (eng_p, cand_p, mod_p):
        if not os.path.exists(p):
            print(f"[ERRO] arquivo ausente: {p}", file=sys.stderr)
            return 4
    try:
        engines = load(eng_p).get("engines") or []
        candidates = load(cand_p).get("candidates") or []
        modules = load(mod_p).get("modules") or []
    except Exception as exc:
        print(f"[ERRO] JSON inválido: {exc}", file=sys.stderr)
        return 4

    if "--list-engines" in argv:
        for e in engines:
            print(f"{e['id']:12} custom_kernel={str(e['requires_custom_kernel']):5} "
                  f"susfs={str(e['supports_susfs']):5} status={e['status']}")
        return 0

    engine_id = argv[argv.index("--engine") + 1] if "--engine" in argv else ""
    engine = next((e for e in engines if e["id"] == engine_id), None)
    if engine is None:
        print(f"[ERRO] motor desconhecido: {engine_id or '(vazio)'}", file=sys.stderr)
        return 4
    cand_id = argv[argv.index("--candidate") + 1] if "--candidate" in argv else ""
    cand = next((c for c in candidates if c["id"] == cand_id), None) if cand_id else None
    if cand_id and cand is None:
        print(f"[ERRO] candidato de kernel desconhecido: {cand_id}", file=sys.stderr)
        return 4

    checks: list[dict] = []

    def add(name: str, verdict: str, detail: str = "") -> None:
        checks.append({"check": name, "verdict": verdict, "detail": detail})

    # 1. candidato de kernel selecionado
    if cand is not None:
        if cand.get("status") == "rejected_eol":
            add("kernel_nao_eol", "incompativel",
                f"{cand['id']} classificados como rejected_eol (release parado não é estável)")
        elif cand.get("status") == "certified":
            add("kernel_certificado", "ok", f"{cand['id']} certificado para a build pinada")
        else:
            add("kernel_certificado", "pendente",
                f"{cand['id']} status={cand.get('status')} — falta L4/hashes/suporte declarado à build")
    else:
        add("kernel_certificado", "pendente" if engine["requires_custom_kernel"] else "ok",
            "motor exige kernel próprio e nenhum candidato foi escolhido"
            if engine["requires_custom_kernel"] else "motor roda no kernel stock da ROM")

    # 2. engine exige kernel próprio
    if engine["requires_custom_kernel"] and cand is None:
        add("kernel_obrigatorio", "pendente", f"{engine['id']} exige kernel customizado")

    # 3. requisitos explícitos por módulo
    for m in modules:
        need = m.get("requires_root_engine") or []
        if need and engine["id"] not in need and not m.get("is_root_engine"):
            add(f"modulo_{m['id']}_motor", "incompativel",
                f"{m['id']} exige motor em {need}, escolhido={engine['id']}")
        if m.get("needs_zygisk") and not engine.get("supports_zygisk"):
            add(f"modulo_{m['id']}_zygisk", "incompativel",
                f"{m['id']} exige Zygisk e {engine['id']} não suporta")
        if m.get("requires_susfs"):
            if not engine.get("supports_susfs"):
                add(f"modulo_{m['id']}_susfs", "incompativel",
                    f"{m['id']} exige SUSFS; {engine['id']} não suporta")
            elif cand is None or not cand.get("kernel_supports_susfs") or cand.get("status") != "certified":
                add(f"modulo_{m['id']}_susfs", "pendente",
                    f"{m['id']} exige SUSFS em kernel certificado (atual: "
                    f"{cand['id'] if cand else 'sem candidato'})")
            else:
                add(f"modulo_{m['id']}_susfs", "ok", "SUSFS disponível no kernel certificado")

    # 4. R03: DroidSpaces + mount-hide global do SUSFS
    if engine.get("supports_susfs") and any(m.get("mount_hide_global") for m in modules):
        add("r03_mount_hide", "condicao",
            "SUSFS só com mount-hide GLOBAL desabilitado (DroidSpaces/M05 no escopo)")

    # 5. módulos que exigem root mas o motor não dá root
    if any(m.get("root_required") for m in modules) and engine.get("mechanism", "").startswith("none"):
        add("root_disponivel", "incompativel", "módulos exigem root e o motor não fornece")

    verdicts = {c["verdict"] for c in checks}
    if "incompativel" in verdicts:
        verdict, code = "INCOMPATÍVEL", 1
    elif "pendente" in verdicts:
        verdict, code = "PENDENTE", 3
    else:
        verdict, code = "COMPATÍVEL", 0

    payload = {
        "schema": "evox-root-engine-verdict/1",
        "engine": {"id": engine["id"], "name": engine["name"], "status": engine["status"],
                   "requires_custom_kernel": engine["requires_custom_kernel"],
                   "supports_susfs": engine["supports_susfs"]},
        "kernel_candidate": ({"id": cand["id"], "status": cand.get("status")} if cand else None),
        "modules_in_scope": len(modules),
        "verdict": verdict,
        "checks": checks,
        "reasons": [c["detail"] for c in checks if c["verdict"] != "ok"],
    }
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"[gate] motor={engine['id']} kernel={cand['id'] if cand else '(stock)'} → {verdict}")
        for c in checks:
            mark = {"ok": "OK ", "pendente": "PEND", "incompativel": "NAO ", "condicao": "COND"}[c["verdict"]]
            print(f"  {mark} {c['check']}: {c['detail']}")
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
