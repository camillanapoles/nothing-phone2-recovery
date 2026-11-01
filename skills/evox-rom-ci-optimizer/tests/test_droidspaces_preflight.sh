#!/usr/bin/env bash
# droidspaces_preflight.py — M05 só entra com contrato completo e requisitos provados (20 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; D="$HERE/../scripts/droidspaces_preflight.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-56s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-56s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
run(){ python3 "$D" --root "$ROOT" "$@" >/dev/null 2>&1; echo $?; }

rc=$(python3 "$D" --help >/dev/null 2>&1; echo $?); ck "--help sai 0" "exit" "$rc" "0"
rc=$(python3 "$D" >/dev/null 2>&1; echo $?); ck "sem modo pede uso" "exit" "$rc" "2"

# ---------------- contrato estático (repo real) -------------------------------
rc=$(run --static); ck "contrato do M05 está completo" "exit" "$rc" "0"
verdict=$(python3 "$D" --root "$ROOT" --static --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["verdict"])')
ck "veredito é PRONTO" "PRONTO" "$verdict" "PRONTO"
rc=$(run --static --engine magisk); ck "motor não suportado (magisk) reprova" "exit" "$rc" "3"

# ---------------- fixtures: o preflight sabe reprovar -------------------------
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/skills/evox-rom-ci-optimizer/references"; mkdir -p "$R"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json" "$R/"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/module-requirements.json" "$R/"

fixture(){ python3 - "$R/droidspaces-requirements.json" "$1" "$2" <<'PY'
import json, sys
p, path, value = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
d = json.load(open(p))
node = d
keys = path.split(".")
for k in keys[:-1]:
    node = node[k]
node[keys[-1]] = value
json.dump(d, open(p, "w"))
PY
}
restore(){ cp "$ROOT/skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json" "$R/"; }

fixture "app.apk.sha256" '"curto"'
rc=$(python3 "$D" --root "$T" --static >/dev/null 2>&1; echo $?)
ck "fixture: sha256 inválido reprova" "exit" "$rc" "3"; restore

fixture "install.after" '[]'
rc=$(python3 "$D" --root "$T" --static >/dev/null 2>&1; echo $?)
ck "fixture: instalar sem M01 reprova" "exit" "$rc" "3"; restore

fixture "constraints.mount_hide_global" 'true'
rc=$(python3 "$D" --root "$T" --static >/dev/null 2>&1; echo $?)
ck "fixture: mount-hide global reprova (R03)" "exit" "$rc" "3"; restore

fixture "kernel.configs_required" '["CONFIG_SYSVIPC"]'
rc=$(python3 "$D" --root "$T" --static >/dev/null 2>&1; echo $?)
ck "fixture: menos de 8 configs reprova" "exit" "$rc" "3"; restore

fixture "install.method" '"TODO definir"'
out=$(python3 "$D" --root "$T" --static --json)
rc=$?
has=$(printf '%s' "$out" | python3 -c 'import json,sys;print("sim" if any("sem_placeholder" in r for r in json.load(sys.stdin)["reasons"]) else "nao")')
ck "fixture: placeholder reprova" "exit" "$rc" "3"
ck "fixture: motivo aponta placeholder" "sim" "$has" "sim"; restore

python3 - "$R/module-requirements.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["modules"] = [m for m in d["modules"] if m["id"] != "M05"]
json.dump(d, open(p, "w"))
PY
rc=$(python3 "$D" --root "$T" --static >/dev/null 2>&1; echo $?)
ck "fixture: M05 fora do contrato de módulos reprova" "exit" "$rc" "3"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/module-requirements.json" "$R/"

python3 - "$R/module-requirements.json" <<'FIX'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for m in d["modules"]:
    if m["id"] == "M05":
        m["app"]["version"] = "v7.0.0"
json.dump(d, open(p, "w"))
FIX
rc=$(python3 "$D" --root "$T" --static >/dev/null 2>&1; echo $?)
ck "fixture: versão do M05 divergente do app reprova" "exit" "$rc" "3"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/module-requirements.json" "$R/"

# ---------------- evidência de kernel (L4) -----------------------------------
K="$T/kernel.json"
printf '{"kmi":"android13-5.10","kernel_base":"5.10","configs":{"CONFIG_SYSVIPC":"y","CONFIG_POSIX_MQUEUE":"y","CONFIG_NAMESPACES":"y","CONFIG_UTS_NS":"y","CONFIG_IPC_NS":"y","CONFIG_PID_NS":"y","CONFIG_NET_NS":"y","CONFIG_USER_NS":"y","CONFIG_CGROUPS":"y","CONFIG_CGROUP_PIDS":"y","CONFIG_CGROUP_FREEZER":"y","CONFIG_SECCOMP":"y"}}\n' > "$K"
rc=$(python3 "$D" --root "$ROOT" --kernel-evidence "$K" >/dev/null 2>&1; echo $?)
ck "kernel com todas as configs = pronto" "exit" "$rc" "0"

rc=$(python3 "$D" --root "$ROOT" --kernel-evidence "$T/nao-existe.json" >/dev/null 2>&1; echo $?)
ck "sem evidência de kernel fica PENDENTE" "exit" "$rc" "3"

