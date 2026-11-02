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

# --jobs: paralelismo sem mudar o veredito (3 mutantes, 3 arquivos, todos mortos)
mkdir -p "$T/p/skills/evox-rom-ci-optimizer/references" "$T/p/skills/evox-rom-ci-optimizer/scripts" "$T/p/skills/evox-rom-ci-optimizer/tests"
: > "$T/p/skills/evox-rom-ci-optimizer/references/mutation-catalog.json"
python3 - "$T/p" <<'PY2'
import json, os, sys
w = sys.argv[1]
SK = os.path.join(w, "skills/evox-rom-ci-optimizer")
cat = {"schema": "evox-mutation-catalog/1", "mutants": []}
for i in (1, 2, 3):
    sh = os.path.join(SK, "scripts", f"logica{i}.sh")
    open(sh, "w").write('#!/usr/bin/env bash\necho "valor 7"\n')
    os.chmod(sh, 0o755)
    tst = os.path.join(SK, "tests", f"test_logica{i}.sh")
    open(tst, "w").write(f'#!/usr/bin/env bash\nbash skills/evox-rom-ci-optimizer/scripts/logica{i}.sh | grep -q "valor 7" || exit 1\n')
    os.chmod(tst, 0o755)
    cat["mutants"].append({"id": f"P{i}", "file": f"skills/evox-rom-ci-optimizer/scripts/logica{i}.sh",
                           "find": "valor 7", "replace": "valor 0", "strength": "semantic",
                           "test": f"skills/evox-rom-ci-optimizer/tests/test_logica{i}.sh",
                           "rationale": "valor tem de ser o declarado"})
json.dump(cat, open(os.path.join(SK, "references", "mutation-catalog.json"), "w"))
PY2
ck "sequencial mata os 3 (exit 0)" "exit" \
  "$(python3 "$M" --root "$T/p" --jobs 1 >/dev/null 2>&1; echo $?)" "0"
SEQ="$(python3 -c 'import json,sys;print([[r["id"],r["status"]] for r in json.load(open(sys.argv[1]))["results"]])' "$T/p/workspace/audit/mutation.json")"
ck "paralelo mata os 3 (exit 0)" "exit" \
  "$(python3 "$M" --root "$T/p" --jobs 3 >/dev/null 2>&1; echo $?)" "0"
PAR="$(python3 -c 'import json,sys;print([[r["id"],r["status"]] for r in json.load(open(sys.argv[1]))["results"]])' "$T/p/workspace/audit/mutation.json")"
ck "paralelo preserva ordem e veredito do catálogo" "igual" \
  "$([ "$SEQ" = "$PAR" ] && echo igual || echo divergente)" "igual"
ck "--jobs 0 é erro de uso (2)" "exit" \
  "$(python3 "$M" --root "$T/p" --jobs 0 >/dev/null 2>&1; echo $?)" "2"
ck "--jobs sem valor é erro de uso (2)" "exit" \
  "$(python3 "$M" --root "$T/p" --jobs >/dev/null 2>&1; echo $?)" "2"
ck "--jobs auto resolve sem quebrar (0)" "exit" \
  "$(python3 "$M" --root "$T/p" --jobs auto >/dev/null 2>&1; echo $?)" "0"

# --shard: a união dos N shards é o catálogo inteiro, sem repetir (matrix de CI)
python3 "$M" --root "$T/p" --shard 1/2 >/dev/null 2>&1
S1="$(python3 -c 'import json,sys;print(" ".join(r["id"] for r in json.load(open(sys.argv[1]))["results"]))' "$T/p/workspace/audit/mutation.json")"
python3 "$M" --root "$T/p" --shard 2/2 >/dev/null 2>&1
S2="$(python3 -c 'import json,sys;print(" ".join(r["id"] for r in json.load(open(sys.argv[1]))["results"]))' "$T/p/workspace/audit/mutation.json")"
UNIAO="$(python3 -c 'import sys;a=set(sys.argv[1].split());b=set(sys.argv[2].split());print(len(a|b), len(a&b), sorted(a|b)==["P1","P2","P3"])' "$S1" "$S2")"
ck "shards 1/2 + 2/2 = catálogo completo, sem sobreposição" "3 0 True" "$UNIAO" "3 0 True"
ck "--shard 0/2 é erro de uso (2)" "exit" \
  "$(python3 "$M" --root "$T/p" --shard 0/2 >/dev/null 2>&1; echo $?)" "2"
ck "--shard 3/2 é erro de uso (2)" "exit" \
  "$(python3 "$M" --root "$T/p" --shard 3/2 >/dev/null 2>&1; echo $?)" "2"
ck "--shard sem formato K/N é erro de uso (2)" "exit" \
  "$(python3 "$M" --root "$T/p" --shard metade >/dev/null 2>&1; echo $?)" "2"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
