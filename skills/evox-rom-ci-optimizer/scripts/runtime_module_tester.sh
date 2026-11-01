#!/usr/bin/env bash
# =============================================================================
# CI-SANDBOX-PROBE v3.1 — [Estagio B] Teste dinamico na AVD (API 36 x86_64) via ADB
# =============================================================================
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "uso: $(basename "$0") — este comando só executa com argumentos explícitos"
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

MODULES_DIR="${1:-./modules}"

echo "[*] Aguardando ADB e sys.boot_completed=1 no emulador (AVD)..."
adb wait-for-device
adb root || true

timeout 180 bash -c 'until [[ "$(adb shell getprop sys.boot_completed | tr -d "\r")" == "1" ]]; do sleep 2; done'

echo "[+] Sistema base emulado inicializado. Injetando ambiente de modulos em /data/adb/modules..."
adb shell "mkdir -p /data/adb/modules /data/local/Droidspaces/bin"

for modzip in "$MODULES_DIR"/*.zip; do
  [ -e "$modzip" ] || continue
  modname="$(basename "$modzip" .zip)"
  echo "[*] Instalando e testando modulo em runtime: $modname"
  adb push "$modzip" "/data/local/tmp/$modname.zip"
  adb shell "mkdir -p /data/adb/modules/$modname && unzip -o -q /data/local/tmp/$modname.zip -d /data/adb/modules/$modname"
  adb shell "if [ -f /data/adb/modules/$modname/post-fs-data.sh ]; then timeout 8 sh -x /data/adb/modules/$modname/post-fs-data.sh; fi"
  adb shell "if [ -f /data/adb/modules/$modname/service.sh ]; then sh -x /data/adb/modules/$modname/service.sh </dev/null >/dev/null 2>&1 & fi"
done

if [ -f "./patches/sysctl.conf" ]; then
  adb push ./patches/sysctl.conf /data/local/tmp/sysctl.conf
  adb shell "sysctl -p /data/local/tmp/sysctl.conf || true"
fi

echo "[*] Realizando Soft-Reboot (Zygote restart) para validar estabilidade pos-injecao..."
adb shell "logcat -c"
adb shell "stop; start"

timeout 120 bash -c 'until [[ "$(adb shell getprop init.svc.bootanim | tr -d "\r")" == "stopped" ]]; do sleep 2; done'

CRASHES="$(adb shell "logcat -d -b crash | grep -E 'FATAL EXCEPTION|SIGSEGV|SIGABRT|RescueParty' || true")"
if [ -n "$CRASHES" ]; then
  echo "[!] FALHA DE RUNTIME DETECTADA APOS INJECAO DE MODULOS:"
  echo "$CRASHES"
  exit 1
fi

echo "[OK] Validacao na AVD concluida sem crashes de Zygote ou SystemServer (nao prova boot do pong arm64)."
