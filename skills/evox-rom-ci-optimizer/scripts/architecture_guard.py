#!/usr/bin/env python3
"""architecture_guard.py — trava a arquitetura decidida (HIL A/B + AVD como pré-gate).

Roda em CI/`make prove`. Falha se alguém reintroduzir a arquitetura antiga como
autoritativa, remover uma correção ou deixar um script citado sem existir.

Regras:
  AG1  workflow cloud: sem `fastboot flash`, com cache e AVD
  AG2  workflow local (act): quarentena + rollback + gate de slot
  AG3  router A/B: comandos completos, sem `rm -rf`, sem `mount`
  AG4  probe de falha: classifica ABL_FALLBACK/HANG/HANG_EARLY/NO_DEVICE
  AG5  todo script/asset citado existe e está no SKILL.md
  AG6  todo teste é executável e está no Makefile
  AG7  AGENTS.md declara /data único e primeiro root fastboot-only
  AG8  SKILL.md corrige a premissa (ROM não inicia em runner)
  AG9  nenhuma instrução ativa manda usar `modules_stable`
  AG10 nenhum script ativo executa `mount`
  AG11 sintaxe de todos os .sh e compilação de todos os .py
  AG12 Makefile roda as suítes de slot/probe/guard
  AG13 nenhum workflow do GitHub executa fastboot
  AG14 workflow local não usa bootctl e confere boot_completed
  AG15 pipeline antigo só existe em references/archive/, marcado
  AG16 manifesto pinado das duas variantes + coletor determinístico
  AG17 nenhuma contradição ativa (C1–C13)
  AG18 todo script tem teste ou isenção declarada
  AG19 todo script testado tem mutante no catálogo
  AG20 nenhum teste viciado (varredura V1–V6)

Uso: architecture_guard.py [--root DIR] [--self-test] [--json]
Exit: 0 ok · 3 violação · 2 uso
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

SK = "skills/evox-rom-ci-optimizer"
CLOUD = f"{SK}/references/evox-ci-validator.yml"
LOCAL = "workflows-local/pong-ab-hil.yml"
ROUTER = f"{SK}/assets/00_slot_router.sh"
PROBE = f"{SK}/scripts/abl_fallback_probe.sh"
SKILL = f"{SK}/SKILL.md"
AGENTS = "AGENTS.md"
BOOT = "skills/BOOT.md"
MAKEFILE = f"{SK}/Makefile"


def load(root: str, rel: str) -> str | None:
    p = os.path.join(root, rel)
    try:
        return open(p, encoding="utf-8").read()
    except OSError:
        return None


def active_docs(t: dict[str, str]) -> dict[str, str]:
    return {k: v for k, v in t.items()
            if k.endswith((".md", ".yml", ".yaml")) and "archive" not in k
            and not k.startswith("docs/skills/")}


def check_ag1(t):
    c = t.get(CLOUD)
    p = []
    if c is None:
        return ["workflow cloud ausente"]
    if re.search(r"fastboot\s+flash", c):
        p.append("workflow cloud contém `fastboot flash`")
    for need in ("android-emulator-runner", "actions/cache", "timeout-minutes"):
        if need not in c:
            p.append(f"workflow cloud sem `{need}`")
    return p


def check_ag2(t):
    c = t.get(LOCAL)
    p = []
    if c is None:
        return ["workflow local ausente"]
    for need in ("# act-local: true", "quarantine", "set-active",
                 "ro.boot.slot_suffix", "rollout_gate.sh"):
        if need not in c:
            p.append(f"workflow local sem `{need}`")
    return p


def check_ag3(t):
    c = t.get(ROUTER)
    p = []
    if c is None:
        return ["00_slot_router.sh ausente"]
    for need in ("guard", "quarantine", "activate", "status", "reset", "disable"):
        if need not in c:
            p.append(f"router sem comando/marcador `{need}`")
    if re.search(r"^\s*rm\s+-rf\s", c, re.M):
        p.append("router executa `rm -rf` (proibido)")
    return p


def check_ag4(t):
    c = t.get(PROBE)
    if c is None:
        return ["abl_fallback_probe.sh ausente"]
    need = ("ABL_FALLBACK", "HANG_EARLY", "HANG", "NO_DEVICE", "pstore")
    return [f"probe sem classificação `{n}`" for n in need if n not in c]


def check_ag5(t, root=None):
    p = []
    skill = t.get(SKILL) or ""
    for base in (f"{SK}/scripts", f"{SK}/assets"):
        d = os.path.join(root or ".", base)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.startswith(".") or f == "__pycache__":
                continue
            if f not in skill:
                p.append(f"{f} existe em {base} mas não é citado no SKILL.md")
    return p


def check_ag6(t, root=None):
    p = []
    mk = t.get(MAKEFILE) or ""
    d = os.path.join(root or ".", f"{SK}/tests")
    if not os.path.isdir(d):
        return [f"diretório de testes ausente: {d}"]
    for f in sorted(os.listdir(d)):
        if not f.endswith(".sh"):
            continue
        path = os.path.join(d, f)
        if not os.access(path, os.X_OK):
            p.append(f"teste não executável: {f}")
        if f not in mk:
            p.append(f"teste fora do Makefile: {f}")
    return p


def check_ag7(t):
    a = t.get(AGENTS)
    if a is None:
        return ["AGENTS.md ausente"]
    p = []
    if "/data" not in a or "único" not in a:
        p.append("AGENTS.md não declara /data compartilhado/único")
    if "fastboot-only" not in a.lower():
        p.append("AGENTS.md não declara primeiro root fastboot-only")
    return p


def check_ag8(t):
    s = t.get(SKILL)
    if s is None:
        return ["SKILL.md ausente"]
    p = []
    if "AVD" not in s:
        p.append("SKILL.md não menciona AVD")
    if not re.search(r"não (inicia|boota)", s):
        p.append("SKILL.md não corrige a premissa (ROM não inicia em runner)")
    return p


def check_ag9(t):
    p = []
    for rel, text in active_docs(t).items():
        if rel == f"{SK}/references/act-ab-hil-review.md":
            continue  # documento de revisão cita o erro de propósito
        for m in re.finditer(r"modules_stable", text):
            ctx = text[max(0, m.start() - 90):m.start() + 40]
            if not re.search(r"não|nunca|proibido|inexistente", ctx):
                p.append(f"{rel} ainda manda usar modules_stable")
    return p


def check_ag10(t):
    p = []
    for rel, text in t.items():
        if not (rel.endswith(".sh") or rel.endswith(".yml")):
            continue
        for line in text.splitlines():
            st = line.strip()
            if st.startswith("#"):
                continue
            if re.match(r"^mount\s", st):
                p.append(f"{rel}: executa `{st[:40]}`")
    return p


def fs_checks(root):
    p = []
    import glob
    for f in glob.glob(os.path.join(root, SK, "**", "*.sh"), recursive=True):
        r = subprocess.run(["bash", "-n", f], capture_output=True)
        if r.returncode != 0:
            p.append(f"sintaxe inválida: {os.path.relpath(f, root)}")
    for f in glob.glob(os.path.join(root, SK, "**", "*.py"), recursive=True):
        r = subprocess.run([sys.executable, "-m", "py_compile", f], capture_output=True)
        if r.returncode != 0:
            p.append(f"python inválido: {os.path.relpath(f, root)}")
    return p


def check_ag14(t):
    c = t.get(LOCAL)
    if c is None:
        return ["workflow local ausente"]
    codigo = "\n".join(ln for ln in c.splitlines() if not ln.strip().startswith("#"))
    if "bootctl" in codigo:
        return ["workflow local usa `bootctl` (HAL boot_control não é garantida)"]
    if "sys.boot_completed" not in c:
        return ["workflow local não confere `sys.boot_completed`"]
    return []


def _py(root, script, *args):
    import subprocess
    f = os.path.join(root, SK, "scripts", script)
    if not os.path.exists(f):
        return None
    r = subprocess.run([sys.executable, f, "--root", root, "--json", *args],
                       capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"ok": False, "error": r.stderr[:200]}


def check_ag19(root):
    cat_p = os.path.join(root, SK, "references", "mutation-catalog.json")
    cov = _py(root, "coverage_matrix.py")
    if cov is None or not os.path.exists(cat_p):
        return ["mutation-catalog.json ou coverage_matrix.py ausente"]
    try:
        cat = json.load(open(cat_p, encoding="utf-8"))
    except Exception as exc:
        return [f"catálogo de mutação inválido: {exc}"]
    files = {m["file"] for m in (cat.get("mutants") or [])}
    ex_p = os.path.join(root, SK, "references", "audit-exemptions.json")
    try:
        ex = json.load(open(ex_p, encoding="utf-8")).get("mutation_exemptions", {})
    except Exception:
        ex = {}
    missing = [r["script"] for r in cov.get("rows", [])
               if r["status"] == "tested" and r["script"] not in files and r["script"] not in ex]
    return [f"script testado sem mutante: {m}" for m in missing]


def check_ag20(root):
    rep = _py(root, "test_vacuity_scan.py")
    if rep is None:
        return ["test_vacuity_scan.py ausente"]
    if rep.get("errors"):
        return [f"{rep['errors']} vício(s) estrutural(is) em teste — rode test_vacuity_scan.py"]
    return []


def check_ag17(root):
    rep = _py(root, "contradiction_scan.py")
    if rep is None:
        return ["contradiction_scan.py ausente"]
    if rep.get("errors"):
        return [f"{rep['errors']} contradição(ões) ativa(s) — rode contradiction_scan.py"]
    return []


def check_ag18(root):
    rep = _py(root, "coverage_matrix.py")
    if rep is None:
        return ["coverage_matrix.py ausente"]
    gaps = [r["script"] for r in rep.get("rows", []) if r["status"] == "GAP"]
    return [f"sem teste nem isenção: {g}" for g in gaps]


def check_ag16(root):
    p = []
    mf = os.path.join(root, SK, "references", "rom-artifacts.json")
    try:
        m = json.load(open(mf, encoding="utf-8"))
    except Exception as exc:
        return [f"manifesto de artefatos ausente/invalido: {exc}"]
    vars_ = m.get("variants") or []
    ids = {v.get("id") for v in vars_}
    if ids != {"vanilla", "gapps"}:
        p.append("manifesto precisa das duas variantes (vanilla e gapps)")
    if len({v.get("filename") for v in vars_}) != len(vars_):
        p.append("nomes de arquivo repetidos entre variantes")
    if not m.get("build"):
        p.append("manifesto sem build pinada")
    for v in vars_:
        if "cdn.evolution-x.org" not in (v.get("url") or ""):
            p.append(f"{v.get('id')}: URL fora do CDN esperado")
        if not (v.get("url") or "").endswith("/download"):
            p.append(f"{v.get('id')}: URL sem /download (nao e o link direto)")
    for f, label in (("scripts/rom_artifact_fetch.sh", "coletor"),):
        if not os.path.exists(os.path.join(root, SK, f)):
            p.append(f"{label} ausente: {f}")
    return p


def check_ag15(root):
    p = []
    ativo = os.path.join(root, SK, "references", "evox-ci-pipeline.yml")
    if os.path.exists(ativo):
        p.append("pipeline antigo ainda em references/ (mover para references/archive/)")
    arq = os.path.join(root, SK, "references", "archive", "evox-ci-pipeline.yml")
    if os.path.exists(arq):
        head = open(arq, encoding="utf-8").read(400)
        if "SUPERSEDIDO" not in head:
            p.append("pipeline arquivado sem aviso de SUPERSEDIDO")
    return p


def check_ag13(root):
    p = []
    import glob
    for f in sorted(glob.glob(os.path.join(root, ".github", "workflows", "*.yml"))):
        for i, line in enumerate(open(f, encoding="utf-8"), 1):
            if re.match(r"\s*run:.*fastboot", line):
                p.append(f"{os.path.basename(f)}:{i} executa fastboot no CI")
    return p


def check_ag12(t):
    mk = t.get(MAKEFILE) or ""
    return [f"Makefile não roda `{n}`" for n in ("test_slot_router.sh", "test_abl_probe.sh")
            if n not in mk]


CONTENT_RULES = [
    ("AG1", check_ag1), ("AG2", check_ag2), ("AG3", check_ag3), ("AG4", check_ag4),
    ("AG7", check_ag7), ("AG8", check_ag8), ("AG9", check_ag9), ("AG10", check_ag10),
    ("AG12", check_ag12), ("AG14", check_ag14),
]

VALID = {
    CLOUD: "android-emulator-runner actions/cache timeout-minutes: 25",
    LOCAL: "# act-local: true quarantine set-active ro.boot.slot_suffix rollout_gate.sh "
           "sys.boot_completed",
    ROUTER: "guard quarantine activate status reset disable",
    PROBE: "ABL_FALLBACK HANG HANG_EARLY NO_DEVICE pstore",
    SKILL: "AVD não inicia 00_slot_router.sh abl_fallback_probe.sh architecture_guard.py "
           "kernel_compat_check.sh rollout_gate.sh cache_manager.sh guard4_verify.sh "
           "session_open.py sandbox_rollout.sh ci_workflow_lint.py extract_rom_assets.sh",
    AGENTS: "/data é único entre os slots fastboot-only",
    MAKEFILE: "test_slot_router.sh test_abl_probe.sh test_architecture_guard.sh",
}

SELF_BAD = {
    "AG1": {CLOUD: VALID[CLOUD] + " fastboot flash boot"},
    "AG2": {LOCAL: VALID[LOCAL].replace("quarantine", "install")},
    "AG3": {ROUTER: VALID[ROUTER] + "\nrm -rf /data/adb/modules\n"},
    "AG4": {PROBE: VALID[PROBE].replace("HANG_EARLY", "HANG")},
    "AG7": {AGENTS: "sem aviso de data"},
    "AG8": {SKILL: "AVD sem correção"},
    "AG9": {SKILL: VALID[SKILL] + " copie para modules_stable"},
    "AG10": {ROUTER: VALID[ROUTER] + "\nmount --bind /a /b\n"},
    "AG12": {MAKEFILE: "test_slot_router.sh"},
    "AG14": {LOCAL: "# act-local: true quarantine set-active ro.boot.slot_suffix "
                    "rollout_gate.sh sys.boot_completed\n  run: bootctl mark-boot-successful"},
}


def run(root: str) -> dict:
    rels = [CLOUD, LOCAL, ROUTER, PROBE, SKILL, AGENTS, MAKEFILE]
    t = {r: (load(root, r) or "") for r in rels}
    results = []
    for rid, fn in CONTENT_RULES:
        problems = fn(t)
        results.append({"rule": rid, "ok": not problems, "problems": problems})
    for rid, fn in (("AG5", check_ag5), ("AG6", check_ag6)):
        problems = fn(t, root)
        results.append({"rule": rid, "ok": not problems, "problems": problems})
    problems = fs_checks(root)
    results.append({"rule": "AG11", "ok": not problems, "problems": problems})
    problems = check_ag13(root)
    results.append({"rule": "AG13", "ok": not problems, "problems": problems})
    problems = check_ag15(root)
    results.append({"rule": "AG15", "ok": not problems, "problems": problems})
    problems = check_ag16(root)
    results.append({"rule": "AG16", "ok": not problems, "problems": problems})
    for rid, fn in (("AG17", check_ag17), ("AG18", check_ag18),
                    ("AG19", check_ag19), ("AG20", check_ag20)):
        problems = fn(root)
        results.append({"rule": rid, "ok": not problems, "problems": problems})
    return {"root": os.path.abspath(root), "ok": all(r["ok"] for r in results),
            "results": results}


def self_test() -> int:
    fails = 0
    for rid, sample in SELF_BAD.items():
        fn = dict(CONTENT_RULES)[rid]
        merged = dict(VALID)
        merged.update(sample)
        if not fn(merged):
            print(f"[self-test] FALHA: regra {rid} não detectou a violação")
            fails += 1
    # todo VALID precisa passar em todas as regras de conteúdo
    for rid, fn in CONTENT_RULES:
        if rid in SELF_BAD and merged is None:
            pass
    for rid, fn in CONTENT_RULES:
        if fn(VALID):
            print(f"[self-test] FALHA: regra {rid} reprova o caso válido: {fn(VALID)}")
            fails += 1
    print(f"[self-test] {'OK' if not fails else f'{fails} falha(s)'} "
          f"({len(SELF_BAD)} violações simuladas)")
    return 0 if not fails else 3


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = "."
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    if "--self-test" in argv:
        return self_test()
    rep = run(root)
    if "--json" in argv:
        print(json.dumps(rep, indent=2, ensure_ascii=False))
    else:
        print(f"[arch] raiz {rep['root']}")
        for r in rep["results"]:
            print(f"  {'OK   ' if r['ok'] else 'FALHA'} {r['rule']}")
            for pr in r["problems"]:
                print(f"        - {pr}")
        print(f"[arch] {'OK' if rep['ok'] else 'VIOLADO'}")
    return 0 if rep["ok"] else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
