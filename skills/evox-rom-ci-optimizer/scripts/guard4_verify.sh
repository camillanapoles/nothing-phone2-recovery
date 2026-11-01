#!/usr/bin/env bash
# =============================================================================
# guard4_verify.sh — prova de rollback: backup do boot.img íntegro e idêntico à ROM
# -----------------------------------------------------------------------------
# Antes de qualquer flash: o backup stock tem que existir, ter hash próprio e ser
# byte-idêntico ao boot.img do pacote oficial (L4). Sem isso, exit != 0.
#
# Uso:
#   ./guard4_verify.sh --boot ./workspace/rom_assets/boot.img \
#                      --backup ./workspace/out/boot_stock_rollback.img \
#                      [--sha-file ./workspace/out/boot_stock_rollback.img.sha256] \
#                      [--rom-assets ./workspace/rom_assets/rom_assets.json] [--json]
#
# Exit: 0 = rollback verificado · 2 = uso · 3 = arquivo ausente · 4 = hash divergente
# =============================================================================
set -uo pipefail

BOOT=""; BACKUP=""; SHAF=""; ROM=""; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --boot) BOOT="$2"; shift 2 ;;
    --backup) BACKUP="$2"; shift 2 ;;
    --sha-file) SHAF="$2"; shift 2 ;;
    --rom-assets) ROM="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$BOOT" && -n "$BACKUP" ]] || { echo "Uso: $0 --boot <stock.img> --backup <rollback.img> [--sha-file F] [--rom-assets F] [--json]" >&2; exit 2; }

python3 - "$BOOT" "$BACKUP" "$SHAF" "$ROM" "$JSON" <<'PY'
import hashlib, json, os, sys

boot, backup, shaf, romp, as_json = sys.argv[1:6]
as_json = as_json == "1"
checks = []
def add(n, ok, d=""): checks.append({"check": n, "ok": bool(ok), "detail": d})
def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""): h.update(c)
    return h.hexdigest()

add("stock_existe", os.path.isfile(boot), boot)
add("backup_existe", os.path.isfile(backup), backup)
if os.path.isfile(boot) and os.path.isfile(backup):
    hb, hr = sha(boot), sha(backup)
    add("backup_identico_ao_stock", hb == hr, f"stock {hb[:12]}… backup {hr[:12]}…")
    if shaf:
        ok = False; detail = f"{shaf} ausente"
        if os.path.isfile(shaf):
            txt = open(shaf).read().split()
            ok = bool(txt) and txt[0].lower() == hr
            detail = f".sha256 {txt[0][:12] if txt else '?'}… vs backup {hr[:12]}…"
        add("arquivo_sha256_confere", ok, detail)
    if romp:
        ok = False; detail = f"{romp} ausente"
        if os.path.isfile(romp):
            try:
                man = json.load(open(romp))
                want = (man.get("images") or {}).get("boot.img", {}).get("sha256")
                ok = bool(want) and want == hr
                detail = f"rom_assets {str(want)[:12]}… vs backup {hr[:12]}…"
            except Exception as exc:
                detail = f"rom_assets inválido: {exc}"
        add("igual_ao_pacote_oficial", ok, detail)

bad = [c for c in checks if not c["ok"]]
missing = any(c["check"].endswith("_existe") and not c["ok"] for c in checks)
verdict = "VERIFIED" if not bad else ("MISSING" if missing else "MISMATCH")
payload = {"verdict": verdict, "checks": checks,
           "reasons": [f"{c['check']}: {c['detail']}" for c in bad]}
if as_json: print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    for c in checks: print(f"  {'OK   ' if c['ok'] else 'FALHA'} {c['check']:<26} {c['detail']}")
    print(f"[guard4] {verdict}" + ("" if not bad else " — " + "; ".join(payload["reasons"])))
sys.exit(0 if verdict == "VERIFIED" else (3 if verdict == "MISSING" else 4))
PY
