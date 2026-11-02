#!/usr/bin/env bash
# root_pair_solver.py — o par (motor × kernel) é CONSEQUÊNCIA das 10 condições, não uma escolha
# hardcoded; cada condição é falseável; a saída é determinística. (48 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/root_pair_solver.py"
ROOT="$(cd "$HERE/../../.." && pwd)"
FIX="$HERE/fixtures/pack-complete"
REF="$ROOT/skills/evox-rom-ci-optimizer/references"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
ck(){ [ "$2" = "$3" ] && ok "$1" "$3" || bad "$1" "${3:-vazio} (esperado '$2', obtido '${3:-}')"; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }

# 1. o conjunto de condições existe, é válido e tem 10 ---------------------------------
out=$(python3 "$S" --root "$ROOT" --json); rc=$?
ck "pack atual avaliado (sem par fechado = 3)" "3" "$rc"
ck "as 10 condições estão no veredito" "10" "$(printf '%s' "$out" | j 'len(d["conditions"])')"
ck "todo par é avaliado contra as 10" "sim" \
   "$(printf '%s' "$out" | j '"sim" if all(len(p["conditions"])==10 for p in d["pairs"]) else "nao"')"
ck "todo par é motor × kernel do catálogo" "16" "$(printf '%s' "$out" | j 'len(d["pairs"])')"

# 2. nenhum motor é preferido: a lista avaliada é TODA a do catálogo --------------------
engs=$(python3 -c "import json;print(','.join(sorted(e['id'] for e in json.load(open('$REF/root-engines.json'))['engines'])))")
avaliados=$(printf '%s' "$out" | j '",".join(sorted({p["engine"] for p in d["pairs"]}))')
ck "todos os motores do catálogo entram na conta" "apatch,kernelsu,magisk,sukisu" "$engs"
ck "o solver avalia todos (nada é filtrado por nome)" "apatch,kernelsu,magisk,sukisu" "$avaliados"

# 3. o código não conhece nomes de motor/kernel ---------------------------------------
for nome in apatch kernelsu sukisu magisk kernelsu-next; do
  hits=$(grep -c -i "\"$nome\"\|'$nome'" "$S" || true)
  ck "solver sem literal de motor ($nome)" "0" "$(printf '%s' "$hits" | tr -d ' ')"
done
for nome in stock-evolutionx custom-build-pong-ksu-susfs-droidspaces np2-kernel-lineageos-v3.0.5; do
  hits=$(grep -c -- "$nome" "$S" || true)
  ck "solver sem literal de kernel (${nome:0:22})" "0" "$(printf '%s' "$hits" | tr -d ' ')"
done
grep -q "allowed\|forbidden" "$REF/root-engines.json" && \
  bad "catálogo sem lista de permitidos/proibidos" "ainda tem 'allowed'/'forbidden'" || \
  ok "catálogo sem lista de permitidos/proibidos" "0 ocorrências"

# 4. determinismo: duas execuções, bytes idênticos ------------------------------------
python3 "$S" --root "$ROOT" --json > "$T/a.json"
python3 "$S" --root "$ROOT" --json > "$T/b.json"
cmp -s "$T/a.json" "$T/b.json" && ok "duas execuções idênticas (byte a byte)" "sim" || \
  bad "duas execuções idênticas (byte a byte)" "divergiu"
# ordem das chaves do JSON não muda o resultado
mkdir -p "$T/shuf/skills/evox-rom-ci-optimizer/references"
python3 - "$REF" "$T/shuf/skills/evox-rom-ci-optimizer/references" <<'PY'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
for name in os.listdir(src):
    if not name.endswith(".json"):
        continue
    d = json.load(open(os.path.join(src, name)))
    rev = json.loads(json.dumps(d))
    if isinstance(rev, dict):
        rev = {k: rev[k] for k in reversed(list(rev))}
    json.dump(rev, open(os.path.join(dst, name), "w"), ensure_ascii=False, indent=1)
PY
python3 "$S" --root "$T/shuf" --json > "$T/c.json" 2>/dev/null
ck "ordem das chaves do JSON não altera o veredito" "sim" \
   "$(python3 -c "import json;a=json.load(open('$T/a.json'));c=json.load(open('$T/c.json'));print('sim' if [p['verdict'] for p in a['pairs']]==[p['verdict'] for p in c['pairs']] else 'nao')")"

