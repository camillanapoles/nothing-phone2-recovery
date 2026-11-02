#!/usr/bin/env bash
# =============================================================================
# Regressão do coletor de evidência (L2) — sem device real, com stub de adb.
# Casos: sucesso (boot ok), boot incompleto (exit 4), adb ausente (exit 3),
#        manifesto SHA-256 verificável e schema do evidence.json.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/collect_evidence.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0

ok()   { printf 'PASS  %-46s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
bad()  { printf 'FAIL  %-46s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# ---- stub de adb -------------------------------------------------------------
make_stub() { # make_stub <dir> <boot_completed> <mode: full|no-device>
  local dir="$1" boot="$2" mode="${3:-full}"
  mkdir -p "$dir"
  cat > "$dir/adb" <<EOF
#!/usr/bin/env bash
mode="$mode"; boot="$boot"
args="\$*"
case "\$args" in
  *get-state*) [ "\$mode" = "no-device" ] && exit 1; echo device; exit 0 ;;
esac
case "\$args" in
  *"ro.build.version.sdk"*) echo 36 ;;
  *"ro.build.version.release"*) echo 16 ;;
  *"ro.boot.slot_suffix"*) echo _b ;;
  *"ro.product.device"*) echo pong ;;
  *"uname -a"*) echo "Linux localhost 6.1.99-android14-11 aarch64" ;;
  *"sys.boot_completed"*) echo "\$boot" ;;
  *"getenforce"*) echo Enforcing ;;
  *"avc: denied"*) echo 3 ;;
  *"command -v"*) echo "apd: /data/adb/apd" ;;
  *"ls -1 /data/adb/modules"*) printf "Zygisk-Next\nTrickyStore\n" ;;
  *"FATAL EXCEPTION"*) echo "" ;;
  *"getprop"*) echo "[ro.build.version.sdk]: [36]" ;;
  *) echo "fixture" ;;
esac
exit 0
EOF
  chmod +x "$dir/adb"
}

# ---- caso 1: sucesso ---------------------------------------------------------
STUB="$WORK/stub-ok"; make_stub "$STUB" 1
OUT="$WORK/ev-ok"
ADB_BIN="$STUB/adb" "$SCRIPT" --out "$OUT" --timeout 5 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "coletor com device saudável" "exit=0" || bad "coletor com device saudável" "exit=$rc"

[ -f "$OUT/evidence.json" ] && [ -f "$OUT/MANIFEST.sha256" ] \
  && ok "artefatos gerados" "evidence.json + MANIFEST.sha256" \
  || bad "artefatos gerados" "arquivos ausentes"

python3 - "$OUT/evidence.json" <<'PY' && ok "schema do evidence.json" "campos obrigatórios presentes" || bad "schema do evidence.json" "campo ausente"
import json, sys
d = json.load(open(sys.argv[1]))
for key in ("collector","device","boot","selinux","root_engine","stability","files"):
    assert key in d, key
assert d["boot"]["ok"] is True
assert d["device"]["codename"] == "pong"
assert d["device"]["sdk"] == "36"
assert d["selinux"]["enforcing_ok"] is True
assert d["stability"]["avc_denied_count"] == 3
assert len(d["files"]) >= 10
PY

( cd "$OUT" && sha256sum -c MANIFEST.sha256 --quiet >/dev/null 2>&1 ) \
  && ok "manifesto SHA-256 verificável" "sha256sum -c OK" \
  || bad "manifesto SHA-256 verificável" "checksum divergente"

# ---- caso 2: boot incompleto -------------------------------------------------
STUB2="$WORK/stub-boot0"; make_stub "$STUB2" 0
OUT2="$WORK/ev-boot0"
ADB_BIN="$STUB2/adb" "$SCRIPT" --out "$OUT2" --timeout 5 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 4 ] && ok "boot não concluído" "exit=4 (evidência parcial)" || bad "boot não concluído" "exit=$rc (esperado 4)"

python3 - "$OUT2/evidence.json" <<'PY' >/dev/null 2>&1 && ok "boot incompleto marcado no JSON" "boot.ok=false" || bad "boot incompleto marcado no JSON" "flag incorreta"
import json, sys
assert json.load(open(sys.argv[1]))["boot"]["ok"] is False
PY

# ---- caso 3: sem device ------------------------------------------------------
STUB3="$WORK/stub-no-device"; make_stub "$STUB3" 1 no-device
ADB_BIN="$STUB3/adb" "$SCRIPT" --out "$WORK/ev-none" --timeout 5 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 3 ] && ok "device indisponível" "exit=3" || bad "device indisponível" "exit=$rc (esperado 3)"

# ---- caso 4: adb ausente -----------------------------------------------------
ADB_BIN="/nonexistent/adb" "$SCRIPT" --out "$WORK/ev-noadb" --timeout 5 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 3 ] && ok "adb ausente" "exit=3" || bad "adb ausente" "exit=$rc (esperado 3)"

echo "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "[OK] coletor de evidência conforme contrato."
