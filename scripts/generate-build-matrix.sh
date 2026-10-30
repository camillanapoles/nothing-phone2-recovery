#!/bin/bash
# generate-build-matrix.sh — Generate GitHub Actions matrix for Pong builds
# Usage: source config/pong.env && bash scripts/generate-build-matrix.sh
# Output: JSON matrix string to stdout
# Set GITHUB_OUTPUT for GitHub Actions artifact

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

# Input variables from GitHub Actions
MANAGER="${MANAGER:-apatch}"
KERNEL_SOURCE="${KERNEL_SOURCE:-prebuilt-evolutionx}"
TOOLCHAIN="${TOOLCHAIN:-auto}"
LTO="${LTO:-thin}"
SUSFS_ENABLED="${SUSFS_ENABLED:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"

# Resolve toolchain
case "${TOOLCHAIN}" in
  auto)
    ACTIVE_TOOLCHAIN="android-r416183b"
    ;;
  android-r416183b|android-r530567|llvm-22.1.8)
    ACTIVE_TOOLCHAIN="${TOOLCHAIN}"
    ;;
  *)
    echo "::error::Unsupported toolchain: ${TOOLCHAIN}"
    exit 1
    ;;
esac

# Resolve kernel source
case "${KERNEL_SOURCE}" in
  prebuilt-evolutionx)
    SOURCE_REPO=""
    SOURCE_REF=""
    SOURCE_TYPE="prebuilt"
    ;;
  gki-source)
    SOURCE_REPO="https://android.googlesource.com/kernel/common"
    SOURCE_REF="common-android13-6.1"
    SOURCE_TYPE="repo"
    ;;
  lineage-pong)
    SOURCE_REPO="https://github.com/LineageOS/android_kernel_nothing_sm8475"
    SOURCE_REF="lineage-23.2"
    SOURCE_TYPE="git"
    ;;
  *)
    echo "::error::Unknown kernel source: ${KERNEL_SOURCE}"
    exit 1
    ;;
esac

# Build label
LABEL="${MANAGER}-${KERNEL_SOURCE}-${ACTIVE_TOOLCHAIN}-lto${LTO}"

# Build entry
ENTRY=$(cat <<EOF
{
  "label": "${LABEL}",
  "manager": "${MANAGER}",
  "kernel_source": "${KERNEL_SOURCE}",
  "source_repo": "${SOURCE_REPO}",
  "source_ref": "${SOURCE_REF}",
  "source_type": "${SOURCE_TYPE}",
  "toolchain": "${ACTIVE_TOOLCHAIN}",
  "lto": "${LTO}",
  "susfs_enabled": ${SUSFS_ENABLED},
  "build_scope": "${BUILD_SCOPE}",
  "device": "${DEVICE_CODENAME}",
  "arch": "${DEVICE_ARCH}",
  "defconfig": "${DEVICE_DEFCONFIG}"
}
EOF
)

# Output
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "matrix=${ENTRY}" >> "${GITHUB_OUTPUT}"
else
  echo "${ENTRY}"
fi
