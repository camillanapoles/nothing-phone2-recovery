#!/bin/bash
# build-kernel-pong.sh — Build GKI kernel for Nothing Phone 2
# Usage: bash scripts/build-kernel-pong.sh [kernel_source_dir]
# Follows AOSP kernel building conventions (Kleaf + build.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

KERNEL_DIR="${1:-kernel-source}"
DIST_DIR="${KERNEL_DIR}/${DIST_DIR}"
OUT_DIR="${KERNEL_DIR}/${OUT_DIR}"

echo "=== Building kernel for Pong (${DEVICE_CODENAME}) ==="
echo "  Kernel dir: ${KERNEL_DIR}"
echo "  Dist dir:   ${DIST_DIR}"
echo "  Arch:       ${DEVICE_ARCH}"
echo "  Toolchain:  ${ACTIVE_TOOLCHAIN:-unknown}"

# Setup build environment
export ARCH="${DEVICE_ARCH}"
export SUBARCH="${DEVICE_ARCH}"
export LLVM=1
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_LLVM=aarch64-linux-gnu-

# Set toolchain path
case "${ACTIVE_TOOLCHAIN:-${TOOLCHAIN:-android-r416183b}}" in
  android-r416183b)
    export CC="${ANDROID_CLANG_BIN}/clang"
    export LD="${ANDROID_CLANG_BIN}/ld.lld"
    export AR="${ANDROID_CLANG_BIN}/llvm-ar"
    ;;
  android-r530567)
    export CC="${ANDROID_CLANG_2024_BIN}/clang"
    export LD="${ANDROID_CLANG_2024_BIN}/ld.lld"
    export AR="${ANDROID_CLANG_2024_BIN}/llvm-ar"
    ;;
  llvm-22.1.8)
    export CC="${LLVM_22_1_8_BIN}/clang"
    export LD="${LLVM_22_1_8_BIN}/ld.lld"
    export AR="${LLVM_22_1_8_BIN}/llvm-ar"
    ;;
esac

# ccache setup
if [[ "${CCACHE_ENABLED:-true}" == "true" ]] && command -v ccache &>/dev/null; then
  export CC="ccache ${CC}"
  export CXX="ccache ${CXX:-${CC}}"
  echo "  [ccache] Enabled"
fi

# ThinLTO setup
if [[ "${LTO:-thin}" == "thin" ]]; then
  export LLVM_ENABLE_LTO=Thin
  echo "  [LTO] ThinLTO enabled"
fi

mkdir -p "${DIST_DIR}" "${OUT_DIR}"

# Check if kernel source exists
if [[ ! -f "${KERNEL_DIR}/Makefile" ]] && [[ ! -f "${KERNEL_DIR}/kleaf.bzl" ]]; then
  echo "  [BUILD] Kernel source not found at ${KERNEL_DIR}"
  echo "  [BUILD] Skipping kernel build — using prebuilt artifact path"
  echo "  [BUILD] Set KERNEL_SOURCE=gki-source or lineage-pong to build from source"
  exit 0
fi

# Determine build method
if [[ -f "${KERNEL_DIR}/kleaf.bzl" ]] || command -v bazel &>/dev/null; then
  echo "  [BUILD] Using Kleaf (Bazel) for GKI 2.0 build"
  # Kleaf build for GKI 2.0
  (cd "${KERNEL_DIR}" && \
    tools/bazel run //common:kernel_${DEVICE_ARCH}_dist \
      --//common:config_flags+=gki \
      --cpu=arm64 \
      --embeddable \
      --fat_aarch64 \
      --define skip_module_signing=true \
      --output_groups=+headers,+all_modules \
      --copt=-Wno-error \
      -- --destdir="${DIST_DIR}") || {
      echo "  [BUILD] Kleaf build failed — falling back to build.sh"
      BAZEL_FAILED=1
    }
fi

if [[ "${BAZEL_FAILED:-0}" == "1" ]] || [[ ! -f "${KERNEL_DIR}/kleaf.bzl" ]]; then
  echo "  [BUILD] Using build.sh (legacy) for kernel build"

  # Build config
  BUILD_CONFIG="${BASE_DEFCONFIG:-common/build.config.gki.${DEVICE_ARCH}}"

  # Build kernel image
  (cd "${KERNEL_DIR}" && \
    BUILD_CONFIG="${BUILD_CONFIG}" \
    DIST_DIR="${DIST_DIR}" \
    OUT_DIR="${OUT_DIR}" \
    SKIP_DEFCONFIG=1 \
    BUILD_BOOT_IMG=1 \
    SKIP_VENDOR_BOOT=1 \
    KERNEL_BINARY=Image \
    ./build/build.sh) || {
      echo "  [BUILD] build.sh failed"
      exit 1
    }
fi

# Validate build output
echo "  [VALIDATE] Checking build artifacts..."
BOOT_IMG=""
IMAGE_FILE=""

if [[ -f "${DIST_DIR}/boot.img" ]]; then
  BOOT_IMG="${DIST_DIR}/boot.img"
  echo "  [VALIDATE] ✓ boot.img found (${DIST_DIR}/boot.img)"
elif [[ -f "${DIST_DIR}/Image" ]]; then
  IMAGE_FILE="${DIST_DIR}/Image"
  echo "  [VALIDATE] ✓ Image found (${DIST_DIR}/Image)"
elif [[ -f "${DIST_DIR}/Image.gz" ]]; then
  IMAGE_FILE="${DIST_DIR}/Image.gz"
  echo "  [VALIDATE] ✓ Image.gz found (${DIST_DIR}/Image.gz)"
fi

if [[ -f "${DIST_DIR}/dtbo.img" ]]; then
  echo "  [VALIDATE] ✓ dtbo.img found (${DIST_DIR}/dtbo.img)"
fi

if [[ -f "${DIST_DIR}/vendor_boot.img" ]]; then
  echo "  [VALIDATE] ✓ vendor_boot.img found (${DIST_DIR}/vendor_boot.img)"
fi

# Extract kernel version
if [[ -n "${BOOT_IMG}" ]]; then
  KERNEL_VERSION=$(grep -a 'Linux version' "${BOOT_IMG}" 2>/dev/null | head -1 || echo "unknown")
  echo "  [VERSION] Kernel: ${KERNEL_VERSION}"
elif [[ -n "${IMAGE_FILE}" ]]; then
  KERNEL_VERSION=$(strings "${IMAGE_FILE}" 2>/dev/null | grep 'Linux version' | head -1 || echo "unknown")
  echo "  [VERSION] Kernel: ${KERNEL_VERSION}"
fi

# Save build info
{
  echo "kernel_version=${KERNEL_VERSION:-unknown}"
  echo "boot_img=${BOOT_IMG:-none}"
  echo "image_file=${IMAGE_FILE:-none}"
  echo "dist_dir=${DIST_DIR}"
  echo "build_config=${BUILD_CONFIG:-none}"
  echo "toolchain=${ACTIVE_TOOLCHAIN:-unknown}"
  echo "lto_mode=${LTO:-none}"
  echo "ccache_enabled=${CCACHE_ENABLED:-true}"
  echo "build_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${DIST_DIR}/build-info.txt"

echo "  [BUILD] Build complete — artifacts in ${DIST_DIR}/"
echo "  [BUILD] Build info: ${DIST_DIR}/build-info.txt"
