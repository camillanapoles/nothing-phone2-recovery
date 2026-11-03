#!/usr/bin/env bash
# refactor_gate.py — "refatoração completa" só é verdade se o gate REPROVAR quando um consumidor
# fica para trás. Sanidade/CLI + 14 falsificações (RC1…RC11); inclui os 2 modos de falha do RC11
# (caminho não classificado e caminho durável dentro do workspace, que é limpo a cada sessão).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
K="$ROOT/scripts/refactor_gate.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-52s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-52s %s\n' "$1" "$2"; }
ck(){ if [ "$3" = "$2" ]; then ok "$1" "$2"; else bad "$1" "esperado '$2', obtido '${3:-}'"; fi; }

# cópia do repo sem .git/workspace (o gate só lê contrato + consumidores)
copiar(){
  local dst="$1"
  mkdir -p "$dst"
  tar -C "$ROOT" -cf - --exclude=.git --exclude=workspace --exclude=node_modules . 2>/dev/null \
    | tar -C "$dst" -xf -
}

# ---------------------------------------------------------------- 0. sanidade
out="$(cd "$ROOT" && python3 "$K" --root . 2>&1)"; rc=$?
ck "repo real: gate passa 12/12" "0" "$rc"
case "$out" in
  *"12/12"*) ok "repo real imprime 12/12" "12/12" ;;
  *) bad "repo real imprime 12/12" "$(printf '%s' "$out" | tail -1)" ;;
esac

# ---------------------------------------------------------------- 1. CLI
python3 "$K" --root . --bogus >/dev/null 2>&1; ck "flag inválida = exit 4 (uso)" "4" "$?"
mkdir -p "$T/vazio"
python3 "$K" --root "$T/vazio" >/dev/null 2>&1; ck "contrato ausente = exit 3 (PENDENTE)" "3" "$?"
js="$(cd "$ROOT" && python3 "$K" --root . --json 2>/dev/null)"
case "$js" in
  *'"verdict": "OK"'*) ok "--json reporta veredito OK" "verdict:OK" ;;
  *) bad "--json reporta veredito OK" "${js:0:80}" ;;
esac
case "$js" in
  *'"checks"'*) ok "--json lista as checagens" "checks" ;;
  *) bad "--json lista as checagens" "${js:0:80}" ;;
esac

# ---------------------------------------------------------------- 2. falseabilidade
# cada caso: copia o repo, quebra UM insumo, exige exit 1 e a checagem-alvo em FALHA
SEQ=0
falsificar(){   # $1 = checagem · $2 = rótulo · resto = comandos de quebra
  local alvo="$1" rotulo="$2"; shift 2
  SEQ=$((SEQ+1))
  local d="$T/c-$alvo-$SEQ"
  copiar "$d"
  ( cd "$d" && eval "$@" ) >/dev/null 2>&1
  local o r
  o="$(cd "$d" && python3 "$K" --root . 2>&1)"; r=$?
  if [ "$r" = "0" ]; then
    bad "$rotulo" "gate passou — a checagem não é falseável"
  elif ! printf '%s' "$o" | grep -q "FALHA $alvo"; then
    bad "$rotulo" "$alvo não reprovou: $(printf '%s' "$o" | grep FALHA | head -2 | tr '\n' ' ')"
  else
    ok "$rotulo" "exit $r"
  fi
}

falsificar RC1_vetados_em_consumidores "RC1: consumidor volta a declarar vetado" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/module-requirements.json"
d=json.load(open(p,encoding="utf-8"))
for m in d["modules"]:
    if m["id"]=="M08":
        m["compliance_base"]=list(m.get("compliance_base") or [])+["tricky-store"]
json.dump(d,open(p,"w",encoding="utf-8"),indent=1,ensure_ascii=False)
PY'

falsificar RC2_integridade_provada "RC2: layer de integridade sem proof_token" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/install-stack.json"
d=json.load(open(p,encoding="utf-8"))
for l in d["layers"]:
    if l["id"]=="pifork":
        l.pop("proof_token",None)
json.dump(d,open(p,"w",encoding="utf-8"),indent=2,ensure_ascii=False)
PY'

falsificar RC2_integridade_provada "RC2: módulo perde o token de integridade" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/module-requirements.json"
d=json.load(open(p,encoding="utf-8"))
for m in d["modules"]:
    if m["id"] in ("M07","M08"):
        m["compliance_base"]=[]
json.dump(d,open(p,"w",encoding="utf-8"),indent=1,ensure_ascii=False)
PY'

