#!/usr/bin/env bash
# coverage_matrix.py — 5 casos: repo completo, lacuna, isenção declarada, JSON, help
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; C="$HERE/../scripts/coverage_matrix.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "repo tem cobertura completa" "exit" "$(python3 "$C" --root "$ROOT" >/dev/null 2>&1; echo $?)" "0"
ck "100% declarado (testado + isento)" "100.0" \
  "$(python3 "$C" --root "$ROOT" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["coverage_pct"])')" "100.0"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/skills/x/scripts" "$T/skills/x/tests" "$T/skills/evox-rom-ci-optimizer/references" "$T/tests"
printf '#!/bin/bash\ntrue\n' > "$T/skills/x/scripts/orfao.sh"; chmod +x "$T/skills/x/scripts/orfao.sh"
echo '{"exemptions":{}}' > "$T/skills/evox-rom-ci-optimizer/references/audit-exemptions.json"
ck "script sem teste = lacuna (3)" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "3"
ck "lacuna aparece no JSON" "orfao.sh" \
  "$(python3 "$C" --root "$T" --json | python3 -c 'import json,sys;print([r["script"].split("/")[-1] for r in json.load(sys.stdin)["rows"] if r["status"]=="GAP"][0])')" "orfao.sh"
printf '#!/bin/bash\nbash skills/x/scripts/orfao.sh\n' > "$T/skills/x/tests/test_orfao.sh"
ck "com teste passa a 0" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "0"
echo '{"exemptions":{"skills/x/scripts/orfao2.sh":"motivo declarado"}}' > "$T/skills/evox-rom-ci-optimizer/references/audit-exemptions.json"
printf '#!/bin/bash\ntrue\n' > "$T/skills/x/scripts/orfao2.sh"; chmod +x "$T/skills/x/scripts/orfao2.sh"
ck "isenção declarada também passa" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "0"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
