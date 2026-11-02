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

if [ ! -f "$ROM_DIR/boot.img" ]; then
  echo "[ERRO] boot.img ausente em $ROM_DIR — nada foi patchado (não é sucesso)" >&2
  exit 3
fi

cd "$ROM_DIR"
cp -f boot.img boot_stock_rollback.img
sha256sum boot_stock_rollback.img > boot_stock_rollback.img.sha256
echo "[GUARD-4] Backup stock salvo: boot_stock_rollback.img"

if [ "$ROOT_METHOD" = "apatch" ]; then
  if ! command -v kptools >/dev/null 2>&1 || [ ! -f "${HOME}/bin/kpimg" ]; then
    echo "[PENDENTE] kptools e/ou kpimg ausentes — patch APatch NÃO aplicado" >&2
    exit 4
  fi
  echo "[*] Extraindo Kernel de boot.img para injecao APatch/KPM (Guard-4)..."
  abootimg -x boot.img >/dev/null 2>&1 || magiskboot unpack boot.img >/dev/null 2>&1 || {
    echo "[ERRO] nenhum desempacotador de boot.img disponivel (abootimg/magiskboot)" >&2
    exit 4
  }
  cp -f kernel kernel_stock_extracted
  SUPERKEY="${APATCH_SUPERKEY:-EvoxTestKey2026}"
  kptools -p --image kernel --skey "$SUPERKEY" --kpimg "${HOME}/bin/kpimg" --out kernel_patched
  for kpm in "$OLDPWD/$MODULES_DIR"/*.kpm; do
    [ -e "$kpm" ] || continue
    echo "[+] Embutindo modulo de Kernel (KPM): $(basename "$kpm")"
    kptools -p --image kernel_patched --skey "$SUPERKEY" --kpm "$kpm" --out kernel_patched
  done
  mv -f kernel_patched kernel
  if [ -f "bootimg.cfg" ]; then
    abootimg --create boot_patched.img -f bootimg.cfg -k kernel -r initrd.img
  else
    magiskboot repack boot.img boot_patched.img
  fi
  sha256sum boot_patched.img > boot_patched.img.sha256
  if cmp -s kernel kernel_stock_extracted; then
    echo "[ERRO] kernel idêntico ao stock extraído — patch NÃO aplicado" >&2
    rm -f boot_patched.img
    exit 5
  fi
fi
echo "[OK] Estagio A (EVOX-FORGE) concluido."
