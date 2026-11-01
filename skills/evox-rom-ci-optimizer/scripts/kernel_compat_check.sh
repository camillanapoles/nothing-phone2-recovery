#!/usr/bin/env bash
# =============================================================================
# kernel_compat_check.sh — Gate 1: kernel × ROM × device (requisitos 1 e 6)
# -----------------------------------------------------------------------------
# Responde com dado, não com opinião: "este kernel serve para ESTA build no pong?"
# Compara o manifesto do candidato com o rom_assets.json produzido pela L4.
#
# Uso:
#   ./kernel_compat_check.sh --rom-assets rom_assets.json --candidate cand.json [--json]
#
# Exit: 0 = COMPATIBLE · 3 = INCOMPATIBLE · 2 = uso · 4 = entrada inválida/ausente
# =============================================================================
set -uo pipefail

ROM=""; CAND=""; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rom-assets) ROM="$2"; shift 2 ;;
    --candidate) CAND="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$ROM" && -n "$CAND" ]] || { echo "Uso: $0 --rom-assets <rom_assets.json> --candidate <kernel.json> [--json]" >&2; exit 2; }
[[ -f "$ROM" ]]  || { echo "[ERRO] rom_assets.json ausente: $ROM (rode a L4 primeiro)" >&2; exit 4; }
[[ -f "$CAND" ]] || { echo "[ERRO] manifesto do kernel ausente: $CAND" >&2; exit 4; }

python3 - "$ROM" "$CAND" "$JSON" <<'PY'
import json, re, sys

rom_p, cand_p, as_json = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
try:
    rom = json.load(open(rom_p))
    cand = json.load(open(cand_p))
except Exception as exc:
    print(f"[ERRO] JSON inválido: {exc}", file=sys.stderr); sys.exit(4)

checks = []
def add(name, ok, detail=""):
    checks.append({"check": name, "ok": bool(ok), "detail": detail})

rom_zip = (rom.get("source") or {}).get("zip", "") or ""
build = (rom.get("source") or {}).get("build_id") or rom_zip
rom_kernel = rom.get("kernel_version") or ""
rom_kmi = rom.get("kmi") or ""
rom_base = ".".join(rom_kernel.split("-")[0].split(".")[:2]) if rom_kernel else ""

add("l4_fechada", bool(rom.get("l4_closed")), f"l4_closed={rom.get('l4_closed')}")
add("modelo_pong", str(cand.get("model", "")).lower() == "pong", f"model={cand.get('model')}")
soc = str(cand.get("soc", "")).upper()
add("soc_sm8475", soc in ("SM8475", "SM_8475", ""), f"soc={soc or 'não declarado'}")
add("android_api_36", str(cand.get("android_api")) == "36", f"api={cand.get('android_api')}")
add("android_release_16", str(cand.get("android_release", "")).startswith("16"),
    f"release={cand.get('android_release')}")
add("kmi_igual_rom", bool(rom_kmi) and cand.get("kmi") == rom_kmi,
    f"rom={rom_kmi} cand={cand.get('kmi')}")
cand_base = str(cand.get("kernel_base", ""))
add("base_kernel_igual", bool(rom_base) and cand_base == rom_base,
    f"rom={rom_base}.x cand={cand_base}.x")

supported = [str(s) for s in (cand.get("supported_rom_builds") or [])]
match = any(s and (s in build or build in s or s in rom_zip) for s in supported)
add("build_suportada", match, f"build={build or '?'} suportadas={supported or '[]'}")

dev = cand.get("developer_support") or {}
add("suporte_declarado", bool(dev.get("declared")), f"declared={dev.get('declared')}")
add("fonte_do_suporte", str(dev.get("source", "")).startswith("http"), f"source={dev.get('source')}")

add("sha256_declarado", bool(re.fullmatch(r"[0-9a-f]{64}", str(cand.get("sha256", "")))),
    "sha256 do artefato do kernel")
add("origem_https", str(cand.get("source_url", "")).startswith("https://"),
    f"source_url={cand.get('source_url')}")

bad = [c for c in checks if not c["ok"]]
verdict = "COMPATIBLE" if not bad else "INCOMPATIBLE"
payload = {
    "verdict": verdict,
    "rom": {"zip": rom_zip, "kernel_version": rom_kernel, "kmi": rom_kmi, "build": build},
    "candidate": {"name": cand.get("name"), "kmi": cand.get("kmi"),
                  "kernel_base": cand_base, "sha256": cand.get("sha256")},
    "checks": checks,
    "reasons": [f"{c['check']}: {c['detail']}" for c in bad],
}
if as_json:
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print(f"[gate1] kernel × ROM × device — ROM {rom_kernel or '?'} / KMI {rom_kmi or '?'}")
    for c in checks:
        print(f"  {'OK  ' if c['ok'] else 'FALHA'} {c['check']:<22} {c['detail']}")
    print(f"[gate1] {verdict}" + ("" if not bad else " — motivos: " + "; ".join(payload["reasons"])))
sys.exit(0 if verdict == "COMPATIBLE" else 3)
PY