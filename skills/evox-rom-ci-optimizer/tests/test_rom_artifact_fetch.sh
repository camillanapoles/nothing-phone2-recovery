#!/usr/bin/env bash
# rom_artifact_fetch.sh — coleta determinística dos dois zips (12 casos, curl simulado)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/rom_artifact_fetch.sh"
P=0; F=0
ok(){ printf 'PASS  %-52s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-52s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'AAAA-vanilla' > "$T/van.zip"; printf 'BBBB-gapps' > "$T/gap.zip"
BIN="$T/bin"; mkdir -p "$BIN"
cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    --retry|--retry-delay) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
[ -n "${CURL_CALLS:-}" ] && printf '%s\n' "$url" >> "$CURL_CALLS"
case "$url" in
  *boom*) exit 6 ;;
  *wrong*) printf 'TAMPERED' > "$out"; exit 0 ;;
  *van.zip) cp "$FIXT/van.zip" "$out"; exit 0 ;;
  *gap.zip) cp "$FIXT/gap.zip" "$out"; exit 0 ;;
  *) exit 22 ;;
esac
STUB
chmod +x "$BIN/curl"

mk_manifest(){ python3 - "$T" "$1" <<'PY'
import json,sys
t,mode=sys.argv[1],sys.argv[2]
base=f"file://{t}"
m={"schema":"evox-rom-artifacts/1","device":"Pong","android":"16","build":"2026-09-15","version":"11.11",
 "variants":[
   {"id":"vanilla","label":"V","filename":"v.zip","url":base+"/van.zip","sha256":None},
   {"id":"gapps","label":"G","filename":"g.zip","url":(base+"/wrong.zip" if mode=="wrong" else base+"/gap.zip"),"sha256":None}]}
json.dump(m,open(t+"/m_"+mode+".json","w"))
PY
}
mk_manifest ok; mk_manifest wrong
python3 - "$T" <<'PY'
import json,sys
t=sys.argv[1]
m=json.load(open(t+"/m_ok.json"))
m["variants"][0]["url"]=f"file://{t}/boom.zip"
json.dump(m,open(t+"/m_net.json","w"))
m2=json.load(open(t+"/m_ok.json"))
m2["variants"][0]["sha256"]="0"*64
json.dump(m2,open(t+"/m_sha.json","w"))
PY

run(){ FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$@" >/dev/null 2>&1; echo $?; }
A="$T/art"; L="$T/lock.json"; E="$T/evox.env"

ck "sem --variant é uso inválido" "exit" "$(run "$S" --manifest "$T/m_ok.json")" "2"
ck "variante inexistente é uso inválido" "exit" "$(run "$S" --variant x --manifest "$T/m_ok.json")" "2"
ck "sem curl instalado = 5" "exit" \
  "$(ROM_FETCH_CURL="$T/nao-existe" "$S" --variant both --manifest "$T/m_ok.json" --dest "$A" >/dev/null 2>&1; echo $?)" "5"

CALLS="$T/calls1"
ck "baixa as duas variantes = 0" "exit" \
  "$(CURL_CALLS="$CALLS" FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$S" --variant both --manifest "$T/m_ok.json" --dest "$A" --lock "$L" --env-out "$E" >/dev/null 2>&1; echo $?)" "0"
ck "dois arquivos presentes" "2" "$(ls "$A" | grep -c '\.zip$')" "2"
ck "pin grava sha256 das duas" "2" \
  "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(sum(1 for v in d["pins"].values() if v.get("sha256")))' "$L")" "2"
ck "env tem caminho absoluto do vanilla" "abs" \
  "$(bash -c 'source "$1"; case "$EVOX_ZIP_VANILLA" in /*) echo abs;; *) echo rel;; esac' _ "$E")" "abs"
ck "env marca variante como indefinida" "undecided" \
  "$(bash -c 'source "$1"; echo "$EVOX_VARIANT"' _ "$E")" "undecided"

CALLS2="$T/calls2"
ck "segunda execução não rebaixa (exit 0)" "0" \
  "$(CURL_CALLS="$CALLS2" FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$S" --variant both --manifest "$T/m_ok.json" --dest "$A" --lock "$L" --env-out "$E" >/dev/null 2>&1; echo $?)" "0"
ck "segunda execução não chamou curl" "nenhuma" \
  "$([ -s "$CALLS2" ] && echo chamou || echo nenhuma)" "nenhuma"
ck "--verify offline passa" "exit" "$(run "$S" --variant both --manifest "$T/m_ok.json" --dest "$A" --lock "$L" --verify)" "0"

printf 'X' >> "$A/v.zip"
ck "arquivo adulterado = drift (4)" "exit" "$(run "$S" --variant both --manifest "$T/m_ok.json" --dest "$A" --lock "$L" --verify)" "4"

B="$T/art2"
ck "sha do manifesto divergente = drift (4)" "exit" \
  "$(CURL_CALLS="$T/c3" FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$S" --variant vanilla --manifest "$T/m_sha.json" --dest "$B" --lock "$T/l2.json" >/dev/null 2>&1; echo $?)" "4"
ck "arquivo divergente guardado como .mismatch" "sim" \
  "$([ -f "$B/v.zip.mismatch" ] && echo sim || echo nao)" "sim"

D="$T/art3"
ck "sem rede = 3 e nada é gravado" "exit" \
  "$(CURL_CALLS="$T/c4" FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$S" --variant vanilla --manifest "$T/m_net.json" --dest "$D" --lock "$T/l3.json" >/dev/null 2>&1; echo $?)" "3"
ck "sem rede não deixa .zip parcial" "0" "$(ls "$D" | grep -c '\.zip$')" "0"

ck "JSON coerente com o exit code" "3" \
  "$(CURL_CALLS="$T/c5" FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$S" --variant vanilla --manifest "$T/m_net.json" --dest "$T/art4" --lock "$T/l4.json" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["exit_code"])')" "3"
ck "variante gapps fixa EVOX_ZIP=GAPPS" "sim" \
  "$(FIXT="$T" ROM_FETCH_CURL="$BIN/curl" "$S" --variant gapps --manifest "$T/m_ok.json" --dest "$T/art5" --lock "$T/l5.json" --env-out "$T/e5" >/dev/null 2>&1; bash -c 'source "$1"; [ "$EVOX_ZIP" = "$EVOX_ZIP_GAPPS" ] && echo sim || echo nao' _ "$T/e5")" "sim"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
