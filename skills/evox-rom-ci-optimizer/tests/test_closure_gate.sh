#!/usr/bin/env bash
# closure_gate.py — o plano de fechamento é executável, ordenado e cobre os débitos reais?
# 26 casos: plano real passa; cada regra K tem um contra-exemplo; entrada inválida e determinismo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K="$HERE/../scripts/closure_gate.py"
ROOT="$(cd "$HERE/../../.." && pwd)"; SK="$ROOT/skills/evox-rom-ci-optimizer"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
ck(){ local esp="${4:-sim}"; if [ "$3" = "$esp" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$esp', obtido '${3:-}')"; fi; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
# raiz de fixture: skill inteira (os gates chamados pelo plano precisam existir)
novo(){ local d="$1"; mkdir -p "$d/skills" "$d/docs/skills"
  cp -a "$SK" "$d/skills/evox-rom-ci-optimizer"
  cp "$ROOT/docs/skills/EXECUTION-PLAN.md" "$d/docs/skills/"
  cp "$ROOT/Makefile" "$d/Makefile"
  echo "$d"; }
falhou(){ python3 "$K" --root "$1" --json | j "\"sim\" if any(c['check']=='$2' and c['state']!='ok' for c in d['checks']) else \"nao\""; }
quebra(){ # nome, expressão python sobre o plano, regra esperada
  local nome="$1" expr="$2" alvo="$3" d
  d=$(novo "$T/q$((P+F+1))")
  python3 - "$d/skills/evox-rom-ci-optimizer/references/closure-plan.json" "$expr" <<'PY'
import json, sys
p, expr = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding="utf-8"))
exec(expr)
json.dump(d, open(p, "w", encoding="utf-8"))
PY
  ck "$nome" "sim" "$(falhou "$d" "$alvo")"
}

# 1. o plano real é executável --------------------------------------------------------
ck "plano real executável (exit 0)" "exit 0" "$(python3 "$K" --root "$ROOT" >/dev/null 2>&1; echo $?)" "0"
out=$(python3 "$K" --root "$ROOT" --json)
ck "schema do gate" "evox-closure-gate/1" "$(printf '%s' "$out" | j 'd["schema"]')" "evox-closure-gate/1"
ck "16 itens avaliados" "16" "$(printf '%s' "$out" | j 'len(d["checks"])')" "16"
ck "todos ok" "sim" "$(printf '%s' "$out" | j '"sim" if all(c["state"]=="ok" for c in d["checks"]) else "nao"')"
ck "--help sai 0" "exit 0" "$(python3 "$K" --help >/dev/null 2>&1; echo $?)" "0"
ck "raiz inexistente é entrada inválida" "exit 4" "$(python3 "$K" --root "$T/nao-existe" >/dev/null 2>&1; echo $?)" "4"
mkdir -p "$T/semplano"
ck "plano ausente reprova" "exit 1" "$(python3 "$K" --root "$T/semplano" >/dev/null 2>&1; echo $?)" "1"

# 2. cada regra é load-bearing --------------------------------------------------------
quebra "K01: plano sem passos reprova"            'd["steps"]=[]' "K01_estrutura"
quebra "K02: passo duplicado reprova"             'd["steps"][1]["id"]=d["steps"][0]["id"]' "K02_passos_unicos"
quebra "K03: débito duplicado reprova"            'd["debts"][1]["id"]=d["debts"][0]["id"]' "K03_debitos_unicos"
quebra "K04: passo sem rollback reprova"          'd["steps"][0].pop("rollback")' "K04_passos_completos"
quebra "K05: tipo inválido reprova"               'd["steps"][0]["kind"]="talvez"' "K05_tipos"
quebra "K06: dependência órfã reprova"            'd["steps"][1]["needs"]=["E99"]' "K06_dependencias_existem"
quebra "K07: ciclo reprova"                        'd["steps"][0]["needs"]=["E12"]' "K07_sem_ciclo"
quebra "K08: depender do futuro reprova"           'd["steps"][0]["needs"]=["E05"]' "K08_ordem_topologica"
quebra "K09: exit esperado inválido reprova"       'd["steps"][0]["gate"]["expect_exit"]=7' "K09_gate_assertivo"
quebra "K10: débito sem passo reprova"             'd["steps"][4]["resolves"]=[]' "K10_debito_tem_passo"
quebra "K10: passo resolve débito inexistente"     'd["steps"][0]["resolves"].append("Z99")' "K10_debito_tem_passo"
quebra "K11: débito real não previsto reprova"     'd["debts"]=[x for x in d["debts"] if x["id"]!="B06"]' "K11_debitos_reais_cobertos"
quebra "K12: decisão sem pergunta reprova"         'next(x for x in d["debts"] if x["kind"]=="decision").pop("question")' "K12_decisao_da_usuario"
quebra "K13: flag inexistente reprova"             'd["steps"][0]["gate"]["cmd"]+=" --flag-que-nao-existe"' "K13_comandos_existem"
quebra "K14: físico sem staging reprova"           'next(x for x in d["steps"] if x["id"]=="E10")["needs"]=[]' "K14_staging_antes_do_fisico"
quebra "K15: placeholder reprova"                  'd["steps"][0]["title"]="TBD"' "K15_sem_placeholder"

D=$(novo "$T/doc")
python3 - "$D/docs/skills/EXECUTION-PLAN.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("E09", "E09x"))
PY
ck "K16: passo fora do documento reprova" "sim" "$(falhou "$D" "K16_documentado")"

# 3. determinismo --------------------------------------------------------------------
python3 "$K" --root "$ROOT" --json > "$T/a.json"; python3 "$K" --root "$ROOT" --json > "$T/b.json"
cmp -s "$T/a.json" "$T/b.json" && ok "duas execuções idênticas" "sim" || bad "duas execuções idênticas" "divergiu"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
