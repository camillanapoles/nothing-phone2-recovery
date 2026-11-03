#!/usr/bin/env python3
"""legacy_scope.py — o que é deste workspace e o que é passado que manda NÃO usar.

Regra (references/legacy-sources.json):
  - fonte canônica existe e é a única que manda;
  - arquivo legado presente tem de carregar o carimbo "HISTÓRICO — NÃO EXECUTAR" no topo;
  - caminho legado removido tem de continuar ausente (se voltar, é regressão);
  - conflito documental declarado (ex.: ordem do DroidSpaces) tem de seguir escrito.

Uso:
  legacy_scope.py --root . [--json]
  legacy_scope.py --list
Exit: 0 escopo limpo · 3 legado sem carimbo / canônico ausente / conflito apagado · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
REGISTRY = f"{SK}/references/legacy-sources.json"
BANNER_LINES = 15


def load(p: str) -> dict:
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = argv[argv.index("--root") + 1] if "--root" in argv else "."
    reg_p = os.path.join(root, REGISTRY)
    if not os.path.exists(reg_p):
        print(f"[ERRO] registro de escopo ausente: {reg_p}", file=sys.stderr)
        return 4
    try:
        reg = load(reg_p)
    except Exception as exc:
        print(f"[ERRO] JSON inválido: {exc}", file=sys.stderr)
        return 4

    if "--list" in argv:
        for c in reg.get("canonical") or []:
            print(f"CANONICO  {c}")
        for l in reg.get("legacy") or []:
            print(f"LEGADO    {l['path']}")
        for r in reg.get("removed") or []:
            print(f"REMOVIDO  {r['path']}")
        return 0

    problems: list[dict] = []
    checks: list[dict] = []

    def add(kind: str, path: str, detail: str) -> None:
        checks.append({"kind": kind, "path": path, "detail": detail})
        if kind != "ok":
            problems.append({"kind": kind, "path": path, "detail": detail})

    for c in reg.get("canonical") or []:
        p = os.path.join(root, c)
        add("ok" if os.path.exists(p) else "canonico_ausente", c,
            "fonte canônica presente" if os.path.exists(p) else "fonte canônica desapareceu")

    for l in reg.get("legacy") or []:
        p = os.path.join(root, l["path"])
        kind = l.get("kind", "file")
        if not os.path.exists(p):
            # Ausência de instrução legada é o estado BOM: não há o que alguém siga por engano.
            # Antes daqui saía `legado_ausente` e o gate reprovava dizendo "aceitável" — mensagem
            # e veredito se contradiziam (o registro virou vermelho só por mover o arquivo).
            # Travar a ausência é papel de `removed`, que reprova se o caminho VOLTAR.
            add("ok", l["path"],
                "legado ausente do repo (registro mantido; use `removed` para travar a ausência)")
            continue
        if kind == "dir":
            add("ok", l["path"], "diretório de arquivo histórico, substituído por " + l.get("replaced_by", "?"))
            continue
        banner = l.get("banner") or "HISTÓRICO"
        try:
            head = "".join(open(p, encoding="utf-8").readlines()[:BANNER_LINES])
        except Exception as exc:
            add("legado_ilegivel", l["path"], f"não foi possível ler: {exc}")
            continue
        if banner in head:
            add("ok", l["path"], f"carimbo '{banner}' presente no topo")
        else:
            add("legado_sem_carimbo", l["path"],
                f"instrução legada ativa sem carimbo '{banner}' — risco de virar fila")

    for r in reg.get("removed") or []:
        p = os.path.join(root, r["path"])
        add("legado_voltou" if os.path.exists(p) else "ok", r["path"],
            "caminho removido continua ausente" if not os.path.exists(p) else "arquivo removido voltou ao repo")

    for d in reg.get("documented_conflicts") or []:
        p = os.path.join(root, d["doc"])
        if not os.path.exists(p):
            add("conflito_sem_doc", d["doc"], "documento do conflito declarado não existe")
            continue
        text = open(p, encoding="utf-8").read()
        if d["must_mention"] in text:
            add("ok", d["id"], f"conflito segue declarado em {d['doc']}")
        else:
            add("conflito_apagado", d["id"],
                f"conflito '{d['id']}' apagado de {d['doc']} (deveria citar '{d['must_mention']}')")

    verdict = "ESCOPO_LIMPO" if not problems else "ESCOPO_COM_LEGADO_ATIVO"
    payload = {"schema": "evox-legacy-scope/1", "verdict": verdict,
               "canonical": len(reg.get("canonical") or []),
               "legacy": len(reg.get("legacy") or []),
               "removed": len(reg.get("removed") or []),
               "problems": problems, "checks": checks}
    if "--json" in argv:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"[escopo] → {verdict}")
        for c in checks:
            mark = "OK  " if c["kind"] == "ok" else "FALHA"
            print(f"  {mark} {c['path']}: {c['detail']}")
    return 0 if not problems else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
