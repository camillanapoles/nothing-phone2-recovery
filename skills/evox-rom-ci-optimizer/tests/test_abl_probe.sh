#!/usr/bin/env bash
# abl_fallback_probe.sh — classificação de falha A/B (9 casos, sem device)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/abl_fallback_probe.sh"
P=0; F=0
ok(){ printf 'PASS  %-52s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-52s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; mkdir -p "$BIN"
cat > "$BIN/adb" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "devices"|"devices "*|*" devices"*) [ "${ADB_MODE:-device}" = "none" ] && { echo "List of devices attached"; exit 0; }
                echo "List of devices attached"; printf 'XYZ\tdevice\n'; exit 0 ;;
  *"getprop sys.boot_completed"*) echo "${ADB_BOOT:-1}"; exit 0 ;;
  *"getprop ro.boot.slot_suffix"*) echo "${ADB_SLOT:-_b}"; exit 0 ;;
  *"ls -1 /data/adb/slot_router/marks"*) echo "${ADB_MARKS-b_1.mark}"; exit 0 ;;
  *"console-ramoops"*) echo "=== pstore stub ==="; exit 0 ;;
  *) echo "stub: $*"; exit 0 ;;
esac
STUB
cat > "$BIN/fastboot" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "devices"|"devices "*|*" devices"*) [ -n "${FB_DEV:-}" ] && echo "$FB_DEV fastboot" || true; exit 0 ;;
  *) [ -n "${FB_CALLS:-}" ] && printf '%s\n' "$*" >> "$FB_CALLS"; exit 0 ;;
esac
STUB
chmod +x "$BIN/adb" "$BIN/fastboot"

run(){ ADB_BIN="$BIN/adb" FASTBOOT_BIN="$BIN/fastboot" "$@" >/dev/null 2>&1; echo $?; }
cls(){ python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["classification"])' "$1/boot_probe.json"; }

ck "staging == produção é uso inválido" "exit" "$(run "$S" --staging a --prod a --timeout 1 --evidence "$T/e0")" "2"
ck "boot no staging = OK" "exit" "$(ADB_BOOT=1 ADB_SLOT=_b run "$S" --staging b --prod a --timeout 1 --evidence "$T/e1")" "0"
ck "boot no slot de produção = ABL_FALLBACK" "exit" \
  "$(ADB_BOOT=1 ADB_SLOT=_a run "$S" --staging b --prod a --timeout 1 --evidence "$T/e2")" "3"
ck "classificação de fallback correta" "ABL_FALLBACK" "$(cls "$T/e2")" "ABL_FALLBACK"
ck "fallback guarda pstore" "arquivo" \
  "$([ -f "$T/e2/fallback_pstore.txt" ] && echo arquivo || echo ausente)" "arquivo"
ck "adb vivo sem boot_completed = HANG" "exit" \
  "$(ADB_BOOT=0 ADB_SLOT=_b ADB_MARKS='b_1.mark,b_2.mark' run "$S" --staging b --prod a --timeout 1 --evidence "$T/e3")" "4"
ck "marca presente classifica HANG" "HANG" "$(cls "$T/e3")" "HANG"
ck "HANG grava dumpsys e pstore" "2" \
  "$(ls "$T/e3" | grep -cE 'hang_(dumpsys|pstore)\.txt')" "2"
ck "sem marca de userspace = HANG_EARLY" "HANG_EARLY" \
  "$(ADB_BOOT=0 ADB_MARKS='' run "$S" --staging b --prod a --timeout 1 --evidence "$T/e4" >/dev/null 2>&1; cls "$T/e4")" "HANG_EARLY"
ck "sem adb e sem fastboot = NO_DEVICE" "NO_DEVICE" \
  "$(ADB_MODE=none FB_DEV='' run "$S" --staging b --prod a --timeout 1 --evidence "$T/e5" >/dev/null 2>&1; cls "$T/e5")" "NO_DEVICE"
ck "sem adb mas no bootloader = BOOTLOADER" "BOOTLOADER" \
  "$(ADB_MODE=none FB_DEV=XYZ run "$S" --staging b --prod a --timeout 1 --evidence "$T/e6" >/dev/null 2>&1; cls "$T/e6")" "BOOTLOADER"
ck "--rollback força set-active para produção" "--set-active=a" \
  "$(FB_CALLS="$T/fb_calls" ADB_BOOT=0 ADB_MARKS='b_1.mark' run "$S" --staging b --prod a --timeout 1 --evidence "$T/e7" --rollback >/dev/null; head -1 "$T/fb_calls")" "--set-active=a"
ck "JSON tem exit_code coerente" "4" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["exit_code"])' "$T/e7/boot_probe.json")" "4"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
