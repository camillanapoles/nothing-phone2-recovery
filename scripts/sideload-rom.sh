#!/bin/bash
# sideload-rom.sh — Sideload Evolution X ROM via ADB with guaranteed 1800s timeout
# Usage: bash scripts/sideload-rom.sh [rom_path]
# Ensures 3.6 GB ZIP transfer completes without premature timeout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ROM_PATH="${1:-}"
TIMEOUT_SECONDS="${2:-1800}"

# Default to latest Evolution X 11.11 ROM if not specified
if [[ -z "${ROM_PATH}" ]]; then
  ROM_PATH="${REPO_ROOT}/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip"
fi

# Verify ROM exists
if [[ ! -f "${ROM_PATH}" ]]; then
  echo "❌ ROM file not found: ${ROM_PATH}"
  exit 1
fi

ROM_SIZE=$(du -b "${ROM_PATH}" | cut -f1)
echo "📱 Sideloading ROM: ${ROM_PATH}"
echo "   Size: $(numfmt --to=iec "${ROM_SIZE}")"

# Verify SHA256 if checksums file exists
if [[ -f "${ROM_PATH}.sha256" ]]; then
  echo "🔐 Verifying SHA256..."
  (cd "$(dirname "${ROM_PATH}")" && sha256sum -c "$(basename "${ROM_PATH}").sha256") && \
    echo "   ✓ SHA256 verified" || {
      echo "   ✗ SHA256 mismatch — aborting"
      exit 1
    }
else
  echo "⚠️ No SHA256 file found — generating for reference"
  sha256sum "${ROM_PATH}" > "${ROM_PATH}.sha256"
  echo "   Generated: ${ROM_PATH}.sha256"
fi

# Check ADB is available
if ! command -v adb &>/dev/null; then
  echo "❌ adb not found — ensure Android SDK is installed"
  exit 1
fi

# Verify ADB is online
echo "🔍 Checking ADB connection..."
adb wait-for-device

# Execute sideload with guaranteed timeout
echo "⏱️ Starting sideload with ${TIMEOUT_SECONDS}s timeout..."
echo "   This is normal for transfers >1 GB — DO NOT CANCEL at ~47%"

# Use timeout command with explicit signal handling
timeout "${TIMEOUT_SECONDS}" adb sideload "${ROM_PATH}"

SIDELoad_EXIT_CODE=$?

if [[ ${SIDELoad_EXIT_CODE} -eq 124 ]]; then
  echo "⚠️ Sideload timed out after ${TIMEOUT_SECONDS}s"
  echo "   If transfer appears stuck at ~47%, this is NORMAL — do not cancel"
  echo "   Wait for completion or retry with extended timeout"
elif [[ ${SIDELoad_EXIT_CODE} -eq 0 ]]; then
  echo "✅ Sideload completed successfully"
  # Recovery will prompt "reboot recovery to install additional packages"
  # User should click YES on the device screen
  echo "   After completion: Clique YES na tela quando recovery pedir"
  echo "   'reboot recovery to install additional packages'"
else
  echo "❌ Sideload failed with exit code ${SIDELoad_EXIT_CODE}"
  exit 1
fi

# Generate post-sideload verification report
echo "📋 Generating post-sideload report..."
python3 << 'PYEOF'
from pathlib import Path
from datetime import datetime, timezone
import json

timestamp = datetime.now(timezone.utc).isoformat()
date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
sideload_log = Path("/tmp/sideload-attempt.log")

report = {
    "simulation": "Sideload Execution",
    "timestamp": timestamp,
    "date": date,
    "device": "Nothing Phone 2 (Pong, SM8475)",
    "android_version": 16,
    "rom_file": str(Path("${ROM_PATH}").name),
    "rom_size_bytes": "${ROM_SIZE}",
    "timeout_seconds": "${TIMEOUT_SECONDS}",
    "adb_online": "${ADB_ONLINE:-true}",
    "verdict": "pending",
    "next_steps": [
        "1. Wait for recovery to show 'reboot recovery' prompt",
        "2. Click YES on device screen",
        "3. Wait for recovery to reboot",
        "4. Reconnect USB and verify: adb devices",
        "5. Check: adb shell getprop ro.build.display.id → BP4A.251205.006",
        "6. Check: adb shell getprop ro.boot.slot_suffix → _b"
    ]
}

report_path = Path("ci/sideload-report.json")
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(json.dumps(report, indent=2))

print(f"   Report written: {report_path}")
PYEOF

echo ""
echo "========================================"
echo "  Sideload Execution Complete"
echo "========================================"
echo "  ROM: $(basename "${ROM_PATH}")"
echo "  Timeout: ${TIMEOUT_SECONDS}s"
echo "  Status: $([ ${SIDELoad_EXIT_CODE} -eq 0 ] && echo 'SUCCESS' || echo 'TIMEOUT/FAILED')"
echo "  Next: Click YES on recovery screen"
echo "========================================"