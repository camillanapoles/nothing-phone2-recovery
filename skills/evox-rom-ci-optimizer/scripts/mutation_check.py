#!/usr/bin/env python3
"""mutation_check.py — o teste consegue FALHAR? (falseabilidade, Popper na prática)

Para cada mutante do catálogo: copia o workspace, injeta a mutação, roda o teste que deveria
pegá-la. Se o teste continua passando, a mutação "sobreviveu" → o teste é mascarado (vício).

Um teste verde só vale se o vermelho for possível: o harness transforma isso em número.

Uso:
  mutation_check.py [--root DIR] [--catalog F] [--only M01,M07] [--json] [--keep]
Exit: 0 todos os mutantes mortos · 3 sobrevivente/inválido · 2 uso
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

SK = "skills/evox-rom-ci-optimizer"
IGNORE = shutil.ignore_patterns(".git", "__pycache__", "workspace", "work", "*.pyc", "node_modules")


def load_catalog(root: str, path: str | None) -> dict:
    p = path or os.path.join(root, SK, "references", "mutation-catalog.json")
    return json.load(open(p, encoding="utf-8"))


def copy_workspace(root: str) -> str:
    dst = tempfile.mkdtemp(prefix="mut-")
    shutil.copytree(root, os.path.join(dst, "w"), ignore=IGNORE, symlinks=True)
    return os.path.join(dst, "w")


def run_mutant(root: str, m: dict, keep: bool = False) -> dict:
    started = time.time()
    tmp = copy_workspace(root)
    target = os.path.join(tmp, m["file"])
    try:
        text = open(target, encoding="utf-8").read()
    except OSError as exc:
        return {"id": m["id"], "file": m["file"], "test": m["test"], "status": "invalid", "detail": f"arquivo ausente: {exc}"}
    n = text.count(m["find"])
    if n != 1:
        return {"id": m["id"], "file": m["file"], "test": m["test"], "status": "invalid",
                "detail": f"padrão aparece {n}× (precisa ser único)"}
    open(target, "w", encoding="utf-8").write(text.replace(m["find"], m["replace"], 1))
    test = os.path.join(tmp, m["test"])
    if not os.path.exists(test):
        return {"id": m["id"], "file": m["file"], "test": m["test"], "status": "invalid", "detail": f"teste ausente: {m['test']}"}
    try:
        proc = subprocess.run(["bash", test] if test.endswith(".sh") else [sys.executable, test],
                              cwd=tmp, capture_output=True, text=True, timeout=300)
        rc, out = proc.returncode, (proc.stdout + proc.stderr)
    except subprocess.TimeoutExpired:
        rc, out = 124, "timeout"
    status = "killed" if rc != 0 else "survived"
    tail = [l for l in out.splitlines() if "FAIL" in l][:2]
    res = {"id": m["id"], "file": m["file"], "test": m["test"], "status": status,
           "test_exit": rc, "seconds": round(time.time() - started, 1),
           "rationale": m.get("rationale", ""), "evidence": tail}
    if not keep:
        shutil.rmtree(os.path.dirname(tmp), ignore_errors=True)
    return res


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = "."
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    cat_path = argv[argv.index("--catalog") + 1] if "--catalog" in argv else None
    only = None
    if "--only" in argv:
        only = {x.strip() for x in argv[argv.index("--only") + 1].split(",")}
    cat = load_catalog(root, cat_path)
    mutants = [m for m in cat["mutants"] if not only or m["id"] in only]

    results = []
    for m in mutants:
        r = run_mutant(root, m, keep="--keep" in argv)
        results.append(r)
        mark = {"killed": "MORTO ", "survived": "VIVO  ", "invalid": "INVÁLIDO"}[r["status"]]
        print(f"  {mark} {r['id']} {os.path.basename(r['file'])} → "
              f"{os.path.basename(r['test'])}" + (f" ({r.get('detail','')})" if r["status"] == "invalid" else ""))
        if r["status"] == "survived":
            print(f"         SOBREVIVEU: o teste passou com a lógica trocada ({r['rationale']})")

    killed = sum(1 for r in results if r["status"] == "killed")
    survived = [r for r in results if r["status"] == "survived"]
    invalid = [r for r in results if r["status"] == "invalid"]
    score = round(100.0 * killed / max(1, len(results)), 1)
    ok = not survived and not invalid
    rep = {"schema": "evox-mutation-report/1", "root": root, "total": len(results),
           "killed": killed, "survived": len(survived), "invalid": len(invalid),
           "score_pct": score, "ok": ok, "results": results,
           "catalog_files": sorted({m["file"] for m in mutants})}
    out = os.path.join(root, "workspace", "audit", "mutation.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(rep, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print(f"[mutation] {killed}/{len(results)} mortos · score {score}% · "
          f"{len(survived)} vivo(s) · {len(invalid)} inválido(s)")
    return 0 if ok else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
