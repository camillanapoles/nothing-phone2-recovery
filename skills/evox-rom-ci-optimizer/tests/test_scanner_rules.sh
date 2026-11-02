#!/usr/bin/env bash
# =============================================================================
# Harness de regressao das regras do CONFLICT-INQUISITOR (scanner v3.1)
# Cada caso monta um diretorio modules/ sintetico e exige a regra esperada.
# Uso: ./tests/test_scanner_rules.sh   (exit 0 = todas as regras conforme contrato)
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCANNER="$SKILL_DIR/scripts/static_conflict_scanner.py"
PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# build_zip <destino.zip> "caminho::conteudo" ...
build_zip() {
  local out="$1"; shift
  local tmp="$WORK/stage.$$"
  rm -rf "$tmp"; mkdir -p "$tmp"
  local spec path content
  for spec in "$@"; do
    path="${spec%%::*}"
    content="${spec#*::}"
    mkdir -p "$tmp/$(dirname "$path")"
    printf '%s\n' "$content" > "$tmp/$path"
  done
  ( cd "$tmp" && zip -qr "$out" . )
  rm -rf "$tmp"
}

# assert_rule <nome-do-caso> <regra-esperada|CLEAN> <exit-esperado> <setup-comando...>
assert_rule() {
  local name="$1" expected="$2" expected_exit="$3"; shift 3
  local dir="$WORK/case"
  rm -rf "$dir"; mkdir -p "$dir/modules"
  MOD="$dir/modules"
  "$@"
  local out="$dir/report.json"
  python3 "$SCANNER" --modules-dir "$dir/modules" --out "$out" --quiet
  local rc=$?
  if [ "$rc" -ne "$expected_exit" ]; then
    printf 'FAIL  %-42s exit=%s esperado=%s\n' "$name" "$rc" "$expected_exit"
    FAIL=$((FAIL + 1)); return
  fi
  if [ "$expected" = "CLEAN" ]; then
    if [ "$rc" -eq 0 ] && grep -q '"status": "CLEAN"' "$out"; then
      printf 'PASS  %-42s CLEAN\n' "$name"; PASS=$((PASS + 1))
    else
      printf 'FAIL  %-42s esperava CLEAN\n' "$name"; FAIL=$((FAIL + 1))
    fi
    return
  fi
  if grep -q "$expected" "$out"; then
    printf 'PASS  %-42s %s\n' "$name" "$expected"; PASS=$((PASS + 1))
  else
    printf 'FAIL  %-42s regra ausente: %s\n' "$name" "$expected"; FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------- fixtures ----
fixture_clean() {
  build_zip "$MOD/magisk-kernel.zip" \
    "META-INF/com/google/android/update-binary::#!sbin/sh" \
    "system/etc/hosts::127.0.0.1 localhost"
}

fixture_file_overwrite() {
  build_zip "$MOD/audio-mod-a.zip" "system/etc/audio_effects.xml::<xml>a</xml>"
  build_zip "$MOD/audio-mod-b.zip" "system/etc/audio_effects.xml::<xml>b</xml>"
}

fixture_prop_collision() {
  build_zip "$MOD/tweak-a.zip" "system.prop::ro.sf.lcd_density=420"
  build_zip "$MOD/tweak-b.zip" "system.prop::ro.sf.lcd_density=560"
}

fixture_duplicate_zygisk() {
  build_zip "$MOD/Zygisk-Next.zip" "system/lib64/libzygisk.so::ELF"
  build_zip "$MOD/ReZygisk.zip" "system/lib64/libzygisk.so::ELF2"
}

fixture_maxmanager_collision() {
  build_zip "$MOD/MaxManager-V2.zip" "system.prop::persist.vendor.max.enabled=1"
  build_zip "$MOD/thermal_unlock.zip" "system/etc/thermal-engine.conf::[thermal]"
}

fixture_sysctl_scope() {
  build_zip "$MOD/MaxManager-V2.zip" "system.prop::persist.vendor.max.enabled=1"
  build_zip "$MOD/tweaks-net.zip" "tweaks/sysctl.conf::vm.swappiness=120"
}

fixture_droidspaces_susfs() {
  build_zip "$MOD/DroidSpaces.zip" "system.prop::ro.droidspaces=1"
  build_zip "$MOD/SuSFS.zip" "system.prop::ro.susfs=1"
}

fixture_duck_duplicates() {
  build_zip "$MOD/Duck-ToolBox.zip" "system.prop::ro.duck.toolbox=1"
  build_zip "$MOD/TrickyStore.zip" "system.prop::ro.trickystore=1"
}

fixture_geniex_unbound() {
  build_zip "$MOD/GenieX-QAIRT.zip" "system.prop::ro.geniex.enabled=1"
}

fixture_persist_write() {
  build_zip "$MOD/fp-calib.zip" "persist/fingerprint/calib.bin::BINARY"
}

fixture_privapp_missing() {
  build_zip "$MOD/gcam-port.zip" "product/priv-app/GCam/GCam.apk::APK"
}

fixture_selinux_permissive() {
  build_zip "$MOD/bank-fix.zip" "post-fs-data.sh::setenforce 0"
}

fixture_wave_order() {
  build_zip "$MOD/MaxManager-V2.zip" "system.prop::persist.vendor.max.enabled=1"
}

echo "======================================================================="
echo " CONFLICT-INQUISITOR v3.1 - regressao das regras (R00..R09)"
echo "======================================================================="

assert_rule "R00 cenario limpo"                       CLEAN                               0 fixture_clean
assert_rule "R00 colisao de inode em OverlayFS"       R00_FILE_OVERWRITE                  1 fixture_file_overwrite
assert_rule "R00 colisao de system.prop"              R00_PROP_COLLISION                  1 fixture_prop_collision
assert_rule "R00 dois provedores Zygisk"              R00_DUPLICATE_ZYGISK_PROVIDER       1 fixture_duplicate_zygisk
assert_rule "R01 MaxManager x escritor termico"       R01_MAXMANAGER_EXCLUSIVITY           1 fixture_maxmanager_collision
assert_rule "R02 sysctl fora do escopo de intranet"   R02_MAXMANAGER_SYSCTL_SCOPE          0 fixture_sysctl_scope
assert_rule "R03 DroidSpaces x SuSFS"                 R03_DROIDSPACES_SUSFS                0 fixture_droidspaces_susfs
assert_rule "R04 Duck-ToolBox x spoof avulso"         R04_DUCK_TOOLBOX_CONSOLIDATION       0 fixture_duck_duplicates
assert_rule "R05 GenieX sem /dev/adsprpc-smd"         R05_GENIEX_NPU_DEVICE_UNBOUND        0 fixture_geniex_unbound
assert_rule "R06 escrita em persist"                  R06_PERSIST_WRITE                    1 fixture_persist_write
assert_rule "R07 priv-app sem XML de permissao"       R07_PRIVAPP_PERMISSION_MISSING       1 fixture_privapp_missing
assert_rule "R08 SELinux permissivo"                  R08_SELINUX_PERMISSIVE               1 fixture_selinux_permissive
assert_rule "R09 onda superior sem fundacao W1"       R09_WAVE_ORDER_VIOLATION             0 fixture_wave_order

echo "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "[OK] Contrato das regras R00..R09 respeitado."