# 5. vacuidade: conjunto vazio/ralo de condições é RECUSADO ---------------------------
for caso in vazio ralo; do
  V="$T/$caso"; mkdir -p "$V/skills/evox-rom-ci-optimizer/references"
  cp "$REF"/*.json "$V/skills/evox-rom-ci-optimizer/references/"
  python3 - "$V/skills/evox-rom-ci-optimizer/references/pack-conditions.json" "$caso" <<'PY'
import json, sys
p, caso = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["conditions"] = [] if caso == "vazio" else d["conditions"][:3]
json.dump(d, open(p, "w"))
PY
  rc=$(python3 "$S" --root "$V" >/dev/null 2>&1; echo $?)
  ck "condições $caso são recusadas (exit 4)" "4" "$rc"
  msg=$(python3 "$S" --root "$V" 2>&1 >/dev/null)
  if [ "$caso" = "vazio" ]; then
    ck "mensagem de vacuidade fala do conjunto vazio" "sim" \
       "$(case "$msg" in *VAZIO*) echo sim;; *) echo nao;; esac)"
  else
    ck "mensagem de vacuidade fala de insuficiência" "sim" \
       "$(case "$msg" in *insuficientes*) echo sim;; *) echo nao;; esac)"
  fi
done

# 6. condição sem contra-exemplo declarado é recusada (decoração) ---------------------
V="$T/sembreaker"; mkdir -p "$V/skills/evox-rom-ci-optimizer/references"
cp "$REF"/*.json "$V/skills/evox-rom-ci-optimizer/references/"
python3 - "$V/skills/evox-rom-ci-optimizer/references/pack-conditions.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["conditions"][0].pop("breaker", None)
json.dump(d, open(p, "w"))
PY
rc=$(python3 "$S" --root "$V" >/dev/null 2>&1; echo $?)
ck "condição sem breaker é recusada (não falseável)" "4" "$rc"

# 7. condição decorativa reprova o selftest ------------------------------------------
V="$T/decor"; mkdir -p "$V/skills/evox-rom-ci-optimizer/references"
cp "$FIX/skills/evox-rom-ci-optimizer/references"/*.json "$V/skills/evox-rom-ci-optimizer/references/"
python3 - "$V/skills/evox-rom-ci-optimizer/references/pack-conditions.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
# C10 passa a ser sempre verdadeira: o breaker não mexe em nada que a regra leia
d["conditions"][-1]["breaker"] = {"file": "root-engines.json",
                                  "pointer": "/engines/0/name", "action": "set", "value": "x"}
json.dump(d, open(p, "w"))
PY
rc=$(python3 "$S" --root "$V" --selftest >/dev/null 2>&1; echo $?)
ck "condição decorativa é pega pelo selftest" "1" "$rc"

# 8. selftest do pack completo: cada condição cai SÓ por ela -------------------------
out=$(python3 "$S" --root "$FIX" --selftest); rc=$?
ck "selftest do pack completo passa" "0" "$rc"
ck "10 condições falseáveis, 0 decorativas" "10 condições · 0 decorativa(s)" "$(printf '%s' "$out" | tail -1 | sed 's/^\[selftest\] //')"

# 9. breaker por linha de comando: quebra exatamente a condição pedida ----------------
for cid in C01 C02 C03 C05 C06 C07 C08 C09 C10; do
  rc=$(python3 "$S" --root "$FIX" --break "$cid" >/dev/null 2>&1; echo $?)
  ck "breaker $cid derruba o par (não-garantido)" "sim" "$([ "$rc" -ne 0 ] && echo sim || echo nao)"
done

# 10. pack completo = PAR_GARANTIDO e UM único par (single_method) -------------------
out=$(python3 "$S" --root "$FIX" --json); rc=$?
ck "pack completo é PAR_GARANTIDO (exit 0)" "0" "$rc"
ck "seleciona exatamente 1 par" "1" "$(printf '%s' "$out" | j 'len(d["selected"])')"
ck "o par é o do dado (motor fictício, não hardcoded)" "engine-x" "$(printf '%s' "$out" | j 'd["selected"][0]["engine"]')"
ck "o kernel é o do dado" "kernel-x" "$(printf '%s' "$out" | j 'd["selected"][0]["kernel"]')"

# 11. dois pares completos = AMBIGUO (não desempata por preferência) ----------------
V="$T/amb"; mkdir -p "$V/skills/evox-rom-ci-optimizer/references"
cp "$FIX/skills/evox-rom-ci-optimizer/references"/*.json "$V/skills/evox-rom-ci-optimizer/references/"
python3 - "$V/skills/evox-rom-ci-optimizer/references" <<'PY'
import json, os, sys
d = sys.argv[1]
e = json.load(open(os.path.join(d, "root-engines.json")))
clone = json.loads(json.dumps(e["engines"][0]))
clone["id"] = "engine-z"
e["engines"].append(clone)
json.dump(e, open(os.path.join(d, "root-engines.json"), "w"))
c = json.load(open(os.path.join(d, "kernel-candidates.json")))
c["candidates"][0]["kernel_supports"].append("engine-z")
json.dump(c, open(os.path.join(d, "kernel-candidates.json"), "w"))
dr = json.load(open(os.path.join(d, "droidspaces-requirements.json")))
dr["constraints"]["supported_engines"].append("engine-z")
json.dump(dr, open(os.path.join(d, "droidspaces-requirements.json"), "w"))
PY
out=$(python3 "$S" --root "$V" --json); rc=$?
ck "dois pares completos = AMBIGUO (exit 1)" "1" "$rc"
ck "veredito nomeia a ambiguidade" "AMBIGUO" "$(printf '%s' "$out" | j 'd["verdict"]')"

# 12. decisão derivada: escrita e conferência --------------------------------------
V="$T/dec"; mkdir -p "$V/skills/evox-rom-ci-optimizer/references"
cp "$FIX/skills/evox-rom-ci-optimizer/references"/*.json "$V/skills/evox-rom-ci-optimizer/references/"
rm -f "$V/skills/evox-rom-ci-optimizer/references/root-decision.json"
python3 "$S" --root "$V" --write-decision >/dev/null
python3 "$S" --root "$V" --check-decision >/dev/null 2>&1 && ok "decisão derivada confere" "sim" || \
  bad "decisão derivada confere" "divergiu"
python3 - "$V/skills/evox-rom-ci-optimizer/references/root-decision.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print("sim" if d.get("generated") is True and d.get("derived_from") else "nao")
PY
ck "decisão é marcada como gerada" "sim" \
   "$(python3 -c "import json;d=json.load(open('$V/skills/evox-rom-ci-optimizer/references/root-decision.json'));print('sim' if d.get('generated') is True and d.get('derived_from') else 'nao')")"
python3 - "$V/skills/evox-rom-ci-optimizer/references/root-decision.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["verdict"] = "IMPOSSIVEL"
json.dump(d, open(sys.argv[1], "w"))
PY
rc=$(python3 "$S" --root "$V" --check-decision >/dev/null 2>&1; echo $?)
ck "decisão editada à mão é recusada" "1" "$rc"

# 12b. ordem determinística dos pares e recusas da decisão --------------------------
ck "pares vêm ordenados por (motor, kernel)" "sim" \
   "$(python3 "$S" --root "$ROOT" --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
keys = [(p["engine"], p["kernel"]) for p in d["pairs"]]
print("sim" if keys == sorted(keys) else "nao")')"

V2="$T/dec2"; mkdir -p "$V2/skills/evox-rom-ci-optimizer/references"
cp "$FIX/skills/evox-rom-ci-optimizer/references"/*.json "$V2/skills/evox-rom-ci-optimizer/references/"
python3 - "$V2/skills/evox-rom-ci-optimizer/references/root-decision.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["generated"] = False
json.dump(d, open(sys.argv[1], "w"))
PY
ck "decisão não marcada como gerada é recusada" "1" "$(python3 "$S" --root "$V2" --check-decision >/dev/null 2>&1; echo $?)"

V3="$T/dec3"; mkdir -p "$V3/skills/evox-rom-ci-optimizer/references"
cp "$FIX/skills/evox-rom-ci-optimizer/references"/*.json "$V3/skills/evox-rom-ci-optimizer/references/"
python3 - "$V3/skills/evox-rom-ci-optimizer/references/root-decision.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["pairs"][0]["verdict"] = "FALTA_PROVA"
json.dump(d, open(sys.argv[1], "w"))
PY
ck "decisão com pares divergentes é recusada" "1" "$(python3 "$S" --root "$V3" --check-decision >/dev/null 2>&1; echo $?)"

ck "selftest sem par garantido não finge sucesso" "3" \
   "$(python3 "$S" --root "$ROOT" --selftest >/dev/null 2>&1; echo $?)"

# 13. decisão do repo é a derivada do estado atual ----------------------------------
python3 "$S" --root "$ROOT" --check-decision >/dev/null 2>&1 && ok "decisão do repo bate com o solver" "sim" || \
  bad "decisão do repo bate com o solver" "rodar make pack-write"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
