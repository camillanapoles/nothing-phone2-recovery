#!/usr/bin/env bash
# =============================================================================
# EVOX-CI v2.0 — [T01] Extrator Deterministico da Imagem Base Evolution X 11.11
# Desempacota payload.bin, extrai particoes criticas, identifica KMI GKI 2.0 e
# gera manifesto criptografico SHA-256 (evox_base_manifest.json).
# =============================================================================
set -euo pipefail

ROM_INPUT=""
OUT_DIR="./workspace/extracted"
PARTITIONS="boot,init_boot,vendor_boot,vbmeta,system,system_ext,product,vendor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rom) ROM_INPUT="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --partitions) PARTITIONS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$ROM_INPUT" ]]; then
  echo "Uso: $0 --rom <caminho_ou_url_evox_11_11.zip> [--out ./workspace/extracted]"
  exit 1
fi

mkdir -p "$OUT_DIR"
WORK_BASE="$(dirname "$OUT_DIR")/base_rom"
mkdir -p "$WORK_BASE"

ROM_FILE="$ROM_INPUT"
if [[ "$ROM_INPUT" =~ ^https?:// ]]; then
  ROM_FILE="$WORK_BASE/evox_11_11_base.zip"
  echo "[1/4] Baixando ROM Evolution X 11.11 de: $ROM_INPUT"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x16 -s16 "$ROM_INPUT" -d "$WORK_BASE" -o "evox_11_11_base.zip"
  else
    curl -L "$ROM_INPUT" -o "$ROM_FILE"
  fi
fi

if [ ! -f "$ROM_FILE" ]; then
  echo "[ERRO] Arquivo da ROM nao encontrado em: $ROM_FILE"
  exit 1
fi

echo "[2/4] Calculando hash SHA-256 da imagem base Evolution X 11.11..."
ROM_SHA256="$(sha256sum "$ROM_FILE" | awk '{print $1}')"
echo "$ROM_SHA256  $(basename "$ROM_FILE")" > "$OUT_DIR/ROM_BASE.sha256"

echo "[3/4] Extraindo payload.bin e desempacotando particoes ($PARTITIONS)..."
if [[ "$ROM_FILE" == *.zip ]]; then
  unzip -o -q "$ROM_FILE" payload.bin -d "$WORK_BASE/"
  PAYLOAD_PATH="$WORK_BASE/payload.bin"
else
  PAYLOAD_PATH="$ROM_FILE"
fi

if command -v payload-dumper-go >/dev/null 2>&1; then
  payload-dumper-go -p "$PARTITIONS" -o "$OUT_DIR" "$PAYLOAD_PATH"
else
  echo "[AVISO] payload-dumper-go nao instalado no PATH. Instale-o para extrair as particoes reais."
fi

echo "[4/4] Extraindo assinatura de Kernel KMI e gerando evox_base_manifest.json..."
KMI_DETECTED="unknown"
if [ -f "$OUT_DIR/boot.img" ]; then
  KMI_DETECTED="$(strings "$OUT_DIR/boot.img" | grep -oE "Linux version [0-9]+\.[0-9]+\.[0-9]+-android[0-9]+-[0-9]+[^\ ]*" | head -n 1 || echo "gki-2.0-detected")"
fi

python3 - "$OUT_DIR" "$ROM_SHA256" "$KMI_DETECTED" << 'PYEOF'
import hashlib, json, os, sys, time
out_dir, rom_sha, kmi = sys.argv[1], sys.argv[2], sys.argv[3]
parts = {}
for fname in sorted(os.listdir(out_dir)):
    if fname.endswith(".img"):
        fpath = os.path.join(out_dir, fname)
        h = hashlib.sha256()
        with open(fpath, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        parts[fname] = {"sha256": h.hexdigest(), "size_bytes": os.path.getsize(fpath)}

manifest = {
    "rom_family": "Evolution X",
    "rom_version": "11.11",
    "android_sdk": 36,
    "android_release": "16.0 (Baklava)",
    "base_zip_sha256": rom_sha,
    "kernel_kmi": kmi,
    "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "partitions": parts
}
manifest_path = os.path.join(out_dir, "evox_base_manifest.json")
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
print(f"[OK] Manifesto gerado em: {manifest_path}")
PYEOF
