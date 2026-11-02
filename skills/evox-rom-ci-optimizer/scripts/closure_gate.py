#!/usr/bin/env python3
"""closure_gate.py — o plano de fechamento é executável, ordenado e cobre os débitos reais?

Um plano de execução só vale se: (a) todo débito derivado dos gates tem passo que o fecha;
(b) a ordem é dependência real (sem ciclo, sem passo que depende do futuro); (c) cada passo tem
gate com comando existente, exit esperado e critério observável; (d) teste em staging vem antes de
físico; (e) decisão de produto está marcada como da usuária, com pergunta objetiva.

Uso:
  closure_gate.py [--root DIR] [--plan F] [--doc F] [--json]
Exit: 0 plano executável · 1 plano quebrado · 4 entrada inválida
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

SK = "skills/evox-rom-ci-optimizer"
PLAN = f"{SK}/references/closure-plan.json"
DOC = "docs/skills/EXECUTION-PLAN.md"
PLACEHOLDER = re.compile(r"\b(TODO|TBD|FIXME|XXX)\b")
KINDS = {"input", "build", "proof", "test", "decision"}
# o que cada passo precisa ter para ser prova, não promessa
CAMPOS = ("id", "title", "kind", "needs", "resolves", "gate", "stop_condition", "rollback")


def roda(root: str, argv: list[str]) -> tuple[int, dict]:
    try:
        p = subprocess.run([sys.executable, *argv], cwd=root, capture_output=True, text=True, timeout=180)
    except (OSError, subprocess.TimeoutExpired):
        return 4, {}
    try:
        return p.returncode, json.loads(p.stdout or "{}")
    except json.JSONDecodeError:
        return p.returncode, {}


def ciclo(passos: list[dict]) -> list[str]:
    grafo = {p["id"]: [n for n in (p.get("needs") or [])] for p in passos}
    cor: dict[str, int] = {}

    def visita(n: str, pilha: list[str]) -> list[str]:
        if cor.get(n) == 1:
            return pilha[pilha.index(n):] + [n]
        if cor.get(n) == 2:
            return []
        cor[n] = 1
        for m in grafo.get(n, []):
            achado = visita(m, pilha + [n])
            if achado:
                return achado
        cor[n] = 2
        return []

    for n in grafo:
        achado = visita(n, [])
        if achado:
            return achado
    return []


def comandos_existem(root: str, cmd: str) -> list[str]:
    """Confere que cada script citado existe e que TODA flag do trecho existe no script."""
    faltas: list[str] = []
    for trecho in re.split(r"&&|\|\|", cmd):
        m = re.search(r"(?:python3|bash)\s+([\w./-]+\.(?:py|sh))", trecho)
        if not m:
            continue
        rel = m.group(1)
        caminhos = [os.path.join(root, rel), os.path.join(root, SK, rel),
                    os.path.join(root, SK, "scripts", os.path.basename(rel))]
        alvo = next((c for c in caminhos if os.path.exists(c)), None)
        if not alvo:
            faltas.append(f"script inexistente: {rel}")
            continue
        codigo = open(alvo, encoding="utf-8").read()
        for flag in re.findall(r"(?<![\w-])-{1,2}[A-Za-z][\w-]*", trecho):
            if flag not in codigo:
                faltas.append(f"{os.path.basename(rel)} não conhece {flag}")
    return faltas


def check(root: str, plan_path: str | None, doc_path: str | None) -> tuple[list[dict], int]:
    caminho = os.path.join(root, plan_path or PLAN)
    if not os.path.isfile(caminho):
        return [{"check": "K00_plano", "state": "falha", "detail": f"não existe: {caminho}"}], 1
    plano = json.load(open(caminho, encoding="utf-8"))
    passos = plano.get("steps") or []
    debitos = plano.get("debts") or []
    checks: list[dict] = []

    def add(cid: str, ok: bool, detail: str) -> None:
        checks.append({"check": cid, "state": "ok" if ok else "falha", "detail": detail})

    add("K01_estrutura", bool(plano.get("schema") and plano.get("rules") and passos and debitos),
        f"schema={plano.get('schema')} passos={len(passos)} débitos={len(debitos)}")

    ids = [p.get("id") for p in passos]
    add("K02_passos_unicos", len(ids) == len(set(ids)) and all(ids),
        f"{len(ids)} passos, {len(set(ids))} ids únicos")

    dids = [d.get("id") for d in debitos]
    add("K03_debitos_unicos", len(dids) == len(set(dids)) and all(dids),
        f"{len(dids)} débitos, {len(set(dids))} ids únicos")

    # `resolves` pode ser vazio (passo de teste que não fecha débito), mas precisa existir como lista
    faltando = [p.get("id") for p in passos
                if any(p.get(c) in (None, "", []) and c not in ("resolves", "needs") for c in CAMPOS)
                or not isinstance(p.get("resolves"), list)
                or not isinstance(p.get("needs"), list)]
    add("K04_passos_completos", not faltando,
        "todo passo tem id/título/tipo/needs/resolves/gate/parada/rollback"
        if not faltando else f"passos incompletos: {faltando}")

    ruins = [p.get("id") for p in passos if p.get("kind") not in KINDS]
    add("K05_tipos", not ruins, f"tipos válidos: {sorted(KINDS)}"
        if not ruins else f"tipo inválido em: {ruins}")

    orfaos = sorted({n for p in passos for n in (p.get("needs") or []) if n not in ids})
    add("K06_dependencias_existem", not orfaos,
        "toda dependência aponta para passo existente"
        if not orfaos else f"dependências órfãs: {orfaos}")

    volta = ciclo(passos)
    add("K07_sem_ciclo", not volta, "grafo acíclico" if not volta else f"ciclo: {' → '.join(volta)}")

    pos = {pid: i for i, pid in enumerate(ids)}
    futuro = [(p["id"], n) for p in passos for n in (p.get("needs") or [])
              if n in pos and pos[n] >= pos[p["id"]]]
    add("K08_ordem_topologica", not futuro,
        "nenhum passo depende de passo posterior"
        if not futuro else f"depende do futuro: {futuro}")

    sem_gate = [p.get("id") for p in passos
                if not (p.get("gate") or {}).get("cmd")
                or (p.get("gate") or {}).get("expect_exit") not in (0, 3)
                or not (p.get("gate") or {}).get("criterion")]
    add("K09_gate_assertivo", not sem_gate,
        "todo passo tem comando, exit esperado (0/3) e critério observável"
        if not sem_gate else f"gate incompleto em: {sem_gate}")

    # todo débito declarado é resolvido por algum passo; nenhum passo resolve débito inexistente
    resolvidos = {r for p in passos for r in (p.get("resolves") or [])}
    sem_passo = [d for d in dids if d not in resolvidos]
    fantasma = sorted(resolvidos - set(dids))
    add("K10_debito_tem_passo", not sem_passo and not fantasma,
        "todo débito tem passo e todo passo resolve débito declarado"
        if not (sem_passo or fantasma) else f"sem passo={sem_passo} · inexistente={fantasma}")

    # débitos reais derivados dos gates ⊆ declarados
    _, kg = roda(root, [f"{SK}/scripts/kernel_build_gate.py", "--root", root, "--prebuild", "--json"])
    _, sol = roda(root, [f"{SK}/scripts/root_pair_solver.py", "--root", root, "--json"])
    reais = {c["check"].split("_")[0] for c in kg.get("checks", []) if c.get("state") != "ok"}
    reais |= {f for t in (sol.get("tied") or []) for f in (t.get("failed") or [])}
    nao_previstos = sorted(r for r in reais if r.startswith(("B", "C")) and r not in dids)
    add("K11_debitos_reais_cobertos", not nao_previstos,
        "todo débito que os gates reportam está no plano"
        if not nao_previstos else f"débitos reais sem passo: {nao_previstos}")

    decisao = [d.get("id") for d in debitos if d.get("kind") == "decision"
               and (not d.get("needs_user") or not d.get("question"))]
    add("K12_decisao_da_usuario", not decisao,
        "decisão de produto marcada como da usuária, com pergunta objetiva"
        if not decisao else f"decisão sem pergunta/ownership: {decisao}")

    faltas = []
    for p in passos:
        faltas += comandos_existem(root, (p.get("gate") or {}).get("cmd", ""))
    add("K13_comandos_existem", not faltas,
        "todo comando citado existe com as flags usadas"
        if not faltas else f"comandos inválidos: {sorted(set(faltas))}")

    # staging antes de físico: passo que usa ledger canário depende de passo com guard4_verify
    staging = {p["id"] for p in passos if "guard4_verify" in ((p.get("gate") or {}).get("cmd") or "")}
    fisicos = [p for p in passos if "rollout_gate" in ((p.get("gate") or {}).get("cmd") or "")]
    needs = {p["id"]: list(p.get("needs") or []) for p in passos}

    def ancestrais(pid: str, vistos: set[str] | None = None) -> set[str]:
        vistos = vistos or set()
        for n in needs.get(pid, []):
            if n not in vistos:
                vistos.add(n)
                ancestrais(n, vistos)
        return vistos

    sem_staging = [p["id"] for p in fisicos if not (ancestrais(p["id"]) & staging)]
    add("K14_staging_antes_do_fisico", bool(staging) and not sem_staging,
        "todo passo físico depende de staging com backup verificado"
        if staging and not sem_staging else f"físico sem staging: {sem_staging or 'nenhum staging'}")

    sujeira = sorted({m.group(0) for m in PLACEHOLDER.finditer(json.dumps(plano, ensure_ascii=False))})
    add("K15_sem_placeholder", not sujeira, "plano sem TODO/TBD/FIXME"
        if not sujeira else f"placeholders: {sujeira}")

    doc = doc_path or os.path.join(root, DOC)
    if not os.path.isfile(doc):
        add("K16_documentado", False, f"documento ausente: {doc}")
    else:
        txt = open(doc, encoding="utf-8").read()
        nao_doc = [i for i in ids if not re.search(rf"\b{re.escape(i)}\b", txt)]
        add("K16_documentado", not nao_doc,
            f"os {len(ids)} passos estão no documento" if not nao_doc
            else f"passos fora do documento: {nao_doc}")

    return checks, 0 if all(c["state"] == "ok" for c in checks) else 1


def main(argv: list[str]) -> int:
    root, plan, doc, como_json, i = ".", None, None, False, 1
    while i < len(argv):
        a = argv[i]
        if a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if a == "--root" and i + 1 < len(argv):
            root, i = argv[i + 1], i + 2
        elif a == "--plan" and i + 1 < len(argv):
            plan, i = argv[i + 1], i + 2
        elif a == "--doc" and i + 1 < len(argv):
            doc, i = argv[i + 1], i + 2
        elif a == "--json":
            como_json, i = True, i + 1
        else:
            print(f"[closure] argumento desconhecido: {a}", file=sys.stderr)
            return 4
    if not os.path.isdir(root):
        print(f"[closure] raiz inexistente: {root}", file=sys.stderr)
        return 4

    checks, rc = check(root, plan, doc)
    if como_json:
        print(json.dumps({"schema": "evox-closure-gate/1", "root": root,
                          "checks": checks, "exit": rc}, ensure_ascii=False, indent=1))
        return rc
    ruins = [c for c in checks if c["state"] != "ok"]
    print(f"[closure] {'EXECUTÁVEL' if not ruins else 'QUEBRADO'} ({len(checks) - len(ruins)}/{len(checks)})")
    for c in checks:
        print(f"  {'OK  ' if c['state'] == 'ok' else 'FALHA'} {c['check']}: {c['detail']}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
