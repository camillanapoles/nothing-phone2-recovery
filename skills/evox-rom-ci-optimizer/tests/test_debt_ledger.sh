#!/usr/bin/env bash
# debt_ledger.py — o ledger de débitos é derivado dos gates, não escrito à mão.
# 20 casos: estado real, derivação por gate, dívida sem passo = inconsistência, filtros e determinismo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K="$HERE/../scripts/debt_ledger.py"
ROOT="$(cd "$HERE/../../.." && pwd)"; SK="$ROOT/skills/evox-rom-ci-optimizer"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
ck(){ local esp="${4:-sim}"; if [ "$3" = "$esp" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$esp', obtido '${3:-}')"; fi; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
novo(){ local d="$1"; mkdir -p "$d/skills" "$d/docs/skills"
  cp -a "$SK" "$d/skills/evox-rom-ci-optimizer"
  cp "$ROOT/docs/skills/EXECUTION-PLAN.md" "$d/docs/skills/"
  cp "$ROOT/Makefile" "$d/Makefile"; echo "$d"; }
estado(){ python3 "$K" --root "$1" --json | j "next((x['estado'] for x in d['debts'] if x['id']=='$2'), 'ausente')"; }

# 1. estado real do workspace ---------------------------------------------------------
rc=$(python3 "$K" --root "$ROOT" >/dev/null 2>&1; echo $?)
ck "ledger real: há débito aberto (exit 3)" "exit 3" "$rc" "3"
out=$(python3 "$K" --root "$ROOT" --json)
ck "schema do ledger" "evox-debt-ledger/1" "$(printf '%s' "$out" | j 'd["schema"]')" "evox-debt-ledger/1"
ck "7 débitos declarados" "7" "$(printf '%s' "$out" | j 'len(d["debts"])')" "7"
ck "todos abertos hoje" "7" "$(printf '%s' "$out" | j 'len([x for x in d["debts"] if x["estado"]=="aberto"])')" "7"
ck "plano de fechamento completo" "0" "$(printf '%s' "$out" | j 'len(d["problems"])')" "0"
ck "todo débito sabe em que passo fecha" "sim" \
   "$(printf '%s' "$out" | j '"sim" if all(x["fecha_com"] for x in d["debts"]) else "nao"')"
ck "todo débito traz comando e critério" "sim" \
   "$(printf '%s' "$out" | j '"sim" if all(x["comando"] and x["criterio"] for x in d["debts"]) else "nao"')"
ck "P1 traz a pergunta objetiva da usuária" "sim" \
   "$(printf '%s' "$out" | j '"sim" if next(x for x in d["debts"] if x["id"]=="P1")["pergunta"] else "nao"')"
ck "--help sai 0" "exit 0" "$(python3 "$K" --help >/dev/null 2>&1; echo $?)" "0"
ck "raiz inexistente é entrada inválida" "exit 4" "$(python3 "$K" --root "$T/nao-existe" >/dev/null 2>&1; echo $?)" "4"

# 2. derivação por gate: cada débito vem do gate que o mede --------------------------
for d in B01 B03 B05 B06 C06 P1 M-ROLLOUT; do
  ck "débito $d presente no ledger" "aberto" "$(estado "$ROOT" "$d")" "aberto"
done

D=$(novo "$T/pin")
python3 - "$D/skills/evox-rom-ci-optimizer/references/kernel-build-plan.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
d["source"]["pin"] = "b" * 40
json.dump(d, open(p, "w", encoding="utf-8"))
PY
ck "pin de 40 hex fecha B01 sozinho" "fechado" "$(estado "$D" "B01")" "fechado"
ck "e não fecha B05 (evidência ausente)" "aberto" "$(estado "$D" "B05")" "aberto"

# 3. inconsistência: débito derivado sem passo no plano -----------------------------
D=$(novo "$T/sempasso")
python3 - "$D/skills/evox-rom-ci-optimizer/references/closure-plan.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
d["debts"] = [x for x in d["debts"] if x["id"] != "B06"]
json.dump(d, open(p, "w", encoding="utf-8"))
PY
ck "débito real não declarado = inconsistência (exit 1)" "exit 1" \
   "$(python3 "$K" --root "$D" >/dev/null 2>&1; echo $?)" "1"
ck "e o ledger nomeia o problema" "sim" \
   "$(python3 "$K" --root "$D" --json | j '"sim" if any("B06" in p for p in d["problems"]) else "nao"')"

D=$(novo "$T/passosemdebito")
python3 - "$D/skills/evox-rom-ci-optimizer/references/closure-plan.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
for s in d["steps"]:
    if s["id"] == "E05":
        s["resolves"] = []
json.dump(d, open(p, "w", encoding="utf-8"))
PY
ck "débito sem passo de fechamento = inconsistência" "exit 1" \
   "$(python3 "$K" --root "$D" >/dev/null 2>&1; echo $?)" "1"

# 4. fontes ausentes não viram sucesso ------------------------------------------------
D=$(novo "$T/semplano")
rm -f "$D/skills/evox-rom-ci-optimizer/references/kernel-build-plan.json"
ck "sem plano do kernel, o ledger acusa problema" "sim" \
   "$(python3 "$K" --root "$D" --json | j '"sim" if d["problems"] else "nao"')"
ck "e não sai 0" "exit 1" "$(python3 "$K" --root "$D" >/dev/null 2>&1; echo $?)" "1"

# 5. saídas alternativas --------------------------------------------------------------
ck "--open-only mantém exit 3 com débito aberto" "exit 3" \
   "$(python3 "$K" --root "$ROOT" --open-only >/dev/null 2>&1; echo $?)" "3"
ck "--open-only não lista o que está fechado" "sim" \
   "$(python3 "$K" --root "$ROOT" --open-only | grep -q FECHADO && echo nao || echo sim)" "sim"
ck "--markdown traz uma linha por débito" "7" \
   "$(python3 "$K" --root "$ROOT" --markdown | grep -c '^| `')" "7"
MD="$(python3 "$K" --root "$ROOT" --markdown || true)"
case "$MD" in
  *"| débito |"*) ok "--markdown traz cabeçalho de débito" "sim" ;;
  *) bad "--markdown traz cabeçalho de débito" "cabeçalho ausente" ;;
esac

# 6. determinismo ---------------------------------------------------------------------
python3 "$K" --root "$ROOT" --json > "$T/a.json"; python3 "$K" --root "$ROOT" --json > "$T/b.json"
cmp -s "$T/a.json" "$T/b.json" && ok "duas execuções idênticas" "sim" || bad "duas execuções idênticas" "divergiu"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
