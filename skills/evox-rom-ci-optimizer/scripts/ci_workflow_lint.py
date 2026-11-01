#!/usr/bin/env python3
"""Lint de travas de custo e segurança em workflows do EVOX-CI.

Não é YAML completo (sem dependência externa): verifica as invariantes que, se
faltarem, custam dinheiro ou deixam o pipeline perigoso. Regras:

  R1  concurrency.cancel-in-progress: true
  R2  todo timeout-minutes <= 30
  R3  step do emulador com timeout <= 15
  R4  actions/cache presente (não rebaixa a ROM a cada run)
  R5  retention-days <= 7
  R6  permissions sem write-all
  R7  passo de KVM (udev 99-kvm4all)
  R8  watchdog de boot (sys.boot_completed + timeout)
  R9  emulador sem snapshot (-no-snapshot)
  R10 nenhum 'fastboot flash' (flash é humano)
  R11 nenhum segredo literal (ghp_, github_pat_, PRIVATE KEY)

Exit: 0 tudo ok · 3 violação · 2 uso/arquivo ausente.
"""
from __future__ import annotations

import json
import re
import sys

CLOUD_RULES = [
    ("R1", "cancel-in-progress", lambda t: "cancel-in-progress: true" in t),
    ("R3", "emulator timeout<=15", lambda t: _emulator_timeout(t)),
    ("R4", "actions/cache", lambda t: "uses: actions/cache" in t),
    ("R5", "retention<=7", lambda t: _retention_ok(t)),
    ("R6", "permissions read-only", lambda t: "write-all" not in t),
    ("R7", "KVM udev", lambda t: "99-kvm4all" in t),
    ("R8", "watchdog boot", lambda t: "sys.boot_completed" in t and "timeout" in t.lower()),
    ("R9", "-no-snapshot", lambda t: "-no-snapshot" in t),
    ("R10", "sem fastboot flash", lambda t: not re.search(r"fastboot\s+flash", t)),
    ("R11", "sem segredo literal", lambda t: not re.search(
        r"ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY", t)),
]

# Perfil local (act + device no USB): concurrency/cache/KVM/snapshot não se aplicam,
# mas rollback e gate de slot passam a ser obrigatórios.
LOCAL_RULES = [
    ("R5", "retention<=7", lambda t: _retention_ok(t)),
    ("R6", "permissions read-only", lambda t: "write-all" not in t),
    ("R10", "fastboot permitido (act-local)", lambda t: True),
    ("R11", "sem segredo literal", lambda t: not re.search(
        r"ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY", t)),
    ("R12", "rollback por set-active", lambda t: "set-active" in t),
    ("R13", "gate de slot", lambda t: "ro.boot.slot_suffix" in t),
]

LOCAL_MARKER = "# act-local: true"



def _emulator_timeout(text: str) -> bool:
    # procura um bloco android-emulator-runner e exige timeout <= 15 no mesmo step
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if "android-emulator-runner" in line:
            window = "\n".join(lines[max(0, i - 8) : i + 1])
            m = re.findall(r"timeout-minutes:\s*(\d+)", window)
            if not m or min(int(x) for x in m) > 15:
                return False
    return True


def _retention_ok(text: str) -> bool:
    for m in re.finditer(r"retention-days:\s*(\d+)", text):
        if int(m.group(1)) > 7:
            return False
    return True


def _timeouts_ok(text: str) -> list[str]:
    bad = [v for v in re.findall(r"timeout-minutes:\s*(\d+)", text) if int(v) > 30]
    return [] if not bad else [f"timeout={v}min (>30)" for v in bad]


def lint(path: str) -> dict:
    text = open(path, encoding="utf-8").read()
    local = LOCAL_MARKER in text
    rules = LOCAL_RULES if local else CLOUD_RULES
    results = []
    for rid, name, fn in rules:
        try:
            ok = bool(fn(text))
        except Exception:  # regra que quebra no arquivo = falha, não passa
            ok = False
        results.append({"rule": rid, "check": name, "ok": ok})
    for extra in _timeouts_ok(text):
        results.append({"rule": "R2", "check": f"timeout-minutes {extra}", "ok": False})
    if not any(r["rule"] == "R2" for r in results):
        results.append({"rule": "R2", "check": "timeout<=30", "ok": True})
    return {"file": path, "profile": "local" if local else "cloud",
            "ok": all(r["ok"] for r in results),
            "violations": [r for r in results if not r["ok"]], "results": results}


def main(argv: list[str]) -> int:
    as_json = "--json" in argv
    paths = [a for a in argv[1:] if not a.startswith("--")]
    if not paths:
        print("Uso: ci_workflow_lint.py <workflow.yml> [...] [--json]", file=sys.stderr)
        return 2
    reports = []
    for p in paths:
        try:
            reports.append(lint(p))
        except FileNotFoundError:
            print(f"[ERRO] arquivo não encontrado: {p}", file=sys.stderr)
            return 2
    if as_json:
        print(json.dumps(reports, indent=2, ensure_ascii=False))
    else:
        for r in reports:
            print(f"[lint] {r['file']} (perfil {r['profile']})")
            for item in r["results"]:
                print(f"  {'OK   ' if item['ok'] else 'FALHA'} {item['rule']:<4} {item['check']}")
            print(f"[lint] {'OK' if r['ok'] else 'VIOLADO'} "
                  f"({len(r['violations'])} violação(ões))")
    return 0 if all(r["ok"] for r in reports) else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
