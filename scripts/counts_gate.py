#!/usr/bin/env python3
"""counts_gate.py — nenhum limite escrito à mão: todo número dito em doc ou CI é DERIVADO.

O catálogo pode crescer (175 → 176 → 999). Se um documento, workflow ou comentário continuar
dizendo o número velho, este gate reprova. Não existe "quase": contagem escrita = contagem
conferida contra a fonte viva (catálogo, contrato, plano, gates).

Fontes da verdade (nada digitado aqui):
  mutantes / aposentados / último id   → skills/*/references/mutation-catalog.json
  camadas                              → skills/*/references/install-stack.json
  invariantes do contrato              → scripts/stack_gate.py --json
  coerências da refatoração            → scripts/refactor_gate.py --json
  passos do plano de fechamento        → skills/*/references/closure-plan.json

Histórico é DECLARADO, nunca presumido: no topo do arquivo (vale para o arquivo inteiro) ou no
fim da própria linha (vale para aquela afirmação): `<!-- contagens: histórico -->`.

Uso:
  counts_gate.py [--root DIR] [--json]
Exit: 0 tudo derivado e coerente · 1 número escrito diverge da fonte · 3 fonte ausente · 4 uso
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys

SK = "skills/evox-rom-ci-optimizer"
CATALOGO = f"{SK}/references/mutation-catalog.json"
STACK = f"{SK}/references/install-stack.json"
PLANO = f"{SK}/references/closure-plan.json"
STACK_GATE = "scripts/stack_gate.py"
REFACTOR_GATE = "scripts/refactor_gate.py"
WORKFLOWS = ".github/workflows/*.yml"
RAIZ_MD = ["AGENTS.md", "README.md", "agente.md"]
DOCS = "docs/**/*.md"
MARCA_HISTORICO = "contagens: histórico"
# Doc congelado tem de dizer A QUE ESTADO ele se refere: commit + data. Sem isso, "histórico" vira
# porta de saída silenciosa e o número velho continua lendo como verdade atual.
CONGELADO_RX = re.compile(r"congelado em:\s*([0-9a-f]{7,40})\s*\((\d{4}-\d{2}-\d{2})\)")


def ler(root: str, rel: str) -> str:
    try:
        return open(os.path.join(root, rel), encoding="utf-8").read()
    except OSError:
        return ""


def json_de(root: str, rel: str):
    try:
        return json.loads(ler(root, rel) or "null")
    except json.JSONDecodeError:
        return None


def gate_json(root: str, script: str):
    """Conta checagens rodando o próprio gate (fonte única, sem lista paralela)."""
    try:
        r = subprocess.run([sys.executable, os.path.join(root, script), "--root", root, "--json"],
                           capture_output=True, text=True, timeout=120)
        return json.loads(r.stdout or "{}")
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}


def verdade(root: str) -> tuple[dict, list[str]]:
    faltando = []
    cat = json_de(root, CATALOGO)
    stack = json_de(root, STACK)
    plano = json_de(root, PLANO)
    for nome, valor in (("catálogo", cat), ("install-stack", stack), ("closure-plan", plano)):
        if not isinstance(valor, dict):
            faltando.append(f"{nome} ausente/inválido")
    if faltando:
        return {}, faltando
    ids = [m.get("id") for m in cat.get("mutants") or []]
    nums = [int(i[1:]) for i in ids + list(cat.get("retired") or [])
            if isinstance(i, str) and re.match(r"^M\d+$", i)]
    invariantes = len(gate_json(root, STACK_GATE).get("checks") or [])
    coer = len(gate_json(root, REFACTOR_GATE).get("checks") or [])
    if not invariantes:
        faltando.append("stack_gate não respondeu")
    if not coer:
        faltando.append("refactor_gate não respondeu")
    return {
        "mutantes": len(ids),
        "ultimo_id": max(nums) if nums else 0,
        "proximo_id": (max(nums) if nums else 0) + 1,
        "camadas": len(stack.get("layers") or []),
        "invariantes": invariantes,
        "coer": coer,
        "passos": len(plano.get("steps") or []),
    }, faltando


# (nome, regex, grupos que formam o número escrito, valor derivado da verdade)
PADROES = [
    ("mortos/mutantes", re.compile(r"(?<!\d)(\d+)\s*/\s*(\d+)\s*(?:mortos|mutantes)\b"),
     "1/2", lambda t: f"{t['mutantes']}/{t['mutantes']}"),
    # só quando a frase afirma o TAMANHO do catálogo (subconjunto é legítimo)
    ("mutantes no catálogo", re.compile(r"cat[áa]logo[^\n]{0,24}?(?<!\d)(\d+)\s+mutante"),
     "1", lambda t: str(t["mutantes"])),
    ("tamanho do catálogo", re.compile(r"(?<!\d)(\d+)\s+mutantes?\s+(?:no|do)\s+cat[áa]logo"),
     "1", lambda t: str(t["mutantes"])),
    ("invariantes do contrato", re.compile(r"(?<!\d)(\d+)\s*/\s*(\d+)\s+invariantes\b"),
     "1/2", lambda t: f"{t['invariantes']}/{t['invariantes']}"),
    ("coerências da refatoração", re.compile(r"(?<!\d)(\d+)\s*/\s*(\d+)\s+coer[êe]ncias\b"),
     "1/2", lambda t: f"{t['coer']}/{t['coer']}"),
    ("passos do plano", re.compile(r"\b(?:os|entre)\s+(\d+)\s+passos\b"),
     "1", lambda t: str(t["passos"])),
    ("faixa de checagens RC", re.compile(r"RC1\s*…\s*RC(\d+)"),
     "1", lambda t: str(t["coer"])),
    ("último id do catálogo", re.compile(r"(?:at[ée]|\.\.)\s*M(\d+)\b"),
     "1", lambda t: str(t["ultimo_id"])),
    ("próximo id", re.compile(r"pr[óo]ximo id\s*M(\d+)"),
     "1", lambda t: str(t["proximo_id"])),
    ("camadas do contrato", re.compile(r"(?<!\d)(\d+)\s+camadas\b"),
     "1", lambda t: str(t["camadas"])),
]


def arquivos(root: str) -> list[str]:
    out = []
    for rel in RAIZ_MD:
        if os.path.isfile(os.path.join(root, rel)):
            out.append(rel)
    for padrao in (DOCS, WORKFLOWS):
        for p in sorted(glob.glob(os.path.join(root, padrao), recursive=True)):
            out.append(os.path.relpath(p, root))
    return out


def confere_arquivo(root: str, rel: str, t: dict) -> list[str]:
    txt = ler(root, rel)
    if not txt:
        return []
    if MARCA_HISTORICO in txt[:400]:
        if not CONGELADO_RX.search(txt[:600]):
            return [f"{rel}: declara histórico sem carimbo — falta "
                    f"'<!-- congelado em: <commit> (AAAA-MM-DD) -->' no topo"]
        return []
    probs = []
    for linha_n, linha in enumerate(txt.splitlines(), 1):
        if MARCA_HISTORICO in linha:  # afirmação histórica declarada na própria linha
            if not CONGELADO_RX.search(linha):
                probs.append(f"{rel}:{linha_n} histórico sem carimbo na linha — falta "
                             f"'congelado em: <commit> (AAAA-MM-DD)'")
            continue
        for nome, rx, grupos, esperado_de in PADROES:
            for m in rx.finditer(linha):
                achado = m.group(0).strip()
                if "/" in grupos:
                    escrito = f"{m.group(1)}/{m.group(2)}"
                else:
                    escrito = m.group(1)
                esperado = esperado_de(t)
                if escrito == esperado:
                    continue
                probs.append(f"{rel}:{linha_n} {nome}: escrito {achado!r}, derivado {esperado!r}")
    return probs


def confere_escopo_do_ci(root: str) -> list[str]:
    """Workflow não pode carregar lista/intervalo de ids na mão: o plano é que fatia."""
    probs = []
    for p in sorted(glob.glob(os.path.join(root, WORKFLOWS))):
        rel = os.path.relpath(p, root)
        txt = ler(root, rel)
        for linha_n, linha in enumerate(txt.splitlines(), 1):
            if "--only" not in linha:
                continue
            if re.search(r'--only\s+"?M\d', linha):
                probs.append(f"{rel}:{linha_n} ids escritos na mão no --only "
                             "(o plano do catálogo é quem decide o escopo)")
    return probs


CHECKS = [
    ("CT1_numeros_derivados", lambda root, t: [p for a in arquivos(root)
                                               for p in confere_arquivo(root, a, t)]),
    ("CT2_ci_sem_lista_de_ids", lambda root, t: confere_escopo_do_ci(root)),
]


def roda(root: str) -> tuple[int, dict]:
    t, faltando = verdade(root)
    if faltando:
        return 3, {"error": "insumo ausente: " + "; ".join(faltando), "checks": []}
    checks = []
    for nome, fn in CHECKS:
        try:
            probs = fn(root, t)
        except Exception as exc:  # gate nunca explode: reprova
            probs = [f"erro ao checar: {exc}"]
        checks.append({"check": nome, "state": "ok" if not probs else "fail",
                       "detail": "; ".join(probs)})
    falhas = [c for c in checks if c["state"] == "fail"]
    return (1 if falhas else 0), {"verdict": "FALHA" if falhas else "OK",
                                  "truth": t, "checks": checks}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Nenhum número escrito à mão: tudo derivado.")
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 4
    if not os.path.isdir(a.root):
        print(f"[contagens] raiz inválida: {a.root}", file=sys.stderr)
        return 4
    rc, out = roda(os.path.abspath(a.root))
    if a.json:
        print(json.dumps(out, indent=1, ensure_ascii=False))
        return rc
    if out.get("error"):
        print(f"[contagens] {out['error']}", file=sys.stderr)
        return rc
    for c in out["checks"]:
        marca = "OK  " if c["state"] == "ok" else "FALHA"
        print(f"  {marca} {c['check']:<26} {c['detail']}")
    t = out["truth"]
    print(f"[contagens] {out['verdict']} · derivado: {t['mutantes']} mutantes · "
          f"ids até M{t['ultimo_id']} (próximo M{t['proximo_id']}) · {t['camadas']} camadas · "
          f"{t['invariantes']} invariantes · {t['coer']} coerências · {t['passos']} passos")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
