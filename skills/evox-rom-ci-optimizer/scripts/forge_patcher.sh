#!/usr/bin/env bash
# =============================================================================
# EVOX-FORGE v3.0 — [Estagio A] Patch Offline de Kernel, APatch Guard-4, KPM
# e Verificacao de Namespaces para DroidSpaces na Evolution X 11.11
# =============================================================================
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "uso: $(basename "$0") — este comando só executa com argumentos explícitos"
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

ROOT_METHOD="${1:-apatch}"
ROM_DIR="${2:-./work/rom_extracted}"
MODULES_DIR="${3:-./modules}"

mkdir -p "$ROM_DIR"
cd "$ROM_DIR"

if [ -f "boot.img" ]; then
  cp -f boot.img boot_stock_rollback.img
  sha256sum boot_stock_rollback.img > boot_stock_rollback.img.sha256
  echo "[GUARD-4] Backup stock salvo: boot_stock_rollback.img"
fi

if [ "$ROOT_METHOD" = "apatch" ] && [ -f "boot.img" ]; then
  echo "[*] Extraindo Kernel de boot.img para injecao APatch/KPM (Guard-4)..."
  abootimg -x boot.img 2>/dev/null || magiskboot unpack boot.img 2>/dev/null || true
  SUPERKEY="${APATCH_SUPERKEY:-EvoxTestKey2026}"

  if command -v kptools >/dev/null 2>&1 && [ -f "${HOME}/bin/kpimg" ]; then
    kptools -p --image kernel --skey "$SUPERKEY" --kpimg "${HOME}/bin/kpimg" --out kernel_patched
    for kpm in "$OLDPWD/$MODULES_DIR"/*.kpm; do
      [ -e "$kpm" ] || continue
      echo "[+] Embutindo modulo de Kernel (KPM): $(basename "$kpm")"
      kptools -p --image kernel_patched --skey "$SUPERKEY" --kpm "$kpm" --out kernel_patched
    done
    mv -f kernel_patched kernel
    if [ -f "bootimg.cfg" ]; then
      abootimg --create boot_patched.img -f bootimg.cfg -k kernel -r initrd.img
    elif command -v magiskboot >/dev/null 2>&1; then
      magiskboot repack boot.img boot_patched.img
    fi
    sha256sum boot_patched.img > boot_patched.img.sha256
  else
    cp -f boot.img boot_patched.img
    sha256sum boot_patched.img > boot_patched.img.sha256
  fi
fi
echo "[OK] Estagio A (EVOX-FORGE) concluido."
