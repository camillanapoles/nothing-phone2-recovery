#!/usr/bin/env bash
# root_engine_gate.py — a escolha motor × kernel × módulos é executável? (23 casos)
# O gate não opina: ele recusa (incompatível), espera (pendente) ou libera (compatível).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; G="$HERE/../scripts/root_engine_gate.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-54s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-54s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
run(){ python3 "$G" --root "$ROOT" "$@" >/dev/null 2>&1; echo $?; }

rc=$(python3 "$G" --help >/dev/null 2>&1; echo $?)
ck "--help sai 0" "exit" "$rc" "0"
rc=$(python3 "$G" >/dev/null 2>&1; echo $?)
ck "sem argumentos pede uso" "exit" "$rc" "2"
n=$(python3 "$G" --root "$ROOT" --list-engines | wc -l | tr -d ' ')
ck "lista motores" "4 motores" "$n" "4"

# 1) baseline limpa: APatch roda no kernel stock, nenhum módulo exige kernel próprio
rc=$(run --engine apatch)
ck "APatch + kernel stock = compatível hoje" "exit" "$rc" "0"
rc=$(run --engine apatch --candidate stock-evolutionx)
ck "APatch com candidato stock fica PENDENTE (falta L4)" "exit" "$rc" "3"

# 2) KernelSU sem kernel próprio não fecha
rc=$(run --engine kernelsu)
ck "KernelSU sem kernel customizado fica PENDENTE" "exit" "$rc" "3"
rc=$(run --engine kernelsu --candidate np2-kernel-lineageos-v3.0.5)
ck "KernelSU + NP² (não certificado) fica PENDENTE" "exit" "$rc" "3"
rc=$(run --engine kernelsu --candidate meteoric-v6-pong)
ck "KernelSU + Meteoric (EOL) é INCOMPATÍVEL" "exit" "$rc" "1"
found=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate meteoric-v6-pong --json |
  python3 -c 'import json,sys;print("sim" if "rejected_eol" in json.dumps(json.load(sys.stdin)) else "nao")')
ck "veredito nomeia o motivo EOL" "sim" "$found" "sim"

rc=$(run --engine nao-existe)
ck "motor desconhecido é entrada inválida" "exit" "$rc" "4"
rc=$(run --engine apatch --candidate nao-existe)
ck "candidato desconhecido é entrada inválida" "exit" "$rc" "4"

# 3) fixtures: o gate também precisa saber dizer NÃO com dados próprios
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/skills/evox-rom-ci-optimizer/references"; mkdir -p "$R"
cat > "$R/root-engines.json" <<'J'
{"schema":"evox-root-engines/1","engines":[
 {"id":"apatch","name":"APatch","mechanism":"kernel-space","requires_custom_kernel":false,"supports_susfs":false,"supports_zygisk":true,"status":"baseline_recommended"},
 {"id":"kernelsu","name":"KernelSU","mechanism":"kernel-space","requires_custom_kernel":true,"supports_susfs":true,"supports_zygisk":true,"status":"second_wave"}]}
J
cat > "$R/kernel-candidates.json" <<'J'
{"schema":"evox-kernel-candidates/1","candidates":[
 {"id":"bom","status":"certified","kernel_supports_susfs":true},
 {"id":"sem_susfs","status":"certified","kernel_supports_susfs":false},
 {"id":"eol","status":"rejected_eol","kernel_supports_susfs":true}]}
J
cat > "$R/module-requirements.json" <<'J'
{"schema":"evox-module-requirements/1","modules":[
 {"id":"M01","is_root_engine":true,"root_required":true},
 {"id":"M05","root_required":true,"mount_hide_global":true}]}
J
rc=$(python3 "$G" --root "$T" --engine apatch >/dev/null 2>&1; echo $?)
ck "fixture: APatch compatível" "exit" "$rc" "0"
cond=$(python3 "$G" --root "$T" --engine kernelsu --candidate bom --json |
  python3 -c 'import json,sys;print(next(c["verdict"] for c in json.load(sys.stdin)["checks"] if c["check"]=="r03_mount_hide"))')
