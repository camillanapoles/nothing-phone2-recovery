#!/usr/bin/env bash
# test_vacuity_scan.py — análise estática de testes viciados (7 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; V="$HERE/../scripts/test_vacuity_scan.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "--help sai 0" "exit" "$(python3 "$V" --help >/dev/null 2>&1; echo $?)" "0"
ck "repositório sem vício estrutural" "exit" "$(python3 "$V" --root "$ROOT" >/dev/null 2>&1; echo $?)" "0"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/skills/evox-rom-ci-optimizer/tests"
printf '#!/usr/bin/env bash\nck "x" "a" "a"\n' > "$T/skills/evox-rom-ci-optimizer/tests/test_ruim.sh"
ck "comparação com literal idêntico = erro" "exit" "$(python3 "$V" --root "$T" >/dev/null 2>&1; echo $?)" "3"
printf '#!/usr/bin/env bash\nck "x" "1" "0"\n' > "$T/skills/evox-rom-ci-optimizer/tests/test_ruim.sh"
ck "suíte sem caso negativo = aviso (não erro)" "exit" "$(python3 "$V" --root "$T" >/dev/null 2>&1; echo $?)" "0"
# V5: grep -q "" casa tudo e finge verificação
VAZIO=""
printf '#!/usr/bin/env bash\nif grep -q "%s" arquivo; then exit 0; fi\nexit 3\n' "$VAZIO" > "$T/skills/evox-rom-ci-optimizer/tests/test_ruim.sh"
rc5=$(python3 "$V" --root "$T" >/dev/null 2>&1; echo $?)
ck "grep -q vazio é erro V5" "exit" "$rc5" "3"
ck "V5 aparece no JSON" "sim" \
  "$(python3 -c 'import json,sys;print("sim" if "V5" in [h["rule"] for h in json.load(open(sys.argv[1]))["hits"]] else "nao")' "$T/workspace/audit/vacuity.json")" "sim"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
