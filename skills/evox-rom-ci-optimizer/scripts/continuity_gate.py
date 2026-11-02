#!/usr/bin/env python3
"""continuity_gate.py — a instrução de continuidade continua servindo para continuar?

Uma instrução de handoff só vale se, lida por quem não viveu a sessão, ainda contiver o que é
preciso: a cláusula pétrea (o solver escolhe por DADO, não por nome), o método, o mandato, os
aprendizados, os anti-padrões, o que garantir e como resolver dúvida. Se alguém apagar uma
cláusula num refactor, o gate reprova — instrução não é decoração.

Cada cláusula é verificada **na sua seção** (não em qualquer lugar do texto): assim remover a seção
derruba a cláusula, e uma frase solta em outra seção não "salva" o documento.

Uso:
  continuity_gate.py [--root DIR] [--doc CAMINHO] [--json]
Exit: 0 íntegra · 1 cláusula faltando/contradita · 4 entrada inválida
"""
from __future__ import annotations

import json
import os
import re
import sys

SK = "skills/evox-rom-ci-optimizer"
DOC = "docs/skills/CONTINUITY-INSTRUCTION.md"

# (id, seções onde a cláusula deve valer, descrição, regex dentro dessas seções)
CLAUSULAS = [
    ("Q01_clausula_petrea", [1], "engine-x/kernel-x escolhidos por dado, sem mudar código",
     r"(?is)engine-x.*kernel-x.*nenhuma linha de c[óo]digo mudou"),
    ("Q02_autoridade", [2], "o passado era erro + vigente/arquivado/proibido",
     r"(?is)passado era erro"),
    ("Q03_metodo", [4], "condição → solver → gate → prova",
     r"(?is)condi[çc][ãa]o false[áa]vel.*solver.*gate.*prova"),
    ("Q04_mandato", [5], "P1/P2/P3 + L4 + o que é da usuária",
     r"(?is)\*\*P1\*\*.*\*\*P2\*\*.*\*\*P3\*\*.*L4"),
    ("Q05_pendente", [17], "dado ausente = PENDENTE (exit 3)",
     r"(?is)PENDENTE.*exit 3|exit 3.*PENDENTE"),
    ("Q06_requisitos", [7, 8], "requisitos funcionais e não funcionais citados",
     r"(?is)FR-01.*FR-11.*NFR-01.*NFR-10"),
    ("Q07_modulos", [9], "critério de PASS por módulo, M01 até M15",
     r"(?is)M01.*M05.*M12A.*M12B.*M15"),
    ("Q08_actions", [10], "build por GitHub Actions com SHA pinado",
     r"(?is)GitHub Actions.*[0-9a-f]{40}"),
    ("Q09_box", [11], "box de kernel: validar × fork × descartar",
     r"(?is)box.*validar.*fork.*descartar"),
    ("Q10_antipadroes", [15], "lista fechada de anti-padrões",
     r"(?is)anti-padr[õo]es.*n[ãa]o.*fazer"),
    ("Q11_garantir", [16], "checklist do que garantir antes de dizer pronto",
     r"(?is)antes de dizer .?pronto"),
    ("Q12_duvida", [17], "escala de decisão para dúvida",
     r"(?is)como resolver d[úu]vida.*escala de decis[ãa]o"),
    ("Q13_retomada", [18], "próximos passos + comandos de retomada",
     r"(?is)pr[óo]ximos passos ordenados"),
    ("Q14_prompt", [20], "prompt pronto para abrir a sessão nova",
     r"(?is)prompt de abertura"),
]

PLACEHOLDER = re.compile(r"\b(TODO|TBD|FIXME|XXX|lorem ipsum)\b")
CAMINHO = re.compile(r"\b((?:docs/skills|scripts|tests|references|skills/[\w./-]+)/[\w./-]+\.(?:md|json|py|sh|yml|yaml))\b")
ALVO_MAKE = re.compile(r"make\s+-s\s+([a-z][\w-]*)")


def secoes(txt: str) -> dict[int, str]:
    """Divide o documento em seções `## N.` → cabeçalho + corpo (o título conta como conteúdo)."""
    marcas = list(re.finditer(r"(?m)^##\s*(\d+)\.\s*([^\n]*)$", txt))
    out: dict[int, str] = {0: txt[: marcas[0].start()] if marcas else txt}
    for i, m in enumerate(marcas):
        fim = marcas[i + 1].start() if i + 1 < len(marcas) else len(txt)
        out[int(m.group(1))] = txt[m.start():fim]
    return out


def candidatos(root: str, caminho: str) -> list[str]:
    out = []
    for base in (root, os.path.join(root, SK)):
        p = os.path.join(base, caminho)
        if os.path.exists(p):
            out.append(p)
    return out


def alvos_do_makefile(root: str) -> set[str]:
    p = os.path.join(root, "Makefile")
    if not os.path.exists(p):
        return set()
    return set(re.findall(r"^([a-z][\w-]*):", open(p, encoding="utf-8").read(), re.M))


