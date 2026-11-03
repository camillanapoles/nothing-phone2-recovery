#!/usr/bin/env bash
# counts_gate.py — nenhum limite escrito à mão: se o catálogo cresce, o texto velho REPROVA.
# 12 casos: sanidade/CLI + deriva de 175→176 + número velho + lista de ids no CI.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
K="$ROOT/scripts/counts_gate.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

copiar(){   # $1 = destino
  mkdir -p "$1"
  tar -C "$ROOT" -cf - --exclude=.git --exclude=workspace --exclude=node_modules . 2>/dev/null \
    | tar -C "$1" -xf -
}

# ---------------------------------------------------------------- 0. sanidade
out="$(cd "$ROOT" && python3 "$K" --root . 2>&1)"; rc=$?
ck "repo real: números derivados conferem" "exit" "$rc" "0"
case "$out" in
  *"mutantes"*"ids até M"*) ok "imprime a verdade derivada" "yes" ;;
  *) bad "imprime a verdade derivada" "$(printf '%s' "$out" | tail -1)" ;;
esac
js="$(cd "$ROOT" && python3 "$K" --root . --json)"
case "$js" in
  *'"mutantes"'*'"ultimo_id"'*) ok "--json expõe a verdade derivada" "truth" ;;
  *) bad "--json expõe a verdade derivada" "${js:0:80}" ;;
esac
python3 "$K" --root . --bogus >/dev/null 2>&1; rc_bogus=$?
ck "flag inválida = exit 4" "exit" "$rc_bogus" "4"
mkdir -p "$T/vazio"
python3 "$K" --root "$T/vazio" >/dev/null 2>&1; rc_vazio=$?
ck "fonte ausente = exit 3 (PENDENTE)" "exit" "$rc_vazio" "3"

# ---------------------------------------------------------------- 1. catálogo cresce
# o teste que responde "e se aumentar?" — a base vem do catálogo, não do texto
CAT_REL="skills/evox-rom-ci-optimizer/references/mutation-catalog.json"
BASE="$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["mutants"]))' "$ROOT/$CAT_REL")"
NOVO=$((BASE+1))
A="$T/cresce"
copiar "$A"
# O repo real NÃO tem contagem escrita à mão (é o que o gate exige). Para provar que o gate
# detecta drift, o fixture ESCREVE uma contagem com o valor atual — e depois faz o catálogo crescer.
printf '\nmutação: %s mutantes no catálogo\n' "$BASE" >> "$A/AGENTS.md"
python3 "$K" --root "$A" >/dev/null 2>&1; rc_antes=$?
ck "texto com $BASE (valor atual) ainda passa" "exit" "$rc_antes" "0"
python3 - "$A" <<'PYCRESCE'
import json, sys
p = sys.argv[1] + "/skills/evox-rom-ci-optimizer/references/mutation-catalog.json"
d = json.load(open(p, encoding="utf-8"))
d["mutants"].append({"file": "scripts/stack_gate.py", "find": "return out",
                     "replace": "return out  # x",
                     "test": "skills/evox-rom-ci-optimizer/tests/test_stack_gate.sh",
                     "strength": "semantic", "rationale": "crescimento do catalogo"})
