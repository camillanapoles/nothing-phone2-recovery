#!/usr/bin/env bash
# Lint de travas de custo do workflow (8 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; L="$HERE/../scripts/ci_workflow_lint.py"; REF="$HERE/../references/evox-ci-validator.yml"
P=0; F=0
ok(){ printf 'PASS  %-46s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-46s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
run(){ python3 "$L" "$@" >/dev/null 2>&1; echo $?; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ck "workflow de referência passa" "exit" "$(run "$REF")" "0"
ck "sem argumento pede uso" "exit" "$(run)" "2"
ck "arquivo inexistente" "exit" "$(run "$T/nao.yml")" "2"

mut(){ cp "$REF" "$T/$1"; python3 - "$T/$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding="utf-8").read()
assert old in s, f"âncora não encontrada: {old}"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}
mut sem_cancel "cancel-in-progress: true" "cancel-in-progress: false"
ck "sem cancel-in-progress é violado" "exit" "$(run "$T/sem_cancel")" "3"
mut timeout_alto "timeout-minutes: 25" "timeout-minutes: 45"
ck "timeout > 30 min é violado" "exit" "$(run "$T/timeout_alto")" "3"
mut cache_off "uses: actions/cache@v4" "uses: actions/upload-artifact@v4"
ck "sem cache é violado" "exit" "$(run "$T/cache_off")" "3"
mut retention "retention-days: 5" "retention-days: 30"
ck "retention > 7 dias é violado" "exit" "$(run "$T/retention")" "3"
mut perms "contents: read" "contents: write-all"
ck "permissions write-all é violado" "exit" "$(run "$T/perms")" "3"
mut snapshot " -no-snapshot" ""
ck "emulador com snapshot é violado" "exit" "$(run "$T/snapshot")" "3"
mut flash "name: Stage C · artefato pré-USB" "name: Stage C · fastboot flash boot"
ck "fastboot flash no CI é violado" "exit" "$(run "$T/flash")" "3"
# token montado em runtime: o arquivo de teste não contém segredo literal
cp "$REF" "$T/segredo"
python3 - "$T/segredo" <<'PY2'
import sys
p = sys.argv[1]
tok = "gh" + "p_" + "1" * 24
s = open(p, encoding="utf-8").read().replace("permissions:", f"env_token: {tok}\npermissions:", 1)
open(p, "w", encoding="utf-8").write(s)
PY2
ck "segredo literal é violado" "exit" "$(run "$T/segredo")" "3"
ck "JSON lista as violações" "0" "$(python3 "$L" "$T/flash" --json | python3 -c 'import json,sys;d=json.load(sys.stdin)[0];print(0 if d["violations"] else 1)')" "0"
echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
