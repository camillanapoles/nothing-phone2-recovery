#!/usr/bin/env bash
# success_guarantee.py — "garantia prévia" só existe com prova; sem prova é exit 3. (32 casos)
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
ck "R1 não é provado por decreto: nenhum par fecha as 10" "FALTA_PROVA" \
   "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R1")')" "FALTA_PROVA"
ck "R1 aponta o solver como caminho" "sim" \
   "$(printf '%s' "$out" | q '"sim" if "root_pair_solver" in next(r["to_prove"] for r in d["requirements"] if r["id"]=="R1") else "nao"')" "sim"
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
ck "repo real: evidência de device não substitui o pack" "exit" "$rc" "3"
FIXP="$HERE/fixtures/pack-complete"
out=$(python3 "$S" --root "$FIXP" --evidence "$T/ok.json" --json); rc=$?
ck "pack completo + tudo medido = GARANTIA_CONFIRMADA" "exit" "$rc" "0"
ck "veredito confirmado" "GARANTIA_CONFIRMADA" "$(printf '%s' "$out" | q 'd["verdict"]')" "GARANTIA_CONFIRMADA"
ck "nenhum pendente" "0" "$(printf '%s' "$out" | q 'str(d["pending"])')" "0"
ck "R1 prova o par único do pack" "engine-x × kernel-x" \
   "$(printf '%s' "$out" | q '" × ".join([d["selected"][0]["engine"], d["selected"][0]["kernel"]])')" "engine-x × kernel-x"

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
ck "com kernel próprio permitido, USER_NS ausente é pendente" "exit" "$rc" "3"
ck "R5 pendente no build (não impossível)" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R5")')" "FALTA_PROVA"

python3 - "$T/ok.json" "$T/sem_sysvipc.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["kernel"]["configs"]["CONFIG_SYSVIPC"] = "n"
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/sem_sysvipc.json" --json); rc=$?
ck "sem SYSVIPC o build reprova (pendente)" "exit" "$rc" "3"

python3 - "$T/ok.json" "$T/nao_instalado.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["droidspaces"]["installed"] = False
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$ROOT" --evidence "$T/nao_instalado.json" --json); rc=$?
ck "kernel ok mas sem instalação = pendente" "exit" "$rc" "3"
ck "R5 pendente, não impossível" "FALTA_PROVA" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R5")')" "FALTA_PROVA"

# catálogo sem kernel que possa provar o trio de ABI → IMPOSSÍVEL (não é "pendente")
FXI="$T/fx2/skills/evox-rom-ci-optimizer/references"; mkdir -p "$FXI"
cp "$ROOT"/skills/evox-rom-ci-optimizer/references/*.json "$FXI/"
python3 - "$FXI" <<'PY'
import json, sys
p = sys.argv[1] + "/kernel-candidates.json"; d = json.load(open(p))
d["candidates"] = [c for c in d["candidates"] if c.get("origin") == "stock-rom"]
json.dump(d, open(p, "w"))
PY
out=$(python3 "$S" --root "$T/fx2" --json); rc=$?
ck "só kernel stock no catálogo = IMPOSSIVEL" "exit" "$rc" "1"
ck "veredito diz que não há par" "IMPOSSIVEL" "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R1")')" "IMPOSSIVEL"
# com evidência que mostra o trio de ABI ausente e nenhum kernel capaz → R5 é IMPOSSÍVEL
python3 - "$T/ok.json" "$T/sem_sysvipc.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["kernel"]["configs"].pop("CONFIG_SYSVIPC", None)
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$S" --root "$T/fx2" --evidence "$T/sem_sysvipc.json" --json); rc=$?
ck "kernel sem o trio e catálogo sem saída = IMPOSSIVEL" "exit" "$rc" "1"
ck "R5 diz impossível (não pendente)" "IMPOSSIVEL" \
   "$(printf '%s' "$out" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R5")')" "IMPOSSIVEL"

out2=$(python3 "$S" --root "$T/fx2" --json)
ck "sem evidência de kernel, R5 não vira 'impossível' por conta própria" "FALTA_PROVA" \
   "$(printf '%s' "$out2" | q 'next(r["state"] for r in d["requirements"] if r["id"]=="R5")')" "FALTA_PROVA"

# sem camada de ocultação declarada: R2 fica pendente (não "aprovado" por ausência)
FX="$T/fx/skills/evox-rom-ci-optimizer/references"; mkdir -p "$FX"
cp "$ROOT"/skills/evox-rom-ci-optimizer/references/*.json "$FX/"
python3 - "$FX" <<'PY'
import json, sys
p = sys.argv[1] + "/hiding-stack.json"; d = json.load(open(p))
d["layers"] = []
json.dump(d, open(p, "w"))
PY
out=$(python3 "$S" --root "$T/fx" --json); rc=$?
ck "sem camada o pack vira IMPOSSIVEL (C08) e R2 fica pendente" "exit" "$rc" "1"
ck "R2 diz que não há camada" "sim" \
   "$(printf '%s' "$out" | q '"sim" if "nenhuma camada" in next(r["detail"] for r in d["requirements"] if r["id"]=="R2") else "nao"')" "sim"

# dois pares completos = AMBÍGUO: R1 não pode ser "provado" escolhendo por gosto
FXA="$T/fx3/skills/evox-rom-ci-optimizer/references"; mkdir -p "$FXA"
cp "$FIXP/skills/evox-rom-ci-optimizer/references"/*.json "$FXA/"
python3 - "$FXA" <<'PY'
import json, os, sys
d = sys.argv[1]
e = json.load(open(os.path.join(d, "root-engines.json")))
cl = json.loads(json.dumps(e["engines"][0])); cl["id"] = "engine-z"; e["engines"].append(cl)
json.dump(e, open(os.path.join(d, "root-engines.json"), "w"))
c = json.load(open(os.path.join(d, "kernel-candidates.json")))
c["candidates"][0]["kernel_supports"].append("engine-z")
json.dump(c, open(os.path.join(d, "kernel-candidates.json"), "w"))
r = json.load(open(os.path.join(d, "droidspaces-requirements.json")))
r["constraints"]["supported_engines"].append("engine-z")
json.dump(r, open(os.path.join(d, "droidspaces-requirements.json"), "w"))
PY
out=$(python3 "$S" --root "$T/fx3" --json); rc=$?
ck "dois pares completos deixam R1 pendente (ambíguo)" "exit" "$rc" "3"
ck "R1 não escolhe por preferência" "sim" \
   "$(printf '%s' "$out" | q '"sim" if "AMBIG" in next(r["detail"].upper() for r in d["requirements"] if r["id"]=="R1") or "pares fecham" in next(r["detail"] for r in d["requirements"] if r["id"]=="R1") else "nao"')" "sim"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
