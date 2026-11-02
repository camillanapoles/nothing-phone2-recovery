#!/bin/bash
# package-anykernel3.sh — Package kernel as flashable AnyKernel3 ZIP
# Usage: bash scripts/package-anykernel3.sh [kernel_dir] [dist_dir] [manager_id]
# Follows osm0sis AnyKernel3 template structure

set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "uso: $(basename "$0") — só executa com argumentos explícitos"
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/pong.env"

KERNEL_DIR="${1:-kernel-source}"
DIST_DIR="${2:-${KERNEL_DIR}/${DIST_DIR}}"
MANAGER="${3:-apatch}"
RELEASE_DIR="${REPO_ROOT}/${RELEASE_DIR}"

echo "=== Packaging AnyKernel3 ZIP ==="

# Nada é apagado antes de validar as entradas (sem efeito colateral destrutivo)
if [[ ! -d "${DIST_DIR}" ]]; then
  echo "  [PENDENTE] diretório de artefatos ausente: ${DIST_DIR} — nada empacotado" >&2
  exit 3
fi
if [[ ! -f "${DIST_DIR}/boot.img" && ! -f "${DIST_DIR}/Image" && ! -f "${DIST_DIR}/Image.gz" ]]; then
  echo "  [PENDENTE] sem boot.img/Image em ${DIST_DIR} — ZIP não seria flashável" >&2
  exit 3
fi

# Prepare release directory
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"

# Download/copy AnyKernel3 template
AK3_TEMPLATE="${AK3_TEMPLATE:-${REPO_ROOT}/ak3}"
if [[ ! -d "${AK3_TEMPLATE}" ]]; then
  echo "  [AK3] Downloading AnyKernel3 template..."
  git clone --depth 1 --branch "${AK3_BRANCH}" "${AK3_REPO}" "${AK3_TEMPLATE}" 2>/dev/null || {
    echo "  [PENDENTE] template AnyKernel3 indisponível e clone falhou — template falso NÃO será inventado" >&2
    exit 3
  }
fi

# Copia do template exige rsync: ausência é erro explícito, não cópia parcial
if ! command -v rsync >/dev/null 2>&1; then
  echo "  [PENDENTE] rsync ausente — ZIP não será montado pela metade" >&2
  exit 3
fi

# Copy AK3 template to release dir
rsync -a --exclude='.git' "${AK3_TEMPLATE}/" "${RELEASE_DIR}/"

# Copy kernel artifacts
BOOT_FOUND=""
IMAGE_FOUND=""
DTBO_FOUND=""
VENDOR_BOOT_FOUND=""
INIT_BOOT_FOUND=""

# Find kernel image
for img in "${DIST_DIR}"/boot.img "${DIST_DIR}"/Image "${DIST_DIR}"/Image.gz; do
  if [[ -f "${img}" ]] && [[ -s "${img}" ]]; then
    if [[ "${img}" == */boot.img ]]; then
      cp "${img}" "${RELEASE_DIR}/boot.img"
      BOOT_FOUND="boot.img"
      echo "  [COPY] boot.img → release/"
    else
      cp "${img}" "${RELEASE_DIR}/Image"
      IMAGE_FOUND="Image"
      echo "  [COPY] Image → release/"
    fi
    break
  fi
done

# Find dtbo
if [[ -f "${DIST_DIR}/dtbo.img" ]] && [[ -s "${DIST_DIR}/dtbo.img" ]]; then
  cp "${DIST_DIR}/dtbo.img" "${RELEASE_DIR}/dtbo.img"
  DTBO_FOUND="dtbo.img"
  echo "  [COPY] dtbo.img → release/"
fi

# Find vendor_boot (only if exists — Pong may not have it)
if [[ -f "${DIST_DIR}/vendor_boot.img" ]] && [[ -s "${DIST_DIR}/vendor_boot.img" ]]; then
  cp "${DIST_DIR}/vendor_boot.img" "${RELEASE_DIR}/vendor_boot.img"
  VENDOR_BOOT_FOUND="vendor_boot.img"
  echo "  [COPY] vendor_boot.img → release/"
fi