ck "fixture: SUSFS + DroidSpaces exige condição R03" "condicao" "$cond" "condicao"

cat > "$R/module-requirements.json" <<'J'
{"schema":"evox-module-requirements/1","modules":[
 {"id":"MX","root_required":true,"requires_root_engine":["kernelsu"]}]}
J
rc=$(python3 "$G" --root "$T" --engine apatch >/dev/null 2>&1; echo $?)
ck "fixture: módulo exige KernelSU e motor é APatch" "exit" "$rc" "1"
first=$(python3 "$G" --root "$T" --engine apatch --json |
  python3 -c 'import json,sys;print(json.load(sys.stdin)["reasons"][0].split()[0])')
ck "fixture: motivo cita o módulo" "MX" "$first" "MX"

cat > "$R/module-requirements.json" <<'J'
{"schema":"evox-module-requirements/1","modules":[
 {"id":"MS","root_required":true,"requires_susfs":true}]}
J
rc=$(python3 "$G" --root "$T" --engine apatch >/dev/null 2>&1; echo $?)
ck "fixture: módulo exige SUSFS e motor é APatch" "exit" "$rc" "1"
rc_bom=$(python3 "$G" --root "$T" --engine kernelsu --candidate bom >/dev/null 2>&1; echo $?)
rc_medio=$(python3 "$G" --root "$T" --engine kernelsu --candidate sem_susfs >/dev/null 2>&1; echo $?)
ck "fixture: SUSFS sem patch no kernel fica PENDENTE" "exit" "$rc_medio" "3"
ck "fixture: SUSFS com KernelSU certificado libera" "exit" "$rc_bom" "0"

# 4) M05/DroidSpaces obedece a instrução do app dentro do gate
rc_magisk=$(run --engine magisk)
ck "DroidSpaces não roda sobre Magisk → INCOMPATÍVEL" "exit" "$rc_magisk" "1"
cond_m05=$(python3 "$G" --root "$ROOT" --engine apatch --json |
  python3 -c 'import json,sys;c=[x for x in json.load(sys.stdin)["checks"] if x["check"]=="m05_kernel_configs"];print(c[0]["verdict"] if c else "ausente")')
ck "configs de kernel não provadas viram CONDIÇÃO" "condicao" "$cond_m05" "condicao"
printf '{"kmi":"android13-5.10","kernel_base":"5.10","configs":{"CONFIG_SYSVIPC":"y","CONFIG_POSIX_MQUEUE":"y","CONFIG_NAMESPACES":"y","CONFIG_UTS_NS":"y","CONFIG_IPC_NS":"y","CONFIG_PID_NS":"y","CONFIG_NET_NS":"y","CONFIG_USER_NS":"y","CONFIG_CGROUPS":"y","CONFIG_CGROUP_PIDS":"y","CONFIG_CGROUP_FREEZER":"y","CONFIG_SECCOMP":"y"}}\n' > "$T/evok.json"
printf '{"kmi":"android13-5.10","kernel_base":"5.10","configs":{"CONFIG_POSIX_MQUEUE":"y"}}\n' > "$T/evno.json"
rc_evok=$(python3 "$G" --root "$ROOT" --engine apatch --kernel-evidence "$T/evok.json" >/dev/null 2>&1; echo $?)
ck "evidência completa do kernel libera o M05" "exit" "$rc_evok" "0"
rc_evno=$(python3 "$G" --root "$ROOT" --engine apatch --kernel-evidence "$T/evno.json" >/dev/null 2>&1; echo $?)
ck "evidência sem SYSVIPC deixa PENDENTE" "exit" "$rc_evno" "3"
rc_evo=$(python3 "$G" --root "$ROOT" --engine apatch --kernel-evidence "$T/nao-existe.json" >/dev/null 2>&1; echo $?)
ck "evidência apontada e ausente deixa PENDENTE" "exit" "$rc_evo" "3"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
