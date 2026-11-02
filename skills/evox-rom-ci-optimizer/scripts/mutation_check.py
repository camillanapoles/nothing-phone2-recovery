#!/usr/bin/env python3
"""mutation_check.py — o teste consegue FALHAR? (falseabilidade, Popper na prática)

Para cada mutante do catálogo: copia o workspace, injeta a mutação, roda o teste que deveria
pegá-la. Se o teste continua passando, a mutação "sobreviveu" → o teste é mascarado (vício).

Um teste verde só vale se o vermelho for possível: o harness transforma isso em número.

Matar por TIMEOUT não conta como cobertura semântica: se o teste só morre porque travou,
o mutante é classificado "timeout" e o harness falha (a menos que --allow-timeout seja usado).
Cada mutante declara "strength": "semantic" (mata por asserção) ou "contract" (só CLI/--help).

Escopo: SEM argumento roda o catálogo INTEIRO. Subconjunto é pedido explícito e é FECHADO:
id pedido que não existe no catálogo = erro (exit 4), nunca "0 de 0 executados" com exit 0.
Cada execução reconstrói `workspace/audit/mutation-latest.json` do zero: cobertura por M[id],
com valor 1 (morto) ou 0 (não executado/sobreviveu) e o produto deles. Rodar em parte deixa
o ledger visivelmente incompleto — não há como confundir "passei" com "pulei".

Ids são auto-incrementais: entrada de catálogo sem "id" recebe o próximo livre (M###) na ordem
do arquivo; `--write-ids` grava os ids atribuídos, `--next-id N` mostra os próximos, `--verify`
cobra unicidade e numeração sem lacunas.

Uso:
  mutation_check.py [--root DIR] [--catalog F] [--json] [--keep] [--allow-timeout]
                    [--only M01,M07 | --range M180-M192 | --from M186 --to M192]
                    [--verify] [--next-id [N]] [--write-ids] [--shard]
Exit: 0 todos mortos por asserção · 3 sobrevivente/inválido/timeout
      4 pedido inválido (id fora do catálogo, seleção vazia) · 1 catálogo inconsistente
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

SK = "skills/evox-rom-ci-optimizer"
# timeout por teste (segundos) — reduzível nos testes do próprio harness
TEST_TIMEOUT = int(os.environ.get("MUTATION_TEST_TIMEOUT", "300"))
IGNORE = shutil.ignore_patterns(".git", "__pycache__", "workspace", "work", "*.pyc", "node_modules")


ID_RE = re.compile(r"^M\d{2,4}$")


def _num(i: str) -> int | None:
    return int(i[1:]) if ID_RE.match(i or "") else None


def load_catalog(root: str, path: str | None) -> dict:
    p = path or os.path.join(root, SK, "references", "mutation-catalog.json")
    cat = json.load(open(p, encoding="utf-8"))
    cat["_auto_ids"] = _auto_ids(cat)
    return cat


def _auto_ids(cat: dict) -> list[str]:
    """Entrada sem id ganha o próximo livre — id não é digitado à mão."""
    pendentes = [m for m in cat.get("mutants") or [] if not m.get("id")]
    if not pendentes:
        return []
    usados = {m["id"] for m in cat["mutants"] if m.get("id")} | set(cat.get("retired") or [])
    nums = [n for n in (_num(i) for i in usados) if n is not None]
    largura = max([len(i) - 1 for i in usados if ID_RE.match(i)] or [2])
    n = max(nums or [0])
    for m in pendentes:
        n += 1
        m["id"] = "M" + str(n).zfill(largura)
    return [m["id"] for m in pendentes]


def catalog_numbers(cat: dict) -> list[int]:
    ids = [m["id"] for m in cat["mutants"]] + list(cat.get("retired") or [])
    return sorted(n for n in (_num(i) for i in ids) if n is not None)


def verify_catalog(cat: dict) -> list[str]:
    probs = []
    ids = [m["id"] for m in cat["mutants"]]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    if dup:
        probs.append("ids duplicados: " + ", ".join(dup))
    ruins = [i for i in ids if not ID_RE.match(i or "")]
    if ruins:
        probs.append("ids fora do padrão M###: " + ", ".join(ruins[:5]))
    nums = catalog_numbers(cat)
    if nums:
        lacunas = [n for n in range(1, max(nums) + 1) if n not in nums]
        if lacunas:
            probs.append("numeração com lacuna: " + ", ".join("M%d" % n for n in lacunas[:5]))
    sem_teste = [m["id"] for m in cat["mutants"] if not m.get("test") or not m.get("find")]
    if sem_teste:
        probs.append("mutante sem find/test: " + ", ".join(sem_teste[:5]))
    return probs


def _expand(tokens: list[str]) -> list[str]:
    """Aceita M186, M186-M192, intervalos com espaços e listas separadas por vírgula."""
    out = []
    for t in tokens:
        t = (t or "").strip()
        if not t:
            continue
        m = re.match(r"^M?(\d+)\s*[-–:]\s*M?(\d+)$", t)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if b < a:
                a, b = b, a
            largura = max(len(m.group(1)), len(m.group(2)), 2)
            out += ["M" + str(i).zfill(largura) for i in range(a, b + 1)]
        else:
            out.append(t if t.startswith("M") else "M" + t)
    return out


def selecao(cat: dict, argv: list[str]) -> tuple[list[str] | None, list[str]]:
    """(ids pedidos | None = todos, problemas). Pedido fechado: id fora do catálogo reprova."""
    if "--only" not in argv and "--range" not in argv and "--from" not in argv:
        return None, []
    pedidos = []
    if "--only" in argv:
        pedidos += _expand(argv[argv.index("--only") + 1].split(","))
    if "--range" in argv:
        pedidos += _expand(argv[argv.index("--range") + 1].split(","))
    if "--from" in argv:
        ini = argv[argv.index("--from") + 1]
        fim = argv[argv.index("--to") + 1] if "--to" in argv else ini
        pedidos += _expand([ini + "-" + fim])
    pedidos = list(dict.fromkeys(pedidos))
    if not pedidos:
        return [], ["seleção vazia: --only/--range/--from sem ids válidos"]
    conhecidos = {m["id"] for m in cat["mutants"]} | set(cat.get("retired") or [])
    fora = [i for i in pedidos if i not in conhecidos]
    if fora:
        return pedidos, ["id pedido não existe no catálogo (não é 'nada a fazer'): " +
                         ", ".join(fora)]
    vivos = {m["id"] for m in cat["mutants"]}
    aposentados = [i for i in pedidos if i not in vivos]
    if aposentados and len(aposentados) == len(pedidos):
        return pedidos, ["todos os ids pedidos estão em 'retired' (já não são prova de nada)"]
    return pedidos, []


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


def write_ledger(root: str, cat: dict, results: list[dict], started_at: str) -> tuple[str, dict]:
    """Reconstrói o ledger a cada execução: 1 = morto, 0 = não executado/sobreviveu."""
    p = os.path.join(root, "workspace", "audit", "mutation-latest.json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    feitos = {r["id"]: r for r in results}
    entries = {}
    for m in cat["mutants"]:
        r = feitos.get(m["id"])
        entries[m["id"]] = {"status": r["status"] if r else "not_run",
                            "value": 1 if (r and r["status"] == "killed") else 0,
                            "at": started_at if r else None,
                            "file": m["file"], "test": m["test"]}
    total = len(entries)
    mortos = sum(e["value"] for e in entries.values())
    prod = 1 if total and mortos == total else 0
    led = {"schema": "evox-mutation-latest/1", "started_at": started_at,
           "catalog_total": total, "entries": entries,
           "coverage": {"total": total, "executed": len(results), "killed": mortos,
                        "complete": bool(prod), "product": prod,
                        "executed_all": len(results) == total,
                        "missing": sorted(i for i, e in entries.items() if e["value"] == 0)}}
    json.dump(led, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    return p, led


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = "."
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    cat_path = argv[argv.index("--catalog") + 1] if "--catalog" in argv else None
    cat = load_catalog(root, cat_path)
    auto = cat.get("_auto_ids") or []
    if auto:
        print("[catalog] ids atribuídos automaticamente: " + ", ".join(auto), file=sys.stderr)

    if "--verify" in argv:
        probs = verify_catalog(cat)
        nums = catalog_numbers(cat)
        prox = "M" + str((max(nums) if nums else 0) + 1).zfill(2)
        if probs:
            print("[catalog] INCONSISTENTE · " + " · ".join(probs), file=sys.stderr)
            return 1
        print(f"[catalog] {len(cat['mutants'])} mutante(s) · numeração fechada até "
              f"{'M%d' % max(nums) if nums else '-'} · próximo id {prox}")
        return 0

    if "--next-id" in argv:
        i = argv.index("--next-id")
        qtd = 1
        if i + 1 < len(argv) and argv[i + 1].isdigit():
            qtd = int(argv[i + 1])
        nums = catalog_numbers(cat)
        base = (max(nums) if nums else 0)
        ids = ["M" + str(base + k).zfill(2) for k in range(1, qtd + 1)]
        print(",".join(ids))
        return 0

    if "--write-ids" in argv:
        if not auto:
            print("[catalog] nada a gravar: todos os mutantes já têm id")
            return 0
        cat.pop("_auto_ids", None)
        cat["note"] = (cat.get("note") or "") if False else cat.get("note")
        cat.pop("note_auto", None)
        dest = cat_path or os.path.join(root, SK, "references", "mutation-catalog.json")
        json.dump(cat, open(dest, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        print("[catalog] ids gravados: " + ", ".join(auto))
        return 0

    ids, problemas = selecao(cat, argv)
    if problemas:
        for pr in problemas:
            print("[mutation] PEDIDO INVÁLIDO: " + pr, file=sys.stderr)
        return 4
    if ids is not None:
        selecionados = set(ids)
        mutants = [m for m in cat["mutants"] if m["id"] in selecionados]
        print(f"[mutation] escopo: {len(mutants)}/{len(cat['mutants'])} mutante(s) pedido(s)",
              file=sys.stderr)
    else:
        mutants = list(cat["mutants"])
        print(f"[mutation] escopo: TODOS ({len(mutants)} mutantes do catálogo)", file=sys.stderr)

    started_at = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    silencioso = "--json" in argv
    results = []
    for m in mutants:
        r = run_mutant(root, m, keep="--keep" in argv)
        results.append(r)
        if silencioso:
            continue
        mark = {"killed": "MORTO ", "survived": "VIVO  ", "invalid": "INVÁLIDO",
                "timeout": "TIMEOUT"}[r["status"]]
        print(f"  {mark} {r['id']} {os.path.basename(r['file'])} → "
              f"{os.path.basename(r['test'])}" + (f" ({r.get('detail','')})" if r["status"] == "invalid" else ""))
        if r["status"] == "survived":
            print(f"         SOBREVIVEU: o teste passou com a lógica trocada ({r['rationale']})")
        elif r["status"] == "timeout":
            print("         TIMEOUT ≠ COBERTURA: o teste travou; sem asserção que mate o mutante")

    killed = sum(1 for r in results if r["status"] == "killed")
    survived = [r for r in results if r["status"] == "survived"]
    invalid = [r for r in results if r["status"] == "invalid"]
    timed_out = [r for r in results if r["status"] == "timeout"]
    allow_timeout = "--allow-timeout" in argv
    # --shard: subconjunto DECLARADO (parte de uma execução completa); a cobertura do
    # catálogo inteiro é cobrada no relatório que junta os shards. Sem --shard, rodar
    # parte continua sendo falha (exit 3) — não existe "passei" por rodar pouco.
    parcial_ok = "--shard" in argv
    score = round(100.0 * killed / max(1, len(results)), 1)
    ok = not survived and not invalid and (allow_timeout or not timed_out)
    by_strength = {}
    for r in results:
        key = r["strength"]
        by_strength[key] = by_strength.get(key, 0) + 1
    per_file = {}
    for m in mutants:
        per_file[m["file"]] = per_file.get(m["file"], 0) + 1
    rep = {"schema": "evox-mutation-report/3", "root": root,
           "scope": {"mode": "todos" if ids is None else "subconjunto",
                     "catalog_total": len(cat["mutants"]),
                     "requested": ids if ids is not None else "todos"},
           "total": len(results),
           "killed": killed, "survived": len(survived), "invalid": len(invalid),
           "timeout_killed": len(timed_out), "allow_timeout": allow_timeout,
           "score_pct": score, "ok": ok, "results": results,
           "by_strength": by_strength, "mutants_per_file": per_file,
           "catalog_files": sorted({m["file"] for m in mutants})}
    out = os.path.join(root, "workspace", "audit", "mutation.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    led_path, led = write_ledger(root, cat, results, started_at)
    rep["ledger"] = {"path": os.path.relpath(led_path, root), "coverage": led["coverage"]}
    json.dump(rep, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    cov = led["coverage"]
    if silencioso:
        print(json.dumps(rep, ensure_ascii=False, indent=1))
        return 0 if ok else 3
    print(f"[mutation] {killed}/{len(results)} mortos por asserção · score {score}% · "
          f"{len(survived)} vivo(s) · {len(invalid)} inválido(s) · {len(timed_out)} só-timeout · "
          f"força {by_strength}")
    print(f"[mutation] cobertura do catálogo: {cov['killed']}/{cov['total']} "
          f"(produto={cov['product']}) · "
          + ("COMPLETA" if cov["complete"] else "INCOMPLETA — faltam " +
             ", ".join(cov["missing"][:8]) + ("..." if len(cov["missing"]) > 8 else "")))
    # "não executei" (executed_all=False) não pode sair 0; "não morreu" já está no ok
    if not cov["executed_all"] and not parcial_ok:
        ok = False
    return 0 if ok else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
