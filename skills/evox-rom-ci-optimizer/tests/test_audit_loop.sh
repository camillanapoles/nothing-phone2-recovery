#!/usr/bin/env bash
# audit_loop.sh — 5 casos: converge, JSON, root inválido falha, skip-tests, help
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; L="$HERE/../scripts/audit_loop.sh"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "--help sai 0 e não roda nada" "exit" "$(bash "$L" --help >/dev/null 2>&1; echo $?)" "0"
ck "loop converge no repositório" "exit" "$(bash "$L" --root "$ROOT" --skip-tests >/dev/null 2>&1; echo $?)" "0"
ck "JSON registra convergência" "True" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["converged"])' "$ROOT/workspace/audit/audit-loop.json")" "True"
ck "iterações dentro do limite" "sim" \
  "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print("sim" if 1<=d["iterations"]<=d["max_iter"] else "nao")' "$ROOT/workspace/audit/audit-loop.json")" "sim"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/docs/skills" "$T/skills/evox-rom-ci-optimizer/scripts" "$T/skills/evox-rom-ci-optimizer/references"
cp "$HERE/../scripts/contradiction_scan.py" "$T/skills/evox-rom-ci-optimizer/scripts/"
echo '{"exemptions":{}}' > "$T/skills/evox-rom-ci-optimizer/references/audit-exemptions.json"
printf 'o HIL é o gate final\n' > "$T/docs/skills/ruim.md"
ck "contradição impede convergência limpa" "exit" "$(bash "$L" --root "$T" --skip-tests >/dev/null 2>&1; echo $?)" "3"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
