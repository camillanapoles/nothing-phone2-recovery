#!/usr/bin/env bash
# =============================================================================
# abl_fallback_probe.sh — captura e classifica falha de boot no A/B (HIL)
# -----------------------------------------------------------------------------
# Problema real: o ABL/devem fazer fallback confiável para falha CEDO (kernel não
# sobe). Travamento DEPOIS do kernel (system_server/watchdog) pode deixar o
# aparelho no slot de teste sem o bootloader perceber. Este probe distingue:
#
#   OK           boot_completed=1 e slot bootado == staging        (exit 0)
#   ABL_FALLBACK slot bootado == produção (o bootloader já voltou)  (exit 3)
#   HANG         adb responde, boot_completed=0 até o timeout       (exit 4)
#   BOOTLOADER   sem adb, mas o fastboot enxerga o aparelho         (exit 5)
#   NO_DEVICE    nem adb nem fastboot                               (exit 5)
#
# A distinção HANG × falha cedo usa as marcas que o 00_slot_router.sh grava no
# post-fs-data:
#   marca presente + sem boot_completed  → morreu no userspace (pós-kernel)
#   marca ausente + sem boot_completed   → morreu antes do userspace (kernel/ABL)
#
# Uso:
#   ./abl_fallback_probe.sh --staging b --prod a --timeout 180 \
#                           --evidence ./workspace/evidence [--rollback] [--json]
#
# Exit: 0 ok · 2 uso · 3 fallback · 4 hang · 5 sem device/bootloader
# =============================================================================
set -uo pipefail

STAGING="b"; PROD="a"; TIMEOUT=180; EVID="./workspace/evidence"; ROLLBACK=0; JSON=0
ADB="${ADB_BIN:-adb}"; FB="${FASTBOOT_BIN:-fastboot}"; SR_STATE="${SR_STATE:-/data/adb/slot_router}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging) STAGING="$2"; shift 2 ;;
    --prod) PROD="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --evidence) EVID="$2"; shift 2 ;;
    --rollback) ROLLBACK=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done
[[ "$STAGING" != "$PROD" ]] || { echo "[ERRO] staging e produção iguais" >&2; exit 2; }
command -v "$ADB" >/dev/null 2>&1 || { echo "[ERRO] adb ausente ($ADB)" >&2; exit 5; }
mkdir -p "$EVID"

prop() { "$ADB" shell getprop "$1" 2>/dev/null | tr -d '\r\n '; }
adb_has_device() { "$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device"{f=1} END{exit f?0:1}'; }

booted=0
deadline=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if adb_has_device && [ "$(prop sys.boot_completed)" = "1" ]; then booted=1; break; fi
  sleep 2
done

slot=""; [ "$booted" -eq 1 ] && slot="$(prop ro.boot.slot_suffix)"

marks=""
if adb_has_device; then
  marks="$("$ADB" shell "su -c 'ls -1 $SR_STATE/marks 2>/dev/null'" 2>/dev/null | tr -d '\r' | tr '\n' ',' | sed 's/,$//')"
fi

collect() {  # collect <arquivo> <comando-adb>
  [ -n "${1:-}" ] || return 0
  "$ADB" shell "$2" >"$EVID/$1" 2>/dev/null || true
}

if [ "$booted" -eq 1 ]; then
  if [ "$slot" = "_$STAGING" ]; then
    classification="OK"; code=0
    recommendation="seguir para o canário (rollout_gate) e coleta de evidência"
  else
    classification="ABL_FALLBACK"; code=3
    recommendation="bootloader reverteu para $slot: quarentena + diagnóstico do slot $STAGING"
    collect "fallback_dmesg.txt" "su -c 'dmesg | tail -120'"
    collect "fallback_logcat_crash.txt" "su -c 'logcat -d -b crash | tail -120'"
    collect "fallback_pstore.txt" "su -c 'cat /sys/fs/pstore/console-ramoops-0 2>/dev/null'"
  fi
else
  if adb_has_device; then
    collect "hang_dmesg.txt" "su -c 'dmesg | tail -200'"
    collect "hang_logcat_crash.txt" "su -c 'logcat -d -b crash | tail -200'"
    collect "hang_pstore.txt" "su -c 'cat /sys/fs/pstore/console-ramoops-0 2>/dev/null'"
    collect "hang_dumpsys.txt" "dumpsys activity activities 2>/dev/null | head -80"
    if [ -n "$marks" ]; then
      classification="HANG"; code=4
      recommendation="userspace alcançado e travado: coletar pstore, forçar rollback para $PROD"
    else
      classification="HANG_EARLY"; code=4
      recommendation="sem marca de post-fs-data: falha antes do userspace (kernel/ramdisk)"
    fi
  else
    if "$FB" devices 2>/dev/null | grep -q .; then
      classification="BOOTLOADER"; code=5
      recommendation="aparelho no bootloader: restaurar slot $PROD e investigar o flash"
    else
      classification="NO_DEVICE"; code=5
      recommendation="sem adb e sem fastboot: verificar cabo/porta antes de concluir qualquer causa"
    fi
  fi
fi

rolled=0
if [ "$ROLLBACK" -eq 1 ] && { [ "$classification" = "HANG" ] || [ "$classification" = "HANG_EARLY" ]; }; then
  if command -v "$FB" >/dev/null 2>&1; then
    "$FB" --set-active="$PROD" >/dev/null 2>&1 || true
    "$FB" reboot >/dev/null 2>&1 || true
    rolled=1
  fi
fi

python3 - "$EVID/boot_probe.json" "$classification" "$code" "$STAGING" "$PROD" \
  "$slot" "$booted" "$marks" "$recommendation" "$rolled" "$TIMEOUT" <<'PY'
import json, os, sys, time
path, cls, code, stg, prd, slot, booted, marks, rec, rolled, timeout = sys.argv[1:12]
files = sorted(f for f in os.listdir(os.path.dirname(path) or ".") if f.endswith(".txt"))
json.dump({
    "schema": "evox-boot-probe/1",
    "classified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "classification": cls, "exit_code": int(code),
    "staging_slot": f"_{stg}", "prod_slot": f"_{prd}",
    "booted_slot": slot or None, "boot_completed": bool(int(booted)),
    "marks": [m for m in marks.split(",") if m],
    "marks_present": bool(marks),
    "timeout_s": int(timeout), "rollback_executed": bool(int(rolled)),
    "recommendation": rec, "evidence_files": files,
}, open(path, "w"), indent=2, ensure_ascii=False)
PY

if [ "$JSON" -eq 1 ]; then
  cat "$EVID/boot_probe.json"
else
  echo "[probe] $classification — slot bootado: ${slot:-nenhum} · marcas: ${marks:-nenhuma}"
  echo "[probe] ação: $recommendation"
  [ "$rolled" -eq 1 ] && echo "[probe] rollback executado para _$PROD"
  echo "[probe] evidência: $EVID/boot_probe.json"
fi
exit "$code"
