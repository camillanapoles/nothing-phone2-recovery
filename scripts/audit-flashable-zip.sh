#!/bin/bash
# audit-flashable-zip.sh — Audit AnyKernel3 ZIP contents and integrity
# Usage: bash scripts/audit-flashable-zip.sh [zip_path]
# Validates: file structure, checksums, device compatibility markers

set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "uso: $(basename "$0") — só executa com argumentos explícitos"
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

ZIP_PATH="${1:-}"
RELEASE_DIR="${ZIP_PATH%/.*}"  # Get directory from zip path

echo "=== Flashable ZIP Audit ==="

# Find ZIP if not specified
if [[ -z "${ZIP_PATH}" ]]; then
  ZIP_PATH=$(find "${RELEASE_DIR:-.}" -name "*.zip" -not -name "*sources*" | head -1)
fi

if [[ -z "${ZIP_PATH}" ]] || [[ ! -f "${ZIP_PATH}" ]]; then
  echo "  [ERROR] No ZIP file found for audit"
  exit 1
fi

echo "  ZIP: ${ZIP_PATH}"
echo "  Size: $(du -h "${ZIP_PATH}" | cut -f1)"

# Integridade: hash ausente NÃO é gerado pelo próprio auditor (evidência não se auto-emite)
if [[ ! -f "${ZIP_PATH}.sha256" ]]; then
  echo "  [ERROR] Manifesto de integridade ausente: ${ZIP_PATH}.sha256"
  echo "  [PENDENTE] Auditoria NÃO executada — gere o sha256 na origem (build), não aqui"
  exit 3
fi

echo "  [CHECKSUM] Verifying SHA256..."
if ! (cd "$(dirname "${ZIP_PATH}")" && sha256sum -c "$(basename "${ZIP_PATH}").sha256"); then
  echo "  [CHECKSUM] ✗ SHA256 mismatch!"
  exit 1
fi
echo "  [CHECKSUM] ✓ SHA256 verified"

echo "  [CONTENT] ZIP contents:"
ZIP_PATH="$ZIP_PATH" python3 - << 'PYEOF'
import os, sys, zipfile

zip_path = os.environ["ZIP_PATH"]
required = ["META-INF/com/google/android/updater-script"]
optional = ["boot.img", "Image", "Image.gz", "dtbo.img", "vendor_boot.img", "init_boot.img"]

with zipfile.ZipFile(zip_path, "r") as z:
    names = z.namelist()
    infos = z.infolist()
print(f"  Total files: {len(names)}")
print(f"  Total size: {sum(i.file_size for i in infos) / 1024 / 1024:.2f} MB")

missing = [r for r in required if not any(r in n for n in names)]
found = [o for o in optional if any(o in n for n in names)]
print("  Kernel images: " + (", ".join(found) if found else "nenhuma (WARNING)"))

for n in sorted(names)[:30]:
    print(f"    {n}")

if missing:
    print("  [VETO] ZIP não flashável — faltando: " + ", ".join(missing))
    raise SystemExit(1)
print("  [OK] Estrutura mínima de ZIP flashável presente")
PYEOF

echo "  [AUDIT] Complete"
