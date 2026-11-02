#!/usr/bin/env python3
"""coverage_matrix.py — nenhum script fica sem prova.

Cobertura = o nome do script aparece em algum `tests/*.sh` (chamada direta, stub ou contrato CLI).
Script sem referência só passa se estiver declarado em `references/audit-exemptions.json`
com o motivo. Lista fechada: sobra = falha (AG18).

Uso: coverage_matrix.py [--root DIR] [--json] [--list]
Exit: 0 cobertura completa · 3 lacuna não declarada · 2 uso
"""
from __future__ import annotations

import glob
import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"


def scripts(root: str) -> list[str]:
    pats = ["skills/**/scripts/*.sh", "skills/**/scripts/*.py", "skills/**/assets/*.sh",
            "scripts/*.sh", "scripts/*.py"]
    out = set()
    for p in pats:
        for f in glob.glob(os.path.join(root, p), recursive=True):
            rel = os.path.relpath(f, root)
            if "__pycache__" in rel:
                continue
            out.add(rel)
    return sorted(out)


def tests_text(root: str) -> list[str]:
    out = []
    for p in ("skills/**/tests/*.sh", "tests/*.sh"):
        for f in glob.glob(os.path.join(root, p), recursive=True):
            out.append(open(f, encoding="utf-8", errors="ignore").read())
    return out


def exemptions(root: str) -> dict:
    p = os.path.join(root, SK, "references", "audit-exemptions.json")
    try:
        return json.load(open(p, encoding="utf-8")).get("exemptions", {})
    except Exception:
        return {}


def run(root: str) -> dict:
    blob = "\n".join(tests_text(root))
    ex = exemptions(root)
    rows = []
    for s in scripts(root):
        base = os.path.basename(s)
        if base in blob:
            rows.append({"script": s, "status": "tested"})
        elif s in ex:
            rows.append({"script": s, "status": "exempt", "reason": ex[s]})
        else:
            rows.append({"script": s, "status": "GAP"})
    gaps = [r for r in rows if r["status"] == "GAP"]
    tested = sum(1 for r in rows if r["status"] == "tested")
    return {"root": os.path.abspath(root), "total": len(rows), "tested": tested,
            "exempt": len(rows) - tested - len(gaps), "gaps": len(gaps),
            "coverage_pct": round(100.0 * (len(rows) - len(gaps)) / max(1, len(rows)), 1),
            "ok": not gaps, "rows": rows}


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = "."
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    rep = run(root)
    if "--json" in argv:
        print(json.dumps(rep, indent=2, ensure_ascii=False))
    else:
        print(f"[coverage] {rep['tested']} testados · {rep['exempt']} isentos declarados · "
              f"{rep['gaps']} lacunas · {rep['coverage_pct']}% coberto")
        if "--list" in argv:
            for r in rep["rows"]:
                if r["status"] != "tested":
                    print(f"  {r['status']:7} {r['script']}")
        for r in rep["rows"]:
            if r["status"] == "GAP":
                print(f"  GAP     {r['script']} — escreva um teste ou declare em audit-exemptions.json")
    return 0 if rep["ok"] else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
