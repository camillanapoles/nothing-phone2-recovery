#!/usr/bin/env python3
"""base_gate.py — a branch da sessão tem de CONTER a main, não apenas divergir dela.

O problema que este gate fecha (achado E12): a branch de trabalho de cada sessão nasce de um
commit antigo (ex.: `334c40a`), enquanto a `main` já andou 20+ commits. Um PR dali para a `main`
não "acrescenta pouco": ele **apaga** o que a `main` ganhou. Aconteceu 4 vezes. Nenhum gate olhava
para `origin/main`.

A direção do teste importa e é a parte que erra fácil:
  * `main` é ancestral de `HEAD`  → a branch CONTÉM a main  → OK
  * `HEAD` é ancestral de `main`  → a branch está ATRÁS     → FALHA

Em clone raso (`git clone --depth`) o git **mente** sobre ancestralidade (o histórico é enxertado):
`merge-base --is-ancestor` pode responder "sim" para uma branch atrasada. Por isso clone raso é
`PENDENTE` (exit 3), nunca verde: sem histórico completo não há como provar.

Uso:
  base_gate.py [--root DIR] [--ref origin/main] [--json]
Exit: 0 branch contém a main · 1 branch atrás (ou divergente) · 3 não dá para provar · 4 uso
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys


def git(root: str, *args: str) -> tuple[int, str]:
    try:
        p = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=60)
        return p.returncode, (p.stdout or p.stderr).strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return 127, str(exc)


def avaliar(root: str, ref: str) -> dict:
    rc, _ = git(root, "rev-parse", "--git-dir")
    if rc != 0:
        return {"verdict": "PENDENTE", "code": 3, "motivo": "não é um repositório git"}
    rc, raso = git(root, "rev-parse", "--is-shallow-repository")
    if rc == 0 and raso == "true":
        return {"verdict": "PENDENTE", "code": 3,
                "motivo": "clone raso: ancestralidade não é provável (use fetch --unshallow "
                          "ou actions/checkout com fetch-depth: 0)"}
    rc, _ = git(root, "rev-parse", "--verify", "--quiet", ref)
    if rc != 0:
        return {"verdict": "PENDENTE", "code": 3, "ref": ref,
                "motivo": f"referência {ref!r} ausente (sem remoto? rode git fetch)"}
    rc, head = git(root, "rev-parse", "--short", "HEAD")
    rc2, alvo = git(root, "rev-parse", "--short", ref)
    contem = git(root, "merge-base", "--is-ancestor", ref, "HEAD")[0] == 0
    if not contem:
        rc3, atras = git(root, "rev-list", "--count", f"HEAD..{ref}")
        rc4, perde = git(root, "diff", "--name-only", "--diff-filter=D", ref, "HEAD")
        perdidos = [l for l in perde.splitlines() if l.strip()][:20] if rc4 == 0 else []
        return {"verdict": "FALHA", "code": 1, "ref": ref, "head": head, "alvo": alvo,
                "commits_atras": int(atras) if rc3 == 0 and atras.isdigit() else None,
                "arquivos_que_o_braco_perderia": perdidos,
                "motivo": f"{ref} NÃO é ancestral de HEAD: a branch está atrás e um PR daqui "
                          f"removeria arquivos que já estão na main"}
    return {"verdict": "OK", "code": 0, "ref": ref, "head": head, "alvo": alvo,
            "motivo": f"{ref} é ancestral de HEAD — a branch contém a main"}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(add_help=True, description="a branch contém a main?")
    ap.add_argument("--root", default=".")
    ap.add_argument("--ref", default="origin/main")
    ap.add_argument("--json", action="store_true")
    try:
        args = ap.parse_args(argv)
    except SystemExit as exc:
        return 4 if exc.code != 0 else 0
    r = avaliar(args.root, args.ref)
    if args.json:
        print(json.dumps(r, indent=2, ensure_ascii=False))
    else:
        icone = {"OK": "OK  ", "FALHA": "FALHA", "PENDENTE": "PEND"}[r["verdict"]]
        print(f"  {icone} base_gate · {r['verdict']}: {r['motivo']}")
        for f in r.get("arquivos_que_o_braco_perderia") or []:
            print(f"        perderia: {f}")
        print(f"[base] {r['verdict']} · ref={r.get('ref')} head={r.get('head')} "
              f"atrás={r.get('commits_atras')}")
    return int(r["code"])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
