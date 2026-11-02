#!/usr/bin/env bash
# mutation_check.py — harness de falseabilidade: reprova vício, escopo fechado e cobertura (19 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; M="$HERE/../scripts/mutation_check.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "--help sai 0" "exit" "$(python3 "$M" --help >/dev/null 2>&1; echo $?)" "0"
ck "mutante real é morto" "exit" \
  "$(python3 "$M" --root "$ROOT" --only M01 --shard >/dev/null 2>&1; echo $?)" "0"
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


# ---- escopo fechado: rodar parte NUNCA pode parecer "tudo passou" -------------
ck "rodar 1 de N sem --shard é INCOMPLETO (exit 3)" "exit" \
  "$(python3 "$M" --root "$ROOT" --only M02 >/dev/null 2>&1; echo $?)" "3"
ck "id inexistente no catálogo reprova (exit 4)" "exit" \
  "$(python3 "$M" --root "$ROOT" --only M9999 >/dev/null 2>&1; echo $?)" "4"
ck "id inválido MISTURADO com válido reprova (não é ignorado em silêncio)" "exit" \
  "$(python3 "$M" --root "$ROOT" --only M01,M9999 >/dev/null 2>&1; echo $?)" "4"
ck "seleção vazia reprova (exit 4)" "exit" \
  "$(python3 "$M" --root "$ROOT" --only "" >/dev/null 2>&1; echo $?)" "4"
ck "id aposentado não é prova de nada (exit 4)" "exit" \
  "$(python3 "$M" --root "$ROOT" --only M104 >/dev/null 2>&1; echo $?)" "4"
ck "--range executa o intervalo pedido" "2" \
  "$(python3 "$M" --root "$ROOT" --range M01-M02 --shard --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["total"])')" "2"
ck "intervalo com --from/--to" "3" \
  "$(python3 "$M" --root "$ROOT" --from M01 --to M03 --shard --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["total"])')" "3"

# ---- ledger por M[id]: 1 feito, 0 não feito; produto fecha só com todos ------
ck "subconjunto deixa o ledger incompleto (produto 0)" "0" \
  "$(python3 "$M" --root "$ROOT" --only M01,M02 --shard >/dev/null 2>&1; python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["coverage"]["product"])' "$ROOT/workspace/audit/mutation-latest.json")" "0"
ck "ledger lista os ids que faltaram" "sim" \
  "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print("sim" if "M03" in d["coverage"]["missing"] else "nao")' "$ROOT/workspace/audit/mutation-latest.json")" "sim"
ck "entrada de id não rodado vale 0" "not_run" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["entries"]["M03"]["status"])' "$ROOT/workspace/audit/mutation-latest.json")" "not_run"
ck "cada nova execução ZERA o ledger anterior" "not_run" \
  "$(python3 "$M" --root "$ROOT" --only M02 --shard >/dev/null 2>&1; python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["entries"]["M01"]["status"])' "$ROOT/workspace/audit/mutation-latest.json")" "not_run"

# ---- catálogo: auto-incremento e numeração fechada ---------------------------
ck "catálogo real tem numeração fechada (--verify)" "exit" \
  "$(python3 "$M" --root "$ROOT" --verify >/dev/null 2>&1; echo $?)" "0"
# calculado do catálogo: o próximo id anda sozinho quando mutantes são adicionados
CAT="$ROOT/skills/evox-rom-ci-optimizer/references/mutation-catalog.json"
PROX1="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));n=max([int(m["id"][1:]) for m in d["mutants"]]+[int(i[1:]) for i in d.get("retired") or []]);print("M%02d"%(n+1))' "$CAT")"
PROX3="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));n=max([int(m["id"][1:]) for m in d["mutants"]]+[int(i[1:]) for i in d.get("retired") or []]);print(",".join("M%02d"%(n+k) for k in (1,2,3)))' "$CAT")"
ck "--next-id devolve o próximo livre" "$PROX1" \
  "$(python3 "$M" --root "$ROOT" --next-id 2>/dev/null)" "$PROX1"
ck "--next-id N devolve N ids seguidos" "$PROX3" \
  "$(python3 "$M" --root "$ROOT" --next-id 3 2>/dev/null)" "$PROX3"

# mutante SEM id recebe id automático, determinístico e gravável
cat > "$T/w/skills/evox-rom-ci-optimizer/references/mutation-catalog.json" <<'J'
{"schema":"evox-mutation-catalog/1","retired":["M02"],"mutants":[
 {"id":"M01","file":"skills/evox-rom-ci-optimizer/scripts/logica.sh",
  "find":"exit 7","replace":"exit 0","strength":"semantic",
  "test":"skills/evox-rom-ci-optimizer/tests/test_logica.sh","rationale":"a"},
 {"file":"skills/evox-rom-ci-optimizer/scripts/logica.sh",
  "find":"--ok","replace":"--nope","strength":"semantic",
  "test":"skills/evox-rom-ci-optimizer/tests/test_logica.sh","rationale":"b"}]}
J
ck "mutante sem id ganha M03 (novo, não o aposentado M02)" "M03" \
  "$(python3 "$M" --root "$T/w" --write-ids 2>/dev/null | sed 's/.*gravados: //')" "M03"
ck "--next-id depois do auto-atribuído devolve M04" "M04" \
  "$(python3 "$M" --root "$T/w" --next-id 2>/dev/null)" "M04"
ck "--write-ids grava o id atribuído" "M03" \
  "$(python3 "$M" --root "$T/w" --write-ids >/dev/null 2>&1; python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mutants"][1]["id"])' "$T/w/skills/evox-rom-ci-optimizer/references/mutation-catalog.json")" "M03"
ck "auto-id é determinístico (2 execuções, mesmo id)" "M03" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mutants"][1]["id"])' "$T/w/skills/evox-rom-ci-optimizer/references/mutation-catalog.json")" "M03"
ck "catálogo com lacuna reprova no --verify" "exit" \
  "$(python3 -c 'import json,sys;p=sys.argv[1];d=json.load(open(p));d["mutants"][1]["id"]="M09";json.dump(d,open(p,"w"),indent=1)' "$T/w/skills/evox-rom-ci-optimizer/references/mutation-catalog.json"; python3 "$M" --root "$T/w" --verify >/dev/null 2>&1; echo $?)" "1"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
