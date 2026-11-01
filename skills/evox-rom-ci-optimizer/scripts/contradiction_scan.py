#!/usr/bin/env python3
"""contradiction_scan.py — varre instruções ativas procurando o que a arquitetura decidiu proibir.

Diferente do architecture_guard (que olha presença de correções), aqui a pergunta é:
"alguma instrução ATIVA ainda manda fazer o que foi abandonado, ou usa vocabulário ambíguo?"

Regras (erro = bloqueia; aviso = registra):
  C1  mount --bind executado (não em comentário)              erro
  C2  bootctl em código de workflow                            erro
  C3  cp -rn                                                   erro
  C4  modules_stable sem negação                               erro
  C5  staging_b usado como caminho                             aviso
  C6  fastboot flash em run: do .github/workflows              erro
  C7  QEMU/KVM em documento ativo                              aviso
  C8  "Gate 4"/"gate-4" (vocabulário ambíguo entre skills)     erro
  C9  "G4" fora do contexto de objetivo global                 erro
  C10 "gate 10" (colide com G10; usar GO-USB 10/10)               erro
  C11 afirmação sobre init_boot sem marcação de não-verificado erro
  C12 HIL como "gate final"                                    erro
  C13 caminho absoluto /home/ ou /Users/ em script/doc ativo    aviso

Exceções: trecho com negação/marcação (não, nunca, proibido, abandonado, supersedido,
legado, inexistente, errado, evitar) nos 90 caracteres anteriores; pastas archive/;
o próprio AUDIT-CONTRADICTIONS.md.

Uso: contradiction_scan.py [--root DIR] [--json] [--self-test] [--warn-only]
Exit: 0 limpo (ou só avisos) · 3 erro · 2 uso
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys

SK = "skills/evox-rom-ci-optimizer"
ROOTS = ["AGENTS.md", "agente.md", "skills/BOOT.md", "skills/README.md"]
GLOBS = [f"{SK}/**/*.md", f"{SK}/**/*.sh", f"{SK}/**/*.py", f"{SK}/**/*.yml",
         "docs/skills/*.md", "workflows-local/*.yml", ".github/workflows/*.yml"]
SKIP_PARTS = ("/archive/", "__pycache__", "/workspace/")
# arquivos que CONTÊM os padrões proibidos de propósito (regras, fixtures, relatório do próprio scan)
SKIP_FILES = (
    "docs/skills/AUDIT-CONTRADICTIONS.md",
    "docs/skills/VALIDATION-REPORT.md",                      # tabela "o que foi abandonado"
    "skills/evox-rom-ci-optimizer/scripts/contradiction_scan.py",   # as próprias regras
    "skills/evox-rom-ci-optimizer/scripts/architecture_guard.py",   # amostras do self-test
    "skills/evox-rom-ci-optimizer/tests/test_architecture_guard.sh",# fixture com fastboot flash
    "skills/evox-rom-ci-optimizer/tests/test_contradiction_scan.sh", # fixture com padrões ruins
    "skills/evox-rom-ci-optimizer/tests/test_audit_loop.sh",         # idem
)
NEG = re.compile(r"não|nunca|proibido|abandonad|supersedid|legado|inexistente|errad|evit|desprezad|renomead|obsolet|desatualiz|nenhum", re.I)

RULES = [
    ("C1", "erro", re.compile(r"^\s*mount\s+--bind|^\s*mount\s+-o\s+bind")),
    ("C2", "erro", re.compile(r"bootctl\s+mark")),
    ("C3", "erro", re.compile(r"\bcp\s+-rn\b")),
    ("C4", "erro", re.compile(r"modules_stable")),
    ("C5", "aviso", re.compile(r"/data/adb/staging_b")),
    ("C6", "erro", re.compile(r"run:.*fastboot\s+flash")),
    ("C7", "aviso", re.compile(r"QEMU/KVM")),
    ("C8", "erro", re.compile(r"\bGate[- ]?4\b|\bgate[- ]?4\b")),
    ("C9", "erro", re.compile(r"(?<![A-Za-z0-9])G4(?![0-9A-Za-z])")),
    ("C10", "erro", re.compile(r"\bgate\s*10\b", re.I)),
    ("C11", "erro", re.compile(r"pre-init_boot|NOT init_boot|no init_boot|não tem init_boot|sem init_boot")),
    ("C12", "erro", re.compile(r"HIL[^.\n]{0,40}gate final", re.I)),
    ("C13", "aviso", re.compile(r"/home/(?!runner)[a-z]|/Users/[A-Za-z]")),
]

# C9: linhas de tabela de objetivos globais em AGENTS.md são legítimas
C9_OK = re.compile(r"^\|\s*G\d+\s*\|")


def files(root: str) -> list[str]:
    out = []
    for r in ROOTS:
        p = os.path.join(root, r)
        if os.path.isfile(p):
            out.append(os.path.relpath(p, root))
    for g in GLOBS:
        for p in glob.glob(os.path.join(root, g), recursive=True):
            rel = os.path.relpath(p, root)
            if any(s in "/" + rel for s in SKIP_PARTS) or rel in SKIP_FILES:
                continue
            out.append(rel)
    return sorted(set(out))


def scan_file(root: str, rel: str) -> list[dict]:
    hits = []
    try:
        text = open(os.path.join(root, rel), encoding="utf-8").read()
    except OSError:
        return hits
    for i, line in enumerate(text.splitlines(), 1):
        st = line.strip()
        if "scan:exempt" in line:
            continue  # exceção explícita: a linha cita o padrão de propósito
        for rid, sev, rx in RULES:
            m = rx.search(line)
            if not m:
                continue
            if st.startswith("#") and rid in ("C1", "C2", "C3", "C6"):
                continue  # comentário não executa
            if rid == "C9" and C9_OK.match(st):
                continue
            if st.startswith("|"):
                ctx = line          # tabela descreve, não comanda
            else:
                ctx = line[max(0, m.start() - 90):m.start()] + " " + line[m.end():m.end() + 40]
            if NEG.search(ctx) or NEG.search(m.group(0)):
                continue
            hits.append({"rule": rid, "severity": sev, "file": rel, "line": i,
                         "snippet": st[:160]})
    return hits


def run(root: str) -> dict:
    hits = []
    for rel in files(root):
        hits.extend(scan_file(root, rel))
    errors = [h for h in hits if h["severity"] == "erro"]
    return {"root": os.path.abspath(root), "files_scanned": len(files(root)),
            "errors": len(errors), "warnings": len(hits) - len(errors),
            "ok": not errors, "hits": hits}


SAMPLES = {
    "C1": "mount --bind /a /b\n",
    "C2": "adb shell bootctl mark-boot-successful\n",
    "C3": "cp -rn mods/ /data/adb/modules\n",
    "C4": "copie os módulos para modules_stable\n",
    "C6": "      - run: fastboot flash boot_b boot.img\n",
    "C8": "o Gate 4 aprova o flash\n",
    "C9": "use G4 antes de gravar\n",
    "C10": "só libera depois do gate 10\n",
    "C11": "Pong is pre-init_boot era\n",
    "C12": "o HIL A/B é o gate final do pipeline\n",
}


def self_test() -> int:
    fails = 0
    rulemap = {rid: rx for rid, _sev, rx in RULES}
    for rid, sample in SAMPLES.items():
        line = [ln for ln in sample.splitlines() if ln.strip()][0]
        if not rulemap[rid].search(line):
            print(f"[self-test] FALHA: regra {rid} não casa a amostra")
            fails += 1
    # texto correto não pode disparar nada
    bom = ("nunca use mount --bind; bootctl é proibido; modules_stable não existe; "
           "o HIL A/B é pré-gate, não gate final; gate 10 foi renomeado para GO-USB 10/10")
    for rid, _sev, rx in RULES:
        for frag in bom.split(";"):
            m = rx.search(frag)
            if not m:
                continue
            ctx = frag[max(0, m.start() - 90):m.start()] + " " + frag[m.end():m.end() + 20]
            if not (NEG.search(ctx) or NEG.search(m.group(0))):
                print(f"[self-test] FALHA: regra {rid} reprova texto correto: {frag.strip()}")
                fails += 1
    print(f"[self-test] {'OK' if not fails else f'{fails} falha(s)'} "
          f"({len(SAMPLES)} padrões proibidos)")
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
        print(f"[scan] {rep['files_scanned']} arquivos · {rep['errors']} erro(s) · {rep['warnings']} aviso(s)")
        for h in rep["hits"]:
            print(f"  {h['severity'].upper():5} {h['rule']:4} {h['file']}:{h['line']}")
            print(f"        {h['snippet']}")
    if "--warn-only" in argv:
        return 0
    return 0 if rep["ok"] else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
