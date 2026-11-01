#!/usr/bin/env bash
# Rollout canário — 1 módulo por vez, evidência antes do próximo (11 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/rollout_gate.sh"
P=0; F=0
ok(){ printf 'PASS  %-46s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-46s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
run(){ "$@" >/dev/null 2>&1; echo $?; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
echo "artefato M01" > "$T/m01.img"; echo "artefato M02" > "$T/m02.img"
S1="$T/ledger1.json"; S2="$T/ledger2.json"
python3 - "$T" <<'PY'
import json, os, sys
t = sys.argv[1]
good = {"boot":{"ok":True},"crashes":0,"stability":{"uptime_min":12},"avc_denials":0}
bad  = {"boot":{"ok":True},"crashes":3,"stability":{"uptime_min":12}}
curto= {"boot":{"ok":True},"crashes":0,"stability":{"uptime_min":4}}
for n,d in (("good",good),("bad",bad),("curto",curto)):
    json.dump(d, open(os.path.join(t,f"{n}.json"),"w"))
PY

ck "sem comando pede uso" "exit" "$(run "$S")" "2"
ck "abre M01 (W1)" "exit" "$(run "$S" start --state "$S1" --wave W1 --module M01 --artifact "$T/m01.img")" "0"
ck "segundo módulo simultâneo é bloqueado" "exit" "$(run "$S" start --state "$S1" --wave W1 --module M02 --artifact "$T/m02.img")" "3"
ck "evidência com crash reprova" "exit" "$(run "$S" record --state "$S1" --module M01 --evidence "$T/bad.json")" "3"
ck "módulo FAILED trava o próximo" "exit" "$(run "$S" start --state "$S1" --wave W1 --module M02 --artifact "$T/m02.img")" "3"
ck "uptime curto reprova" "exit" "$(run "$S" record --state "$S1" --module M01 --evidence "$T/curto.json")" "3"
run "$S" reset --state "$S1" --module M01 >/dev/null
ck "evidência saudável aprova" "exit" "$(run "$S" record --state "$S1" --module M01 --evidence "$T/good.json")" "0"
ck "próximo módulo liberado após PASS" "exit" "$(run "$S" start --state "$S1" --wave W1 --module M02 --artifact "$T/m02.img")" "0"
ck "onda que regride é recusada (R09)" "exit" "$(run "$S" start --state "$S2" --wave W2 --module M03 --artifact "$T/m01.img")" "0"
run "$S" start --state "$S2" --wave W1 --module M04 --artifact "$T/m01.img" >/dev/null 2>&1
python3 - "$S2" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); d["modules"][0]["state"]="passed"; json.dump(d,open(sys.argv[1],"w"))
PY
ck "onda decrescente é bloqueada" "exit" "$(run "$S" start --state "$S2" --wave W0 --module M05 --artifact "$T/m01.img")" "3"
ck "artefato inexistente é recusado" "exit" "$(run "$S" start --state "$T/s3.json" --wave W1 --module M09 --artifact "$T/nao.img")" "4"
ck "sha256 divergente é recusado" "exit" "$(run "$S" start --state "$T/s4.json" --wave W1 --module M09 --artifact "$T/m01.img" --sha256 "$(printf '0%.0s' {1..64})")" "4"
ck "status --json é parseável" "passed" \
  "$("$S" status --state "$S1" --json | python3 -c 'import json,sys;print(",".join(json.load(sys.stdin)["passed"]))')" "M01"
echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