printf '{"kmi":"android13-5.10","kernel_base":"5.10","configs":{"CONFIG_POSIX_MQUEUE":"y"}}\n' > "$T/k2.json"
out=$(python3 "$D" --root "$ROOT" --kernel-evidence "$T/k2.json" --json)
rc=$?
ck "config faltando reprova" "exit" "$rc" "3"
has=$(printf '%s' "$out" | python3 -c 'import json,sys;print("sim" if "CONFIG_SYSVIPC" in json.dumps(json.load(sys.stdin)) else "nao")')
ck "motivo nomeia o CONFIG ausente" "sim" "$has" "sim"

printf '{"kmi":"android13-6.1","kernel_base":"6.1","configs":{"CONFIG_SYSVIPC":"y","CONFIG_POSIX_MQUEUE":"y","CONFIG_NAMESPACES":"y","CONFIG_UTS_NS":"y","CONFIG_IPC_NS":"y","CONFIG_PID_NS":"y","CONFIG_NET_NS":"y","CONFIG_USER_NS":"y","CONFIG_CGROUPS":"y","CONFIG_CGROUP_PIDS":"y","CONFIG_CGROUP_FREEZER":"y","CONFIG_SECCOMP":"y"}}\n' > "$T/k3.json"
rc=$(python3 "$D" --root "$ROOT" --kernel-evidence "$T/k3.json" >/dev/null 2>&1; echo $?)
ck "base de kernel diferente reprova" "exit" "$rc" "3"

# ---------------- device (adb stubado) ---------------------------------------
S="$T/stub"; mkdir -p "$S"
cat > "$S/adb" <<'EOF'
#!/usr/bin/env bash
set -u
[ "${1:-}" = "shell" ] || exit 0
case "${2:-}" in
  "getprop ro.product.device") echo "${FAKE_DEVICE:-pong}" ;;
  "uname -r") echo "${FAKE_KERNEL:-5.10.246-gki-g4ec5491f6b5f}" ;;
  "id -u") echo "${FAKE_UID:-0}" ;;
  "getenforce") echo "${FAKE_SELINUX:-Enforcing}" ;;
  "ls /proc/self/ns") echo "${FAKE_NS:-pid net uts ipc user mnt}" ;;
  "cat /proc/sysvipc/shm"|"cat /proc/sysvipc/sem"|"cat /proc/sysvipc/msg"|"cat /proc/sys/kernel/posix-mqueue/qsize")
    case "${2:-}" in *"${FAKE_MISSING_PROC:-vazio}"*) : ;; *) echo "0 0 0" ;; esac ;;
  "ls -d /data/local/Droidspaces/bin"|"ls -d /data/adb/modules/droidspaces_kernel"|"ls -d /data/adb/service.d")
    case "${FAKE_PATH_PRESENT:-0}" in 1) echo "${2#ls -d }" ;; esac ;;
  "ls /data/adb/service.d") echo "${FAKE_SERVICE:-droidspaces.sh}" ;;
esac
exit 0
EOF
chmod +x "$S/adb"
dev(){ PATH="$S:/usr/bin:/bin" "$@" ; }
rc=$(PATH="$S:/usr/bin:/bin" python3 "$D" --root "$ROOT" --device --adb "$S/adb" >/dev/null 2>&1; echo $?)
ck "device pronto (pong, root, enforcing, ns, procfs)" "exit" "$rc" "0"
rc=$(PATH="$S:/usr/bin:/bin" FAKE_DEVICE=marble python3 "$D" --root "$ROOT" --device --adb "$S/adb" >/dev/null 2>&1; echo $?)
ck "device errado reprova" "exit" "$rc" "3"
rc=$(PATH="$S:/usr/bin:/bin" FAKE_UID=2000 python3 "$D" --root "$ROOT" --device --adb "$S/adb" >/dev/null 2>&1; echo $?)
ck "sem root reprova" "exit" "$rc" "3"
rc=$(PATH="$S:/usr/bin:/bin" FAKE_SELINUX=Permissive python3 "$D" --root "$ROOT" --device --adb "$S/adb" >/dev/null 2>&1; echo $?)
ck "SELinux Permissive reprova" "exit" "$rc" "3"
rc=$(PATH="$S:/usr/bin:/bin" FAKE_NS="pid net" python3 "$D" --root "$ROOT" --device --adb "$S/adb" >/dev/null 2>&1; echo $?)
ck "namespace faltando reprova" "exit" "$rc" "3"
rc=$(PATH="$S:/usr/bin:/bin" FAKE_MISSING_PROC=shm python3 "$D" --root "$ROOT" --device --adb "$S/adb" >/dev/null 2>&1; echo $?)
ck "/proc/sysvipc ilegível reprova" "exit" "$rc" "3"
rc=$(PATH="$S:/usr/bin:/bin" python3 "$D" --root "$ROOT" --device --adb "$S/adb" --expect-installed >/dev/null 2>&1; echo $?)
ck "pós-instalação sem caminhos reprova" "exit" "$rc" "3"
rc=$(PATH="$S:/usr/bin:/bin" FAKE_PATH_PRESENT=1 python3 "$D" --root "$ROOT" --device --adb "$S/adb" --expect-installed >/dev/null 2>&1; echo $?)
ck "pós-instalação com caminhos = pronto" "exit" "$rc" "0"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
