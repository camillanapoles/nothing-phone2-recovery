#!/bin/bash
# resolve-kernel-source.sh — Resolve kernel source for Pong builds
# Usage: source config/pong.env && bash scripts/resolve-kernel-source.sh
# Output: Sets SOURCE_REPO, SOURCE_REF, SOURCE_TYPE, DEFCONFIG, BASE_DEFCONFIG

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

KERNEL_SOURCE="${KERNEL_SOURCE:-prebuilt-evolutionx}"
DEFCONFIG_MODE=""
DEFCONFIG=""
BASE_DEFCONFIG=""
CONFIG_FRAGMENTS=""

case "${KERNEL_SOURCE}" in
  prebuilt-evolutionx)
    SOURCE_REPO=""
    SOURCE_REF=""
    SOURCE_TYPE="prebuilt"
    echo "::info::Using prebuilt kernel from Evolution X 11.11 ROM"
    ;;

  gki-source)
    SOURCE_REPO="https://android.googlesource.com/kernel/common"
    SOURCE_REF="${GKI_BRANCH}"
    SOURCE_TYPE="repo"
    DEFCONFIG_MODE="gki_fragments"
    DEFCONFIG="gki_defconfig"
    BASE_DEFCONFIG="common/arch/arm64/configs/gki_defconfig"
    CONFIG_FRAGMENTS="common/arch/arm64/configs/gki"
    echo "::info::Using AOSP common kernel ${GKI_BRANCH}"
    ;;

  lineage-pong)
    SOURCE_REPO="${KERNEL_SOURCE_REPO_ALT}"
    SOURCE_REF="${KERNEL_SOURCE_REF}"
    SOURCE_TYPE="git"
    DEFCONFIG="${DEVICE_DEFCONFIG}"
    echo "::info::Using LineageOS Pong kernel ${KERNEL_SOURCE_REF}"
    ;;

  custom)
    SOURCE_REPO="${CUSTOM_KERNEL_REPO:-}"
    SOURCE_REF="${CUSTOM_KERNEL_REF:-main}"
    SOURCE_TYPE="git"
    DEFCONFIG="${CUSTOM_KERNEL_DEFCONFIG:-${DEVICE_DEFCONFIG}}"
    echo "::info::Using custom kernel source"
    ;;

  *)
    echo "::error::Unknown kernel source: ${KERNEL_SOURCE}"
    exit 1
    ;;
esac

# Export for downstream scripts
{
  echo "SOURCE_REPO=${SOURCE_REPO}"
  echo "SOURCE_REF=${SOURCE_REF}"
  echo "SOURCE_TYPE=${SOURCE_TYPE}"
  echo "DEFCONFIG_MODE=${DEFCONFIG_MODE}"
  echo "DEFCONFIG=${DEFCONFIG}"
  echo "BASE_DEFCONFIG=${BASE_DEFCONFIG}"
  echo "CONFIG_FRAGMENTS=${CONFIG_FRAGMENTS}"
} >> "${GITHUB_ENV:-/dev/null}"

echo "Resolved: repo=${SOURCE_REPO:-none} ref=${SOURCE_REF:-none} type=${SOURCE_TYPE}"
