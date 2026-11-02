#!/usr/bin/env bash
# =============================================================================
# sandbox_rollout.sh — Stage B: injeta módulos 1 por 1 na AVD via ADB e prova
# -----------------------------------------------------------------------------
# Roda no host do runner (com adb) DEPOIS que a AVD subiu. Não é flash: é
# injeção em /data/adb/modules + soft-reboot (stop/start) + coleta de evidência.
#
# Uso:
#   ./sandbox_rollout.sh --modules ./modules --state references/rollout-ledger.json \
#                        --evidence ./workspace/evidence \
#                        [--boot-timeout 300] [--observe 60] [--min-uptime 1] [--wave W1]
#
# Exit: 0 = todos os módulos PASS · 3 = rollout bloqueado (módulo reprovado)
#       4 = boot não concluiu / adb ausente · 2 = uso
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODULES="./modules"; EVID="./workspace/evidence"
# ledger durável (versionado); workspace é limpo a cada sessão
STATE="${ROLLOUT_LEDGER:-$HERE/../references/rollout-ledger.json}"
BOOT_TIMEOUT=300; OBSERVE=60; MIN_UP=1; WAVE="W1"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --modules) MODULES="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --evidence) EVID="$2"; shift 2 ;;
    --boot-timeout) BOOT_TIMEOUT="$2"; shift 2 ;;
    --observe) OBSERVE="$2"; shift 2 ;;
    --min-uptime) MIN_UP="$2"; shift 2 ;;
    --wave) WAVE="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done

command -v adb >/dev/null 2>&1 || { echo "[ERRO] adb ausente — Stage B não pode rodar" >&2; exit 4; }
GATE="$HERE/rollout_gate.sh"
mkdir -p "$EVID" "$(dirname "$STATE")"

echo "[sandbox] aguardando device..."
adb wait-for-device >/dev/null 2>&1 || { echo "[ERRO] adb wait-for-device falhou" >&2; exit 4; }

deadline=$(( $(date +%s) + BOOT_TIMEOUT ))
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | tr -d ' ')" = "1" ]; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "[ERRO] boot não concluiu em ${BOOT_TIMEOUT}s — capturando evidência de falha"
    adb shell dmesg 2>/dev/null | tail -80 > "$EVID/boot_failure_dmesg.txt" || true
    adb shell logcat -d -b crash 2>/dev/null | tail -80 > "$EVID/boot_failure_logcat.txt" || true
    exit 4
  fi
  sleep 2
done
echo "[sandbox] boot_completed=1"

baseline_avc="$(adb shell 'dmesg 2>/dev/null | grep -c avc' 2>/dev/null | tr -dc '0-9' || true)"; baseline_avc="${baseline_avc:-0}"

[ -d "$MODULES" ] || { echo "[ERRO] diretório de módulos inexistente: $MODULES" >&2; exit 4; }
mapfile -t ZIPS < <(find "$MODULES" -maxdepth 1 -type f -name '*.zip' | sort)
[ "${#ZIPS[@]}" -gt 0 ] || { echo "[ERRO] nenhum .zip em $MODULES" >&2; exit 4; }

pass=0; fail=0
for z in "${ZIPS[@]}"; do
  name="$(basename "$z" .zip)"
  echo "[sandbox] ---- módulo $name ----"
  if ! "$GATE" start --state "$STATE" --wave "$WAVE" --module "$name" --artifact "$z" >/dev/null 2>&1; then
    echo "[BLOQUEADO] rollout_gate recusou $name (módulo anterior sem PASS ou FAILED pendente)"
    exit 3
  fi
  adb push "$z" "/data/local/tmp/$name.zip" >/dev/null 2>&1
  adb shell "rm -rf /data/adb/modules/$name && mkdir -p /data/adb/modules/$name && unzip -o -q /data/local/tmp/$name.zip -d /data/adb/modules/$name" >/dev/null 2>&1
  adb shell "[ -f /data/adb/modules/$name/post-fs-data.sh ] && sh /data/adb/modules/$name/post-fs-data.sh" >/dev/null 2>&1 || true
  adb shell "[ -f /data/adb/modules/$name/service.sh ] && sh /data/adb/modules/$name/service.sh" >/dev/null 2>&1 || true

  adb logcat -c >/dev/null 2>&1 || true
  adb shell 'stop; start' >/dev/null 2>&1 || true
  dl=$(( $(date +%s) + 90 ))
  until [ "$(adb shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' | tr -d ' ')" = "stopped" ] \
        && [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | tr -d ' ')" = "1" ]; do
    [ "$(date +%s)" -ge "$dl" ] && break
    sleep 2
  done
  [ "$OBSERVE" -gt 0 ] && sleep "$OBSERVE"

  crashes="$(adb shell 'logcat -d -b crash 2>/dev/null | grep -cE "FATAL EXCEPTION|SIGSEGV|SIGABRT"' 2>/dev/null | tr -dc '0-9' || true)"; crashes="${crashes:-0}"
  boot_ok="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | tr -d ' ')"
  avc="$(adb shell 'dmesg 2>/dev/null | grep -c avc' 2>/dev/null | tr -dc '0-9' || true)"; avc="${avc:-0}"

  python3 - "$EVID/$name.json" "$name" "$boot_ok" "$crashes" "$OBSERVE" "$avc" "$baseline_avc" <<'PY'
import json, sys, time
path, name, boot_ok, crashes, observe, avc, base = sys.argv[1:8]
json.dump({"module": name, "collected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "environment": "qemu-avd-api36-x86_64",
           "boot": {"ok": boot_ok == "1"},
           "crashes": int(crashes or 0),
           "stability": {"uptime_min": round(float(observe or 0) / 60.0, 2)},
           "avc_denials": int(avc or 0), "avc_baseline": int(base or 0)},
          open(path, "w"), indent=2)
PY

  if "$GATE" record --state "$STATE" --module "$name" --evidence "$EVID/$name.json" \
       --min-uptime 0 >/dev/null 2>&1; then
    echo "PASS  $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name — ver $EVID/$name.json"
    fail=$((fail + 1))
    exit 3
  fi
done

echo "[sandbox] $pass PASS / $fail FAIL · ledger $STATE · evidência $EVID"
exit 0
