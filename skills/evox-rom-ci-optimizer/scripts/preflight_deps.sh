#!/usr/bin/env bash
# =============================================================================
# EVOX-CI v3.2 — [Gate 0] Preflight de dependências externas (lacuna L3)
# -----------------------------------------------------------------------------
# O pipeline depende de binários que NÃO são embarcados. Antes: falha obscura no
# meio do `make extract`. Agora: diagnóstico determinístico ANTES de começar,
# com dica de instalação e exit code contratual.
#
# Uso:
#   ./preflight_deps.sh [--json] [--require LISTA] [--hints]
#
#   --require LISTA   csv de binários exigidos (default: "python3,unzip,sha256sum")
#   --hints           imprime comando de instalação para o que falta
#   --json            saída machine-readable
#
# Exit: 0 = todos os exigidos presentes | 1 = falta exigido | 2 = erro de uso
# =============================================================================
set -uo pipefail

JSON=0
HINTS=0
REQUIRED="python3,unzip,sha256sum"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --hints) HINTS=1; shift ;;
    --require) REQUIRED="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done

# binário|papel|escopo(opcional=1)|hint
CATALOG=(
  "python3|motor do scanner e do manifesto|1|apt install -y python3"
  "unzip|desempacotar módulos .zip|1|apt install -y unzip"
  "sha256sum|integridade Guard-4|1|apt install -y coreutils"
  "payload-dumper-go|extrair payload.bin da ROM (L4/Wave 1)|-|go install github.com/ssut/payload-dumper-go@latest  # ou releases do repo"
  "kptools|patch APatch/KPM|-|https://github.com/bmax121/KernelPatch/releases"
  "magiskboot|unpack/repack de boot.img|-|https://github.com/topjohnwu/Magisk (MagiskBoot)"
  "abootimg|extrair/repack boot.img legado|-|apt install -y abootimg"
  "strings|ler Linux version/KMI do boot.img (L4)|-|apt install -y binutils"
  "adb|Estágio B via QEMU/device|-|apt install -y android-tools-adb"
  "qemu-system-x86_64|emulador local (opcional)|-|apt install -y qemu-system-x86"
  "act|rodar workflow local (skill act-github-pat)|-|gh extension install nektos/act  # ou https://github.com/nektos/act"
  "gh|operações GitHub (skill github)|-|apt install -y gh"
  "jq|inspeção de JSON|-|apt install -y jq"
)

found=0; missing_required=""; missing_optional=""
declare -a RESULTS=()

for entry in "${CATALOG[@]}"; do
  IFS='|' read -r bin role req hint <<< "$entry"
  if command -v "$bin" >/dev/null 2>&1; then
    path="$(command -v "$bin")"
    RESULTS+=("$bin|$path|present|$role|")
    found=$((found + 1))
  else
    if [[ "$req" == "1" ]]; then
      RESULTS+=("$bin||missing|$role|$hint")
      missing_required="${missing_required:+$missing_required,}$bin"
    else
      RESULTS+=("$bin||missing|$role|$hint")
      missing_optional="${missing_optional:+$missing_optional,}$bin"
    fi
  fi
done

IFS=',' read -r -a REQ_LIST <<< "$REQUIRED"
missing_req_list=""
for bin in "${REQ_LIST[@]}"; do
  [[ -z "$bin" ]] && continue
  command -v "$bin" >/dev/null 2>&1 || missing_req_list="${missing_req_list:+$missing_req_list,}$bin"
done

if [[ "$JSON" -eq 1 ]]; then
  printf '{\n  "results": [\n'
  first=1
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r bin path state role hint <<< "$r"
    [[ "$first" -eq 0 ]] && printf ',\n'
    first=0
    printf '    {"bin": "%s", "path": "%s", "state": "%s", "role": "%s", "hint": "%s"}' \
      "$bin" "$path" "$state" "${role//\"/}" "${hint//\"/}"
  done
  printf '\n  ],\n  "required": "%s",\n  "missing_required": "%s",\n  "missing_optional": "%s"\n}\n' \
    "$REQUIRED" "$missing_req_list" "$missing_optional"
else
  echo "======================================================================="
  echo " EVOX-CI preflight — dependências externas"
  echo "======================================================================="
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r bin path state role hint <<< "$r"
    if [[ "$state" == "present" ]]; then
      printf '  [ok]   %-20s %-45s %s\n' "$bin" "$path" "$role"
    else
      printf '  [--]   %-20s %-45s %s\n' "$bin" "(ausente)" "$role"
    fi
  done
  echo "-----------------------------------------------------------------------"
  echo "exigidos agora : ${REQUIRED}"
  [[ -n "$missing_req_list" ]] && echo "FALTANDO        : $missing_req_list"
  [[ -n "$missing_optional" ]] && echo "opcionais ausentes: $missing_optional"
  if [[ "$HINTS" -eq 1 && ( -n "$missing_req_list" || -n "$missing_optional" ) ]]; then
    echo "-----------------------------------------------------------------------"
    echo "como instalar:"
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r bin path state role hint <<< "$r"
      [[ "$state" == "missing" ]] && printf '  %-20s %s\n' "$bin" "$hint"
    done
  fi
  echo "======================================================================="
fi

if [[ -n "$missing_req_list" ]]; then
  echo "[BLOQUEADO] dependência exigida ausente: $missing_req_list" >&2
  exit 1
fi
exit 0
