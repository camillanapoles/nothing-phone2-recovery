#!/usr/bin/env bash
# =============================================================================
# A16-SENTINEL · T01 — Coletor de evidência primária (read-only, zero mutação)
# -----------------------------------------------------------------------------
# Fecha a lacuna L2: a skill era 100% doutrina e dependia de digitação manual.
# Toda inferência passa a ter output real + hash, conforme o Princípio 1
# ("Evidência Primária Obrigatória") do SKILL.md.
#
# Uso:
#   ./collect_evidence.sh [--out DIR] [--serial SERIAL] [--local] [--timeout N]
#
#   --local     coleta no próprio aparelho (Termux com root/ADB local)
#   ADB_BIN     override do binário adb (usado nos testes com stub)
#
# Saída: DIR/raw/*.txt + DIR/evidence.json + DIR/MANIFEST.sha256
# Exit:  0 = evidência completa | 3 = adb/device indisponível
#        4 = evidência parcial (boot não concluído) | 2 = erro de uso
# =============================================================================
set -uo pipefail

OUT_DIR="./evidence/$(date -u +%Y%m%dT%H%M%SZ)"
SERIAL=""
LOCAL=0
TIMEOUT=20
ADB="${ADB_BIN:-adb}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    --serial) SERIAL="$2"; shift 2 ;;
    --local) LOCAL=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR/raw" || { echo "nao consigo criar $OUT_DIR" >&2; exit 2; }

# executa um comando no alvo (device via adb ou local)
run() {
  if [[ "$LOCAL" -eq 1 ]]; then
    timeout "$TIMEOUT" sh -c "$*" 2>/dev/null
  else
    if [[ -n "$SERIAL" ]]; then
      timeout "$TIMEOUT" "$ADB" -s "$SERIAL" shell "$*" 2>/dev/null
    else
      timeout "$TIMEOUT" "$ADB" shell "$*" 2>/dev/null
    fi
  fi
}

raw() { # raw <arquivo> <comando>
  local file="$OUT_DIR/raw/$1"; shift
  run "$*" | tr -d '\r' > "$file"
  printf '%-28s %6s B\n' "$1" "$(wc -c < "$file" 2>/dev/null || echo 0)"
}

if [[ "$LOCAL" -eq 0 ]]; then
  if ! command -v "$ADB" >/dev/null 2>&1; then
    echo "[ERRO] '$ADB' nao encontrado no PATH (use --local ou instale android-tools-adb)" >&2
    exit 3
  fi
  if ! timeout "$TIMEOUT" "$ADB" ${SERIAL:+-s "$SERIAL"} get-state >/dev/null 2>&1; then
    echo "[ERRO] nenhum device autorizado em '$ADB devices'" >&2
    exit 3
  fi
fi

echo "[1/4] Identidade, build, slot e KMI"
raw getprop.txt 'getprop' 
run 'getprop ro.build.version.sdk' > "$OUT_DIR/raw/sdk.txt"
run 'getprop ro.build.version.release' > "$OUT_DIR/raw/release.txt"
run 'getprop ro.boot.slot_suffix' > "$OUT_DIR/raw/slot.txt"
run 'getprop ro.product.device' > "$OUT_DIR/raw/device.txt"
run 'uname -a' > "$OUT_DIR/raw/uname.txt"
run 'cat /proc/version' > "$OUT_DIR/raw/proc_version.txt"

echo "[2/4] Engine de root, módulos e política SELinux"
raw root_engine.txt 'for b in apd ksud magisk; do command -v $b >/dev/null 2>&1 && echo "$b: $(command -v $b)"; done'
raw modules.txt 'ls -1 /data/adb/modules 2>/dev/null'
raw selinux.txt 'getenforce 2>/dev/null || cat /sys/fs/selinux/enforce 2>/dev/null'
raw avc_denials.txt 'dmesg 2>/dev/null | grep -c "avc: denied" || echo 0'

echo "[3/4] Telemetria de boot e estabilidade"
raw boot_completed.txt 'getprop sys.boot_completed'
raw logcat_crash.txt 'logcat -d -b crash -t 400 2>/dev/null | grep -E "FATAL EXCEPTION|SIGSEGV|RescueParty" | tail -50'
raw dmesg.txt 'dmesg 2>/dev/null | tail -200'
raw meminfo.txt 'cat /proc/meminfo 2>/dev/null | head -20'
raw df.txt 'df -h /data /system 2>/dev/null'

echo "[4/4] Consolidando evidence.json + manifesto SHA-256"
BOOT_COMPLETED="$(tr -d '\r\n' < "$OUT_DIR/raw/boot_completed.txt" 2>/dev/null)"
AVC_COUNT="$(tr -dc '0-9' < "$OUT_DIR/raw/avc_denials.txt" 2>/dev/null)"
SDK="$(tr -d '\r\n' < "$OUT_DIR/raw/sdk.txt" 2>/dev/null)"
SLOT="$(tr -d '\r\n' < "$OUT_DIR/raw/slot.txt" 2>/dev/null)"
DEVICE="$(tr -d '\r\n' < "$OUT_DIR/raw/device.txt" 2>/dev/null)"
SELINUX="$(tr -d '\r\n' < "$OUT_DIR/raw/selinux.txt" 2>/dev/null)"
ROOT_ENGINE="$(tr '\n' ' ' < "$OUT_DIR/raw/root_engine.txt" 2>/dev/null | sed 's/  */ /g')"
CRASHES="$(grep -c . "$OUT_DIR/raw/logcat_crash.txt" 2>/dev/null || true)"

python3 - "$OUT_DIR" "$BOOT_COMPLETED" "$AVC_COUNT" "$SDK" "$SLOT" "$DEVICE" "$SELINUX" "$ROOT_ENGINE" "${CRASHES:-0}" <<'PY'
import hashlib, json, os, sys
out, boot, avc, sdk, slot, device, selinux, engine, crashes = sys.argv[1:10]
raw = os.path.join(out, "raw")
files = {}
for name in sorted(os.listdir(raw)):
    path = os.path.join(raw, name)
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    files[name] = {"sha256": h.hexdigest(), "size_bytes": os.path.getsize(path)}
evidence = {
    "collector": "a16-sentinel/collect_evidence.sh",
    "device": {"codename": device, "sdk": sdk, "slot": slot},
    "boot": {"sys_boot_completed": boot, "ok": boot == "1"},
    "selinux": {"mode": selinux, "enforcing_ok": selinux.strip() == "Enforcing"},
    "root_engine": engine.strip(),
    "stability": {
        "avc_denied_count": int(avc or 0),
        "crash_lines": int(crashes or 0),
    },
    "files": files,
}
with open(os.path.join(out, "evidence.json"), "w", encoding="utf-8") as fh:
    json.dump(evidence, fh, indent=2, ensure_ascii=False)
lines = [f"{meta['sha256']}  raw/{name}" for name, meta in files.items()]
open(os.path.join(out, "MANIFEST.sha256"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(json.dumps({"boot_ok": evidence["boot"]["ok"], "selinux": selinux,
                  "crash_lines": evidence["stability"]["crash_lines"],
                  "artifacts": len(files)}, ensure_ascii=False))
PY

echo "-----------------------------------------------------------------------"
echo "evidência em: $OUT_DIR"
echo "verificar:    (cd $OUT_DIR && sha256sum -c MANIFEST.sha256 --quiet) && echo OK"

if [[ "$BOOT_COMPLETED" != "1" ]]; then
  echo "[PARCIAL] sys.boot_completed='$BOOT_COMPLETED' — coleta registrada, mas o boot nao concluiu." >&2
  exit 4
fi
exit 0
