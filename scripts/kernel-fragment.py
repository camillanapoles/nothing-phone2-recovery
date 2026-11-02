#!/usr/bin/env python3
"""kernel-fragment.py — gera o fragmento de config do pack a partir do CONTRATO, não da memória.

O fragmento que vai para `arch/arm64/configs/evox_pong_pack.config` é derivado de
`skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json` (fonte única das CONFIG_*
que o DroidSpaces exige). Assim, mudar o contrato muda o fragmento, e o gate `--prebuild`
(`B08`) reprova se o arquivo commitado divergir do gerado — não existe cópia manual para sair de sincronia.

Uso:
  kernel-fragment.py [--root DIR] [--out F] [--check] [--json]
Exit: 0 ok · 1 divergência/contrato inválido · 2 uso · 4 entrada
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
CONTRATO = f"{SK}/references/droidspaces-requirements.json"
DESTINO = "kernel/fragments/evox_pong_pack.config"
# devtmpfs entra por exigência textual do DroidSpaces (não está nas listas do contrato)
EXTRA = ["CONFIG_DEVTMPFS"]

CABECALHO = """# evox_pong_pack.config — fragmento do pack (gerado; NÃO editar à mão)
# Fonte: {contrato}
# sha256 do contrato: {hash}
# Gerado por: scripts/kernel-fragment.py
#
# Regra: se uma CONFIG_* do contrato muda, este arquivo muda junto. `kernel_build_gate
# --prebuild` (B08) reprova quando os dois divergem.
"""


def carregar(root: str) -> tuple[list[str], str, str]:
    caminho = os.path.join(root, CONTRATO)
    bruto = open(caminho, "rb").read()
    d = json.loads(bruto)
    kernel = (d.get("kernel") or {}).get("configs_required") or []
    isolation = (d.get("isolation") or {}).get("required_configs") or []
    if not kernel:
        raise ValueError("contrato sem kernel.configs_required")
    cfgs = sorted(set(kernel) | set(isolation) | set(EXTRA))
    return cfgs, hashlib.sha256(bruto).hexdigest(), CONTRATO


def gerar(root: str) -> str:
    cfgs, hash_contrato, origem = carregar(root)
    linhas = [CABECALHO.format(contrato=origem, hash=hash_contrato)]
    for c in cfgs:
        linhas.append(f"{c}=y")
    return "\n".join(linhas).rstrip() + "\n"


def main(argv: list[str]) -> int:
    root, out, check, como_json, i = ".", None, False, False, 1
    while i < len(argv):
        a = argv[i]
        if a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if a == "--root" and i + 1 < len(argv):
            root, i = argv[i + 1], i + 2
        elif a == "--out" and i + 1 < len(argv):
            out, i = argv[i + 1], i + 2
        elif a == "--check":
            check, i = True, i + 1
        elif a == "--json":
            como_json, i = True, i + 1
        else:
            print(f"[fragmento] argumento desconhecido: {a}", file=sys.stderr)
            return 2
    if not os.path.isdir(root):
        print(f"[fragmento] raiz inexistente: {root}", file=sys.stderr)
        return 4
    try:
        conteudo = gerar(root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[fragmento] contrato inválido: {exc}", file=sys.stderr)
        return 1

    destino = out or os.path.join(root, DESTINO)
    if check:
        atual = None
        if os.path.exists(destino):
            atual = open(destino, encoding="utf-8").read()
        igual = atual == conteudo
        detalhe = {"arquivo": destino, "igual": igual,
                   "linhas": conteudo.count("\n"), "sha256": hashlib.sha256(conteudo.encode()).hexdigest()}
        if como_json:
            print(json.dumps(detalhe, ensure_ascii=False))
        else:
            print(f"[fragmento] {'em sincronia' if igual else 'DIVERGENTE'}: {destino} "
                  f"({detalhe['linhas']} linhas, sha256 {detalhe['sha256'][:12]})")
        return 0 if igual else 1

    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(conteudo)
        print(f"[fragmento] escrito: {out} ({conteudo.count(chr(10))} linhas)")
    else:
        sys.stdout.write(conteudo)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
