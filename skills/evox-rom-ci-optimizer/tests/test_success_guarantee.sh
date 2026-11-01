#!/usr/bin/env bash
# success_guarantee.py — "garantia prévia" só existe com prova; sem prova é exit 3. (29 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/success_guarantee.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-58s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-58s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
q(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
run(){ python3 "$S" --root "$ROOT" "$@" >/dev/null 2>&1; echo $?; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

rc=$(python3 "$S" --help >/dev/null 2>&1; echo $?); ck "--help sai 0" "exit" "$rc" "0"
rc=$(python3 "$S" >/dev/null 2>&1; echo $?); ck "sem argumentos pede uso" "exit" "$rc" "2"
rc=$(python3 "$S" --template >/dev/null 2>&1; echo $?); ck "--template sai 0" "exit" "$rc" "0"
sch=$(python3 "$S" --template | q 'd["schema"]'); ck "template tem schema" "evox-guarantee-evidence/1" "$sch" "evox-guarantee-evidence/1"

# sem evidência: nada é dado como provado além do que já está travado no repo
out=$(python3 "$S" --root "$ROOT" --json); rc=$?
ck "sem evidência = PENDENTE" "exit" "$rc" "3"
ck "veredito pendente" "GARANTIA_PENDENTE" "$(printf '%s' "$out" | q 'd["verdict"]')" "GARANTIA_PENDENTE"
ck "R1 provado pela decisão ratificada" "PROVADO" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R1")')" "PROVADO"
ck "cinco requisitos avaliados" "5" "$(printf '%s' "$out" | q 'len(d["requirements"])')" "5"
ck "R2 não pode ser provado sem medir" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R2")')" "FALTA_PROVA"
ck "R4 não pode ser provado sem varredura" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R4")')" "FALTA_PROVA"

rc=$(python3 "$S" --root "$ROOT" --evidence "$T/nao-existe.json" >/dev/null 2>&1; echo $?)
ck "evidência ausente é entrada inválida" "exit" "$rc" "4"

# evidência completa: tudo medido
cat > "$T/ok.json" <<'J'
{"schema":"evox-guarantee-evidence/1",
 "device":{"hide_verified":true,"hide_tested_apps":["br.gov.meugovbr"],"device_integrity":true,"integrity_tested_apps":["br.gov.meugovbr"]},
 "conflicts":{"scan_report":"workspace/audit/conflict_report.json","conflicts":0},
 "kernel":{"kmi":"android13-5.10","configs":{"CONFIG_SYSVIPC":"y","CONFIG_POSIX_MQUEUE":"y","CONFIG_NAMESPACES":"y","CONFIG_UTS_NS":"y","CONFIG_IPC_NS":"y","CONFIG_PID_NS":"y","CONFIG_NET_NS":"y","CONFIG_USER_NS":"y","CONFIG_CGROUPS":"y","CONFIG_CGROUP_PIDS":"y","CONFIG_CGROUP_FREEZER":"y","CONFIG_SECCOMP":"y"}},
 "droidspaces":{"installed":true,"proc_ok":true,"paths_ok":true}}
J
out=$(python3 "$S" --root "$ROOT" --evidence "$T/ok.json" --json); rc=$?
ck "com tudo medido = GARANTIA_CONFIRMADA" "exit" "$rc" "0"
ck "veredito confirmado" "GARANTIA_CONFIRMADA" "$(printf '%s' "$out" | q 'd["verdict"]')" "GARANTIA_CONFIRMADA"
ck "nenhum pendente" "0" "$(printf '%s' "$out" | q 'str(d["pending"])')" "0"

# uma prova faltando por vez derruba o veredito
python3 - "$T/ok.json" "$T/sem_hide.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["device"]["hide_verified"] = False
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/sem_hide.json" --json); rc=$?
ck "sem medir ocultação, não há garantia" "exit" "$rc" "3"
ck "R2 volta a pendente" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R2")')" "FALTA_PROVA"

python3 - "$T/ok.json" "$T/com_conflito.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["conflicts"]["conflicts"] = 3
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/com_conflito.json" --json); rc=$?
ck "conflito declarado derruba a garantia" "exit" "$rc" "3"
ck "R4 aponta conflito" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R4")')" "FALTA_PROVA"

python3 - "$T/ok.json" "$T/sem_report.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["conflicts"]["scan_report"] = ""
json.dump(d, open(sys.argv[2], "w"))
PY
rc=$(python3 "$S" --root "$ROOT" --evidence "$T/sem_report.json" >/dev/null 2>&1; echo $?)
ck "conflito zero sem relatório não é prova" "exit" "$rc" "3"

# kernel stock sem USER_NS + kernel próprio proibido = impossível sob a decisão
python3 - "$T/ok.json" "$T/sem_userns.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["kernel"]["configs"]["CONFIG_USER_NS"] = "n"
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/sem_userns.json" --json); rc=$?
ck "USER_NS ausente = IMPOSSIVEL sob a decisão" "exit" "$rc" "1"
ck "veredito impossível (não pendente)" "IMPOSSIVEL_SOB_DECISAO_A" "$(printf '%s' "$out" | q 'd["verdict"]')" "IMPOSSIVEL_SOB_DECISAO_A"
ck "R5 marcado impossível" "IMPOSSIVEL" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R5")')" "IMPOSSIVEL"

python3 - "$T/ok.json" "$T/sem_sysvipc.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["kernel"]["configs"]["CONFIG_SYSVIPC"] = "n"
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/sem_sysvipc.json" --json); rc=$?
ck "sem SYSVIPC no kernel = IMPOSSIVEL sob a decisão" "exit" "$rc" "1"

python3 - "$T/ok.json" "$T/nao_instalado.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["droidspaces"]["installed"] = False
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/nao_instalado.json" --json); rc=$?
ck "kernel ok mas sem instalação = pendente" "exit" "$rc" "3"
ck "R5 pendente, não impossível" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R5")')" "FALTA_PROVA"

# fixtures de contrato: decisão trocada e pilha incompleta
R="$T/fx/skills/evox-rom-ci-optimizer/references"; mkdir -p "$R"
for f in root-decision.json root-engines.json hiding-stack.json module-requirements.json droidspaces-requirements.json; do
  cp "$ROOT/skills/evox-rom-ci-optimizer/references/$f" "$R/"
done
python3 - "$R" <<'PY'
import json, sys
p = sys.argv[1] + "/root-decision.json"; d = json.load(open(p)); d["engine"] = "kernelsu"
json.dump(d, open(p, "w"))
PY
out=$(python3 "$S" --root "$T/fx" --json); rc=$?
ck "decisão trocada quebra R1" "exit" "$rc" "3"
ck "R1 pendente com motor diferente" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R1")')" "FALTA_PROVA"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/root-decision.json" "$R/"

python3 - "$R" <<'PY'
import json, sys
p = sys.argv[1] + "/hiding-stack.json"; d = json.load(open(p))
d["layers"] = [l for l in d["layers"] if l["id"] != "zygisk-assistant"]
json.dump(d, open(p, "w"))
PY
out=$(python3 "$S" --root "$T/fx" --json); rc=$?
ck "pilha incompleta quebra R2" "exit" "$rc" "3"
ck "R2 cita camada ausente" "sim" "$(printf '%s' "$out" | q '"zygisk-assistant" in next(r["detail"] for r in d["requirements"] if r["id"]=="R2") and "sim" or "nao"')" "sim"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
