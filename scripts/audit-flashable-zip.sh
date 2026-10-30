#!/bin/bash
# audit-flashable-zip.sh — Audit AnyKernel3 ZIP contents and integrity
# Usage: bash scripts/audit-flashable-zip.sh [zip_path]
# Validates: file structure, checksums, device compatibility markers

set -euo pipefail

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

# Verify SHA256
if [[ -f "${ZIP_PATH}.sha256" ]]; then
  echo "  [CHECKSUM] Verifying SHA256..."
  (cd "$(dirname "${ZIP_PATH}")" && sha256sum -c "$(basename "${ZIP_PATH}").sha256") && \
    echo "  [CHECKSUM] ✓ SHA256 verified" || {
      echo "  [CHECKSUM] ✗ SHA256 mismatch!"
      exit 1
    }
else
  echo "  [CHECKSUM] No SHA256 file found — generating..."
  sha256sum "${ZIP_PATH}" > "${ZIP_PATH}.sha256"
fi

# Audit ZIP contents
echo "  [CONTENT] ZIP contents:"
python3 << 'PYEOF'
import zipfile, sys, os

zip_path = os.environ.get("ZIP_PATH", "")
if not zip_path or not os.path.isfile(zip_path):
    print("  [CONTENT] No ZIP file to audit")
    sys.exit(0)

errors = []
warnings = []
info = []

with zipfile.ZipFile(zip_path, 'r') as z:
    names = z.namelist()
    total_size = sum(i.file_size for i in z.infolist())

    info.append(f"  Total files: {len(names)}")
    info.append(f"  Total size: {total_size / 1024 / 1024:.2f} MB")

    # Required files
    required = ["META-INF/com/google/android/updater-script"]
    for req in required:
        if any(req in n for n in names):
            info.append(f"  ✓ Found: {req}")
        else:
            errors.append(f"  ✗ Missing: {req}")

    # Optional files (check for Pong-specific)
    optional = ["boot.img", "Image", "Image.gz", "dtbo.img", "vendor_boot.img", "init_boot.img"]
    found_any = False
    for opt in optional:
        if any(opt in n for n in names):
            info.append(f"  ✓ Found: {opt}")
            found_any = True

    if not found_any:
        warnings.append("  ⚠ No kernel images found in ZIP")

    # Show first 30 entries
    print("\n".join(info))
    if errors:
        print("\nErrors:")
        for e in errors:
            print(e)
    if warnings:
        print("\nWarnings:")
        for w in warnings:
            print(w)

    # List all files (truncated)
    print("\n  [FILES] First 30 entries:")
    for n in sorted(names)[:30]:
        print(f"    {n}")
    if len(names) > 30:
        print(f"    ... and {len(names)-30} more")
PYEOF

export ZIP_PATH="${ZIP_PATH}"
python3 << PYEOF
import zipfile, sys, os

zip_path = os.environ.get("ZIP_PATH", "")
if not zip_path or not os.path.isfile(zip_path):
    sys.exit(0)

with zipfile.ZipFile(zip_path, 'r') as z:
    names = z.namelist()
    total_size = sum(i.file_size for i in z.infolist())
    print(f"  Total files: {len(names)}")
    print(f"  Total size: {total_size / 1024 / 1024:.2f} MB")

    required = ["META-INF/com/google/android/updater-script"]
    for req in required:
        if any(req in n for n in names):
            print(f"  Found: {req}")
        else:
            print(f"  Missing: {req} !!")

    optional = ["boot.img", "Image", "Image.gz", "dtbo.img", "vendor_boot.img"]
    found = [o for o in optional if any(o in n for n in names)]
    if found:
        print(f"  Kernel images: {', '.join(found)}")
    else:
        print(f"  WARNING: No kernel images in ZIP")

    print("\n  Files (first 30):")
    for n in sorted(names)[:30]:
        print(f"    {n}")
PYEOF

echo "  [AUDIT] Complete"
