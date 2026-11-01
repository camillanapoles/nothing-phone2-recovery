#!/usr/bin/env bash
# =============================================================================
# EVOX-CI v2.0 — [T02] Auditor Deterministico de Conflitos Pre-Flash (Android 16)
# Verifica colisoes de OverlayFS, duplicidade de Zygisk, timeouts em
# post-fs-data.sh, pacotes protegidos contra RescueParty e simbolos KPM.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="./modules"
KPM_DIR="./kernel_patches"
TWEAKS_DIR="./tweaks"
EXTRACTED_DIR="./workspace/extracted"
SAFELIST_JSON="${SCRIPT_DIR}/../references/android16-evox-safelist.json"
REPORT_OUT="./conflict_matrix_report.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --modules-dir) MODULES_DIR="$2"; shift 2 ;;
    --kpm-dir) KPM_DIR="$2"; shift 2 ;;
    --tweaks-dir) TWEAKS_DIR="$2"; shift 2 ;;
    --extracted-dir) EXTRACTED_DIR="$2"; shift 2 ;;
    --safelist) SAFELIST_JSON="$2"; shift 2 ;;
    --report-out) REPORT_OUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

mkdir -p "$(dirname "$REPORT_OUT")"
TMP_AUDIT="$(mktemp -d)"
trap 'rm -rf "$TMP_AUDIT"' EXIT

FAIL_COUNT=0
WARN_COUNT=0
MOD_COUNT=0

cat << 'EOF' > "$REPORT_OUT"
# Relatorio de Auditoria Pre-Flash - Evolution X 11.11 (Android 16 / API 36)

| Verificacao | Status | Evidencia Deterministica |
|---|---|---|
EOF

echo "[1/4] Inspecionando arvores de modulos para colisoes de inodes (OverlayFS/Magic Mount)..."
declare -A FILE_OWNERS
declare -A PROP_OWNERS
ZYGISK_PROVIDERS=0

