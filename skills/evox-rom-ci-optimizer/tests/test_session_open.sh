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
d["build"].update({"flavor": "gapps", "flavor_source": "user", "rationale": "M03 já resolvido; banking e IA prontos",
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
# --- modo auto: só decisões delegadas -----------------------------------
D="$T/auto.json"
ck "auto preenche sem erro" "exit" "$(python3 "$S" auto --out "$D" >/dev/null 2>&1; echo $?)" "0"
ck "auto fixa kernel stock+apatch" "stock+apatch" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["kernel"]["choice"])' "$D")" "stock+apatch"
ck "auto registra P10–P14" "5" \
  "$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["defaults"])-3)' "$D")" "5"
ck "auto mantém build/zip pendentes" "build.zip_path" \
  "$(python3 -c 'import json,subprocess,sys;o=subprocess.run([sys.executable,sys.argv[1],"check","--file",sys.argv[2],"--json"],capture_output=True,text=True);print("build.zip_path" if "build.zip_path" in json.loads(o.stdout)["pending"] else "ausente")' "$S" "$D")" "build.zip_path"
ck "auto mantém P3 (binários) preenchido" "sim" \
  "$(python3 -c 'import json,sys;print("sim" if all(i["authorized"] for i in json.load(open(sys.argv[1]))["installs"]) else "nao")' "$D")" "sim"


# P1 é decisão da usuária: variante sem flavor_source=user continua pendente
D2="$T/p1.json"
python3 "$S" auto --out "$D2" >/dev/null 2>&1
python3 - "$D2" <<'PYE'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["build"].update({"flavor":"gapps","zip_path":"/x/rom.zip","zip_sha256":"a"*64})  # sem flavor_source
json.dump(d,open(p,"w"))
PYE
ck "flavor sem fonte humana segue pendente" "sim" \
  "$(python3 -c 'import json,subprocess,sys;o=subprocess.run([sys.executable,sys.argv[1],"check","--file",sys.argv[2],"--json"],capture_output=True,text=True);print("sim" if any("P1 é decisão da usuária" in x for x in json.loads(o.stdout)["pending"]) else "nao")' "$S" "$D2")" "sim"
ck "auto não inventa variante (decisão completa fica)" "None" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["build"]["flavor"])' "$D")" "None"
# variante herdada (sem fonte humana) tem de ser limpa pelo auto
D3="$T/auto2.json"
python3 "$S" auto --out "$D3" >/dev/null 2>&1
python3 - "$D3" <<'PYH'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["build"]["flavor"]="gapps"   # herdada, flavor_source continua nulo
json.dump(d,open(p,"w"))
PYH
python3 "$S" auto --out "$D3" >/dev/null 2>&1
ck "auto limpa variante herdada" "None" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["build"]["flavor"])' "$D3")" "None"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
