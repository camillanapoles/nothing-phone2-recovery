#!/usr/bin/env python3
"""debt_ledger.py — quais débitos existem AGORA, o que cada um trava e qual passo o fecha.

O ledger não é escrito à mão: ele é **derivado** dos gates que já existem
(`kernel_build_gate --prebuild`, `root_pair_solver`, `continuity_gate`, `session_open check`,
ledger canário de rollout). Assim, débito que fecha some do ledger e débito novo aparece sem
ninguém editar uma lista — e débito que não tem passo de fechamento no plano vira FALHA.

Uso:
  debt_ledger.py [--root DIR] [--plan F] [--json] [--markdown] [--open-only]
Exit: 0 nenhum débito aberto · 3 há débito aberto · 1 débito sem passo/plano inválido · 4 entrada
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

SK = "skills/evox-rom-ci-optimizer"
PLAN = f"{SK}/references/closure-plan.json"


def roda(root: str, argv: list[str], timeout: int = 120) -> tuple[int, dict]:
    try:
        p = subprocess.run([sys.executable, *argv], cwd=root, capture_output=True,
                           text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return 4, {}
    try:
        return p.returncode, json.loads(p.stdout or "{}")
    except json.JSONDecodeError:
        return p.returncode, {}


def planejado(root: str, plan: str | None) -> dict:
    caminho = os.path.join(root, plan or PLAN)
    with open(caminho, encoding="utf-8") as fh:
        return json.load(fh)


def derivar(root: str) -> tuple[dict[str, dict], list[str]]:
    """Roda os gates e devolve {debito: {estado, evidencia}} + problemas estruturais."""
    debitos: dict[str, dict] = {}
    problemas: list[str] = []
    py = sys.executable

    # 1. pré-build do kernel: B01/B03/B05/B06...
    rc, out = roda(root, [f"{SK}/scripts/kernel_build_gate.py", "--root", root, "--prebuild", "--json"])
    if not out.get("checks"):
        problemas.append("kernel_build_gate não devolveu checks (plano ausente?)")
    for c in out.get("checks", []):
        cid = c.get("check", "").split("_")[0]
        if c.get("state") != "ok" and cid.startswith("B"):
            debitos[cid] = {"estado": "aberto", "origem": "kernel_build_gate --prebuild",
                            "evidencia": c.get("detail", "")}

    # 2. condições do pack: só as que impedem o par de vencer (empate/pendente)
    rc, sol = roda(root, [f"{SK}/scripts/root_pair_solver.py", "--root", root, "--json"])
    if "verdict" not in sol:
        problemas.append("root_pair_solver não devolveu veredito")
    for t in sol.get("tied") or []:
        for cond in t.get("failed") or []:
            debitos.setdefault(cond, {"estado": "aberto", "origem": "root_pair_solver",
                                      "evidencia": f"{t.get('engine')} × {t.get('kernel')} — falta {cond}"})
    if sol.get("verdict") == "PAR_GARANTIDO" and not sol.get("tied"):
        debitos.pop("C06", None)

    # 3. instrução de continuidade
    rc, cont = roda(root, [f"{SK}/scripts/continuity_gate.py", "--root", root, "--json"])
    if rc == 1:
        ruins = [c["check"] for c in cont.get("checks", []) if c.get("state") != "ok"]
        debitos["CONTINUIDADE"] = {"estado": "aberto", "origem": "continuity_gate",
                                   "evidencia": f"cláusulas quebradas: {ruins}"}

    # 4. decisão da usuária (P1 e afins)
    rc, dec = roda(root, [f"{SK}/scripts/session_open.py", "check", "--json"])
    if rc != 0:
        falta = (dec.get("pending") or dec.get("missing") or dec.get("gaps")
                 or ["decisão ausente (nada gravado em workspace/decision.json)"])
        debitos["P1"] = {"estado": "aberto", "origem": "session_open.py check",
                         "evidencia": f"pendente: {falta if isinstance(falta, str) else ', '.join(map(str, falta))}"}

    # 5. rollout: existe algum módulo com PASS?
    rollout = os.path.join(root, "workspace/rollout.json")
    passou = []
    if os.path.exists(rollout):
        try:
            d = json.load(open(rollout, encoding="utf-8"))
            passou = [m for m, v in (d.get("modules") or {}).items()
                      if str((v or {}).get("state", "")).upper() == "PASS"]
        except Exception:
            problemas.append("workspace/rollout.json ilegível")
    if not passou:
        debitos["M-ROLLOUT"] = {"estado": "aberto", "origem": "ledger canário de rollout",
                                "evidencia": "nenhum módulo M01–M15 com PASS"}

    return debitos, problemas


def montar(root: str, plan_path: str | None) -> tuple[list[dict], list[str]]:
    plano = planejado(root, plan_path)
    abertos, problemas = derivar(root)
    passos = plano.get("steps") or []
    declarados = {d.get("id"): d for d in (plano.get("debts") or [])}
    problemas += [f"débito derivado sem declaração no plano: {i}"
                  for i in sorted(abertos) if i not in declarados]
    linhas: list[dict] = []
    for did, meta in sorted(declarados.items()):
        fecha = [s for s in passos if did in (s.get("resolves") or [])]
        if not fecha:
            problemas.append(f"débito sem passo que fecha: {did}")
        estado = abertos.get(did, {}).get("estado", "fechado")
        linhas.append({
            "id": did,
            "kind": meta.get("kind"),
            "estado": estado,
            "origem": abertos.get(did, {}).get("origem", meta.get("origem", "")),
            "impacto": meta.get("impacto", ""),
            "evidencia": abertos.get(did, {}).get("evidencia", ""),
            "fecha_com": [s.get("id") for s in fecha],
            "comando": (fecha[0].get("gate") or {}).get("cmd") if fecha else None,
            "criterio": (fecha[0].get("gate") or {}).get("criterion") if fecha else None,
            "pergunta": meta.get("question"),
        })
    return linhas, problemas


def render(linhas: list[dict], problemas: list[str], aberto_so: bool) -> str:
    out = []
    visiveis = [l for l in linhas if l["estado"] == "aberto"] if aberto_so else linhas
    n_ab = len([l for l in linhas if l["estado"] == "aberto"])
    out.append(f"[debitos] {n_ab} aberto(s) de {len(linhas)} · plano de fechamento "
               f"{'completo' if not problemas else 'INCOMPLETO'}")
    for l in visiveis:
        marca = "ABERTO" if l["estado"] == "aberto" else "FECHADO"
        out.append(f"  {marca:7} {l['id']:11} [{l['kind']}] trava: {l['impacto']}")
        out.append(f"          fecha em: {', '.join(l['fecha_com']) or '—'} · evidência atual: {l['evidencia'] or '—'}")
        if l.get("pergunta"):
            out.append(f"          pergunta: {l['pergunta']}")
    for p in problemas:
        out.append(f"  FALHA   {p}")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    root, plan, como_json, md, aberto_so, i = ".", None, False, False, False, 1
    while i < len(argv):
        a = argv[i]
        if a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if a == "--root" and i + 1 < len(argv):
            root, i = argv[i + 1], i + 2
        elif a == "--plan" and i + 1 < len(argv):
            plan, i = argv[i + 1], i + 2
        elif a == "--json":
            como_json, i = True, i + 1
        elif a == "--markdown":
            md, i = True, i + 1
        elif a == "--open-only":
            aberto_so, i = True, i + 1
        else:
            print(f"[debitos] argumento desconhecido: {a}", file=sys.stderr)
            return 4
    if not os.path.isdir(root):
        print(f"[debitos] raiz inexistente: {root}", file=sys.stderr)
        return 4
    try:
        linhas, problemas = montar(root, plan)
    except FileNotFoundError as exc:
        print(f"[debitos] plano ausente: {exc}", file=sys.stderr)
        return 4

    n_abertos = len([l for l in linhas if l["estado"] == "aberto"])
    rc = 1 if problemas else (3 if n_abertos else 0)
    if como_json:
        print(json.dumps({"schema": "evox-debt-ledger/1", "root": root, "debts": linhas,
                          "open": n_abertos, "problems": problemas, "exit": rc},
                         ensure_ascii=False, indent=1))
    elif md:
        print("| débito | natureza | estado | trava | fecha em | comando |")
        print("|---|---|---|---|---|---|")
        for l in linhas:
            print(f"| `{l['id']}` | {l['kind']} | {l['estado']} | {l['impacto']} | "
                  f"{', '.join(l['fecha_com']) or '—'} | `{(l['comando'] or '—')}` |")
        if problemas:
            print("\n**FALHAS:** " + "; ".join(problemas))
    else:
        print(render(linhas, problemas, aberto_so))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
