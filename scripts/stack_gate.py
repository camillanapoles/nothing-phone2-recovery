#!/usr/bin/env python3
"""stack_gate.py — o combo e a sequência são um CONTRATO de dados, não uma lista na memória.

`references/install-stack.json` é a fonte única: camadas com pin verificável, fases com passo a
passo e, em cada passo, um critério de PASS falseável. Este gate cobra os invariantes declarados
no próprio arquivo e confere os pins ESTRANGEIROS contra os canônicos:

  kernel-build-plan.json      → o commit do kernel tem de ser o mesmo pin
  rom-artifacts.json          → a build tem de ser a mesma do manifesto
  droidspaces-requirements.json + kernel/fragments/*.config + kernel-build-plan.json
                              → todo `must_deliver` da camada de kernel tem de existir em algum
                                canônico (config prometida e não provada reprova)

Nada aqui nomeia motor, kernel ou flavor: tudo vem do JSON. Trocar o dado muda o resultado;
quebrar o dado reprova.

Uso:
  stack_gate.py [--root DIR] [--json]
Exit: 0 contrato íntegro · 1 invariante violado · 3 insumo canônico ausente (PENDENTE) · 4 uso
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

SK = "skills/evox-rom-ci-optimizer"
STACK = f"{SK}/references/install-stack.json"
PLAN = f"{SK}/references/kernel-build-plan.json"
ROM = f"{SK}/references/rom-artifacts.json"
REQ = f"{SK}/references/droidspaces-requirements.json"
FRAG = "kernel/fragments/evox_pong_pack.config"
DECISIONS = f"{SK}/references/decisions.json"

PIN_RE = re.compile(r"^(commit:[0-9a-f]{7,40}|tag:[^\s]+|build:[^\s]+|sha256:[0-9a-f]{64}|pkg:[^\s]+)$")
ACTIVE = ("required", "conditional", "optional")


def carrega(root: str, rel: str, faltando: list[str]):
    p = os.path.join(root, rel)
    try:
        with open(p, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        faltando.append(rel)
        return ""


def camadas_ativas(d: dict) -> list[dict]:
    return [l for l in d.get("layers") or [] if l.get("status") in ACTIVE]


def fase_de_cada_camada(d: dict) -> dict[str, int]:
    """Menor índice de fase que executa a camada."""
    pos: dict[str, int] = {}
    for i, ph in enumerate(d.get("phases") or []):
        for st in ph.get("steps") or []:
            lid = st.get("layer")
            if lid and (lid not in pos or i < pos[lid]):
                pos[lid] = i
    return pos


# ----------------------------------------------------------------------------- invariantes

def i_schema(d, ctx):
    if d.get("schema") != "evox-install-stack/1":
        return [f"schema inesperado: {d.get('schema')!r}"]
    return []


def i_unique_ids(d, ctx):
    p = []
    ids = [l.get("id") for l in d.get("layers") or []]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        p.append(f"ids de camada repetidos: {sorted(dup)}")
    fases = [ph.get("id") for ph in d.get("phases") or []]
    dupf = {i for i in fases if fases.count(i) > 1}
    if dupf:
        p.append(f"ids de fase repetidos: {sorted(dupf)}")
    passos = [st.get("id") for ph in d.get("phases") or [] for st in ph.get("steps") or []]
    dups = {i for i in passos if passos.count(i) > 1}
    if dups:
        p.append(f"ids de passo repetidos: {sorted(dups)}")
    if any(not i for i in ids + passos):
        p.append("id vazio em camada ou passo")
    return p


def i_pins_format(d, ctx):
    return [f"{l.get('id')}: pin fora do formato ({l.get('pin')!r})"
            for l in d.get("layers") or [] if not PIN_RE.match(str(l.get("pin") or ""))]


def i_steps_have_pass(d, ctx):
    p = []
    conhecidas = {l.get("id") for l in d.get("layers") or []}
    for ph in d.get("phases") or []:
        if not ph.get("steps"):
            p.append(f"{ph.get('id')}: fase sem passo")
        for st in ph.get("steps") or []:
            if not str(st.get("pass") or "").strip():
                p.append(f"passo {st.get('id')}: sem critério de PASS (prova maquiada)")
            if st.get("layer") not in conhecidas:
                p.append(f"passo {st.get('id')}: camada inexistente {st.get('layer')!r}")
    return p


def i_phases_contiguous(d, ctx):
    ids = [ph.get("id") for ph in d.get("phases") or []]
    esperado = [f"F{i}" for i in range(len(ids))]
    if ids != esperado:
        return [f"fases fora de sequência/contiguidade: {ids} (esperado {esperado})"]
    return []


def i_requires_exist(d, ctx):
    p = []
    ids = {l.get("id") for l in d.get("layers") or []}
    for l in d.get("layers") or []:
        for r in l.get("requires") or []:
            if r not in ids:
                p.append(f"{l.get('id')}: requires camada inexistente {r!r}")
            if r == l.get("id"):
                p.append(f"{l.get('id')}: requires a si mesma")
    return p


def i_requires_dag(d, ctx):
    grafo = {l.get("id"): list(l.get("requires") or []) for l in d.get("layers") or []}
    estado: dict[str, int] = {}

    def visita(n, pilha):
        if estado.get(n) == 1:
            return [f"ciclo em requires: {' -> '.join(pilha + [n])}"]
        if estado.get(n) == 2 or n not in grafo:
            return []
        estado[n] = 1
        out = []
        for m in grafo[n]:
            out += visita(m, pilha + [n])
        estado[n] = 2
        return out

    p = []
    for n in grafo:
        p += visita(n, [])
    return p


def i_phase_order(d, ctx):
    fase = fase_de_cada_camada(d)
    p = []
    for l in camadas_ativas(d):
        lid = l.get("id")
        if lid not in fase:
            p.append(f"{lid}: camada ativa sem passo em nenhuma fase")
            continue
        for r in l.get("requires") or []:
            if r in fase and fase[r] > fase[lid]:
                p.append(f"{lid} (F{fase[lid]}) exige {r} (F{fase[r]}): dependência depois do dependente")
    return p


def i_conflicts_symmetric(d, ctx):
    mapa = {l.get("id"): set(l.get("conflicts") or []) for l in d.get("layers") or []}
    p = []
    for a, alvos in mapa.items():
        for b in alvos:
            if b in mapa and a not in mapa[b]:
                p.append(f"conflito assimétrico: {a} declara {b}, mas {b} não declara {a}")
    return p


def i_no_active_conflict(d, ctx):
    ativos = {l.get("id") for l in camadas_ativas(d)}
    p = []
    for l in camadas_ativas(d):
        for c in l.get("conflicts") or []:
            if c in ativos:
                p.append(f"{l.get('id')} e {c} ativos ao mesmo tempo (conflito declarado)")
    return p


def i_forbidden_absent(d, ctx):
    vetados = {f.get("id") for f in d.get("forbidden") or []}
    p = [f"camada vetada presente na pilha: {l.get('id')}"
         for l in d.get("layers") or [] if l.get("id") in vetados]
    if any(not f.get("why") for f in d.get("forbidden") or []):
        p.append("vetado sem justificativa (`why` vazio)")
    return p


def i_decisions_complete(d, ctx):
    dec = d.get("decisions") or {}
    p = []
    if (dec.get("flavor") or {}).get("value") not in ("vanilla", "gapps"):
        p.append("decisions.flavor ausente ou fora de {vanilla,gapps}")
    if not (dec.get("gapps") or {}).get("value"):
        p.append("decisions.gapps sem valor")
    if not (dec.get("integrity_engine") or {}).get("value"):
        p.append("decisions.integrity_engine sem valor")
    pin = str((dec.get("screen_search") or {}).get("pin") or "")
    if not re.fullmatch(r"commit:[0-9a-f]{7,40}", pin):
        p.append(f"decisions.screen_search.pin não é commit pinado ({pin!r})")
    if not (dec.get("hiding") or {}).get("value"):
        p.append("decisions.hiding sem valor")
    for chave in ("flavor", "gapps", "integrity_engine", "screen_search", "hiding"):
        if not (dec.get(chave) or {}).get("decided_by"):
            p.append(f"decisions.{chave} sem decided_by")
    return p


def i_foreign_pin_kernel(d, ctx):
    plan = json.loads(ctx["plan"] or "{}")
    esperado = (plan.get("source") or {}).get("pin")
    if not esperado:
        return []
    camadas = [l for l in d.get("layers") or [] if l.get("kind") == "kernel"]
    p = []
    for l in camadas:
        if l.get("pin") != f"commit:{esperado}":
            p.append(f"{l.get('id')}: pin {l.get('pin')} != kernel-build-plan ({esperado})")
    if not camadas:
        p.append("nenhuma camada de kind=kernel declarada")
    return p


def i_foreign_pin_rom(d, ctx):
    rom = json.loads(ctx["rom"] or "{}")
    build, versao = rom.get("build"), rom.get("version")
    if not (build and versao):
        return []
    esperado = "build:EvolutionX-16.0-%s-Pong-%s" % (build.replace("-", ""), versao)
    camadas = [l for l in d.get("layers") or [] if l.get("id") == "evox-vanilla"]
    if not camadas:
        return ["camada evox-vanilla ausente"]
    return [f"evox-vanilla: pin {l.get('pin')} != rom-artifacts ({esperado})"
            for l in camadas if l.get("pin") != esperado]


def i_decision_sync(d, ctx):
    """O registro de decisão (versionado) não pode divergir do contrato."""
    try:
        dec = json.loads(ctx["dec"] or "{}")
    except json.JSONDecodeError:
        return ["decisions.json inválido"]
    if not dec:
        return []
    p = []
    dec_ = d.get("decisions") or {}
    if (dec.get("build") or {}).get("flavor") != (dec_.get("flavor") or {}).get("value"):
        p.append(f"flavor no registro ({dec.get('build', {}).get('flavor')}) != contrato "
                 f"({(dec_.get('flavor') or {}).get('value')})")
    camadas = {l.get("id"): l for l in d.get("layers") or []}
    ativos = [i for i, l in camadas.items() if l.get("status") != "not_installed"]
    mods = dec.get("modules") or []
    if len(mods) != len(ativos):
        p.append(f"registro tem {len(mods)} módulos, contrato tem {len(ativos)} camadas ativas")
    for m in mods:
        l = camadas.get(m.get("id"))
        if l is None:
            p.append(f"módulo {m.get('id')!r} não existe no contrato")
        elif m.get("pin") != l.get("pin"):
            p.append(f"{m.get('id')}: pin do registro ({m.get('pin')}) != contrato ({l.get('pin')})")
    kpin = (dec.get("kernel") or {}).get("pin")
    klayer = [l for l in d.get("layers") or [] if l.get("kind") == "kernel"]
    if kpin and klayer and klayer[0].get("pin") != f"commit:{kpin}":
        p.append(f"pin do kernel no registro ({kpin}) != contrato ({klayer[0].get('pin')})")
    return p


def i_contract_configs(d, ctx):
    fonte = "\n".join([ctx["req"] or "", ctx["frag"] or "", ctx["plan"] or ""])
    p = []
    for l in d.get("layers") or []:
        for tok in l.get("must_deliver") or []:
            if tok not in fonte:
                p.append(f"{l.get('id')}: promete {tok}, mas nenhum canônico prova")
    return p


INVARIANTES = {
    "schema": i_schema,
    "unique_ids": i_unique_ids,
    "pins_format": i_pins_format,
    "steps_have_pass": i_steps_have_pass,
    "phases_contiguous": i_phases_contiguous,
    "requires_exist": i_requires_exist,
    "requires_dag": i_requires_dag,
    "phase_order": i_phase_order,
    "conflicts_symmetric": i_conflicts_symmetric,
    "no_active_conflict": i_no_active_conflict,
    "forbidden_absent": i_forbidden_absent,
    "decisions_complete": i_decisions_complete,
    "foreign_pin_kernel": i_foreign_pin_kernel,
    "foreign_pin_rom": i_foreign_pin_rom,
    "contract_configs": i_contract_configs,
    "decision_sync": i_decision_sync,
}

ORDEM = ["schema", "unique_ids", "pins_format", "steps_have_pass", "phases_contiguous",
         "requires_exist", "requires_dag", "phase_order", "conflicts_symmetric",
         "no_active_conflict", "forbidden_absent", "decisions_complete",
         "foreign_pin_kernel", "foreign_pin_rom", "contract_configs", "decision_sync"]


def roda(root: str) -> tuple[int, dict]:
    faltando: list[str] = []
    bruto = carrega(root, STACK, faltando)
    if not bruto:
        return 4, {"error": f"contrato ausente: {STACK}", "checks": []}
    try:
        d = json.loads(bruto)
    except json.JSONDecodeError as exc:
        return 4, {"error": f"contrato inválido: {exc}", "checks": []}

    ctx = {
        "plan": carrega(root, PLAN, faltando),
        "rom": carrega(root, ROM, faltando),
        "req": carrega(root, REQ, faltando),
        "frag": carrega(root, FRAG, faltando),
        "dec": carrega(root, DECISIONS, faltando),
    }
    checks = []
    for nome in d.get("invariantes_ativos") or d.get("invariants") or ORDEM:
        fn = INVARIANTES.get(nome)
        if fn is None:
            checks.append({"check": nome, "state": "fail", "detail": "invariante desconhecido"})
            continue
        if nome.startswith("foreign_") or nome in ("contract_configs", "decision_sync"):
            if faltando:
                checks.append({"check": nome, "state": "pending",
                               "detail": f"insumo ausente: {sorted(set(faltando))}"})
                continue
        probs = fn(d, ctx)
        checks.append({"check": nome, "state": "ok" if not probs else "fail",
                       "detail": "; ".join(probs)})

    if faltando and any(c["state"] == "pending" for c in checks):
        return 3, {"verdict": "PENDENTE", "checks": checks, "missing": sorted(set(faltando))}
    falhas = [c for c in checks if c["state"] == "fail"]
    return (1 if falhas else 0), {
        "verdict": "FALHA" if falhas else "OK",
        "checks": checks,
        "layers": len(d.get("layers") or []),
        "phases": len(d.get("phases") or []),
        "steps": sum(len(ph.get("steps") or []) for ph in d.get("phases") or []),
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Contrato do combo e da sequência de instalação.")
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if not os.path.isdir(a.root):
        print(f"[stack] raiz inválida: {a.root}", file=sys.stderr)
        return 4
    rc, out = roda(a.root)
    if a.json:
        print(json.dumps(out, indent=1, ensure_ascii=False))
        return rc
    if out.get("error"):
        print(f"[stack] {out['error']}", file=sys.stderr)
        return rc
    for c in out["checks"]:
        marca = {"ok": "OK  ", "fail": "FALHA", "pending": "PEND"}[c["state"]]
        print(f"  {marca} {c['check']:<20} {c['detail']}")
    ok = sum(1 for c in out["checks"] if c["state"] == "ok")
    total = len(out["checks"])
    print(f"[stack] {out['verdict']} · {ok}/{total} invariantes · "
          f"{out.get('layers', 0)} camadas · {out.get('phases', 0)} fases · {out.get('steps', 0)} passos")
    if out.get("missing"):
        print(f"[stack] insumo ausente: {', '.join(out['missing'])}", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
