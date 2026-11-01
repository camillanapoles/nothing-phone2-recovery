#!/usr/bin/env bash
# Cache versionado + prova de rollback Guard-4 (13 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
C="$HERE/../scripts/cache_manager.sh"; G="$HERE/../scripts/guard4_verify.sh"
P=0; F=0
ok(){ printf 'PASS  %-48s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-48s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
run(){ "$@" >/dev/null 2>&1; echo $?; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
CACHE="$T/cache"; mkdir -p "$T/src"
printf 'conteudo do boot\n' > "$T/src/boot.img"

ck "put inline grava no cache" "exit" "$(run "$C" put --state "$CACHE" --phase extract --file "$T/src/boot.img" --proven-by teste)" "0"
ck "put repetido é idempotente" "exit" "$(run "$C" put --state "$CACHE" --phase extract --file "$T/src/boot.img")" "0"
ck "get restaura byte a byte" "sha igual" \
  "$( run "$C" get --state "$CACHE" --phase extract --name boot.img --to "$T/out.img" >/dev/null
     [ "$(sha256sum "$T/out.img" | awk '{print $1}')" = "$(sha256sum "$T/src/boot.img" | awk '{print $1}')" ] && echo "sha igual" || echo diferente)" "sha igual"
ck "get de item inexistente é miss" "exit" "$(run "$C" get --state "$CACHE" --phase extract --name nao.img --to "$T/x.img")" "3"
ck "verify íntegro passa" "exit" "$(run "$C" verify --state "$CACHE")" "0"
printf 'corrompido\n' > "$CACHE/extract/boot.img"
ck "verify detecta corrupção" "exit" "$(run "$C" verify --state "$CACHE")" "3"
printf 'conteudo do boot\n' > "$CACHE/extract/boot.img"
ck "arquivo grande vira referência externa (≤0 MB)" "external" \
  "$(run "$C" put --state "$CACHE" --phase image --file "$T/src/boot.img" --max-inline-mb 0 >/dev/null
     python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(next(e["external"] for e in d["entries"] if e["phase"]=="image"))' "$CACHE/manifest.json")" "True"
ck "list --json parseável" "entradas" \
  "$("$C" list --state "$CACHE" --json | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["entries"])>=2)')" "True"

# Guard-4
cp "$T/src/boot.img" "$T/stock.img"; cp "$T/src/boot.img" "$T/backup.img"
sha256sum "$T/backup.img" > "$T/backup.img.sha256"
python3 - "$T" <<'PY'
import hashlib, json, sys, os
t=sys.argv[1]; h=hashlib.sha256(open(os.path.join(t,"stock.img"),"rb").read()).hexdigest()
json.dump({"l4_closed":True,"images":{"boot.img":{"sha256":h,"size_bytes":15}}},
          open(os.path.join(t,"rom.json"),"w"))
PY
ck "sem backup = MISSING" "exit" "$(run "$G" --boot "$T/stock.img" --backup "$T/nao.img")" "3"
printf 'outra coisa\n' > "$T/ruim.img"
ck "backup diferente = MISMATCH" "exit" "$(run "$G" --boot "$T/stock.img" --backup "$T/ruim.img")" "4"
ck "backup íntegro verifica" "exit" "$(run "$G" --boot "$T/stock.img" --backup "$T/backup.img" --sha-file "$T/backup.img.sha256" --rom-assets "$T/rom.json")" "0"
ck "hash do .sha256 divergente reprova" "exit" \
  "$( printf '%064d  backup.img\n' 0 > "$T/falso.sha256"; run "$G" --boot "$T/stock.img" --backup "$T/backup.img" --sha-file "$T/falso.sha256")" "4"
ck "JSON declara VERIFIED" "verdict" \
  "$("$G" --boot "$T/stock.img" --backup "$T/backup.img" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["verdict"])')" "VERIFIED"
echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
