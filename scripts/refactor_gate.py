#!/usr/bin/env python3
"""refactor_gate.py — a refatoração não pode ficar pela metade.

O contrato (`references/install-stack.json`) é a verdade. Este gate cobra que TODO consumidor
— módulos, pilha de ocultação, abertura de sessão, garantia, plano de fechamento, docs de fila e
CI — fique coerente com ele. Refatorar o contrato e deixar consumidor velho passa a ser **falha**,
não esquecimento.

Cada checagem é falsificável: existe um teste que quebra o insumo e exige a reprovação.

Uso:
  refactor_gate.py [--root DIR] [--json]
Exit: 0 tudo coerente · 1 consumidor divergente · 3 contrato ausente (PENDENTE) · 4 uso
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

SK = "skills/evox-rom-ci-optimizer"
STACK = f"{SK}/references/install-stack.json"
MODREQ = f"{SK}/references/module-requirements.json"
HIDING = f"{SK}/references/hiding-stack.json"
SESSION = f"{SK}/scripts/session_open.py"
GUARANTEE = f"{SK}/scripts/success_guarantee.py"
CLOSURE_PLAN = f"{SK}/references/closure-plan.json"
LEDGER = f"{SK}/scripts/debt_ledger.py"
QUEUE_DOC = "docs/skills/APPROVED-INSTALL-SEQUENCE.md"
PROOF_CI = ".github/workflows/proof.yml"
AGENTS = "AGENTS.md"

CAMPOS_MODULO = ("compliance_base", "zygisk_base", "stack", "requires", "hiding_base", "name")
TOKENS_APATCH = ("kptools",)


def ler(root: str, rel: str) -> str:
    try:
        return open(os.path.join(root, rel), encoding="utf-8").read()
    except OSError:
        return ""


def json_ou(root: str, rel: str, vazio):
    try:
        return json.loads(ler(root, rel) or "null") or vazio
    except json.JSONDecodeError:
        return vazio


def ids_vetados(stack: dict) -> set[str]:
    return {f.get("id") for f in stack.get("forbidden") or [] if f.get("id")}


def _texto(v) -> str:
    if isinstance(v, str):
        return v
    if isinstance(v, list):
        return " ".join(_texto(x) for x in v)
    if isinstance(v, dict):
        return " ".join(_texto(x) for x in v.values())
    return str(v)


# ------------------------------------------------------------------ checagens

def g1_vetados_em_consumidores(root, stack, ctx):
    """Nenhum consumidor pode DECLARAR como ativo um item vetado."""
    vetados = ids_vetados(stack)
    p = []
    mods = json_ou(root, MODREQ, {}).get("modules") or []
    for m in mods:
        blob = _texto({k: m.get(k) for k in CAMPOS_MODULO if k in m}).lower()
        for v in vetados:
            if v.replace("-", " ") in blob or v in blob:
                p.append(f"module-requirements {m.get('id')}: declara vetado {v!r}")
    hiding = json_ou(root, HIDING, {}).get("layers") or []
    for l in hiding:
        for campo in ("id", "requires"):
            blob = _texto(l.get(campo)).lower()
            for v in vetados:
                if v in blob:
                    p.append(f"hiding-stack {l.get('id')}: campo {campo} usa vetado {v!r}")
    src = ler(root, GUARANTEE)
    for v in vetados:
        if f'"{v}"' in src.lower() or (v == "tricky-store" and "Tricky Store" in src):
            p.append(f"success_guarantee.py: exige vetado {v!r} para dar R3")
    sis = ler(root, SESSION)
    for t in TOKENS_APATCH:
        if f'"{t}"' in sis:
            p.append(f"session_open.py: instala {t!r} (APatch) sem decisão que o adote")
    return p


def g2_integridade_provada(root, stack, ctx):
    """Todo layer de integridade obrigatório tem de aparecer no compliance_base dos módulos."""
    mods = json_ou(root, MODREQ, {}).get("modules") or []
    base = " ".join(_texto(m.get("compliance_base") or []) for m in mods
                    if m.get("id") in ("M07", "M08"))
    p = []
    for l in stack.get("layers") or []:
        if l.get("kind") != "integrity" or l.get("status") != "required":
            continue
        tok = l.get("proof_token")
        if not tok:
            p.append(f"{l.get('id')}: layer de integridade sem proof_token")
        elif tok not in base:
            p.append(f"{l.get('id')}: {tok!r} não aparece em compliance_base de M07/M08")
    return p


def g3_sessao_igual_contrato(root, stack, ctx):
    """O template de abertura de sessão tem de emitir exatamente as camadas do contrato."""
    p = []
    caminho = os.path.join(root, SESSION)
    if not os.path.exists(caminho):
        return [f"ausente: {SESSION}"]
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "dec.json")
        r = subprocess.run([sys.executable, caminho, "template", "--out", out],
                           cwd=root, capture_output=True, text=True, timeout=60)
        if r.returncode != 0 or not os.path.exists(out):
            return [f"session_open template falhou (exit {r.returncode})"]
        mods = json.load(open(out, encoding="utf-8")).get("modules") or []
    esperado = [l.get("id") for l in stack.get("layers") or [] if l.get("status") != "not_installed"]
    obtido = [m.get("id") for m in mods]
    if obtido != esperado:
        sobra = [x for x in obtido if x not in esperado]
        falta = [x for x in esperado if x not in obtido]
        p.append(f"template diverge do contrato (sobra={sobra}, falta={falta})")
    return p


def g4_ocultacao_coerente(root, stack, ctx):
    """A pilha de ocultação não pode depender de camada vetada nem contradizer a decisão."""
    vetados = ids_vetados(stack)
    decisao = ((stack.get("decisions") or {}).get("hiding") or {}).get("value") or ""
    camadas = json_ou(root, HIDING, {}).get("layers") or []
    p = []
    for l in camadas:
        for r in l.get("requires") or []:
            if r in vetados:
                p.append(f"hiding-stack {l.get('id')}: requires vetado {r!r}")
            elif r not in {x.get("id") for x in camadas}:
                p.append(f"hiding-stack {l.get('id')}: requires inexistente {r!r}")
    if "susfs" in decisao and not any("susfs" in (l.get("needs") or []) for l in camadas):
        p.append("decisão exige SUSFS, mas nenhuma camada declara needs=susfs")
    return p


def g5_plano_cobre_contrato(root, stack, ctx):
    """O plano de fechamento tem de conhecer o gate do contrato."""
    plan = json_ou(root, CLOSURE_PLAN, {})
    cmds = " ".join(_texto((s.get("gate") or {}).get("cmd")) for s in plan.get("steps") or [])
    if "stack_gate.py" not in cmds:
        return ["closure-plan não tem passo cujo gate rode stack_gate.py (o contrato ficaria fora do plano)"]
    return []


def g6_fila_supersedida(root, stack, ctx):
    head = ler(root, QUEUE_DOC)[:600]
    if "SUPERSEDIDO" not in head:
        return [f"{QUEUE_DOC}: sem banner SUPERSEDIDO no topo (duas filas concorrentes)"]
    return []


def g7_ci_de_prova(root, stack, ctx):
    txt = ler(root, PROOF_CI)
    if not txt:
        return [f"{PROOF_CI}: ausente — a prova só roda na máquina de quem lembrou"]
    p = []
    for alvo in ("make -s prove", "mutation_check.py", "--only"):
        if alvo not in txt:
            p.append(f"{PROOF_CI}: não executa {alvo!r}")
    return p


def g8_merge_com_aprovacao(root, stack, ctx):
    txt = ler(root, AGENTS).lower()
    if not ("merge" in txt and ("aprovação explícita" in txt or "aprovacao explicita" in txt)):
        return ["AGENTS.md: falta a regra 'merge só com aprovação explícita da usuária'"]
    return []


def g9_ledger_duravel(root, stack, ctx):
    src = ler(root, LEDGER)
    if "references/decisions.json" not in src:
        return ["debt_ledger.py: ainda aponta decisão para caminho não versionado"]
    return []


def rc10_mutacao_completa(root, stack, ctx):
    """Por padrão TUDO é validado: catálogo fechado, todo script com mutante e teste existente."""
    rel_cat = f"{SK}/references/mutation-catalog.json"
    try:
        cat = json.load(open(os.path.join(root, rel_cat), encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"{rel_cat}: ausente ou inválido ({exc})"]
    p = []
    ids = [m.get("id") or "" for m in cat.get("mutants") or []]
    dif = sorted({i for i in ids if ids.count(i) > 1})
    if dif:
        p.append("ids duplicados: " + ", ".join(dif[:5]))
    fora = [i for i in ids if not re.match(r"^M\d{2,4}$", i)]
    if fora:
        p.append("ids fora do padrão M###: " + ", ".join(fora[:5]))
    todos = ids + list(cat.get("retired") or [])
    nums = sorted({int(i[1:]) for i in todos if re.match(r"^M\d+$", i)})
    lacunas = [n for n in range(1, (nums[-1] if nums else 0) + 1) if n not in nums]
    if lacunas:
        p.append("numeração com lacuna (buraco não registrado): "
                 + ", ".join(f"M{n}" for n in lacunas[:5]))
    cobertos = {m.get("file") for m in cat.get("mutants") or []}
    for d in ("scripts", f"{SK}/scripts"):
        for f in sorted(glob.glob(os.path.join(root, d, "*"))):
            if not os.path.isfile(f) or f.endswith((".md", ".json", ".yml", ".yaml")):
                continue
            rel = os.path.relpath(f, root)
            if rel not in cobertos:
                p.append(f"{rel}: nenhum mutante — o script nunca é validado por mutação")
    for m in cat.get("mutants") or []:
        t = m.get("test") or ""
        if not t or not os.path.isfile(os.path.join(root, t)):
            p.append(f"{m.get('id')}: teste ausente ({t or 'sem test'})")
    return p


CHECKS = [
    ("RC1_vetados_em_consumidores", g1_vetados_em_consumidores),
    ("RC2_integridade_provada", g2_integridade_provada),
    ("RC3_sessao_igual_contrato", g3_sessao_igual_contrato),
    ("RC4_ocultacao_coerente", g4_ocultacao_coerente),
    ("RC5_plano_cobre_contrato", g5_plano_cobre_contrato),
    ("RC6_fila_supersedida", g6_fila_supersedida),
    ("RC7_ci_de_prova", g7_ci_de_prova),
    ("RC8_merge_com_aprovacao", g8_merge_com_aprovacao),
    ("RC9_ledger_duravel", g9_ledger_duravel),
    ("RC10_mutacao_completa", rc10_mutacao_completa),
]


def roda(root: str) -> tuple[int, dict]:
    if not os.path.exists(os.path.join(root, STACK)):
        return 3, {"verdict": "PENDENTE", "checks": [],
                   "missing": [STACK], "error": f"contrato ausente: {STACK}"}
    try:
        stack = json.loads(ler(root, STACK))
    except json.JSONDecodeError as exc:
        return 4, {"error": f"contrato inválido: {exc}", "checks": []}
    checks = []
    for nome, fn in CHECKS:
        try:
            probs = fn(root, stack, {})
        except Exception as exc:  # gate nunca explode: reprova
            probs = [f"erro ao checar: {exc}"]
        checks.append({"check": nome, "state": "ok" if not probs else "fail",
                       "detail": "; ".join(probs)})
    falhas = [c for c in checks if c["state"] == "fail"]
    return (1 if falhas else 0), {"verdict": "FALHA" if falhas else "OK", "checks": checks}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Coerência contrato × consumidores (refatoração completa).")
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 4
    if not os.path.isdir(a.root):
        print(f"[refactor] raiz inválida: {a.root}", file=sys.stderr)
        return 4
    rc, out = roda(a.root)
    if a.json:
        print(json.dumps(out, indent=1, ensure_ascii=False))
        return rc
    if out.get("error"):
        print(f"[refactor] {out['error']}", file=sys.stderr)
        return rc
    for c in out["checks"]:
        marca = "OK  " if c["state"] == "ok" else "FALHA"
        print(f"  {marca} {c['check']:<28} {c['detail']}")
    ok = sum(1 for c in out["checks"] if c["state"] == "ok")
    print(f"[refactor] {out['verdict']} · {ok}/{len(out['checks'])} coerências")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
