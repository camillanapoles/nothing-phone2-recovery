#!/bin/bash
# patch-apatch.sh — Apply APatch kallsyms patch to kernel source
# Usage: bash scripts/patch-apatch.sh [kernel_source_dir] [manager_id]
# Patches: kprobe-based root injection into kernel binary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

KERNEL_DIR="${1:-kernel-source}"
MANAGER="${2:-apatch}"

echo "=== Applying ${MANAGER} patch to ${KERNEL_DIR} ==="

case "${MANAGER}" in
  apatch)
    # APatch uses kprobe-based patching — patches the kernel binary directly
    # The patch is applied during build via the APatch app, not in CI
    # CI just needs to ensure the kernel is built with kprobe support
    if [[ -d "${KERNEL_DIR}/kernel" ]]; then
      echo "  [APatch] Kernel tree has kernel/ subdir — kprobe patching will be done by APatch app"
    fi

    # Verify kprobe support in defconfig
    if [[ -f "${KERNEL_DIR}/.config" ]]; then
      if grep -q "CONFIG_KPROBES=y" "${KERNEL_DIR}/.config"; then
        echo "  [APatch] kprobes enabled: CONFIG_KPROBES=y"
      else
        echo "  [APatch] WARNING: kprobes not enabled — APatch may not work"
      fi
      if grep -q "CONFIG_KALLSYMS=y" "${KERNEL_DIR}/.config"; then
        echo "  [APatch] kallsyms enabled: CONFIG_KALLSYMS=y"
      fi
    fi
    ;;

  magisk)
    # Magisk patches boot.img directly — no kernel patch needed
    echo "  [Magisk] No kernel patching required (boot.img patcher)"
    ;;

  kernelsu-next)
    # KernelSU Next patches kernel source with LKM
    if [[ -f "${KERNEL_DIR}/kernel/kernelsu.c" ]]; then
      echo "  [KSU] KernelSU already present in kernel tree"
    elif [[ -d "${KERNEL_DIR}/scripts/kernelsu" ]]; then
      echo "  [KSU] KSU scripts found, applying..."
      # KSU integration — add to Makefile
      if grep -q "kernelsu" "${KERNEL_DIR}/Makefile" 2>/dev/null; then
        echo "  [KSU] Already integrated in Makefile"
      else
        echo "  [KSU] Adding KSU to Makefile..."
        echo 'obj-y += kernelsu/' >> "${KERNEL_DIR}/Makefile"
      fi
    else
      echo "  [KSU] WARNING: KernelSU source not found — LKM support disabled"
    fi
    ;;

  *)
    echo "::error::Unknown manager: ${MANAGER}"
    exit 1
    ;;
esac

echo "=== Patch applied successfully ==="
