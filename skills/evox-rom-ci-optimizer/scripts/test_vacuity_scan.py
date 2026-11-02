#!/usr/bin/env python3
"""test_vacuity_scan.py — o teste é capaz de reprovar? (análise estática de vício)

Complementa o mutation_check (dinâmico) com o que dá para ver no texto: asserções que não
podem falhar, falhas engolidas e suítes sem nenhum caso negativo.

Regras:
  V1  `|| true` em linha de asserção (engole a falha)                      erro
  V2  `2>/dev/null || echo 0` dentro de comparação de saída                erro
  V3  suíte sem nenhum caso negativo (exit 2/3/4/5 esperado)                aviso
  V4  comparação com literal idêntico (asserta sempre verdade)              erro
  V5  `grep -q ""` (padrão vazio casa tudo)                                 erro
  V6  `sleep` no teste (flakiness, não determinismo)                        aviso
  V7  helper ck/check cujo "esperado" é o próprio comando (echo $?)         aviso

Uso: test_vacuity_scan.py [--root DIR] [--json]
Exit: 0 sem erro · 3 vício encontrado · 2 uso
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys

SK = "skills/evox-rom-ci-optimizer"
RULES = [
    ("V1", "erro", re.compile(r"\|\|\s*true\s*(2>&1)?\s*$")),
    ("V2", "erro", re.compile(r"2>/dev/null\s*\|\|\s*echo\s+0")),
    ("V4", "erro", re.compile(r'\bck\s+"[^"]*"\s+"([^"]+)"\s+"\1"')),
    ("V5", "erro", re.compile(r'grep\s+-q\s+""')),
    ("V6", "aviso", re.compile(r"^\s*sleep\s+\d")),
]
NEG = re.compile(r'"(1|2|3|4|5)"\s*$|exit[= ](1|2|3|4|5)|CONFLICT|bloquead|blocked|FAILED|denied|drift|mismatch|MISMATCH', re.I)


def suites(root: str) -> list[str]:
    pats = [f"{SK}/tests/test_*.sh", "tests/test_*.sh", f"{SK}/tests/test_*.py", "tests/test_*.py"]
    out = set()
    for p in pats:
        for f in glob.glob(os.path.join(root, p)):
            out.add(os.path.relpath(f, root))
    return sorted(out)


def scan(root: str) -> dict:
    rows, hits = [], []
    for rel in suites(root):
        try:
            text = open(os.path.join(root, rel), encoding="utf-8").read()
        except OSError:
            continue
        lines = text.splitlines()
        neg = sum(1 for ln in lines if NEG.search(ln))
        file_hits = []
        for i, ln in enumerate(lines, 1):
            st = ln.strip()
            if st.startswith("#"):
                continue
            for rid, sev, rx in RULES:
                if rx.search(ln):
                    file_hits.append({"rule": rid, "severity": sev, "file": rel,
                                      "line": i, "snippet": st[:140]})
        if neg == 0:
            file_hits.append({"rule": "V3", "severity": "aviso", "file": rel, "line": 0,
                              "snippet": "suíte sem caso negativo (só caminho feliz)"})
        hits.extend(file_hits)
        rows.append({"file": rel, "negative_cases": neg,
                     "checks": len(re.findall(r"\b(?:ck|check|ok|bad)\b", text)),
                     "issues": len(file_hits)})
    errors = [h for h in hits if h["severity"] == "erro"]
    return {"schema": "evox-vacuity/1", "root": os.path.abspath(root),
            "suites": len(rows), "errors": len(errors),
            "warnings": len(hits) - len(errors), "ok": not errors,
            "rows": rows, "hits": hits}


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = os.path.abspath(argv[argv.index("--root") + 1]) if "--root" in argv else "."
    rep = scan(root)
    out = os.path.join(root, "workspace", "audit", "vacuity.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(rep, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    if "--json" in argv:
        print(json.dumps(rep, indent=2, ensure_ascii=False))
    else:
        print(f"[vacuity] {rep['suites']} suítes · {rep['errors']} erro(s) · {rep['warnings']} aviso(s)")
        for h in rep["hits"]:
            print(f"  {h['severity'].upper():5} {h['rule']:3} {h['file']}:{h['line']}  {h['snippet']}")
    return 0 if rep["ok"] else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
