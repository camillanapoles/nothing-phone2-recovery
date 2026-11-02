#!/usr/bin/env bash
# contradiction_scan.py — 7 casos: self-test, repo limpo, mutação, negação, tabela, JSON, help
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; C="$HERE/../scripts/contradiction_scan.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "self-test detecta os 10 padrões" "exit" "$(python3 "$C" --self-test >/dev/null 2>&1; echo $?)" "0"
ck "repo sem contradições ativas" "exit" "$(python3 "$C" --root "$ROOT" >/dev/null 2>&1; echo $?)" "0"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/skills/evox-rom-ci-optimizer/scripts" "$T/docs/skills"
printf '#!/bin/bash\nmount --bind /a /b\n' > "$T/skills/evox-rom-ci-optimizer/scripts/ruim.sh"
ck "mount --bind executado = erro (3)" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "3"
ck "regra apontada é C1" "C1" \
  "$(python3 "$C" --root "$T" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["hits"][0]["rule"])')" "C1"
printf '# nunca use mount --bind; bootctl é proibido\n' > "$T/skills/evox-rom-ci-optimizer/scripts/ruim.sh"
ck "negação não vira erro" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "0"
printf '| `cp -rn` | não idempotente | use manifesto |\n' > "$T/docs/skills/tabela.md"
ck "linha de tabela com negação passa" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "0"
printf 'gate 10 é o gate final\n' > "$T/docs/skills/ruim.md"
ck "vocabulário ambíguo = erro" "exit" "$(python3 "$C" --root "$T" >/dev/null 2>&1; echo $?)" "3"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
