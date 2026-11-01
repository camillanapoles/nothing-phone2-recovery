#!/usr/bin/env python3
"""
CONFLICT-INQUISITOR v3.1 - Scanner estatico de colisoes pre-boot e arbitragem
de contratos entre os 15 modulos + MaxManager, Duck-ToolBox, GenieX e DroidSpaces.

Regras implementadas (ver references/external-engines-arbitration.md):
  R00_*                      colisao de overlay / prop / Zygisk / zip corrompido  -> CONFLICT
  R01_MAXMANAGER_EXCLUSIVITY escritores concorrentes de CPU/GPU/Thermal/ZRAM   -> CONFLICT
  R02_MAXMANAGER_SYSCTL_SCOPE sysctl manual fora do escopo de intranet         -> WARN
  R03_DROIDSPACES_SUSFS      DroidSpaces + SuSFS coexistentes                  -> WARN
  R04_DUCK_TOOLBOX_CONSOLIDATION  Duck-ToolBox + modulos avulsos de spoofing   -> WARN
  R05_GENIEX_NPU_DEVICE_UNBOUND   GenieX sem /dev/adsprpc-smd                  -> WARN
  R06_PERSIST_WRITE          escrita em persist (calibracao Goodix)            -> CONFLICT
  R07_PRIVAPP_PERMISSION_MISSING  priv-app sem privapp-permissions-*.xml       -> CONFLICT
  R08_SELINUX_PERMISSIVE     setenforce 0 / androidboot.selinux=permissive     -> CONFLICT
  R09_WAVE_ORDER_VIOLATION   modulo de onda superior sem a fundacao da Wave 1  -> WARN

Uso:
  static_conflict_scanner.py [MODULES_DIR] [--modules-dir DIR] [--out FILE]
                             [--strict] [--json] [--quiet]

Saida: JSON {status, waves, modules, conflicts[], warnings[], checks[]}
Exit:  0 = CLEAN | 1 = CONFLICT (ou WARN com --strict) | 2 = erro de uso
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import zipfile
from collections import defaultdict

PARTITIONS = ("system/", "vendor/", "product/", "system_ext/")
TEXT_MEMBERS = re.compile(r"(\.sh|\.prop|\.conf|\.xml|\.json|\.cfg|\.ini)$", re.I)
MAX_TEXT_BYTES = 262_144

# Onda canonica por padrao de nome de modulo (M01..M15 -> Waves 1..5)
WAVE_MAP = [
    (1, ("kernel", "apatch", "kernelsu", "magisk", "droidspace", "kpm")),
    (2, ("gapps", "google", "fingerprint", "duck", "toolbox", "trickystore", "integrity")),
    (3, ("maxmanager", "max_manager", "geniex", "genie", "camera", "gcam")),
    (4, ("capture", "screenshot", "freeform", "free-form", "saf", "storage", "net", "port")),
    (5, ("snapshot", "release", "ci")),
]

MAXMANAGER_COMPETITORS = ("thermal", "governor", "fde", "lkt", "sysctl", "tuning", "perf")
SYSCTL_INTRANET_KEYS = ("ip_forward", "forwarding", "route_localnet", "tcp_", "rp_filter")
SPOOF_MODULE_HINTS = ("trickystore", "pif", "playintegrityfix", "play_integrity_fix", "spoof", "rkp", "keybox")
PRIVAPP_RE = re.compile(r"(system|product|system_ext)/priv-app/[^/]+/([^/]+)\.apk$")
PERMISSION_RE = re.compile(r"etc/permissions/.*privapp-permissions.*\.xml$", re.I)
PERSIST_DESTRUCTIVE = re.compile(
    r"(dd\s+[^\n]*persist|fastboot\s+erase\s+persist|rm\s+-rf?\s+\S*persist|mkfs\.[a-z0-9]+\s+\S*persist)",
    re.I,
)
SELINUX_PERMISSIVE = re.compile(
    r"(setenforce\s+0|androidboot\.selinux=permissive|ro\.boot\.selinux=permissive|SELINUX=permissive)",
    re.I,
)


def wave_of(module_name: str) -> int | None:
    low = module_name.lower()
    for wave, keys in WAVE_MAP:
        if any(k in low for k in keys):
            return wave
    return None


def read_text(zf: zipfile.ZipFile, member: str) -> str:
    try:
        info = zf.getinfo(member)
        if info.file_size > MAX_TEXT_BYTES:
            return ""
        return zf.read(member).decode("utf-8", errors="ignore")
    except Exception:  # pragma: no cover - defensivo
        return ""


def scan_modules(modules_dir: str) -> dict:
    file_map: dict[str, list[str]] = defaultdict(list)
    prop_map: dict[str, list[tuple[str, str]]] = defaultdict(list)
    modules: dict[str, dict] = {}
    conflicts: list[dict] = []
    warnings: list[dict] = []
    checks: list[dict] = []

    def add(kind: str, rule: str, severity: str, **payload):
        item = {"rule": rule, "severity": severity, **payload}
        (conflicts if severity == "CONFLICT" else warnings).append(item)

    if not os.path.isdir(modules_dir):
        return {
            "status": "ERROR",
            "modules": {},
            "conflicts": [],
            "warnings": [],
            "checks": [
                {
                    "rule": "R00_INPUT",
                    "severity": "ERROR",
                    "detail": f"diretorio de modulos inexistente: {modules_dir}",
                }
            ],
        }

    for fname in sorted(os.listdir(modules_dir)):
        if not fname.lower().endswith(".zip"):
            continue
        zpath = os.path.join(modules_dir, fname)
        meta = {
            "wave": wave_of(fname),
            "members": 0,
            "texts": {},
            "privapp": [],
            "has_permission_xml": False,
            "zygisk_so": False,
        }
        try:
            with zipfile.ZipFile(zpath, "r") as zf:
                names = zf.namelist()
                meta["members"] = len(names)
                for member in names:
                    if member.endswith("/"):
                        continue
                    if member.startswith(PARTITIONS):
                        file_map[member].append(fname)
                    if member.startswith("persist/"):
                        add(
                            kind="PERSIST",
                            rule="R06_PERSIST_WRITE",
                            severity="CONFLICT",
                            module=fname,
                            target=member,
                            detail="escrita em persist corrompe a calibracao Goodix (irreversivel)",
                        )
                    low = member.lower()
                    if "zygisk" in low and low.endswith(".so"):
                        meta["zygisk_so"] = True
                    if PRIVAPP_RE.search(member):
                        meta["privapp"].append(member)
                    if PERMISSION_RE.search(member):
                        meta["has_permission_xml"] = True
                    if member == "system.prop" or TEXT_MEMBERS.search(member):
                        text = read_text(zf, member)
                        if text:
                            meta["texts"][member] = text
                            for line in text.splitlines():
                                line = line.strip()
                                if line and not line.startswith("#") and "=" in line and member.endswith(".prop"):
                                    key, val = line.split("=", 1)
                                    prop_map[key.strip()].append((fname, val.strip()))
        except zipfile.BadZipFile:
            add(kind="CORRUPT", rule="R00_CORRUPT_ZIP", severity="CONFLICT", module=fname)
            continue
        modules[fname] = meta

    # ---------- R00: colisoes de overlay e propriedades ----------
    for path, owners in file_map.items():
        if len(owners) > 1:
            add(
                kind="FILE",
                rule="R00_FILE_OVERWRITE",
                severity="CONFLICT",
                target=path,
                modules=owners,
                detail="dois modulos disputam o mesmo inode em OverlayFS",
            )
    for prop, entries in prop_map.items():
        values = {v for _, v in entries}
        if len(values) > 1:
            add(
                kind="PROP",
                rule="R00_PROP_COLLISION",
                severity="CONFLICT",
                property=prop,
                definitions=entries,
                detail="mesma propriedade com valores divergentes",
            )
    zygisk = [m for m, meta in modules.items() if meta["zygisk_so"] and any(
        k in m.lower() for k in ("zygisk", "rezygisk"))]
    if len(set(zygisk)) > 1:
        add(
            kind="ZYGISK",
            rule="R00_DUPLICATE_ZYGISK_PROVIDER",
            severity="CONFLICT",
            modules=sorted(set(zygisk)),
            detail="mais de um provedor Zygisk ativo derruba zygote64",
        )

    # ---------- R06 (via scripts) e R08 (SELinux permissivo) ----------
    for fname, meta in modules.items():
        for member, text in meta["texts"].items():
            if PERSIST_DESTRUCTIVE.search(text):
                add(
                    kind="PERSIST",
                    rule="R06_PERSIST_WRITE",
                    severity="CONFLICT",
                    module=fname,
                    target=member,
                    detail="comando destrutivo em persist detectado no conteudo do modulo",
                )
            if SELINUX_PERMISSIVE.search(text):
                add(
                    kind="SELINUX",
                    rule="R08_SELINUX_PERMISSIVE",
                    severity="CONFLICT",
                    module=fname,
                    target=member,
                    detail="setenforce 0 / androidboot.selinux=permissive quebra bancos e Play Integrity",
                )
        # R07: priv-app sem XML de permissao
        if meta["privapp"] and not meta["has_permission_xml"]:
            add(
                kind="PRIVAPP",
                rule="R07_PRIVAPP_PERMISSION_MISSING",
                severity="CONFLICT",
                module=fname,
                apps=meta["privapp"],
                detail="app privilegiado sem etc/permissions/privapp-permissions-*.xml impede o boot no API 36",
            )

    # ---------- R03: DroidSpaces x SuSFS ----------
    has_droidspaces = any("droidspace" in m.lower() for m in modules)
    has_susfs = any("susfs" in m.lower() for m in modules)
    if has_droidspaces and has_susfs:
        add(
            kind="DROIDSPACES",
            rule="R03_DROIDSPACES_SUSFS",
            severity="WARN",
            action_required=(
                "Desativar 'Hide sus mounts for all processes' no SuSFS para os UIDs/processos "
                "do droidspaces; caso contrario os containers Linux nao dao boot."
            ),
        )

    # ---------- R01/R02: MaxManager ----------
    maxmanager = [m for m in modules if "maxmanager" in m.lower() or "max_manager" in m.lower()]
    if maxmanager:
        competing = [
            m for m in modules
            if m not in maxmanager and any(k in m.lower() for k in MAXMANAGER_COMPETITORS)
        ]
        if competing:
            add(
                kind="MAXMANAGER",
                rule="R01_MAXMANAGER_EXCLUSIVITY",
                severity="CONFLICT",
                modules=maxmanager,
                competing_modules=competing,
                detail="Max Atlas exige exclusividade de escrita em sysfs CPU/GPU/Thermal/ZRAM",
            )
        out_of_scope = []
        for fname, meta in modules.items():
            for member, text in meta["texts"].items():
                if not (member.endswith("sysctl.conf") or "sysctl" in member.lower()):
                    continue
                for line in text.splitlines():
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    key = line.split("=", 1)[0].strip()
                    if not any(k in key for k in SYSCTL_INTRANET_KEYS):
                        out_of_scope.append({"module": fname, "file": member, "key": key})
        if out_of_scope:
            add(
                kind="SYSCTL",
                rule="R02_MAXMANAGER_SYSCTL_SCOPE",
                severity="WARN",
                entries=out_of_scope,
                detail="com MaxManager ativo, sysctl manual so pode tratar port-forward de intranet (M11)",
            )

    # ---------- R04: Duck-ToolBox consolidacao ----------
    duck = [m for m in modules if "duck" in m.lower() and "toolbox" in m.lower()]
    if duck:
        avulsos = [m for m in modules if m not in duck and any(k in m.lower() for k in SPOOF_MODULE_HINTS)]
        if avulsos:
            add(
                kind="DUCK",
                rule="R04_DUCK_TOOLBOX_CONSOLIDATION",
                severity="WARN",
                modules=duck,
                redundant_modules=avulsos,
                detail="Duck-ToolBox ja entrega M07/M08 (perfis RKP, X.509, ferramentas); remover avulsos evita conflito de escopo",
            )

    # ---------- R05: GenieX NPU bound ----------
    geniex = [m for m in modules if "geniex" in m.lower() or "genie" in m.lower()]
    if geniex:
        bound = any(
            "adsprpc" in text
            for m in geniex
            for text in modules[m]["texts"].values()
        )
        if not bound:
            add(
                kind="GENIEX",
                rule="R05_GENIEX_NPU_DEVICE_UNBOUND",
                severity="WARN",
                modules=geniex,
                detail="GenieX precisa de acesso a /dev/adsprpc-smd (bind explicito dentro de DroidSpaces)",
            )

    # ---------- R09: ordem das ondas ----------
    waves = sorted({m["wave"] for m in modules.values() if m["wave"]})
    if 1 not in waves and any(w and w > 1 for w in waves):
        add(
            kind="WAVE",
            rule="R09_WAVE_ORDER_VIOLATION",
            severity="WARN",
            waves=waves,
            detail="nenhum modulo de fundacao (Wave 1: kernel/root/DroidSpaces) presente antes de ondas superiores",
        )

    status = "CONFLICT" if conflicts else ("WARN" if warnings else "CLEAN")
    for rule in sorted({c["rule"] for c in conflicts}):
        checks.append({"rule": rule, "severity": "CONFLICT", "count": sum(c["rule"] == rule for c in conflicts)})
    for rule in sorted({w["rule"] for w in warnings}):
        checks.append({"rule": rule, "severity": "WARN", "count": sum(w["rule"] == rule for w in warnings)})

    return {
        "status": status,
        "modules_dir": modules_dir,
        "module_count": len(modules),
        "waves": waves,
        "modules": {m: {"wave": meta["wave"], "members": meta["members"]} for m, meta in modules.items()},
        "conflicts": conflicts,
        "warnings": warnings,
        "checks": checks,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="CONFLICT-INQUISITOR v3.1 - auditoria estatica pre-boot (15 modulos + 3 plataformas)"
    )
    parser.add_argument("positional_dir", nargs="?", default=None, help="(compat) diretorio de modulos")
    parser.add_argument("--modules-dir", default=None)
    parser.add_argument("--out", default=os.path.join("work", "conflict_report.json"))
    parser.add_argument("--strict", action="store_true", help="trata WARN como falha")
    parser.add_argument("--json", action="store_true", help="imprime o relatorio completo no stdout")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    modules_dir = args.modules_dir or args.positional_dir or "./modules"
    report = scan_modules(modules_dir)

    if args.out:
        out_dir = os.path.dirname(os.path.abspath(args.out))
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2, ensure_ascii=False)

    if not args.quiet:
        if args.json:
            print(json.dumps(report, indent=2, ensure_ascii=False))
        else:
            print(
                f"[CONFLICT-INQUISITOR] status={report['status']} "
                f"modulos={report.get('module_count', 0)} ondas={report.get('waves', [])}"
            )
            for item in report.get("conflicts", []):
                print(f"  FAIL {item['rule']}: {item.get('detail', '')}")
            for item in report.get("warnings", []):
                print(f"  WARN {item['rule']}: {item.get('detail', '')}")

    if report["status"] == "ERROR":
        return 2
    if report["status"] == "CONFLICT":
        return 1
    if report["status"] == "WARN" and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
