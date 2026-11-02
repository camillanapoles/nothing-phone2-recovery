#!/usr/bin/env python3
"""proof_items.py — a prova vira item, e cada item é validado de volta (retorno item a item).

`make prove` imprime 700+ linhas de texto. Texto não viaja: não dá para conferir se uma
suíte foi *omitida*, se um PASS foi reescrito, ou se o "tudo verde" do fim sobreviveu a um
log truncado. Este script fecha esse buraco em duas etapas:

  1. COLETA  — transforma o log de cada suíte em itens (`PASS`/`FAIL` → status), com
               paridade declarada × observada (`TOTAL: n PASS / m FAIL`) e um digest
               sha256 que cobre suíte + modo + itens + paridade.
  2. VALIDA  — lê os bundles de volta e confere cada item: id contíguo (ninguém apagou
               item no meio), status válido, paridade, flag `ok` coerente com os itens,
               digest intacto. Qualquer divergência = exit 3.

O digest é o que permite um consumidor externo (Actions, Worker, Colab, Linear) aceitar
o resultado sem confiar no transporte: se o JSON chegou completo e igual, o número é o
mesmo; se chegou editado/truncado, a validação reprova.

Uso:
  proof_items.py --log LOG --suite NOME [--mode cases|gate] [--exit-code N] [--out F] [--json]
  proof_items.py --mutation workspace/audit/mutation.json --suite NOME [--out F]
  proof_items.py --validate F [F ...] [--summary-md F] [--json]

Exit: 0 tudo verde e íntegro · 3 FAIL/inconsistência/tamper · 2 uso
"""
from __future__ import annotations

import hashlib
import json
import re
import sys

SCHEMA = "evox-proof-items/1"
CASE_RE = re.compile(r"^(PASS|FAIL)\s{2,}(.+)$")
TOTAL_RE = re.compile(r"^TOTAL:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL")
FAIL_MARKERS = ("VIOLACOES ENCONTRADAS", "REPROVADO")


