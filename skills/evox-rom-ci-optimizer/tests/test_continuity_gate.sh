#!/usr/bin/env bash
# continuity_gate.py — a instrução de continuidade continua servindo para continuar?
# 20 casos: documento íntegro passa; cada cláusula removida reprova; caminho/alvo/literal reprovam.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K="$HERE/../scripts/continuity_gate.py"
ROOT="$(cd "$HERE/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
ck(){ local esp="${4:-sim}"; if [ "$3" = "$esp" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$esp', obtido '${3:-}')"; fi; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
# workspace mínimo: doc + Makefile + solver + catálogo de motores
novo(){ local d="$1"; mkdir -p "$d/docs/skills" "$d/skills/evox-rom-ci-optimizer/scripts" \
  "$d/skills/evox-rom-ci-optimizer/references" "$d/references"
  cp "$ROOT/docs/skills/CONTINUITY-INSTRUCTION.md" "$d/docs/skills/"
  cp "$ROOT/skills/evox-rom-ci-optimizer/scripts/root_pair_solver.py" "$d/skills/evox-rom-ci-optimizer/scripts/"
  cp "$ROOT/skills/evox-rom-ci-optimizer/references/root-engines.json" "$d/skills/evox-rom-ci-optimizer/references/"
  cp "$ROOT/Makefile" "$d/Makefile"
  # caminhos citados no doc: criar os que o workspace mínimo não tem
  for p in $(grep -oE '(docs/skills|scripts|tests|references)/[A-Za-z0-9_./-]+\.(md|json|py|sh|yml)' \
             "$d/docs/skills/CONTINUITY-INSTRUCTION.md" | sort -u); do
    mkdir -p "$d/$(dirname "$p")"; [ -f "$d/$p" ] || : > "$d/$p"
  done
  echo "$d"; }
falhou(){ # raiz, cláusula esperada
  python3 "$K" --root "$1" --json | j "\"sim\" if any(c['check']=='$2' and c['state']!='ok' for c in d['checks']) else \"nao\""
}
quebra(){ # nome, expressão python que muta o doc, cláusula que deve cair
  local nome="$1" expr="$2" alvo="$3" d r
  d=$(novo "$T/c$((P+F+1))")
  python3 - "$d/docs/skills/CONTINUITY-INSTRUCTION.md" "$expr" <<'PY'
import re, sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
s = re.sub(expr, "", s, flags=re.I | re.S)
open(p, "w", encoding="utf-8").write(s)
PY
  ck "$nome" "sim" "$(falhou "$d" "$alvo")"
}

# 1. o documento real é íntegro ------------------------------------------------------
ck "documento real íntegro (exit 0)" "exit 0" "$(python3 "$K" --root "$ROOT" >/dev/null 2>&1; echo $?)" "0"
out=$(python3 "$K" --root "$ROOT" --json)
ck "schema do gate" "evox-continuity-gate/1" "$(printf '%s' "$out" | j 'd["schema"]')" "evox-continuity-gate/1"
ck "todas as cláusulas ok" "sim" "$(printf '%s' "$out" | j '"sim" if all(c["state"]=="ok" for c in d["checks"]) else "nao"')"
ck "21 itens avaliados" "21" "$(printf '%s' "$out" | j 'len(d["checks"])')" "21"
ck "--help sai 0" "exit 0" "$(python3 "$K" --help >/dev/null 2>&1; echo $?)" "0"
ck "raiz inexistente é entrada inválida" "exit 4" "$(python3 "$K" --root "$T/nao-existe" >/dev/null 2>&1; echo $?)" "4"
mkdir -p "$T/vazio"
ck "documento ausente reprova" "exit 1" "$(python3 "$K" --root "$T/vazio" --doc "$T/nada.md" >/dev/null 2>&1; echo $?)" "1"

# 2. cada cláusula é load-bearing ----------------------------------------------------
quebra "sem a cláusula pétrea reprova"        '## 1\. A verdade absoluta.*?(?=## 2\.)' "Q01_clausula_petrea"
quebra "sem a regra de autoridade reprova"    '## 2\. Regra de autoridade.*?(?=## 3\.)' "Q02_autoridade"
quebra "sem o método reprova"                 '## 4\. Método de ação.*?(?=## 5\.)' "Q03_metodo"
quebra "sem o mandato reprova"                '## 5\. Mandato.*?(?=## 6\.)' "Q04_mandato"
quebra "sem a regra de PENDENTE reprova"      '## 17\. Como resolver dúvida.*?(?=## 18\.)' "Q05_pendente"
quebra "sem requisitos reprova"               '## 7\. Requisitos da kernel.*?(?=## 9\.)' "Q06_requisitos"
quebra "sem critério por módulo reprova"      '## 9\. Critério de 100%.*?(?=## 10\.)' "Q07_modulos"
quebra "sem build por Actions reprova"        '## 10\. Build e deploy.*?(?=## 11\.)' "Q08_actions"
quebra "sem a decisão do box reprova"         '## 11\. Box de kernel.*?(?=## 12\.)' "Q09_box"
quebra "sem anti-padrões reprova"             '## 15\. Anti-padrões.*?(?=## 16\.)' "Q10_antipadroes"
quebra "sem o que garantir reprova"           '## 16\. O que garantir.*?(?=## 17\.)' "Q11_garantir"
quebra "sem a escala de dúvida reprova"       '## 17\. Como resolver dúvida.*?(?=## 18\.)' "Q12_duvida"
quebra "sem próximos passos/comandos reprova" '## 18\. Próximos passos.*?(?=## 20\.)' "Q13_retomada"
quebra "sem o prompt de abertura reprova"     '## 20\. Prompt de abertura.*' "Q14_prompt"

# 3. coerência com o workspace -------------------------------------------------------
D=$(novo "$T/alvo")
python3 - "$D/docs/skills/CONTINUITY-INSTRUCTION.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("make -s mutation", "make -s mutation-que-nao-existe", 1))
PY
ck "alvo make inexistente reprova" "sim" "$(falhou "$D" "Q19_alvos_existem")"

D=$(novo "$T/solver"); python3 - "$D" <<'PY'
import json, os, sys
root = sys.argv[1]
p = os.path.join(root, "skills/evox-rom-ci-optimizer/scripts/root_pair_solver.py")
ids = json.load(open(os.path.join(root, "skills/evox-rom-ci-optimizer/references/root-engines.json")))
alvo = ids["engines"][0]["id"]
s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write('MOTOR_PREFERIDO = "%s"\n' % alvo + s)
PY
ck "motor literal no solver reprova (cláusula pétrea)" "sim" "$(falhou "$D" "Q20_solver_sem_literal")"

D=$(novo "$T/caminho")
python3 - "$D/docs/skills/CONTINUITY-INSTRUCTION.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("`docs/skills/AUDIT-CONTRADICTIONS.md`",
                                               "`docs/skills/NAO-EXISTE.md`", 1))
PY
ck "caminho inexistente reprova" "sim" "$(falhou "$D" "Q18_caminhos_existem")"

D=$(novo "$T/placeholder")
python3 - "$D/docs/skills/CONTINUITY-INSTRUCTION.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("## 18. Próximos passos ordenados (retomada imediata)",
                                               "## 18. Próximos passos ordenados (TBD)", 1))
PY
ck "placeholder reprova" "sim" "$(falhou "$D" "Q17_sem_placeholder")"

D=$(novo "$T/curto")
python3 - "$D/docs/skills/CONTINUITY-INSTRUCTION.md" <<'PY'
import sys
p = sys.argv[1]
open(p, "w", encoding="utf-8").write("# instrução\n\nmuito curta\n")
PY
ck "documento curto reprova" "sim" "$(falhou "$D" "Q00_documento")"

# 4. determinismo --------------------------------------------------------------------
python3 "$K" --root "$ROOT" --json > "$T/a.json"; python3 "$K" --root "$ROOT" --json > "$T/b.json"
cmp -s "$T/a.json" "$T/b.json" && ok "duas execuções idênticas" "sim" || bad "duas execuções idênticas" "divergiu"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