# init_boot: layout nao verificado (confirmar no payload.bin); se existir, precisa de par proprio
if [[ -f "${DIST_DIR}/init_boot.img" ]] && [[ -s "${DIST_DIR}/init_boot.img" ]]; then
  cp "${DIST_DIR}/init_boot.img" "${RELEASE_DIR}/init_boot.img"
  INIT_BOOT_FOUND="init_boot.img"
  echo "  [COPY] ⚠️  init_boot.img → release/ (Pong uses boot.img, not init_boot!)"
fi

# Update updater-script for Pong
UPDATER_SCRIPT="${RELEASE_DIR}/META-INF/com/google/android/updater-script"
if [[ -f "${UPDATER_SCRIPT}" ]]; then
  # Generate Pong-specific flashing script
  cat > "${UPDATER_SCRIPT}" << 'UPDATER'
assert(getprop("ro.product.device") == "pong" || getprop("ro.build.product") == "pong" || getprop("ro.product.name") == "pong" || getprop("ro.hardware") == "sm8475");
show_progress(0.5, 0);
ui_print("Patching boot image...");
unpack_boot("/tmp/boot.img");
block_image_update("/tmp/boot.img", package_extract_file("boot.img"), 0);
show_progress(0.3, 10);
if is_image_mounted("/system") then unmount("/system"); endif;
if is_image_mounted("/vendor") then unmount("/vendor"); endif;
show_progress(0.2, 0);
ui_print("Done!");
UPDATER
  echo "  [SCRIPT] Generated Pong-specific updater-script"
fi

# Generate build metadata
BUILD_DATE=$(date -u '+%Y.%m.%d')
BUILD_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

ZIP_NAME="${MANAGER}-pongo-${BUILD_DATE}.zip"
ZIP_PATH="${RELEASE_DIR}/${ZIP_NAME}"

# Create ZIP
echo "  [ZIP] Creating ${ZIP_NAME}..."
(cd "${RELEASE_DIR}" && zip -r9 -q "${ZIP_NAME}" . -x "*.sha256" -x ".git/*")

# Generate SHA256
sha256sum "${ZIP_PATH}" > "${ZIP_PATH}.sha256"
echo "  [SHA256] $(cat "${ZIP_PATH}.sha256")"

# Write zip-name.env for release job
cat > "${RELEASE_DIR}/zip-name.env" << EOF
ZIP_NAME=${ZIP_NAME}
ZIP_PATH=${ZIP_PATH}
MANAGER=${MANAGER}
DEVICE=${DEVICE_CODENAME}
BUILD_DATE=${BUILD_DATE}
BUILD_TIMESTAMP=${BUILD_TIMESTAMP}
EOF

# Write resolved refs
cat > "${RELEASE_DIR}/resolved-refs.env" << EOF
kernel_source=${KERNEL_SOURCE:-prebuilt-evolutionx}
manager=${MANAGER}
toolchain=${ACTIVE_TOOLCHAIN:-${TOOLCHAIN:-android-r416183b}}
lto=${LTO:-thin}
device=${DEVICE_CODENAME}
arch=${DEVICE_ARCH}
gki_version=${GKI_KERNEL_VERSION}
gki_kmi=${GKI_KMI_TAG}
gki_branch=${GKI_BRANCH}
commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
build_date=${BUILD_DATE}
build_timestamp=${BUILD_TIMESTAMP}
EOF

echo "  [PACKAGE] ZIP: ${ZIP_PATH}"
echo "  [PACKAGE] SHA256: ${ZIP_PATH}.sha256"
echo "  [PACKAGE] Env: ${RELEASE_DIR}/zip-name.env"
echo "  [PACKAGE] Refs: ${RELEASE_DIR}/resolved-refs.env"

# Output summary
echo ""
echo "=== Package Summary ==="
echo "  Device:     ${DEVICE_CODENAME} (${DEVICE_MODEL})"
echo "  Manager:    ${MANAGER}"
echo "  Kernel:     ${GKI_KERNEL_VERSION}-${GKI_KMI_TAG}"
echo "  Boot part:  ${BOOT_PARTITION}"
echo "  ZIP:        ${ZIP_NAME}"
echo "  Size:       $(du -h "${ZIP_PATH}" | cut -f1)"
echo "  Files:      $(find "${RELEASE_DIR}" -type f -not -name '*.sha256' -not -name '*.env' | wc -l)"
echo "  Artifact:   ${ZIP_PATH}"