falsificar RC3_sessao_igual_contrato "RC3: template de sessão inventa módulo" '
python3 - <<"PY"
p="skills/evox-rom-ci-optimizer/scripts/session_open.py"
s=open(p,encoding="utf-8").read()
s=s.replace("    return out", "    out.append({\"id\": \"M99\", \"name\": \"fantasma\"})\n    return out",1)
open(p,"w",encoding="utf-8").write(s)
PY'

falsificar RC4_ocultacao_coerente "RC4: camada de ocultação exige camada inexistente" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/hiding-stack.json"
d=json.load(open(p,encoding="utf-8"))
d["layers"].append({"id":"quebra","name":"x","requires":["kernelsu"],"needs":["root"]})
json.dump(d,open(p,"w",encoding="utf-8"),indent=1,ensure_ascii=False)
PY'

falsificar RC5_plano_cobre_contrato "RC5: plano deixa de rodar o gate do contrato" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/closure-plan.json"
d=json.load(open(p,encoding="utf-8"))
for s in d["steps"]:
    g=s.get("gate") or {}
    if "stack_gate.py" in str(g.get("cmd","")):
        g["cmd"]="make -s prove"
json.dump(d,open(p,"w",encoding="utf-8"),indent=1,ensure_ascii=False)
PY'

falsificar RC6_fila_supersedida "RC6: fila superse[d]ida volta a competir" '
sed -i "s/SUPERSEDIDO/PENDENTE/" docs/skills/APPROVED-INSTALL-SEQUENCE.md'

falsificar RC7_ci_de_prova "RC7: CI de prova desaparece" 'rm -f .github/workflows/proof.yml'

falsificar RC8_merge_com_aprovacao "RC8: regra de merge com aprovação removida" '
sed -i "/gh pr merge/d; /Merge de PR só com aprovação/d; /aprovação explícita da usuária/d" AGENTS.md
sed -i "s/aprovação explícita//g; s/aprovacao explicita//g" AGENTS.md'

falsificar RC10_mutacao_completa "RC10: script fica sem mutante (nunca é validado)" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/mutation-catalog.json"
d=json.load(open(p,encoding="utf-8"))
alvo="scripts/stack_gate.py"
d["mutants"]=[m for m in d["mutants"] if m["file"]!=alvo]
json.dump(d,open(p,"w",encoding="utf-8"),indent=1,ensure_ascii=False)
PY'

falsificar RC10_mutacao_completa "RC10: id duplicado/lacuna no catálogo" '
python3 - <<"PY"
import json
p="skills/evox-rom-ci-optimizer/references/mutation-catalog.json"
d=json.load(open(p,encoding="utf-8"))
d["mutants"][1]["id"]=d["mutants"][0]["id"]
json.dump(d,open(p,"w",encoding="utf-8"),indent=1,ensure_ascii=False)
PY'

falsificar RC9_ledger_duravel "RC9: ledger aponta decisão para arquivo não versionado" '
sed -i "s#references/decisions.json#workspace/decision.json#g" skills/evox-rom-ci-optimizer/scripts/debt_ledger.py'

falsificar RC11_nada_duravel_no_workspace "RC11: caminho do workspace não classificado" '
printf "\nCACHE_DIR=\"\${EVOX_CACHE:-./workspace/cache_novo}\"\n" >> skills/evox-rom-ci-optimizer/scripts/cache_manager.sh'

falsificar RC11_nada_duravel_no_workspace "RC11: ledger durável escondido em subpasta permitida" '
printf "\nLEDGER=\"\${LEDGER:-./workspace/audit/rollout.json}\"\n" >> skills/evox-rom-ci-optimizer/scripts/cache_manager.sh'

falsificar RC11_nada_duravel_no_workspace "RC11: decisão durável volta para o workspace" '
printf "\n> A decisão fica em \`workspace/decision.json\`.\n" >> AGENTS.md'

falsificar RC12_residuo_vetado "RC12: artefato antigo perde o carimbo e volta a mandar instalar vetado" '
python3 - <<"PY"
p="ci-build-full/build-package/modules/install-list.txt"
linhas=[l for l in open(p,encoding="utf-8").read().splitlines(True) if "HISTÓRICO" not in l and not l.startswith("# Esta lista") and not l.startswith("# A fila") and not l.startswith("# docs/skills") and not l.startswith("# ====")]
open(p,"w",encoding="utf-8").writelines(linhas)
PY'

falsificar RC12_residuo_vetado "RC12: artefato novo cita módulo vetado sem carimbo" '
printf "instalar TrickyStore v1.4.1 e Shamiko\n" > ci-build-full/build-package/modules/fila-nova.txt'

# ---------------------------------------------------------------- veredito
echo
if [ "$F" = "0" ]; then
  echo "[refactor-gate] $P/$P PASS — toda checagem é falseável"
  exit 0
fi
echo "[refactor-gate] $P PASS · $F FAIL"
exit 1
