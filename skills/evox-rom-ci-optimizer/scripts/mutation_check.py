#!/usr/bin/env python3
"""mutation_check.py — o teste consegue FALHAR? (falseabilidade, Popper na prática)

Para cada mutante do catálogo: copia o workspace, injeta a mutação, roda o teste que deveria
pegá-la. Se o teste continua passando, a mutação "sobreviveu" → o teste é mascarado (vício).

Um teste verde só vale se o vermelho for possível: o harness transforma isso em número.

Matar por TIMEOUT não conta como cobertura semântica: se o teste só morre porque travou,
o mutante é classificado "timeout" e o harness falha (a menos que --allow-timeout seja usado).
Cada mutante declara "strength": "semantic" (mata por asserção) ou "contract" (só CLI/--help).

Uso:
  mutation_check.py [--root DIR] [--catalog F] [--only M01,M07] [--jobs N|auto]
                    [--shard K/N] [--keep] [--allow-timeout]

`--jobs` roda N mutantes em paralelo (cada um em sua cópia isolada do workspace — não há
estado compartilhado, então o resultado é idêntico ao sequencial, só que mais rápido).
`--shard K/N` executa só a fração K do catálogo (para matrix de CI): os arquivos inteiros
são distribuídos entre N baldes por contagem, então a união dos N shards é o catálogo
inteiro, uma vez cada — a agregação reprova se algum mutante não voltar.

Exit: 0 todos mortos por asserção · 3 sobrevivente/inválido/timeout · 2 uso
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor

SK = "skills/evox-rom-ci-optimizer"
# timeout por teste (segundos) — reduzível nos testes do próprio harness
TEST_TIMEOUT = int(os.environ.get("MUTATION_TEST_TIMEOUT", "300"))
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
        return {"id": m["id"], "file": m["file"], "test": m["test"], "status": "invalid",
                "strength": m.get("strength", "semantic"), "detail": f"arquivo ausente: {exc}"}
    n = text.count(m["find"])
    if n != 1:
        return {"id": m["id"], "file": m["file"], "test": m["test"], "status": "invalid",
                "strength": m.get("strength", "semantic"), "detail": f"padrão aparece {n}× (precisa ser único)"}
    open(target, "w", encoding="utf-8").write(text.replace(m["find"], m["replace"], 1))
    test = os.path.join(tmp, m["test"])
    if not os.path.exists(test):
        return {"id": m["id"], "file": m["file"], "test": m["test"], "status": "invalid",
                "strength": m.get("strength", "semantic"), "detail": f"teste ausente: {m['test']}"}
    try:
        proc = subprocess.run(["bash", test] if test.endswith(".sh") else [sys.executable, test],
                              cwd=tmp, capture_output=True, text=True, timeout=TEST_TIMEOUT)
        rc, out = proc.returncode, (proc.stdout + proc.stderr)
    except subprocess.TimeoutExpired:
        rc, out = 124, "timeout"
    if rc == 124 or out.strip() == "timeout":
        status = "timeout"
    else:
        status = "killed" if rc != 0 else "survived"
    tail = [l for l in out.splitlines() if "FAIL" in l][:2]
    res = {"id": m["id"], "file": m["file"], "test": m["test"], "status": status,
           "strength": m.get("strength", "semantic"),
           "test_exit": rc, "seconds": round(time.time() - started, 1),
           "rationale": m.get("rationale", ""), "evidence": tail}
    if not keep:
        shutil.rmtree(os.path.dirname(tmp), ignore_errors=True)
    return res


def parse_jobs(argv: list[str]) -> tuple[int, str | None]:
    """--jobs N | --jobs auto. Default 1 (ordem determinística). Inválido -> erro de uso."""
    if "--jobs" not in argv:
        return 1, None
    i = argv.index("--jobs")
    if i + 1 >= len(argv):
        return 0, "--jobs exige um valor (N >= 1 ou 'auto')"
    raw = argv[i + 1].strip().lower()
    if raw == "auto":
        return max(1, os.cpu_count() or 1), None
    try:
        n = int(raw)
    except ValueError:
        return 0, f"--jobs inválido: {raw!r} (use N >= 1 ou 'auto')"
    if n < 1:
        return 0, f"--jobs inválido: {n} (mínimo 1)"
    return n, None


def parse_shard(argv: list[str]) -> tuple[tuple[int, int] | None, str | None]:
    """--shard K/N (1 <= K <= N). Ausente = catálogo inteiro."""
    if "--shard" not in argv:
        return None, None
    i = argv.index("--shard")
    raw = argv[i + 1].strip() if i + 1 < len(argv) else ""
    m = re.fullmatch(r"(\d+)/(\d+)", raw)
    if not m:
        return None, f"--shard inválido: {raw!r} (use K/N, ex.: 1/4)"
    k, n = int(m.group(1)), int(m.group(2))
    if n < 1 or not 1 <= k <= n:
        return None, f"--shard fora do intervalo: {k}/{n} (exige 1 <= K <= N)"
    return (k, n), None


def shard_mutants(mutants: list[dict], k: int, n: int, costs: dict | None = None) -> list[dict]:
    """Distribui mutantes entre N baldes equilibrando o CUSTO, não a contagem.

    Cada mutante roda numa cópia isolada do workspace (sem estado compartilhado), então dois
    mutantes do mesmo arquivo podem ficar em shards diferentes. O peso vem de
    `catalog["costs"]` (segundos medidos); sem peso, 1.0. Guloso: o mais caro primeiro, no
    balde de menor carga. Contar mutantes em vez de segundos foi o que produziu baldes de
    53 s e 186 s — o peso corrige para ~102 s cada. A ordem do catálogo é preservada.
    """
    costs = costs or {}
    buckets: list[list[dict]] = [[] for _ in range(n)]
    load = [0.0] * n
    for m in sorted(mutants, key=lambda m: (-costs.get(m["id"], 1.0), m["id"])):
        idx = min(range(n), key=lambda i: (load[i], i))
        buckets[idx].append(m)
        load[idx] += costs.get(m["id"], 1.0)
    chosen = {m["id"] for m in buckets[k - 1]}
    return [m for m in mutants if m["id"] in chosen]


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    jobs, jobs_err = parse_jobs(argv)
    if jobs_err:
        print(f"[mutation] USO: {jobs_err}", file=sys.stderr)
        return 2
    shard, shard_err = parse_shard(argv)
    if shard_err:
        print(f"[mutation] USO: {shard_err}", file=sys.stderr)
        return 2
    root = "."
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    cat_path = argv[argv.index("--catalog") + 1] if "--catalog" in argv else None
    only = None
    if "--only" in argv:
        only = {x.strip() for x in argv[argv.index("--only") + 1].split(",")}
    cat = load_catalog(root, cat_path)
    mutants = [m for m in cat["mutants"] if not only or m["id"] in only]
    if shard:
        mutants = shard_mutants(mutants, *shard, costs=cat.get("costs"))
        print(f"[mutation] shard {shard[0]}/{shard[1]} · {len(mutants)} mutante(s) neste balde")

    keep = "--keep" in argv
    lock = threading.Lock()

    def report(r: dict) -> None:
        mark = {"killed": "MORTO ", "survived": "VIVO  ", "invalid": "INVÁLIDO",
                "timeout": "TIMEOUT"}[r["status"]]
        with lock:
            print(f"  {mark} {r['id']} {os.path.basename(r['file'])} → "
                  f"{os.path.basename(r['test'])}" + (f" ({r.get('detail','')})" if r["status"] == "invalid" else ""))
            if r["status"] == "survived":
                print(f"         SOBREVIVEU: o teste passou com a lógica trocada ({r['rationale']})")
            elif r["status"] == "timeout":
                print("         TIMEOUT ≠ COBERTURA: o teste travou; sem asserção que mate o mutante")

    if jobs > 1:
        print(f"[mutation] {len(mutants)} mutante(s) em {jobs} processo(s) paralelo(s)")
    if jobs == 1:
        results = []
        for m in mutants:
            r = run_mutant(root, m, keep=keep)
            results.append(r)
            report(r)
    else:
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            # map preserva a ordem do catálogo no relatório, mesmo com execução fora de ordem
            results = list(pool.map(lambda m: run_mutant(root, m, keep=keep), mutants))
        for r in results:
            report(r)

    killed = sum(1 for r in results if r["status"] == "killed")
    survived = [r for r in results if r["status"] == "survived"]
    invalid = [r for r in results if r["status"] == "invalid"]
    timed_out = [r for r in results if r["status"] == "timeout"]
    allow_timeout = "--allow-timeout" in argv
    score = round(100.0 * killed / max(1, len(results)), 1)
    ok = not survived and not invalid and (allow_timeout or not timed_out)
    by_strength = {}
    for r in results:
        key = r["strength"]
        by_strength[key] = by_strength.get(key, 0) + 1
    per_file = {}
    for m in mutants:
        per_file[m["file"]] = per_file.get(m["file"], 0) + 1
    rep = {"schema": "evox-mutation-report/2", "root": root, "total": len(results),
           "shard": f"{shard[0]}/{shard[1]}" if shard else None,
           "killed": killed, "survived": len(survived), "invalid": len(invalid),
           "timeout_killed": len(timed_out), "allow_timeout": allow_timeout,
           "score_pct": score, "ok": ok, "results": results,
           "by_strength": by_strength, "mutants_per_file": per_file,
           "catalog_files": sorted({m["file"] for m in mutants})}
    out = os.path.join(root, "workspace", "audit", "mutation.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(rep, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print(f"[mutation] {killed}/{len(results)} mortos por asserção · score {score}% · "
          f"{len(survived)} vivo(s) · {len(invalid)} inválido(s) · {len(timed_out)} só-timeout · "
          f"força {by_strength}")
    return 0 if ok else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
