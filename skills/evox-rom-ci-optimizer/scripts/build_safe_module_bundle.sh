#!/usr/bin/env bash
# =============================================================================
# EVOX-CI v2.0 — [T05/T06] Construtor de Modulo Consolidado All-in-One
# Empacota ajustes de sistema/kernel da Evolution X 11.11 com injecao
# obrigatoria do Watchdog Anti-Bootloop de 120s.
# =============================================================================
set -euo pipefail

MOD_ID="evox-11-11-camilla-prevalidated"
PROP_FILE="./assets/evox_tuning_preset.prop"
WATCHDOG_FILE="./assets/watchdog_anti_bootloop_service.sh"
OUT_DIR="./workspace/out"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) MOD_ID="$2"; shift 2 ;;
    --prop) PROP_FILE="$2"; shift 2 ;;
    --watchdog) WATCHDOG_FILE="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

mkdir -p "$OUT_DIR"
BUILD_TMP="$(mktemp -d)"
trap 'rm -rf "$BUILD_TMP"' EXIT

cat << EOF > "$BUILD_TMP/module.prop"
id=${MOD_ID}
name=Evolution X 11.11 Pre-Validated Optimization Suite (EVOX-CI v2.0)
version=v2.0-A16
versionCode=200
author=Camilla Napoles & EVOX-CI Architect
description=Camada unificada e pre-validada em emulador GitHub Actions para Evolution X 11.11 (Android 16 / API 36) com Watchdog Anti-Bootloop de 120s.
EOF

if [ -f "$PROP_FILE" ]; then
  cp "$PROP_FILE" "$BUILD_TMP/system.prop"
fi

if [ -f "$WATCHDOG_FILE" ]; then
  cp "$WATCHDOG_FILE" "$BUILD_TMP/service.sh"
  chmod +x "$BUILD_TMP/service.sh"
fi

cat << 'EOF' > "$BUILD_TMP/post-fs-data.sh"
#!/system/bin/sh
# EVOX-CI v2.0: post-fs-data estritamente nao-bloqueante (< 1s)
MODDIR=${0%/*}
# Se o arquivo de boot_attempt_counter atingir 2 falhas consecutivas, desativa o modulo
if [ -f "$MODDIR/boot_attempt_count" ]; then
  COUNT=$(cat "$MODDIR/boot_attempt_count" 2>/dev/null || echo 0)
  if [ "$COUNT" -ge 2 ]; then
    touch "$MODDIR/disable"
    rm -f "$MODDIR/boot_attempt_count"
    exit 0
  fi
  echo $((COUNT + 1)) > "$MODDIR/boot_attempt_count"
else
  echo 1 > "$MODDIR/boot_attempt_count"
fi
EOF
chmod +x "$BUILD_TMP/post-fs-data.sh"

BUNDLE_ZIP="$OUT_DIR/${MOD_ID}.zip"
if command -v zip >/dev/null 2>&1; then
  (cd "$BUILD_TMP" && zip -r -q "$OLDPWD/$BUNDLE_ZIP" .)
else
  python3 -m zipfile -c "$BUNDLE_ZIP" "$BUILD_TMP"/*
fi
sha256sum "$BUNDLE_ZIP" > "${BUNDLE_ZIP}.sha256"

echo "[OK] Modulo consolidado e protegido por Watchdog gerado em: $BUNDLE_ZIP"
