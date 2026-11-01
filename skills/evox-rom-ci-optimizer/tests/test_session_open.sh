#!/usr/bin/env bash
# Protocolo de abertura: decisão registrada antes de baixar/instalar (8 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/session_open.py"
P=0; F=0
ok(){ printf 'PASS  %-46s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-46s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
run(){ python3 "$S" "$@" >/dev/null 2>&1; echo $?; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ck "sem comando pede uso" "exit" "$(run)" "2"
ck "template cria decisão vazia" "exit" "$(run template --out "$T/dec.json")" "0"
ck "decisão vazia está PENDENTE" "exit" "$(run check --file "$T/dec.json")" "3"
ck "check aponta campo faltante" "build.flavor" \
  "$(python3 "$S" check --file "$T/dec.json" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["pending"][0])')" "build.flavor"

python3 - "$T/dec.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["build"].update({"flavor": "gapps", "rationale": "M03 já resolvido; banking e IA prontos",
                   "zip_path": "/dados/EvolutionX-11.11-Official.zip", "zip_sha256": "a"*64})
for i in d["installs"]: i["authorized"] = True
d["kernel"].update({"choice": "stock+apatch", "rationale": "menor variável; rollback verificado"})
for m in d["modules"]: m["approved"] = True
d["canary"]["approved"] = True
d["cache"]["approved"] = True
d["usb"]["acknowledged"] = True
json.dump(d, open(p, "w"), indent=2)
PY
ck "decisão completa libera execução" "exit" "$(run check --file "$T/dec.json")" "0"
ck "check --json reporta complete" "True" \
  "$(python3 "$S" check --file "$T/dec.json" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["complete"])')" "True"
ck "decisão inexistente é erro" "exit" "$(run check --file "$T/nao.json")" "4"
printf '{ nao json' > "$T/quebrado.json"
ck "decisão inválida é erro" "exit" "$(run check --file "$T/quebrado.json")" "4"
ck "questions lista P1..P8" "8" "$(python3 "$S" questions | grep -c '^  P[0-9]')" "8"
ck "módulo sem aprovação trava" "exit" \
  "$(python3 - "$T/dec.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["modules"][0]["approved"]=None
json.dump(d,open(p,"w"))
PY
  run check --file "$T/dec.json")" "3"
echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