# ── digest ────────────────────────────────────────────────────────────────────
def digest_of(bundle: dict) -> str:
    """sha256 canônico sobre o que importa: suíte, modo, itens e paridade declarada."""
    core = {"suite": bundle["suite"], "mode": bundle["mode"],
            "items": bundle["items"], "declared": bundle["declared"]}
    blob = json.dumps(core, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _bundle(suite: str, mode: str, items: list[dict], declared: dict) -> dict:
    b = {"schema": SCHEMA, "suite": suite, "mode": mode, "items": items,
         "declared": declared, "ok": True, "digest": ""}
    b["ok"] = not any(i["status"] == "FAIL" for i in items) and _parity_ok(b)
    b["digest"] = digest_of(b)
    return b


def _parity_ok(bundle: dict) -> bool:
    got_pass = sum(1 for i in bundle["items"] if i["status"] == "PASS")
    got_fail = sum(1 for i in bundle["items"] if i["status"] == "FAIL")
    return (got_pass == bundle["declared"]["pass"] and got_fail == bundle["declared"]["fail"])


def _items(suite: str, raw: list[tuple[str, str, str]]) -> list[dict]:
    return [{"id": f"{suite}#{n:03d}", "name": name, "status": st, "evidence": ev}
            for n, (st, name, ev) in enumerate(raw, 1)]


# ── coleta ────────────────────────────────────────────────────────────────────
def collect_cases(suite: str, log: str) -> dict:
    """Cada linha PASS/FAIL é um item; `TOTAL:` é a testemunha da paridade."""
    raw, tot_p, tot_f, seen_total = [], 0, 0, False
    for line in log.splitlines():
        m = CASE_RE.match(line.strip())
        if m:
            body = m.group(2).rstrip()
            parts = re.split(r"\s{2,}", body, maxsplit=1)
            name = parts[0].strip()
            ev = parts[1].strip() if len(parts) > 1 else ""
            raw.append((m.group(1), name, ev))
            continue
        t = TOTAL_RE.match(line.strip())
        if t:
            seen_total = True
            tot_p += int(t.group(1))
            tot_f += int(t.group(2))
    if seen_total:
        # a testemunha manda: se um PASS/FAIL sumiu do log, a paridade acusa
        declared = {"pass": tot_p, "fail": tot_f}
    else:
        declared = {"pass": sum(1 for r in raw if r[0] == "PASS"),
                    "fail": sum(1 for r in raw if r[0] == "FAIL")}
    return _bundle(suite, "cases", _items(suite, raw), declared)


def collect_gate(suite: str, log: str, exit_code: int) -> dict:
    """Suíte-gate (validate/eval/arch): um item — e uma contradição explícita é inválida."""
    contradicao = exit_code == 0 and any(mk in log for mk in FAIL_MARKERS)
    has_fail_line = any(ln.strip().startswith("FAIL") for ln in log.splitlines())
    bad = exit_code != 0 or contradicao or has_fail_line
    tail = [ln.strip() for ln in log.splitlines() if ln.strip()][-1:] or [""]
    status = "FAIL" if bad else "PASS"
    ev = tail[0] if status == "PASS" else (
        f"exit={exit_code}" + (" · saida contradiz exit 0" if contradicao else "")
        + (f" · {tail[0]}" if tail[0] else ""))
    item = {"id": f"{suite}#001", "name": suite, "status": status, "evidence": ev[:300]}
    b = _bundle(suite, "gate", [item], {"pass": 1 if status == "PASS" else 0,
                                        "fail": 0 if status == "PASS" else 1})
    if contradicao:
        b["ok"] = False
    return b


def collect_mutation(suite: str, report: dict) -> dict:
    """Relatório do mutation_check → 1 item por mutante (morto = PASS)."""
    raw = []
    for r in report.get("results") or []:
        st = "PASS" if r.get("status") == "killed" else "FAIL"
        ev = f"{r.get('status')} · {r.get('file', '').split('/')[-1]} · {r.get('test_exit')}"
        if r.get("rationale"):
            ev += f" · {r['rationale'][:120]}"
        raw.append((st, r.get("id", "?"), ev))
    return _bundle(suite, "mutation", _items(suite, raw),
                   {"pass": sum(1 for r in raw if r[0] == "PASS"),
                    "fail": sum(1 for r in raw if r[0] == "FAIL")})


# ── validação item a item ─────────────────────────────────────────────────────
def validate(bundle: dict) -> list[str]:
    """Devolve a lista de problemas. Lista vazia = bundle íntegro e sem FAIL."""
    p: list[str] = []
    tag = bundle.get("suite", "?")
    if bundle.get("schema") != SCHEMA:
        p.append(f"{tag}: schema {bundle.get('schema')!r} != {SCHEMA}")
        return p
    items = bundle.get("items")
    if not isinstance(items, list) or not items:
        return [f"{tag}: nenhum item (suíte vazia não é prova)"]
    for n, it in enumerate(items, 1):
        expected = f"{tag}#{n:03d}"
        if it.get("id") != expected:
            p.append(f"{tag}: item {n} com id {it.get('id')!r} (esperado {expected!r}) — item faltando/fora de ordem")
        if it.get("status") not in ("PASS", "FAIL"):
            p.append(f"{tag}: item {it.get('id')} com status inválido {it.get('status')!r}")
        if not (it.get("name") or "").strip():
            p.append(f"{tag}: item {it.get('id')} sem nome")
    if not _parity_ok(bundle):
        got_pass = sum(1 for i in items if i.get("status") == "PASS")
        got_fail = sum(1 for i in items if i.get("status") == "FAIL")
        p.append(f"{tag}: paridade quebrada — declarado {bundle.get('declared')} × "
                 f"observado pass={got_pass} fail={got_fail}")
    fail_items = [i for i in items if i.get("status") == "FAIL"]
    if fail_items:
        p.append(f"{tag}: {len(fail_items)} item(ns) FAIL ({', '.join(i['name'][:40] for i in fail_items[:3])})")
    if bundle.get("ok") is not (not fail_items and _parity_ok(bundle)):
        p.append(f"{tag}: flag ok={bundle.get('ok')} incoerente com os itens")
    if bundle.get("digest") != digest_of(bundle):
        p.append(f"{tag}: digest não confere — payload editado ou serializado de outro jeito")
    return p


# ── CLI ───────────────────────────────────────────────────────────────────────
def _arg(argv: list[str], flag: str) -> str | None:
    return argv[argv.index(flag) + 1] if flag in argv and argv.index(flag) + 1 < len(argv) else None


def _emit(bundle: dict, out: str | None) -> None:
    blob = json.dumps(bundle, ensure_ascii=False, indent=2)
    if out:
        open(out, "w", encoding="utf-8").write(blob + "\n")
    print(blob)


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    as_json = "--json" in argv

    if "--validate" in argv:
        paths = []
        i = argv.index("--validate") + 1
        while i < len(argv) and not argv[i].startswith("--"):
            paths.append(argv[i])
            i += 1
        if not paths:
            print("[proof] USO: --validate BUNDLE.json [BUNDLE.json ...]", file=sys.stderr)
            return 2
        problems, bundles = [], []
        for path in paths:
            try:
                b = json.load(open(path, encoding="utf-8"))
            except Exception as exc:
                problems.append(f"{path}: ilegível ({exc})")
                continue
            bundles.append(b)
            problems.extend(validate(b))
        total = sum(len(b.get("items") or []) for b in bundles)
        md = _arg(argv, "--summary-md")
        if md:
            open(md, "w", encoding="utf-8").write(summary_md(bundles, problems))
        if as_json:
            print(json.dumps({"schema": "evox-proof-validation/1", "bundles": len(bundles),
                              "items": total, "problems": problems, "ok": not problems},
                             ensure_ascii=False, indent=2))
        else:
            for b in bundles:
                print(f"  {b.get('suite', '?'):<34} {len(b.get('items') or []):>4} item(ns) "
                      f"{'PASS' if not validate(b) else 'FAIL'}  {str(b.get('digest'))[:23]}")
            for pr in problems:
                print(f"  PROBLEMA  {pr}")
            print(f"[proof] {total} item(ns) em {len(bundles)} bundle(s) · "
                  f"{len(problems)} problema(s) · {'ÍNTEGRO' if not problems else 'REPROVADO'}")
        return 0 if not problems else 3

    suite = _arg(argv, "--suite")
    if not suite:
        print("[proof] USO: --suite NOME (ou --validate BUNDLE ...)", file=sys.stderr)
        return 2

    out = _arg(argv, "--out")
    if _arg(argv, "--mutation"):
        report = json.load(open(_arg(argv, "--mutation"), encoding="utf-8"))
        bundle = collect_mutation(suite, report)
    else:
        log_path = _arg(argv, "--log")
        if not log_path:
            print("[proof] USO: --log ARQUIVO --suite NOME", file=sys.stderr)
            return 2
        try:
            log = open(log_path, encoding="utf-8", errors="replace").read()
        except OSError as exc:
            print(f"[proof] log ilegível: {exc}", file=sys.stderr)
            return 2
        mode = _arg(argv, "--mode") or "cases"
        if mode not in ("cases", "gate"):
            print(f"[proof] modo inválido: {mode!r} (cases|gate)", file=sys.stderr)
            return 2
        if mode == "gate":
            try:
                code = int(_arg(argv, "--exit-code") or "0")
            except ValueError:
                print("[proof] --exit-code exige inteiro", file=sys.stderr)
                return 2
            bundle = collect_gate(suite, log, code)
        else:
            bundle = collect_cases(suite, log)

    problems = validate(bundle)
    _emit(bundle, out)
    if problems and not as_json:
        for pr in problems:
            print(f"  PROBLEMA  {pr}", file=sys.stderr)
    return 0 if not problems else 3


def summary_md(bundles: list[dict], problems: list[str]) -> str:
    lines = ["## Prova item a item", "",
             "| suíte | itens | PASS | FAIL | digest |", "|---|---:|---:|---:|---|"]
    for b in bundles:
        items = b.get("items") or []
        mp = sum(1 for i in items if i.get("status") == "PASS")
        lines.append(f"| `{b.get('suite')}` | {len(items)} | {mp} | {len(items) - mp} | "
                     f"`{str(b.get('digest'))[7:19]}` |")
    lines += ["", f"**{sum(len(b.get('items') or []) for b in bundles)} itens · "
              f"{len(problems)} problema(s)**", ""]
    if problems:
        lines += ["### Reprovado", ""] + [f"- {p}" for p in problems] + [""]
    else:
        lines += ["Todos os itens íntegros: paridade declarada × observada confere e o "
                  "digest de cada bundle bate.", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
