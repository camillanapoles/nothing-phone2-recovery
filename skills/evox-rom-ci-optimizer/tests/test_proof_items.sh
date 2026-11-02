#!/usr/bin/env bash
# proof_items.py — retorno item a item: coleta, paridade, digest e reprovação (14 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; PR="$HERE/../scripts/proof_items.py"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
jq_get(){ python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2],{"d":d,"len":len,"sum":sum,"any":any}))' "$1" "$2"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

ck "--help sai 0" "exit" "$(python3 "$PR" --help >/dev/null 2>&1; echo $?)" "0"

# ── 1. log de suíte de casos: PASS/FAIL + TOTAL
cat > "$T/bom.log" <<'L'
PASS  R1 nao escolhe por preferencia                            sim
PASS  R2 kernel por dado                                        sim
FAIL  R3 modulo ausente reprova                                 exit 3
TOTAL: 2 PASS / 1 FAIL
L
python3 "$PR" --log "$T/bom.log" --suite unit > "$T/bom.json" 2>/dev/null
ck "3 itens coletados do log" "itens" "$(jq_get "$T/bom.json" 'len(d["items"])')" "3"
ck "FAIL no log reprova o bundle (3)" "exit" \
  "$(python3 "$PR" --log "$T/bom.log" --suite unit >/dev/null 2>&1; echo $?)" "3"
ck "FAIL capturado como item FAIL" "1" "$(jq_get "$T/bom.json" 'sum(1 for i in d["items"] if i["status"]=="FAIL")')" "1"

# ── 2. paridade: TOTAL diz 3 PASS, log só mostra 2 (item sumiu)
cat > "$T/truncado.log" <<'L'
PASS  so dois itens aparecem                                    sim
PASS  o terceiro foi apagado do log                             sim
TOTAL: 3 PASS / 0 FAIL
L
ck "log truncado reprova por paridade (3)" "exit" \
  "$(python3 "$PR" --log "$T/truncado.log" --suite truncada >/dev/null 2>&1; echo $?)" "3"

# ── 3. bundle íntegro passa na validação
cat > "$T/ok.log" <<'L'
PASS  caso verde um                                             sim
PASS  caso verde dois                                           sim
TOTAL: 2 PASS / 0 FAIL
L
python3 "$PR" --log "$T/ok.log" --suite s1 --out "$T/s1.json" >/dev/null 2>&1
ck "bundle íntegro valida (0)" "exit" \
  "$(python3 "$PR" --validate "$T/s1.json" >/dev/null 2>&1; echo $?)" "0"

# ── 4. ids deslocados, paridade intacta e digest recalculado: só a contiguidade pode pegar
python3 - "$T/s1.json" "$T/buraco.json" "$HERE/../scripts" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[3])
import proof_items as pi
b = json.load(open(sys.argv[1]))
b["items"] = [dict(b["items"][0], id="s1#002"), dict(b["items"][1], id="s1#003")]
b["declared"] = {"pass": 2, "fail": 0}
b["digest"] = pi.digest_of(b)          # digest recalculado: não é ele que denuncia
json.dump(b, open(sys.argv[2], "w"))
PY
ck "id fora de sequência reprova (3)" "exit" \
  "$(python3 "$PR" --validate "$T/buraco.json" >/dev/null 2>&1; echo $?)" "3"
ck "só a regra de contiguidade acusa (2 de 2)" "2" \
  "$(python3 "$PR" --validate "$T/buraco.json" --json 2>/dev/null | python3 -c 'import json,sys;p=json.load(sys.stdin)["problems"];print(len(p) if all("esperado" in x for x in p) else 0)')" "2"

# ── 5. digest adulterado (PASS reescrito para FAIL, sem recontar)
python3 - "$T/ok.log" "$T/adulterado.json" <<'PY'
import json, sys
b = json.load(open(sys.argv[1].replace("ok.log", "s1.json")))
b["items"][0]["name"] = "nome trocado no transporte"
json.dump(b, open(sys.argv[2], "w"))
PY
ck "digest detecta payload editado (3)" "exit" \
  "$(python3 "$PR" --validate "$T/adulterado.json" >/dev/null 2>&1; echo $?)" "3"

# ── 6. status inválido
python3 - "$T/s1.json" "$T/status.json" <<'PY'
import json, sys
b = json.load(open(sys.argv[1]))
b["items"][1]["status"] = "SKIP"
json.dump(b, open(sys.argv[2], "w"))
PY
ck "status fora de PASS/FAIL reprova (3)" "exit" \
  "$(python3 "$PR" --validate "$T/status.json" >/dev/null 2>&1; echo $?)" "3"

# ── 7. suíte vazia não é prova
printf 'nada aqui\n' > "$T/vazio.log"
ck "log vazio reprova (3)" "exit" \
  "$(python3 "$PR" --log "$T/vazio.log" --suite vazia >/dev/null 2>&1; echo $?)" "3"

# ── 8. gates: exit code manda; exit 0 com REPROVADO é contradição
printf '[eval] REPROVADO (2 abaixo do limite)\n' > "$T/gate.log"
ck "gate com exit 7 reprova (3)" "exit" \
  "$(python3 "$PR" --log "$T/gate.log" --suite eval --mode gate --exit-code 7 >/dev/null 2>&1; echo $?)" "3"
ck "exit 0 com saida REPROVADO reprova (3)" "exit" \
  "$(python3 "$PR" --log "$T/gate.log" --suite eval --mode gate --exit-code 0 >/dev/null 2>&1; echo $?)" "3"
printf '[harness] OK (0 falhas)\n' > "$T/gate-ok.log"
ck "gate verde passa (0)" "exit" \
  "$(python3 "$PR" --log "$T/gate-ok.log" --suite validate --mode gate --exit-code 0 >/dev/null 2>&1; echo $?)" "0"

# ── 9. relatório de mutação → 1 item por mutante
cat > "$T/mut.json" <<'J'
{"results":[
 {"id":"M01","status":"killed","file":"skills/x/scripts/a.sh","test_exit":1,"rationale":"ok"},
 {"id":"M02","status":"survived","file":"skills/x/scripts/a.sh","test_exit":0,"rationale":"viciado"}]}
J
python3 "$PR" --mutation "$T/mut.json" --suite mutation > "$T/mut-out.json" 2>/dev/null
ck "mutantes viram 2 itens" "itens" "$(jq_get "$T/mut-out.json" 'len(d["items"])')" "2"
ck "mutante vivo reprova (3)" "exit" \
  "$(python3 "$PR" --mutation "$T/mut.json" --suite mutation >/dev/null 2>&1; echo $?)" "3"

# ── 10. dois bundles bons + resumo markdown
python3 "$PR" --log "$T/ok.log" --suite s2 --out "$T/s2.json" >/dev/null 2>&1
ck "validar dois bundles bons (0)" "exit" \
  "$(python3 "$PR" --validate "$T/s1.json" "$T/s2.json" --summary-md "$T/resumo.md" >/dev/null 2>&1; echo $?)" "0"
ck "resumo tem uma linha por suíte" "linhas" "$(grep -c '^| `s' "$T/resumo.md")" "2"

# ── 11. modo inválido é erro de uso
ck "modo inválido sai 2" "exit" \
  "$(python3 "$PR" --log "$T/ok.log" --suite x --mode torpedo >/dev/null 2>&1; echo $?)" "2"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
