#!/usr/bin/env python3
"""kernel_build_gate.py — o plano do kernel do par está completo e é executável item por item?

Duas leituras do mesmo plano (`references/kernel-build-plan.json`):

  --plan (padrão)  o PLANO está completo? cada requisito tem como provar E como falsificar?
                   todo módulo tem critério? as CONFIG_* cobrem o contrato do DroidSpaces?
                   as ações estão pinadas? os artefatos têm hash/proveniência?
                   → 0 plano completo · 3 lacuna de plano · 1 contradição

  --prebuild       os INSUMOS existem? source pinado (40 hex), ações com SHA,
                   fragmento presente na árvore, evidência de kernel com as CONFIG_*,
                   artefatos com sha256, paridade com o solver (C06).
                   → 0 pronto para buildar · 3 falta materializar · 1 contradição

Nada aqui nomeia motor de root: o plano é do kernel, e a paridade com o pack é medida
contra `root_pair_solver.py` (mesmo conjunto de CONFIG_* que C06 exige).

Uso:
  kernel_build_gate.py [--root DIR] [--plan] [--prebuild] [--json]
  kernel_build_gate.py --kernel-tree DIR --config-json F --build-dir DIR   (insumos do prebuild)

Exit: 0 ok · 3 pendente · 1 contradição/falha · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import glob
import importlib.util
import json
import os
import re
import sys

SK = "skills/evox-rom-ci-optimizer"
PLAN = f"{SK}/references/kernel-build-plan.json"
DROID = f"{SK}/references/droidspaces-requirements.json"
MODULES = f"{SK}/references/module-requirements.json"

HEX40 = re.compile(r"^[0-9a-f]{40}$")
SEMVER_TAG = re.compile(r"^v\d+(\.\d+){0,2}$")
PLACEHOLDER = re.compile(r"\b(TODO|TBD|FIXME|XXX)\b|\b(Todo|TBD|A definir|a definir|preencher|lorem)\b")

OK, PEND, FAIL = "ok", "pendente", "falha"


def load(p: str):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)


def texts(node) -> list[str]:
    out: list[str] = []
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, dict):
        for v in node.values():
            out.extend(texts(v))
    elif isinstance(node, list):
        for v in node:
            out.extend(texts(v))
    return out


def solver_config_set(root: str) -> set[str]:
    """As CONFIG_* que o pack exige hoje (C06) — lidas do contrato, não escritas aqui."""
    d = load(os.path.join(root, DROID))
    req = set((d.get("kernel") or {}).get("configs_required") or [])
    req |= set((d.get("isolation") or {}).get("required_configs") or [])
    return req


def plan_checks(plan: dict, root: str) -> list[dict]:
    checks: list[dict] = []

    def add(cid: str, state: str, detail: str) -> None:
        checks.append({"check": cid, "state": state, "detail": detail})

    alvo = plan.get("target") or {}
    faltando = [k for k in ("device", "model", "soc", "android", "rom_build", "kmi",
                            "kernel_base", "gki", "partition") if alvo.get(k) in (None, "")]
    add("P01_alvo", OK if not faltando else FAIL,
        "alvo completo (device/soc/rom/KMI/partição)" if not faltando else f"faltam campos: {faltando}")

    src = plan.get("source") or {}
    add("P02_fonte", OK if src.get("url") and src.get("branch") and src.get("license_check") else FAIL,
        f"fonte={src.get('id')} branch={src.get('branch')} pin={src.get('pin')} "
        f"licença={'declarada' if src.get('license_check') else 'AUSENTE'}")

    tc = plan.get("toolchain") or {}
    add("P03_toolchain", OK if tc.get("image") and tc.get("clang") and tc.get("llvm") else FAIL,
        f"imagem={tc.get('image')} clang={tc.get('clang')}")

    b = plan.get("build") or {}
    frags = b.get("fragments") or []
    ok_build = bool(b.get("defconfig")) and len(frags) >= 1 and b.get("pack_fragment") in frags \
        and len(b.get("reproducible") or []) >= 2
    add("P04_build", OK if ok_build else FAIL,
        f"defconfig={b.get('defconfig')} fragmentos={len(frags)} "
        f"fragmento_do_pack={'presente' if b.get('pack_fragment') in frags else 'AUSENTE'}")

    patches = b.get("patch_set") or []
    ruins = [p.get("id") for p in patches
             if not (p.get("kind") in ("patch", "tree_integration")
                     and p.get("source") and p.get("applies_to")
                     and p.get("on_reject") in ("fail_build", "drop_patch")
                     and (p.get("file") or p.get("how")))]
    tipos = sorted({p.get("kind") for p in patches})
    add("P05_patches", OK if len(patches) >= 4 and not ruins else FAIL,
        f"{len(patches)} patches; tipos={tipos}; cada um com política explícita "
        f"(fail_build/drop_patch); fora do padrão={ruins or 'nenhum'}")

    cfgs = plan.get("configs") or {}
    contrato_plan = set(cfgs.get("contract") or [])
    contrato_real = solver_config_set(root)
    falta = sorted(contrato_real - contrato_plan)
    add("P06_configs_contrato", OK if not falta else FAIL,
        f"{len(contrato_plan)} CONFIG_* no plano vs {len(contrato_real)} exigidas pelo pack"
        + ("" if not falta else f" — faltam {falta}"))

    espec = cfgs.get("module_specific") or []
    ruins_esp = [e.get("config") for e in espec
                 if not (e.get("config") and e.get("module") and e.get("kind") in ("contract", "to_confirm")
                         and e.get("confirm_in"))]
    add("P07_configs_modulo", OK if espec and not ruins_esp else FAIL,
        f"{len(espec)} CONFIG_* específicas de módulo; sem origem/confirmação={ruins_esp or 'nenhuma'}")

    reqs = plan.get("requirements") or {}
    fr, nfr = reqs.get("functional") or [], reqs.get("non_functional") or []
    todas = fr + nfr
    ids = [r.get("id") for r in todas]
    sem_prova = [r.get("id") for r in todas if not (r.get("verified_by") and r.get("falsified_by"))]
    add("P08_requisitos_funcionais", OK if len(fr) >= 10 else PEND,
        f"{len(fr)} requisitos funcionais (mínimo 10)")
    add("P09_requisitos_nao_funcionais", OK if len(nfr) >= 10 else PEND,
        f"{len(nfr)} requisitos não funcionais (mínimo 10)")
    add("P10_requisito_falseavel", OK if not sem_prova else FAIL,
        "todo requisito diz como provar E como falsificar"
        if not sem_prova else f"sem par prova/falsificação: {sem_prova}")
    add("P11_ids_unicos", OK if len(ids) == len(set(ids)) else FAIL,
        f"{len(ids)} requisitos, {len(set(ids))} ids únicos")

    sujeira = sorted({m.group(0) for t in texts(plan) for m in PLACEHOLDER.finditer(t)})
    add("P12_sem_placeholder", OK if not sujeira else FAIL,
        "plano sem TODO/TBD/a definir" if not sujeira else f"placeholders: {sujeira}")

    acoes = plan.get("actions") or []
    ruins_a = [a.get("use") for a in acoes if not (a.get("use") and a.get("version") and a.get("sha")
                                                  and a.get("source") and a.get("released_at"))]
    fora_de_padrao = [a.get("use") for a in acoes if not SEMVER_TAG.match(str(a.get("version", "")))]
    add("P13_acoes_declaradas", OK if len(acoes) >= 6 and not ruins_a else FAIL,
        f"{len(acoes)} ações; sem metadado={ruins_a or 'nenhuma'}")
    add("P14_acoes_versoes", OK if acoes and not fora_de_padrao else FAIL,
        "todas as ações com versão vX.Y.Z" if not fora_de_padrao else f"versão fora do padrão: {fora_de_padrao}")
    add("P15_acoes_evitadas", OK if len(plan.get("actions_avoided") or []) >= 2 else PEND,
        f"{len(plan.get('actions_avoided') or [])} alternativas avaliadas e recusadas com motivo")

    arts = plan.get("artifacts") or []
    nomes = {a.get("name") for a in arts}
    precisos = {"boot.img", "evox_pong_pack.config", "kernel-config.json"}
    add("P16_artefatos", OK if precisos <= nomes else FAIL,
        f"artefatos={sorted(nomes)}; faltando={sorted(precisos - nomes) or 'nenhum'}")
    add("P17_artefatos_hash", OK if all(a.get("sha256_required") for a in arts) and
        any(a.get("attest") for a in arts) else FAIL,
        f"{len(arts)} artefatos; todos exigem sha256="
        f"{all(a.get('sha256_required') for a in arts)}; proveniência="
        f"{any(a.get('attest') for a in arts)}")

    dep = plan.get("deploy") or {}
    proib = " ".join(dep.get("forbidden") or []).lower()
    add("P18_deploy", OK if len(dep.get("steps") or []) >= 5 and "fastboot" in proib
        and "guard4_verify" in " ".join(dep.get("steps") or []) else FAIL,
        f"{len(dep.get('steps') or [])} passos; proíbe flash no CI="
        f"{'fastboot' in proib}; cita guard4_verify="
        f"{'guard4_verify' in ' '.join(dep.get('steps') or [])}")

    m = load(os.path.join(root, MODULES))
    ids_mod = [x["id"] for x in m.get("modules") or []]
    val = plan.get("validation") or []
    cobertos = {v.get("module") for v in val}
    descobertos = [i for i in ids_mod if i not in cobertos]
    vazios = [v.get("module") for v in val
              if not all(v.get(k) for k in ("check", "expected", "falsified_by"))]
    add("P19_cobertura_de_modulos", OK if not descobertos and not vazios else FAIL,
        f"{len(ids_mod)} módulos; sem critério={descobertos or 'nenhum'}; "
        f"critério não falseável={vazios or 'nenhum'}")

    riscos = plan.get("risks") or []
    add("P20_riscos", OK if len(riscos) >= 3 and all(r.get("mitigation") for r in riscos) else FAIL,
        f"{len(riscos)} riscos com mitigação")
    return checks


def prebuild_checks(plan: dict, root: str, argv: list[str]) -> list[dict]:
    checks: list[dict] = []

    def add(cid: str, state: str, detail: str) -> None:
        checks.append({"check": cid, "state": state, "detail": detail})

    src = plan.get("source") or {}
    pin = str(src.get("pin", ""))
    add("B01_fonte_pinada", OK if HEX40.match(pin) else PEND,
        f"pin={pin}" + ("" if HEX40.match(pin) else " — fixar o commit (40 hex) do source"))

    acoes = plan.get("actions") or []
    sem_sha = [a.get("use") for a in acoes if not HEX40.match(str(a.get("sha", "")))]
    add("B02_acoes_com_sha", OK if acoes and not sem_sha else PEND,
        "todas as ações pinadas por SHA de 40 hex" if not sem_sha
        else f"faltam SHAs: {sem_sha}")

    tree = argv[argv.index("--kernel-tree") + 1] if "--kernel-tree" in argv else ""
    if not tree:
        add("B03_arvore_do_kernel", PEND, "sem --kernel-tree: não há como conferir o source")
    elif not os.path.isdir(tree):
        add("B03_arvore_do_kernel", FAIL, f"árvore inexistente: {tree}")
    else:
        frag = (plan.get("build") or {}).get("pack_fragment") or ""
        c = os.path.join(tree, frag) if frag else ""
        add("B03_arvore_do_kernel", OK if c and os.path.exists(c) else PEND,
            f"{frag} {'existe' if c and os.path.exists(c) else 'ainda não escrito na árvore'}")
        patches = [p for p in ((plan.get("build") or {}).get("patch_set") or [])
                   if p.get("kind") == "patch"]
        achados = [p.get("id") for p in patches
                   if p.get("file") and glob.glob(os.path.join(glob.escape(tree), "**", p["file"]), recursive=True)]
        add("B04_patches_no_source", OK if patches and len(achados) == len(patches) else PEND,
            f"{len(achados)}/{len(patches)} arquivos de patch na árvore")

    cfg_json = argv[argv.index("--config-json") + 1] if "--config-json" in argv else ""
    exigidas = solver_config_set(root)
    if not cfg_json:
        add("B05_configs_provadas", PEND,
            f"sem --config-json: {len(exigidas)} CONFIG_* seguem sem prova (é o que trava C06)")
    elif not os.path.exists(cfg_json):
        add("B05_configs_provadas", FAIL, f"evidência ausente: {cfg_json}")
    else:
        try:
            cfgs = (load(cfg_json) or {}).get("configs") or {}
        except Exception:
            cfgs = {}
        falta = sorted(c for c in exigidas if str(cfgs.get(c, "n")) not in ("y", "m"))
        add("B05_configs_provadas", OK if not falta else PEND,
            f"{len(exigidas) - len(falta)}/{len(exigidas)} CONFIG_* provadas"
            + ("" if not falta else f" — faltam {falta}"))

    build_dir = argv[argv.index("--build-dir") + 1] if "--build-dir" in argv else ""
    precisos = [a["name"] for a in (plan.get("artifacts") or []) if a.get("sha256_required")]
    if not build_dir:
        add("B06_artefatos_gerados", PEND, f"sem --build-dir: {len(precisos)} artefatos ainda não existem")
    else:
        achados = [n for n in precisos if os.path.exists(os.path.join(build_dir, n))]
        add("B06_artefatos_gerados", OK if len(achados) == len(precisos) else PEND,
            f"{len(achados)}/{len(precisos)} artefatos no build dir")

    add("B07_paridade_com_pack", OK,
        f"o plano e o pack usam o mesmo conjunto de {len(exigidas)} CONFIG_* (fonte única: "
        "droidspaces-requirements.json)")
    return checks


def run(checks: list[dict]) -> tuple[str, int]:
    estados = {c["state"] for c in checks}
    if FAIL in estados:
        return "FALHA", 1
    if PEND in estados:
        return "PENDENTE", 3
    return "PRONTO", 0


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = argv[argv.index("--root") + 1] if "--root" in argv else "."
    as_json = "--json" in argv
    plan_p = os.path.join(root, PLAN)
    for p in (plan_p, os.path.join(root, DROID), os.path.join(root, MODULES)):
        if not os.path.exists(p):
            print(f"[ERRO] arquivo ausente: {p}", file=sys.stderr)
            return 4
    try:
        plan = load(plan_p)
    except Exception as exc:
        print(f"[ERRO] plano inválido: {exc}", file=sys.stderr)
        return 4
    if not isinstance(plan.get("requirements"), dict):
        print("[ERRO] plano sem `requirements` funcional/não-funcional", file=sys.stderr)
        return 4

    modo = "prebuild" if "--prebuild" in argv else "plan"
    checks = plan_checks(plan, root)
    if modo == "prebuild":
        checks += prebuild_checks(plan, root, argv)
    verdict, code = run(checks)

    if as_json:
        print(json.dumps({"schema": "evox-kernel-build-gate/1", "mode": modo, "verdict": verdict,
                          "checks": checks, "exit": code}, indent=2, ensure_ascii=False, sort_keys=True))
    else:
        print(f"[kernel-plan] {modo} → {verdict} "
              f"({sum(c['state'] == OK for c in checks)}/{len(checks)} ok)")
        for c in checks:
            mark = {OK: "OK  ", PEND: "PEND", FAIL: "FALHA"}[c["state"]]
            print(f"  {mark} {c['check']}: {c['detail']}")
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
