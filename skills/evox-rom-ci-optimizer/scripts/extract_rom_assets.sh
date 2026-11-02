#!/usr/bin/env bash
# =============================================================================
# EVOX-CI v3.2 — [L4] Fecha a lacuna L4 a partir do PACOTE DA ROM (não do device)
# -----------------------------------------------------------------------------
# A pergunta que este script responde, com bytes e não com memória:
#   "qual kernel/KMI e quais hashes de boot/vendor_boot/vbmeta veem nesta build?"
#
# Fonte de verdade = o .zip oficial da Evolution X 11.11 (payload.bin → imagens).
# O aparelho NÃO é fonte de hash: ele só confirma slot/fingerprint (read-only).
#
# Uso:
#   ./extract_rom_assets.sh --zip EvolutionX-...-11.11-Official.zip \
#                           [--out ./workspace/rom_assets] \
#                           [--partitions boot,init_boot,vendor_boot,vbmeta,dtbo] \
#                           [--expect-sha256 <hex do .zip>] \
#                           [--no-extract] [--json]
#
#   --expect-sha256  aborta se o .zip não for o arquivo esperado (anti-ROM-trocada)
#   --no-extract     reusa imagens já extraídas em --out (idempotente, offline)
#   --json           resumo machine-readable no stdout
#
# Exit: 0 = L4 fechada (boot + kernel + vendor_boot + vbmeta)
#       2 = uso incorreto
#       3 = payload-dumper-go ausente (nada foi inventado)
#       4 = zip inválido / sem payload.bin / extração falhou
#       5 = hash do .zip não confere com --expect-sha256
#       6 = extração ok, mas L4 NÃO fecha (falta imagem ou assinatura de kernel)
# =============================================================================
set -euo pipefail

ZIP=""
OUT="./workspace/rom_assets"
PARTS="boot,init_boot,vendor_boot,vbmeta,dtbo"
EXPECT=""
JSON=0
EXTRACT=1
DUMPER="${PAYLOAD_DUMPER:-payload-dumper-go}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zip) ZIP="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --partitions) PARTS="$2"; shift 2 ;;
    --expect-sha256) EXPECT="${2,,}"; shift 2 ;;
    --no-extract) EXTRACT=0; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done

die() { echo "[ERRO] $2" >&2; exit "$1"; }

[[ -n "$ZIP" ]] || { echo "Uso: $0 --zip <ROM.zip> [--out DIR] [--json]" >&2; exit 2; }
[[ -f "$ZIP" ]] || { echo "[ERRO] zip não encontrado: $ZIP" >&2; exit 4; }
command -v unzip >/dev/null 2>&1 || die 3 "unzip ausente (apt install -y unzip)"

ZIP_SHA="$(sha256sum "$ZIP" | awk '{print $1}')"
if [[ -n "$EXPECT" && "$ZIP_SHA" != "$EXPECT" ]]; then
  die 5 "hash do zip não confere: esperado ${EXPECT:0:12}… obtido ${ZIP_SHA:0:12}…"
fi

unzip -l "$ZIP" 2>/dev/null | awk '{print $NF}' | grep -qx 'payload.bin' \
  || die 4 "zip sem payload.bin (não é um pacote de ROM A/B): $(basename "$ZIP")"

mkdir -p "$OUT"

if [[ "$EXTRACT" -eq 1 ]]; then
  command -v "$DUMPER" >/dev/null 2>&1 \
    || die 3 "payload-dumper-go ausente (go install github.com/ssut/payload-dumper-go@latest | release oficial). Nada foi extraído."
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  unzip -o -q "$ZIP" payload.bin -d "$TMP" || die 4 "falha ao extrair payload.bin"
  "$DUMPER" -p "$PARTS" -o "$OUT" "$TMP/payload.bin" >/dev/null 2>&1 \
    || die 4 "payload-dumper-go falhou (payload corrompido ou partição inexistente)"
fi

# ── Inventário: hash, tamanho, kernel/KMI por imagem ────────────────────────
python3 - "$OUT" "$ZIP" "$ZIP_SHA" "$PARTS" <<'PY'
import hashlib, json, os, re, subprocess, sys, time

out, zip_path, zip_sha, parts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
images, kernel, kmi = {}, None, None

for name in sorted(os.listdir(out)):
    if not name.endswith(".img"):
        continue
    p = os.path.join(out, name)
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    images[name] = {"sha256": h.hexdigest(), "size_bytes": os.path.getsize(p)}

def strings(path):
    try:
        return subprocess.run(["strings", path], capture_output=True, text=True,
                              timeout=120).stdout
    except Exception:
        return ""

boot = os.path.join(out, "boot.img")
if os.path.isfile(boot):
    blob = strings(boot)
    m = re.search(r"Linux version (\S+)", blob)
    kernel = m.group(1) if m else None
    if kernel:
        km = re.search(r"android(\d+)-(\d+)", kernel)
        kmi = f"android{km.group(1)}-{km.group(2)}" if km else "unknown"

required = ["boot.img", "vendor_boot.img", "vbmeta.img"]
missing = [r for r in required if r not in images]
profile = {
    "schema": "pong-rom-assets/1",
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "source": {"zip": os.path.basename(zip_path), "zip_sha256": zip_sha,
               "partitions_requested": parts},
    "kernel_version": kernel,
    "kmi": kmi,
    "images": images,
    "l4_closed": not missing and bool(kernel),
    "l4_missing": missing + ([] if kernel else ["kernel_version"]),
    "note": "L4 se fecha aqui: hashes e kernel vêm do pacote oficial, não do aparelho. "
            "O device só confirma slot/fingerprint em modo read-only.",
}
path = os.path.join(out, "rom_assets.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
print(path, file=sys.stderr)
PY

PROFILE="$OUT/rom_assets.json"
CLOSED="$(python3 -c 'import json,sys;print("true" if json.load(open(sys.argv[1]))["l4_closed"] else "false")' "$PROFILE")"
KERNEL="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["kernel_version"] or "?")' "$PROFILE")"
KMI="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["kmi"] or "?")' "$PROFILE")"
NIMG="$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["images"]))' "$PROFILE")"

if [[ "$JSON" -eq 1 ]]; then
  python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["exit_code"]=int(sys.argv[2]);print(json.dumps(d,indent=2,ensure_ascii=False))' "$PROFILE" "$([[ "$CLOSED" == true ]] && echo 0 || echo 6)"
else
  echo "[OK] ROM: $(basename "$ZIP") · sha256 ${ZIP_SHA:0:16}…"
  echo "[OK] imagens: $NIMG · kernel: $KERNEL · KMI: $KMI"
  if [[ "$CLOSED" == true ]]; then
    echo "[OK] L4 FECHADA — manifesto: $PROFILE"
    echo "     próximo passo: revisar $PROFILE e só então patchear boot (estágio A)."
  else
    echo "[AVISO] L4 não fecha: imagens/assinatura ausentes (ver l4_missing no manifesto)."
  fi
fi

[[ "$CLOSED" == true ]] && exit 0 || exit 6