def ids_de_motor(root: str) -> list[str]:
    for p in candidatos(root, "references/root-engines.json"):
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        ids = [str(e.get("id", "")) for e in (d.get("engines") or []) if e.get("id")]
        if ids:
            return ids
    return []


def check(root: str, doc: str | None) -> tuple[list[dict], int]:
    caminho = doc or os.path.join(root, DOC)
    if not os.path.isfile(caminho):
        return [{"check": "Q00_documento", "state": "falha", "detail": f"não existe: {caminho}"}], 1
    txt = open(caminho, encoding="utf-8").read()
    sec = secoes(txt)
    checks: list[dict] = []

    def add(cid: str, ok: bool, detail: str) -> None:
        checks.append({"check": cid, "state": "ok" if ok else "falha", "detail": detail})

    n_linhas = txt.count("\n") + 1
    add("Q00_documento", n_linhas >= 120, f"{n_linhas} linhas (mínimo 120)")

    for cid, nums, desc, rx in CLAUSULAS:
        corpo = "\n".join(sec.get(n, "") for n in nums)
        add(cid, bool(corpo.strip()) and bool(re.search(rx, corpo)),
            desc if corpo.strip() else f"seção ausente: {nums}")

    corpo_anti = sec.get(15, "")
    antipadroes = len(re.findall(r"(?m)^\s*-\s*❌", corpo_anti))
    add("Q15_antipadroes_contagem", antipadroes >= 8, f"{antipadroes} anti-padrões (mínimo 8)")

    corpo_apr = sec.get(14, "")
    n_apr = len(re.findall(r"(?m)^\s*\d+\.\s", corpo_apr))
    add("Q16_aprendizados_contagem", n_apr >= 8, f"{n_apr} aprendizados (mínimo 8)")

    sujeira = sorted(set(PLACEHOLDER.findall(txt)))
    add("Q17_sem_placeholder", not sujeira, "sem TODO/TBD/FIXME"
        if not sujeira else f"placeholders: {sujeira}")

    citados = sorted(set(CAMINHO.findall(txt)))
    faltando = [c for c in citados if not candidatos(root, c)]
    add("Q18_caminhos_existem", bool(citados) and not faltando,
        f"{len(citados)} caminhos citados, todos existem"
        if not faltando else f"caminhos inexistentes: {faltando}")

    alvos = alvos_do_makefile(root)
    pedidos = sorted(set(ALVO_MAKE.findall(txt)))
    ruins = [a for a in pedidos if a not in alvos]
    add("Q19_alvos_existem", bool(pedidos) and not ruins,
        f"{len(pedidos)} alvos citados, todos no Makefile"
        if not ruins else f"alvos inexistentes: {ruins}")

    # o solver "de verdade" é o maior candidato (fixtures vazias não podem mascarar a cláusula pétrea)
    cand_solver = sorted(candidatos(root, "scripts/root_pair_solver.py"),
                         key=lambda p: os.path.getsize(p), reverse=True)
    solver = cand_solver[0] if cand_solver else None
    if not solver:
        add("Q20_solver_sem_literal", False, "root_pair_solver.py ausente: não há como conferir a cláusula pétrea")
    else:
        codigo = open(solver, encoding="utf-8").read()
        literais = [i for i in ids_de_motor(root) if f'"{i}"' in codigo or f"'{i}'" in codigo]
        add("Q20_solver_sem_literal", not literais,
            "o solver não cita motor por nome (escolha é por dado)"
            if not literais else f"o solver tem id de motor literal: {literais}")

    return checks, 0 if all(c["state"] == "ok" for c in checks) else 1


def main(argv: list[str]) -> int:
    root, doc, como_json, i = ".", None, False, 1
    while i < len(argv):
        a = argv[i]
        if a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if a == "--root" and i + 1 < len(argv):
            root, i = argv[i + 1], i + 2
        elif a == "--doc" and i + 1 < len(argv):
            doc, i = argv[i + 1], i + 2
        elif a == "--json":
            como_json, i = True, i + 1
        else:
            print(f"[continuidade] argumento desconhecido: {a}", file=sys.stderr)
            return 4
    if not os.path.isdir(root):
        print(f"[continuidade] raiz inexistente: {root}", file=sys.stderr)
        return 4

    checks, rc = check(root, doc)
    if como_json:
        print(json.dumps({"schema": "evox-continuity-gate/1", "root": root,
                          "checks": checks, "exit": rc}, ensure_ascii=False, indent=1))
        return rc

    ruins = [c for c in checks if c["state"] != "ok"]
    print(f"[continuidade] {'ÍNTEGRA' if not ruins else 'INCOMPLETA'} "
          f"({len(checks) - len(ruins)}/{len(checks)} cláusulas)")
    for c in checks:
        print(f"  {'OK  ' if c['state'] == 'ok' else 'FALHA'} {c['check']}: {c['detail']}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
