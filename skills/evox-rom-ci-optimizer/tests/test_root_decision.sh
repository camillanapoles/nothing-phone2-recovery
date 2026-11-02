#!/usr/bin/env bash
# "decisão" deixou de ser texto ratificado à mão: é DERIVADA das 10 condições.
# Esta suíte prova o contrato do pack: objetivo, condições falseáveis, catálogos sem
# listas de permitidos/proibidos e decisão gerada (nunca escrita por preferência). (30 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
SK="skills/evox-rom-ci-optimizer"; REF="$ROOT/$SK/references"
S="$HERE/../scripts/root_pair_solver.py"
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
ck(){ [ "$2" = "$3" ] && ok "$1" "$3" || bad "$1" "${3:-vazio} (esperado '$2', obtido '${3:-}')"; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }

# 1. objetivo do pack: todas as condições, um único método ----------------------------
obj="$REF/pack-objective.json"
ck "pack-objective.json existe" "sim" "$([ -f "$obj" ] && echo sim || echo nao)"
ck "objetivo é 'todas as condições verdadeiras'" "all_conditions_true" "$(j <"$obj" 'd["goal"]')"
ck "objetivo exige um único método" "True" "$(j <"$obj" 'str(d["single_method"])')"
ck "objetivo ratificado por quem decide" "user" "$(j <"$obj" 'd["decided_by"]')"
ck "objetivo fixa o mínimo de condições" "10" "$(j <"$obj" 'd["params"]["min_conditions"]')"

# 2. as 10 condições existem, têm id único, regra conhecida e contra-exemplo ----------
conds="$REF/pack-conditions.json"
ck "10 condições declaradas" "10" "$(j <"$conds" 'len(d["conditions"])')"
ck "ids são C01..C10" "C01,C02,C03,C04,C05,C06,C07,C08,C09,C10" \
   "$(j <"$conds" '",".join(c["id"] for c in d["conditions"])')"
ck "ids são únicos" "10" "$(j <"$conds" 'len({c["id"] for c in d["conditions"]})')"
ck "toda condição nomeia a feature que protege" "0" \
   "$(j <"$conds" 'len([c for c in d["conditions"] if not c.get("feature")])')"
ck "toda condição tem contra-exemplo (breaker)" "0" \
   "$(j <"$conds" 'len([c for c in d["conditions"] if not c.get("breaker")])')"
ck "breaker aponta arquivo do pack" "0" \
   "$(python3 - "$conds" "$REF" <<'PY'
import json, os, sys
conds = json.load(open(sys.argv[1])); ref = sys.argv[2]
print(len([c for c in conds["conditions"] if not os.path.exists(os.path.join(ref, c["breaker"]["file"]))]))
PY
)"
ck "nenhuma condição nomeia motor ou kernel" "0" \
   "$(python3 - "$conds" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
alvo = re.compile(r"apatch|kernelsu|sukisu|magisk|meteoric|np2|stock-evolutionx|custom-build-pong", re.I)
texto = json.dumps({"n": [c["name"] for c in d["conditions"]],
                    "r": [c["rule"] for c in d["conditions"]]})
print(len(alvo.findall(texto)))
PY
)"

# 3. catálogos não têm lista de permitidos/proibidos ---------------------------------
for f in root-engines.json root-decision.json; do
  n=$(grep -c -E '"(allowed|forbidden_engines|forbidden_capabilities|blocked_by|third_party_kernel_allowed|custom_kernel_allowed|susfs_allowed)"' "$REF/$f" || true)
  ck "$f sem lista de proibidos/permitidos" "0" "$(printf '%s' "$n" | tr -d ' ')"
done

# 4. motores: todo motor declara o que o pack precisa medir --------------------------
ck "todo motor tem artefato versionado" "0" \
   "$(j <"$REF/root-engines.json" 'len([e for e in d["engines"] if not (e.get("artifact") or {}).get("version")])')"
ck "todo motor declara capacidades" "0" \
   "$(j <"$REF/root-engines.json" 'len([e for e in d["engines"] if not e.get("capabilities")])')"
ck "todo motor declara rollback e plano de OTA" "0" \
   "$(j <"$REF/root-engines.json" 'len([e for e in d["engines"] if not e.get("rollback") or not e.get("ota_plan")])')"

# 5. kernels: todo candidato declara o que o pack mede -------------------------------
ck "todo candidato declara os motores que embute" "0" \
   "$(j <"$REF/kernel-candidates.json" 'len([c for c in d["candidates"] if "kernel_supports" not in c])')"
ck "todo candidato separa prova de intenção (configs_proven)" "0" \
   "$(j <"$REF/kernel-candidates.json" 'len([c for c in d["candidates"] if "configs_proven" not in c])')"
ck "configs_proven só aceita CONFIG_*" "0" \
   "$(j <"$REF/kernel-candidates.json" 'len([x for c in d["candidates"] for x in c["configs_proven"] if not x.startswith("CONFIG_")])')"

# 6. contrato do DroidSpaces é dado, não decisão ------------------------------------
ck "lista de motores aceitos vem do contrato do app" "sim" \
   "$(j <"$REF/droidspaces-requirements.json" '"sim" if d["constraints"]["supported_engines"] else "nao"')"
ck "trio de ABI declarado" "3" "$(j <"$REF/droidspaces-requirements.json" 'len(d["kernel"]["abi_trio_not_in_stock_gki"])')"
ck "patches de kABI declarados" "2" "$(j <"$REF/droidspaces-requirements.json" 'len(d["kernel"]["patches_required"])')"

# 7. camadas de ocultação são por capacidade ---------------------------------------
ck "toda camada declara as capacidades que exige" "0" \
   "$(j <"$REF/hiding-stack.json" 'len([l for l in d["layers"] if not l.get("needs")])')"
ck "pilha não fixa 'required_layers'" "0" "$(j <"$REF/hiding-stack.json" '1 if "required_layers" in d else 0')"

# 8. decisão no repo é derivada e confere com o solver ------------------------------
dec="$REF/root-decision.json"
ck "decisão é marcada como gerada" "True" "$(j <"$dec" 'str(d.get("generated") is True)')"
ck "decisão aponta de onde deriva" "sim" "$(j <"$dec" '"sim" if d.get("derived_from") else "nao"')"
ck "decisão lista as 10 condições" "10" "$(j <"$dec" 'len(d["conditions"])')"
python3 "$S" --root "$ROOT" --check-decision >/dev/null 2>&1 && \
  ok "decisão confere com o solver (não pode mentir)" "sim" || \
  bad "decisão confere com o solver (não pode mentir)" "rodar make pack-write"

# 9. o modelo está escrito onde vale ------------------------------------------------
grep -qi "condição, não preferência\|condicao, nao preferencia" "$ROOT/AGENTS.md" && \
  ok "invariante escrito em AGENTS.md" "sim" || bad "invariante escrito em AGENTS.md" "não encontrado"
grep -qi "10 condições" "$ROOT/docs/skills/PACK-DETERMINISM.md" 2>/dev/null && \
  ok "doc do pack determinístico presente" "sim" || bad "doc do pack determinístico presente" "ausente"
grep -q "^pack:" "$ROOT/Makefile" && ok "make pack existe" "sim" || bad "make pack existe" "ausente"
grep -q "root_pair_solver.py" "$ROOT/$SK/SKILL.md" && ok "solver citado no SKILL.md" "sim" || \
  bad "solver citado no SKILL.md" "ausente"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
