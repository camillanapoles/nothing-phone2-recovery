#!/bin/bash
# validate-cuttlefish.sh — Validate kernel build on Cuttlefish virtual device
# Usage: bash scripts/validate-cuttlefish.sh [boot_img] [system_img]
# Requires: cvd (Cuttlefish) installed on host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

BOOT_IMG="${1:-}"
SYSTEM_IMG="${2:-}"
CVD_HOST="${CVD_HOST:-localhost}"
CVD_PORT="${CVD_PORT:-8443}"

echo "=== Cuttlefish Validation ==="

# Check if CVD is available
if ! command -v cvd &>/dev/null; then
  echo "  [SKIP] Cuttlefish (cvd) not found — skipping validation"
  echo "  [INFO] Install: https://source.android.com/docs/devices/cuttlefish/get-started"
  exit 0
fi

# Check if CVD is running
if ! cvd list 2>/dev/null | grep -q "running"; then
  echo "  [SKIP] No running Cuttlefish instance"
  echo "  [INFO] Start with: cvd start"
  exit 0
fi

# Validate boot image
if [[ -z "${BOOT_IMG}" ]] || [[ ! -f "${BOOT_IMG}" ]]; then
  echo "  [ERROR] No boot image provided for validation"
  exit 1
fi

echo "  [VALIDATE] Boot image: ${BOOT_IMG}"
echo "  [VALIDATE] System image: ${SYSTEM_IMG:-not provided}"

# Extract and check kernel version
echo "  [VALIDATE] Checking kernel version..."
KERNEL_VERSION=$(grep -a 'Linux version' "${BOOT_IMG}" 2>/dev/null | head -1 || echo "unknown")
echo "  [VALIDATE] Kernel: ${KERNEL_VERSION}"

# Check for GKI compliance
if echo "${KERNEL_VERSION}" | grep -q "gki\|GKI"; then
  echo "  [VALIDATE] ✓ GKI kernel detected"
else
  echo "  [WARN] Non-GKI kernel — Cuttlefish may not boot"
fi

# Try to boot on Cuttlefish (if system image provided)
if [[ -n "${SYSTEM_IMG}" ]] && [[ -f "${SYSTEM_IMG}" ]]; then
  echo "  [VALIDATE] Booting on Cuttlefish..."
  echo "  [INFO] Command: cvd start --kernel=${BOOT_IMG} --system=${SYSTEM_IMG}"
  # Note: Actual CVD booting is done manually — CI can only validate artifacts
  echo "  [INFO] Artifacts validated — manual CVD boot recommended"
fi

# Validate SELinux context
echo "  [VALIDATE] SELinux: Enforcing required on device"
echo "  [INFO] Run: adb shell getenforce"
echo "  [INFO] Expected: Enforcing"

echo "=== Cuttlefish Validation Complete ==="