json.dump(d, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
PYCRESCE
n_novo="$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["mutants"]))' "$A/$CAT_REL")"
ck "catálogo do fixture cresceu ($BASE→$NOVO)" "cresceu" "$n_novo" "$NOVO"
python3 "$K" --root "$A" >/dev/null 2>&1; rc=$?
ck "$NOVO com texto dizendo $BASE REPROVA (drift detectado)" "exit" "$rc" "1"
det="$(python3 "$K" --root "$A" 2>&1 | grep -c "$BASE")"
[ "$det" -ge 1 ] && ok "o gate aponta onde o número velho está" "$det linha(s)" \
  || bad "o gate aponta onde o número velho está" "não citou $BASE"

# 1b. com o texto corrigido, o mesmo fixture passa (não é 'sempre falha')
BASE="$BASE" NOVO="$NOVO" python3 - "$A" <<'PYFIX'
import glob, os, sys
base, novo = os.environ["BASE"], os.environ["NOVO"]
alvos = (glob.glob(sys.argv[1] + "/docs/**/*.md", recursive=True)
         + glob.glob(sys.argv[1] + "/*.md")
         + glob.glob(sys.argv[1] + "/.github/workflows/*.yml"))
for f in alvos:
    s = open(f, encoding="utf-8").read()
    if base in s:
        s = s.replace(f"{base}/{base}", f"{novo}/{novo}")
        s = s.replace(f"{base} mutantes no catálogo", f"{novo} mutantes no catálogo")
        open(f, "w", encoding="utf-8").write(s)
PYFIX
python3 "$K" --root "$A" >/dev/null 2>&1; rc=$?
ck "$NOVO com texto $NOVO passa (deriva, não decoreba)" "exit" "$rc" "0"

# ---------------------------------------------------------------- 2. número velho
B="$T/velho"; copiar "$B"
# forma exclusiva do CT1 (número sozinho, sem par): se só o CT3 funcionasse, este caso passaria
printf '\n| camadas do contrato | 999 camadas | `make -s stack` |\n' >> "$B/AGENTS.md"
outb="$(python3 "$K" --root "$B" 2>&1)"; rc_b=$?
ck "999 camadas escrito à mão reprova" "exit" "$rc_b" "1"
case "$outb" in
  *"FALHA CT1_numeros_derivados"*) ok "reprova pela checagem de número colado (CT1)" "CT1" ;;
  *) bad "reprova pela checagem de número colado (CT1)" "$(printf '%s' "$outb" | tail -1 | cut -c1-60)" ;;
esac

# 2b. par N/N em célula de tabela (a forma que escapava do padrão "colado na palavra")
C2="$T/tabela"; copiar "$C2"
printf '\n| Mutações mortas por asserção | 1/1 | `make -s mutation` |\n' >> "$C2/AGENTS.md"
out2="$(python3 "$K" --root "$C2" 2>&1)"; rc2=$?
ck "par N/N em tabela com número velho reprova" "exit" "$rc2" "1"
case "$out2" in
  *"FALHA CT3_par_na_linha_da_familia"*) ok "reprova pela família certa (CT3)" "CT3" ;;
  *) bad "reprova pela família certa (CT3)" "$(printf '%s' "$out2" | tail -1 | cut -c1-60)" ;;
esac

# 2c. o mesmo par, com o valor derivado, passa (não é "sempre falha")
C3="$T/tabela-ok"; copiar "$C3"
printf '\n| Mutações mortas por asserção | %s/%s | `make -s mutation` |\n' "$BASE" "$BASE" >> "$C3/AGENTS.md"
python3 "$K" --root "$C3" >/dev/null 2>&1; rc3=$?
ck "tabela com o par derivado passa" "exit" "$rc3" "0"

# ---------------------------------------------------------------- 3. CI sem lista de ids
C="$T/ci"; copiar "$C"
printf '        run: python3 x.py --only "M01,M02,M03"\n' >> "$C/.github/workflows/proof.yml"
out="$(python3 "$K" --root "$C" 2>&1)"; rc=$?
ck "workflow com ids na mão reprova" "exit" "$rc" "1"
case "$out" in
  *"CT2_ci_sem_lista_de_ids"*) ok "reprova pela checagem certa (CT2)" "CT2" ;;
  *) bad "reprova pela checagem certa (CT2)" "$(printf '%s' "$out" | grep FALHA | head -1)" ;;
esac

# ---------------------------------------------------------------- 4. histórico é declarado
D="$T/hist"; copiar "$D"
printf '\nNúmeros de 2026-10-01: 139/139 mortos. <!-- contagens: histórico -->\n' >> "$D/AGENTS.md"
python3 "$K" --root "$D" >/dev/null 2>&1; rc_d=$?
ck "afirmação histórica marcada não reprova" "exit" "$rc_d" "0"

echo
if [ "$F" = "0" ]; then
  echo "[counts-gate] $P/$P PASS — nenhum número escrito à mão passa despercebido"
  exit 0
fi
echo "[counts-gate] $P PASS · $F FAIL"
exit 1
