#!/usr/bin/env bash
# mutation_check.py — o harness de falseabilidade funciona E sabe reprovar (8 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; M="$HERE/../scripts/mutation_check.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "--help sai 0" "exit" "$(python3 "$M" --help >/dev/null 2>&1; echo $?)" "0"
ck "mutante real é morto" "exit" \
  "$(python3 "$M" --root "$ROOT" --only M01 >/dev/null 2>&1; echo $?)" "0"
ck "JSON registra o resultado" "killed" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["results"][0]["status"])' "$ROOT/workspace/audit/mutation.json")" "killed"

# workspace falso: teste viciado (não olha nada) + código mutável → TEM de sobreviver
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/w/skills/evox-rom-ci-optimizer/references" "$T/w/skills/evox-rom-ci-optimizer/scripts" "$T/w/skills/evox-rom-ci-optimizer/tests"
cat > "$T/w/skills/evox-rom-ci-optimizer/scripts/logica.sh" <<'S'
#!/usr/bin/env bash
if [ "$1" = "--ok" ]; then exit 0; fi
exit 7
S
chmod +x "$T/w/skills/evox-rom-ci-optimizer/scripts/logica.sh"
cat > "$T/w/skills/evox-rom-ci-optimizer/references/mutation-catalog.json" <<'J'
{"schema":"evox-mutation-catalog/1","mutants":[
 {"id":"X1","file":"skills/evox-rom-ci-optimizer/scripts/logica.sh",
  "find":"exit 7","replace":"exit 0",
  "test":"skills/evox-rom-ci-optimizer/tests/test_logica.sh","rationale":"falha tem de acontecer"}]}
J
cat > "$T/w/skills/evox-rom-ci-optimizer/tests/test_logica.sh" <<'S'
#!/usr/bin/env bash
# teste viciado: não chama o script, não pode falhar
echo "PASS  nada"
exit 0
S
chmod +x "$T/w/skills/evox-rom-ci-optimizer/tests/test_logica.sh"
ck "teste viciado faz o mutante sobreviver (exit 3)" "exit" \
  "$(python3 "$M" --root "$T/w" >/dev/null 2>&1; echo $?)" "3"
ck "sobrevivente é reportado como survived" "survived" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["results"][0]["status"])' "$T/w/workspace/audit/mutation.json")" "survived"

# harness honesto: teste que TRAVA não é cobertura semântica (timeout ≠ kill)
cat > "$T/w/skills/evox-rom-ci-optimizer/tests/test_trava.sh" <<'S'
#!/usr/bin/env bash
tail -f /dev/null   # trava de propósito (timeout do harness é o que mata)
S
cat > "$T/w/skills/evox-rom-ci-optimizer/references/mutation-catalog.json" <<'J'
{"schema":"evox-mutation-catalog/1","mutants":[
 {"id":"X9","file":"skills/evox-rom-ci-optimizer/scripts/logica.sh",
  "find":"exit 7","replace":"exit 0","strength":"semantic",
  "test":"skills/evox-rom-ci-optimizer/tests/test_trava.sh","rationale":"trava em vez de asserção"}]}
J
ck "mutante que só mata por timeout NÃO conta" "exit" \
  "$(MUTATION_TEST_TIMEOUT=1 python3 "$M" --root "$T/w" >/dev/null 2>&1; echo $?)" "3"
ck "timeout é classificado como timeout" "timeout" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["results"][0]["status"])' "$T/w/workspace/audit/mutation.json")" "timeout"
ck "--allow-timeout aceita explicitamente" "exit" \
  "$(MUTATION_TEST_TIMEOUT=1 python3 "$M" --root "$T/w" --allow-timeout >/dev/null 2>&1; echo $?)" "0"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
