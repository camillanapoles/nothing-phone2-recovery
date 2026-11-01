#!/usr/bin/env bash
# Stage B — injeção 1-a-1 na AVD via ADB, com stub (7 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/sandbox_rollout.sh"
P=0; F=0
ok(){ printf 'PASS  %-48s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-48s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/mods"
for m in 01-root 02-camera; do printf 'PK\x03\x04%s\n' "$m" > "$T/mods/$m.zip"; done
cat > "$T/bin/adb" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *"wait-for-device"*) [ "${ADB_FAIL:-}" = "wait" ] && exit 1; exit 0 ;;
  *"getprop sys.boot_completed"*) [ "${ADB_BOOT:-1}" = "1" ] && echo 1 || echo 0 ;;
  *"getprop init.svc.bootanim"*) echo stopped ;;
  *"grep -cE"*) echo "${ADB_CRASH:-0}" ;;
  *"grep -c avc"*) echo 0 ;;
  *"dmesg"*) echo "dmesg stub" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$T/bin/adb"
export PATH="$T/bin:$PATH"

run(){ "$@" >/dev/null 2>&1; echo $?; }
ck "sem módulos não finge sucesso" "exit" "$(run "$S" --modules "$T/vazio" --state "$T/s1.json" --evidence "$T/e1" --observe 0)" "4"
ck "adb indisponível no wait" "exit" "$(ADB_FAIL=wait run "$S" --modules "$T/mods" --state "$T/s2.json" --evidence "$T/e2")" "4"
ck "boot que não conclui falha com evidência" "exit" \
  "$(ADB_BOOT=0 run "$S" --modules "$T/mods" --state "$T/s3.json" --evidence "$T/e3" --boot-timeout 2 --observe 0)" "4"
ck "evidência de falha de boot é gravada" "arquivo" \
  "$([ -f "$T/e3/boot_failure_dmesg.txt" ] && echo arquivo || echo ausente)" "arquivo"
ck "dois módulos = dois PASS sequenciais" "exit" \
  "$(run "$S" --modules "$T/mods" --state "$T/s4.json" --evidence "$T/e4" --observe 0 --wave W1)" "0"
ck "ledger registra ambos como passed" "2" \
  "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(sum(1 for m in d["modules"] if m["state"]=="passed"))' "$T/s4.json")" "2"
ck "evidência declara ambiente de emulação" "qemu-avd-api36-x86_64" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["environment"])' "$T/e4/01-root.json")" "qemu-avd-api36-x86_64"
ck "reuso do mesmo ledger é bloqueado" "exit" \
  "$(run "$S" --modules "$T/mods" --state "$T/s4.json" --evidence "$T/e5" --observe 0)" "3"
ck "crash de sistema reprova o módulo" "exit" \
  "$(ADB_CRASH=3 run "$S" --modules "$T/mods" --state "$T/s6.json" --evidence "$T/e6" --observe 0)" "3"
echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
