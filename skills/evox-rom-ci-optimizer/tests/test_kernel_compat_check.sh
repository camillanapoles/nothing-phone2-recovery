#!/usr/bin/env bash
# Gate 1 — kernel × ROM × device (8 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/kernel_compat_check.sh"
P=0; F=0
ok(){ printf 'PASS  %-44s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-44s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

python3 - "$T" <<'PY'
import json, os, sys
t = sys.argv[1]
rom = {"schema":"pong-rom-assets/1","l4_closed":True,"kernel_version":"6.1.75-android14-11-g9f2c638f",
       "kmi":"android14-11","images":{"boot.img":{"sha256":"a"*64,"size_bytes":1}},
       "source":{"zip":"EvolutionX-16.0-20260915-Pong-11.11-Official.zip","zip_sha256":"b"*64}}
cand = {"name":"APatch pong 6.1.75","model":"pong","soc":"SM8475","android_api":36,
        "android_release":"16","kmi":"android14-11","kernel_base":"6.1",
        "supported_rom_builds":["EvolutionX-16.0-20260915-Pong-11.11"],
        "developer_support":{"declared":True,"source":"https://x.dev/support"},
        "source_url":"https://x.dev/kernel.zip","sha256":"c"*64}
json.dump(rom, open(os.path.join(t,"rom.json"),"w"))
json.dump(cand, open(os.path.join(t,"ok.json"),"w"))
for name, patch in {"modelo":("model","pixel"),"api":("android_api",35),
                    "kmi":("kmi","android15-6.19"),"build":("supported_rom_builds",["Outra-11.11"]),
                    "sem_suporte":("developer_support",{"declared":False})}.items():
    import copy; c = copy.deepcopy(cand); k,v = patch; c[k]=v
    json.dump(c, open(os.path.join(t,f"{name}.json"),"w"))
rom_f = dict(rom); rom_f["l4_closed"]=False
json.dump(rom_f, open(os.path.join(t,"rom_aberto.json"),"w"))
PY

"$S" >/dev/null 2>&1; ck "sem argumentos pede uso" "exit=$?" "$?" "2"
"$S" --rom-assets "$T/nao.json" --candidate "$T/ok.json" >/dev/null 2>&1; ck "rom_assets ausente" "exit=$?" "$?" "4"
"$S" --rom-assets "$T/rom.json" --candidate "$T/ok.json" >/dev/null 2>&1; ck "kernel compatível passa" "exit=$?" "$?" "0"
"$S" --rom-assets "$T/rom.json" --candidate "$T/modelo.json" >/dev/null 2>&1; ck "modelo diferente bloqueia" "exit=$?" "$?" "3"
"$S" --rom-assets "$T/rom.json" --candidate "$T/api.json" >/dev/null 2>&1; ck "API diferente bloqueia" "exit=$?" "$?" "3"
"$S" --rom-assets "$T/rom.json" --candidate "$T/kmi.json" >/dev/null 2>&1; ck "KMI diferente bloqueia" "exit=$?" "$?" "3"
"$S" --rom-assets "$T/rom.json" --candidate "$T/build.json" >/dev/null 2>&1; ck "build não suportada bloqueia" "exit=$?" "$?" "3"
"$S" --rom-assets "$T/rom.json" --candidate "$T/sem_suporte.json" >/dev/null 2>&1; ck "sem suporte declarado bloqueia" "exit=$?" "$?" "3"
ck "L4 aberta reprova o gate" "exit" "$("$S" --rom-assets "$T/rom_aberto.json" --candidate "$T/ok.json" >/dev/null 2>&1; echo $?)" "3"
"$S" --rom-assets "$T/rom.json" --candidate "$T/ok.json" --json >/dev/null 2>&1
ck "JSON declara COMPATIBLE" "verdict" "$("$S" --rom-assets "$T/rom.json" --candidate "$T/ok.json" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["verdict"])')" "COMPATIBLE"
echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
