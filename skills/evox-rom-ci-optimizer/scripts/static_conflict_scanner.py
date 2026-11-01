#!/usr/bin/env python3
"""
CONFLICT-INQUISITOR v3.0 — Scanner Estatico de Colisoes Pre-Boot e Arbitragem
de Contratos entre os 15 Modulos + MaxManager, Duck-ToolBox, GenieX e DroidSpaces.
"""
import json, os, sys, zipfile
from collections import defaultdict

modules_dir = sys.argv[1] if len(sys.argv) > 1 else "./modules"
file_map = defaultdict(list)
prop_map = defaultdict(list)
detected_mods = set()
zygisk_providers = []
conflicts = []
warnings = []

if os.path.isdir(modules_dir):
    for fname in sorted(os.listdir(modules_dir)):
        if not fname.endswith(".zip"):
            continue
        detected_mods.add(fname.lower())
        zpath = os.path.join(modules_dir, fname)
        try:
            with zipfile.ZipFile(zpath, "r") as z:
                for member in z.namelist():
                    if member.startswith(("system/", "vendor/", "product/", "system_ext/")) and not member.endswith("/"):
                        file_map[member].append(fname)
                    if "zygisk" in member.lower() and member.endswith(".so"):
                        if any(k in fname.lower() for k in ("zygisk", "rezygisk")):
                            zygisk_providers.append(fname)
                    if member == "system.prop":
                        lines = z.read(member).decode("utf-8", errors="ignore").splitlines()
                        for line in lines:
                            line = line.strip()
                            if line and not line.startswith("#") and "=" in line:
                                key, val = line.split("=", 1)
                                prop_map[key.strip()].append((fname, val.strip()))
        except zipfile.BadZipFile:
            conflicts.append({"type": "CORRUPT_ZIP", "module": fname})

for path, mods in file_map.items():
    if len(mods) > 1:
        conflicts.append({"type": "FILE_OVERWRITE", "target": path, "modules": mods})

for prop, entries in prop_map.items():
    vals = set(v for _, v in entries)
    if len(vals) > 1:
        conflicts.append({"type": "PROP_COLLISION", "property": prop, "definitions": entries})

if len(set(zygisk_providers)) > 1:
    conflicts.append({"type": "DUPLICATE_ZYGISK_PROVIDER", "modules": sorted(set(zygisk_providers))})

if any("droidspaces" in m for m in detected_mods) and any("susfs" in m for m in detected_mods):
    warnings.append({
        "type": "DROIDSPACES_SUSFS_INTERACTION",
        "action_required": "Desativar 'Hide sus mounts for all processes' no SuSFS para permitir boot dos containers DroidSpaces."
    })

if any("maxmanager" in m for m in detected_mods):
    competing = [m for m in detected_mods if any(k in m for k in ("thermal", "governor", "fde", "lkt")) and "maxmanager" not in m]
    if competing:
        conflicts.append({
            "type": "MAXMANAGER_ARBITER_COLLISION",
            "detail": "MaxManager (Max Atlas) exige exclusividade de escrita em sysfs CPU/GPU/Thermal.",
            "competing_modules": competing
        })

os.makedirs("work", exist_ok=True)
report = {"status": "CONFLICT" if conflicts else "CLEAN", "conflicts": conflicts, "warnings": warnings}
with open("work/conflict_report.json", "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)

if conflicts:
    print(f"[!] ALERTA DE CONFLITO ESTATICO DETECTADO: {json.dumps(report, indent=2)}")
    sys.exit(1)
print("[OK] Zero colisoes estaticas de overlay, system.prop ou arbitragem entre os modulos.")