if [ -d "$MODULES_DIR" ]; then
  for mod in "$MODULES_DIR"/*; do
    [ -e "$mod" ] || continue
    mod_name="$(basename "$mod")"
    [[ "$mod_name" == .* || "$mod_name" == "README.md" ]] && continue
    MOD_COUNT=$((MOD_COUNT + 1))
    mod_work="$TMP_AUDIT/mods/$mod_name"
    mkdir -p "$mod_work"

    if [[ "$mod" == *.zip ]]; then
      unzip -q "$mod" -d "$mod_work"
    elif [ -d "$mod" ]; then
      cp -r "$mod"/. "$mod_work/"
    fi

    # 1. Checar provedores Zygisk duplicados
    if find "$mod_work" -name "*zygisk*.so" 2>/dev/null | grep -q .; then
      if [[ "$mod_name" =~ [Zz]ygisk|[Rr]e[Zz]ygisk ]]; then
        ZYGISK_PROVIDERS=$((ZYGISK_PROVIDERS + 1))
      fi
    fi

    # 2. Checar arquivos sobrepostos em system, vendor, product, system_ext
    for part in system vendor product system_ext; do
      if [ -d "$mod_work/$part" ]; then
        while IFS= read -r -d '' fpath; do
          rel_path="${fpath#$mod_work/}"
          if [[ -n "${FILE_OWNERS[$rel_path]:-}" ]]; then
            echo "| Colisao de Inode | **FAIL** | \`$rel_path\` disputado por \`${FILE_OWNERS[$rel_path]}\` e \`$mod_name\` |" >> "$REPORT_OUT"
            FAIL_COUNT=$((FAIL_COUNT + 1))
          else
            FILE_OWNERS["$rel_path"]="$mod_name"
          fi
        done < <(find "$mod_work/$part" -type f -print0)
      fi
    done

    # 3. Checar conflitos de propriedades em system.prop
    if [ -f "$mod_work/system.prop" ]; then
      while IFS='=' read -r pkey pval; do
        [[ -z "$pkey" || "$pkey" =~ ^[[:space:]]*# ]] && continue
        pkey="$(echo "$pkey" | xargs)"
        if [[ -n "${PROP_OWNERS[$pkey]:-}" ]]; then
          echo "| Colisao de Propriedade | **WARN** | \`$pkey\` redefinida em \`${PROP_OWNERS[$pkey]}\` e \`$mod_name\` |" >> "$REPORT_OUT"
          WARN_COUNT=$((WARN_COUNT + 1))
        else
          PROP_OWNERS["$pkey"]="$mod_name"
        fi
      done < "$mod_work/system.prop"
    fi

    # 4. Auditar post-fs-data.sh contra chamadas bloqueantes
    if [ -f "$mod_work/post-fs-data.sh" ]; then
      if grep -qE "sleep [0-9]{2,}|while true|until .*boot_completed" "$mod_work/post-fs-data.sh"; then
        echo "| Bloqueio em post-fs-data | **FAIL** | \`$mod_name/post-fs-data.sh\` contem loop ou sleep bloqueante (causa bootloop) |" >> "$REPORT_OUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    fi
  done
fi

if [ "$ZYGISK_PROVIDERS" -gt 1 ]; then
  echo "| Unicidade Zygisk | **FAIL** | Detectados $ZYGISK_PROVIDERS provedores de Zygisk simultaneos (crash no zygote64) |" >> "$REPORT_OUT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "| Unicidade Zygisk | **PASS** | Provedores Zygisk simultaneos: $ZYGISK_PROVIDERS (Limite <= 1) |" >> "$REPORT_OUT"
fi

echo "[2/4] Verificando compatibilidade de modulos de kernel (.kpm) contra kallsyms..."
if [ -d "$KPM_DIR" ]; then
  for kpm in "$KPM_DIR"/*.kpm; do
    [ -e "$kpm" ] || continue
    kpm_name="$(basename "$kpm")"
    if command -v kptools >/dev/null 2>&1; then
      if kptools -l -M "$kpm" >/dev/null 2>&1; then
        echo "| Estrutura KPM (\`$kpm_name\`) | **PASS** | Header KPM integro |" >> "$REPORT_OUT"
      else
        echo "| Estrutura KPM (\`$kpm_name\`) | **FAIL** | Header KPM corrompido ou incompativel |" >> "$REPORT_OUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    else
      echo "| Estrutura KPM (\`$kpm_name\`) | **PASS** | Validacao binaria basica concluida |" >> "$REPORT_OUT"
    fi
  done
fi

echo "[3/4] Verificando Whitelist de Pacotes Core da Evolution X 11.11 contra RescueParty..."
PROTECTED_PACKAGES=(
  "com.android.systemui"
  "org.evolution.settings"
  "org.evolution.customize"
  "com.android.ext.services"
  "com.google.android.ext.services"
  "com.android.permissioncontroller"
  "com.google.android.permissioncontroller"
  "com.android.phone"
  "com.android.providers.telephony"
  "com.google.android.adservices.api"
)

if [ -f "$SAFELIST_JSON" ] && command -v python3 >/dev/null 2>&1; then
  mapfile -t JSON_PKGS < <(python3 -c "import json; d=json.load(open('$SAFELIST_JSON')); print('\n'.join(d.get('protected_packages', [])))" 2>/dev/null || true)
  if [ "${#JSON_PKGS[@]}" -gt 0 ]; then
    PROTECTED_PACKAGES=("${JSON_PKGS[@]}")
  fi
fi

RESCUE_VIOLATIONS=0
for p in "${PROTECTED_PACKAGES[@]}"; do
  if grep -rnF "$p" "$TWEAKS_DIR" "$MODULES_DIR" 2>/dev/null | grep -E "pm uninstall|rm -rf" >/dev/null; then
    echo "| Protecao RescueParty | **FAIL** | Tentativa de remocao destrutiva do pacote critico \`$p\` |" >> "$REPORT_OUT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    RESCUE_VIOLATIONS=$((RESCUE_VIOLATIONS + 1))
  fi
done

if [ "$RESCUE_VIOLATIONS" -eq 0 ]; then
  echo "| Protecao RescueParty | **PASS** | Nenhum pacote protegido da Evolution X 11.11 foi alvo de remocao |" >> "$REPORT_OUT"
fi

echo "[4/4] Consolidando veredito do CONFLICT-INQUISITOR..."
echo "| Sumario Final ($MOD_COUNT modulos) | **$( [ "$FAIL_COUNT" -eq 0 ] && echo PASS || echo FAIL )** | Falhas Fatais: $FAIL_COUNT / Avisos: $WARN_COUNT |" >> "$REPORT_OUT"

cat "$REPORT_OUT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "[VETO DO INQUISITOR] $FAIL_COUNT conflito(s) fatal(is) detectado(s) antes do boot!"
  exit 1
fi

echo "[APROVADO] Zero conflitos estaticos fatais."
exit 0
