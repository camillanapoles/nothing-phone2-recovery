#!/usr/bin/env bash
# test_stage_logic.sh — testes SEMÂNTICOS dos estágios (A/B e empacotamento), com fixtures e stubs.
# Diferente de test_script_contracts.sh (que só valida --help), aqui cada caso força o caminho
# real: ausência de insumo NÃO pode virar sucesso, ""patch"" no-op não pode virar OK, e as
# decisões de veto (conflito fatal, crash em runtime, loop no watchdog) precisam aparecer na saída.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SK="$(cd "$HERE/.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-56s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-56s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
has(){ case "$3" in *"$4"*) ok "$1" "$2";; *) bad "$1" "$2 (não achei '$4' em: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-400))";; esac; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
STUBS="$T/stub"; mkdir -p "$STUBS"

# ---------------- stubs de ferramentas (sem binário real: comportamento fixo e verificável) ----
cat > "$STUBS/abootimg" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "$1" = "-x" ]; then
  printf 'cmdline=console=ttyMSM0\n' > bootimg.cfg
  printf 'KERNEL-STOCK\n' > kernel
  printf 'INITRD\n' > initrd.img
  exit 0
fi
if [ "$1" = "--create" ]; then
  out="$2"; cfg=""; kern=""; rdir=""
  while [ $# -gt 0 ]; do case "$1" in -f) cfg="$2"; shift 2;; -k) kern="$2"; shift 2;; -r) rdir="$2"; shift 2;; *) shift;; esac; done
  cat "$kern" "$cfg" "$rdir" > "$out"
  exit 0
fi
exit 0
EOF
cat > "$STUBS/magiskboot" <<'EOF'
#!/usr/bin/env bash
set -u
case "$1" in
  unpack) printf 'KERNEL-STOCK\n' > kernel ;;
  repack) cat kernel > "$3" ;;
esac
exit 0
EOF
cat > "$STUBS/kptools" <<'EOF'
#!/usr/bin/env bash
set -u
img=""; out=""; mode="${KPTOOLS_MODE:-patch}"
while [ $# -gt 0 ]; do case "$1" in --image|-i) img="$2"; shift 2;; --out|-o) out="$2"; shift 2;; *) shift;; esac; done
[ -n "$img" ] && [ -n "$out" ] || exit 2
if [ "$mode" = "noop" ]; then cp -f "$img" "$out"; else { cat "$img"; printf 'PATCHED-BY-KPTOOLS\n'; } > "$out"; fi
exit 0
EOF
cat > "$STUBS/payload-dumper-go" <<'EOF'
#!/usr/bin/env bash
set -u
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done
[ -n "$out" ] || exit 2
printf 'BOOT-IMG-CONTENT\n' > "$out/boot.img"
printf 'VBMETA\n' > "$out/vbmeta.img"
exit 0
EOF
chmod +x "$STUBS"/*

# ---------------- T05/T06 forge_patcher (Estágio A) ------------------------------------------
mkdir -p "$T/forge/rom" "$T/forge/mods"
FORGE="$SK/scripts/forge_patcher.sh"
( cd "$T/forge" && bash "$FORGE" apatch rom mods >"$T/o1" 2>&1 ); rc=$?
ck "forge sem boot.img recusa (não é sucesso)" "exit" "$rc" "3"
has "forge diz que nada foi patchado" "mensagem" "$(cat "$T/o1")" "nada foi patchado"
mkdir -p "$T/forge/rom"; printf 'BOOT\n' > "$T/forge/rom/boot.img"
( cd "$T/forge" && PATH="$STUBS:/usr/bin:/bin" HOME="$T/nohome" bash "$FORGE" apatch rom mods >"$T/o2" 2>&1 ); rc=$?
ck "forge sem kptools/kpimg fica PENDENTE" "exit" "$rc" "4"
ck "forge não cria imagem quando pendente" "existe" "$([ -f "$T/forge/rom/boot_patched.img" ] && echo sim || echo nao)" "nao"
mkdir -p "$T/homedir/bin"; printf 'KPIMG\n' > "$T/homedir/bin/kpimg"
( cd "$T/forge" && PATH="$STUBS:/usr/bin:/bin" HOME="$T/homedir" bash "$FORGE" apatch rom mods >"$T/o3" 2>&1 ); rc=$?
ck "forge com ferramentas patcheia de verdade" "exit" "$rc" "0"
ck "imagem patcheada difere da stock" "diferente" \
  "$(cmp -s "$T/forge/rom/boot_patched.img" "$T/forge/rom/boot_stock_rollback.img" && echo igual || echo diferente)" "diferente"
rm -f "$T/forge/rom/boot_patched.img" "$T/forge/rom/"*.sha256
( cd "$T/forge" && PATH="$STUBS:/usr/bin:/bin" HOME="$T/homedir" KPTOOLS_MODE=noop bash "$FORGE" apatch rom mods >"$T/o4" 2>&1 ); rc=$?
ck "patch que não altera nada é REJEITADO" "exit" "$rc" "5"
has "forge explica patch não aplicado" "mensagem" "$(cat "$T/o4")" "NÃO aplicado"

# ---------------- T03 patch_boot_offline -----------------------------------------------------
PATCH="$SK/scripts/patch_boot_offline.sh"
mkdir -p "$T/po/out"
( cd "$T/po" && bash "$PATCH" --engine apatch --boot ./ausente.img --out out >"$T/p1" 2>&1 ); rc=$?
ck "patch sem boot.img recusa (antes: exit 0)" "exit" "$rc" "3"
( cd "$T/po" && PATH="$STUBS:/usr/bin:/bin" bash "$PATCH" --engine apatch --boot "$T/forge/rom/boot_stock_rollback.img" --out out >"$T/p2" 2>&1 ); rc=$?
ck "patch sem binários fica PENDENTE" "exit" "$rc" "4"
ck "patch pendente não gera flash script" "existe" "$([ -f "$T/po/out/flash_and_rollback.sh" ] && echo sim || echo nao)" "nao"
printf 'KPIMG\n' > "$T/po/kpimg"
( cd "$T/po" && PATH="$STUBS:/usr/bin:/bin" bash "$PATCH" --engine apatch --boot "$T/forge/rom/boot_stock_rollback.img" --out out >"$T/p3" 2>&1 ); rc=$?
ck "patch com binários gera imagem" "exit" "$rc" "0"
ck "patch gera flash_and_rollback.sh" "existe" "$([ -f "$T/po/out/flash_and_rollback.sh" ] && echo sim || echo nao)" "sim"
( cd "$T/po" && PATH="$STUBS:/usr/bin:/bin" bash "$PATCH" --engine none --boot "$T/forge/rom/boot_stock_rollback.img" --out "$T/po/out_none" >"$T/p4" 2>&1 ); rc=$?
ck "sem imagem patcheada não gera flash script" "exit" "$rc" "4"
ck "out_none fica sem flash_and_rollback.sh" "existe" "$([ -f "$T/po/out_none/flash_and_rollback.sh" ] && echo sim || echo nao)" "nao"
ck "backup stock confere pelo sha256" "sha256sum -c" \
  "$( cd "$T/po" && sha256sum -c out/boot_stock_rollback.img.sha256 >/dev/null 2>&1 && echo ok || echo falhou)" "ok"

# ---------------- T01 extract_evox_base ------------------------------------------------------
EX="$SK/scripts/extract_evox_base.sh"
( bash "$EX" >"$T/e1" 2>&1 ); rc=$?
ck "extract sem --rom recusa" "exit" "$rc" "1"
mkdir -p "$T/romzip"; printf 'payloadbytes\n' > "$T/romzip/payload.bin"
( cd "$T/romzip" && zip -q -r "$T/evox.zip" payload.bin )
( PATH="/usr/bin:/bin" bash "$EX" --rom "$T/evox.zip" --out "$T/ext" >"$T/e2" 2>&1 ); rc=$?
ck "extract sem payload-dumper-go fica PENDENTE" "exit" "$rc" "3"
ck "extract pendente NÃO gera manifesto" "existe" "$([ -f "$T/ext/evox_base_manifest.json" ] && echo sim || echo nao)" "nao"
( PATH="$STUBS:/usr/bin:/bin" bash "$EX" --rom "$T/evox.zip" --out "$T/ext2" --partitions boot,vbmeta >"$T/e3" 2>&1 ); rc=$?
ck "extract com dumper gera manifesto" "exit" "$rc" "0"
ck "manifesto lista as partições extraídas" "boot+vbmeta" \
  "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print("+".join(sorted(k[:-4] for k in d["partitions"])))' "$T/ext2/evox_base_manifest.json")" "boot+vbmeta"
ck "manifesto tem sha256 real do boot.img" "sha256" \
  "$(python3 -c 'import hashlib,json,sys;d=json.load(open(sys.argv[1]));print(d["partitions"]["boot.img"]["sha256"]==hashlib.sha256(open(sys.argv[2],"rb").read()).hexdigest())' "$T/ext2/evox_base_manifest.json" "$T/ext2/boot.img")" "True"
ck "KMI não é inventado quando ausente" "unknown" \
  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["kernel_kmi"])' "$T/ext2/evox_base_manifest.json")" "unknown"

# ---------------- T02 audit_rom_conflicts ----------------------------------------------------
AUD="$SK/scripts/audit_rom_conflicts.sh"
mkdir -p "$T/aud/clean/moda/system/app" "$T/aud/bad/moda/system/app" "$T/aud/bad/modb/system/app"
printf 'a\n' > "$T/aud/clean/moda/system/app/a.apk"
printf 'a\n' > "$T/aud/bad/moda/system/app/a.apk"; printf 'b\n' > "$T/aud/bad/modb/system/app/a.apk"
( bash "$AUD" --modules-dir "$T/aud/clean" --kpm-dir "$T/aud/nokpm" --tweaks-dir "$T/aud/notweaks" --report-out "$T/aud/r1.md" >"$T/a1" 2>&1 ); rc=$?
ck "audit limpo aprova" "exit" "$rc" "0"
( bash "$AUD" --modules-dir "$T/aud/bad" --kpm-dir "$T/aud/nokpm" --tweaks-dir "$T/aud/notweaks" --report-out "$T/aud/r2.md" >"$T/a2" 2>&1 ); rc=$?
ck "audit veta colisão de arquivo" "exit" "$rc" "1"
has "relatório nomeia o arquivo disputado" "system/app/a.apk" "$(cat "$T/aud/r2.md")" "system/app/a.apk"
mkdir -p "$T/aud/zyg/zygiskA/system/lib64" "$T/aud/zyg/zygiskB/system/lib64"
printf 'x\n' > "$T/aud/zyg/zygiskA/system/lib64/libzygisk_a.so"
printf 'y\n' > "$T/aud/zyg/zygiskB/system/lib64/libzygisk_b.so"
( bash "$AUD" --modules-dir "$T/aud/zyg" --kpm-dir "$T/aud/nokpm" --tweaks-dir "$T/aud/notweaks" --report-out "$T/aud/r3.md" >"$T/a3" 2>&1 ); rc=$?
ck "audit veta dois provedores Zygisk" "exit" "$rc" "1"
has "relatório cita Zygisk duplicado" "provedores de Zygisk" "$(cat "$T/aud/r3.md")" "provedores de Zygisk"
mkdir -p "$T/aud/loop/modloop"
printf '#!/system/bin/sh\nsleep 30\n' > "$T/aud/loop/modloop/post-fs-data.sh"
( bash "$AUD" --modules-dir "$T/aud/loop" --kpm-dir "$T/aud/nokpm" --tweaks-dir "$T/aud/notweaks" --report-out "$T/aud/r4.md" >"$T/a4" 2>&1 ); rc=$?
ck "audit veta sleep bloqueante" "exit" "$rc" "1"
mkdir -p "$T/aud/kpm/kpms"
printf 'kpm\n' > "$T/aud/kpm/kpms/x.kpm"
( PATH="/usr/bin:/bin" bash "$AUD" --modules-dir "$T/aud/clean" --kpm-dir "$T/aud/kpm/kpms" --tweaks-dir "$T/aud/notweaks" --report-out "$T/aud/r5.md" >"$T/a5" 2>&1 ); rc=$?
ck "KPM sem kptools é PENDENTE (antes: PASS)" "exit" "$rc" "3"
has "relatório marca KPM como PENDENTE" "PENDENTE" "$(cat "$T/aud/r5.md")" "PENDENTE"

# ---------------- T05/T06 build_safe_module_bundle -------------------------------------------
BUN="$SK/scripts/build_safe_module_bundle.sh"
mkdir -p "$T/bun"
printf 'net.ipv4.tcp_fastopen=3\n' > "$T/bun/preset.prop"
printf '#!/system/bin/sh\necho watchdog\n' > "$T/bun/watchdog.sh"
( bash "$BUN" --prop "$T/bun/preset.prop" --watchdog "$T/bun/ausente.sh" --out "$T/bun/out1" >"$T/b1" 2>&1 ); rc=$?
ck "bundle sem watchdog recusa" "exit" "$rc" "3"
( bash "$BUN" --prop "$T/bun/ausente.prop" --watchdog "$T/bun/watchdog.sh" --out "$T/bun/out2" >"$T/b2" 2>&1 ); rc=$?
ck "bundle sem preset recusa" "exit" "$rc" "3"
( bash "$BUN" --name teste-ci --prop "$T/bun/preset.prop" --watchdog "$T/bun/watchdog.sh" --out "$T/bun/out3" >"$T/b3" 2>&1 ); rc=$?
ck "bundle completo gera zip" "exit" "$rc" "0"
ck "zip embarca watchdog + prop + module.prop" "4 arquivos" \
  "$(python3 -c 'import sys,zipfile;n=set(zipfile.ZipFile(sys.argv[1]).namelist());print(sum(m in n for m in ("module.prop","system.prop","service.sh","post-fs-data.sh")))' "$T/bun/out3/teste-ci.zip")" "4"
ck "module.prop usa o id pedido" "id=teste-ci" \
  "$(python3 -c 'import sys,zipfile;print([l for l in zipfile.ZipFile(sys.argv[1]).read("module.prop").decode().splitlines() if l.startswith("id=")][0])' "$T/bun/out3/teste-ci.zip")" "id=teste-ci"

# ---------------- watchdog anti-bootloop (on-device) -----------------------------------------
WD="$T/wd"; mkdir -p "$WD"; cp "$SK/assets/watchdog_anti_bootloop_service.sh" "$WD/service.sh"
cat > "$STUBS/getprop" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in sys.boot_completed) echo "${FAKE_BOOT:-1}";; *) echo "";; esac
EOF
cat > "$STUBS/log" <<'EOF'
#!/usr/bin/env bash
echo "log: $*" >> "$LOG_OUT"
EOF
cat > "$STUBS/reboot" <<'EOF'
#!/usr/bin/env bash
echo "reboot" >> "$REBOOT_OUT"
EOF
chmod +x "$STUBS/getprop" "$STUBS/log" "$STUBS/reboot"
export LOG_OUT="$T/log.txt" REBOOT_OUT="$T/reboot.txt"
: > "$LOG_OUT"; : > "$REBOOT_OUT"; printf '1\n' > "$WD/boot_attempt_count"
( PATH="$STUBS:/usr/bin:/bin" FAKE_BOOT=1 bash "$WD/service.sh" >"$T/w1" 2>&1 ); rc=$?
ck "watchdog com boot ok sai limpo" "exit" "$rc" "0"
ck "boot ok zera contador de tentativas" "removido" "$([ -f "$WD/boot_attempt_count" ] && echo ficou || echo removido)" "removido"
ck "boot ok não reinicia" "0 reboots" "$(wc -l < "$REBOOT_OUT" | tr -d ' ')" "0"
( PATH="$STUBS:/usr/bin:/bin" FAKE_BOOT=0 EVOX_WATCHDOG_TIMEOUT_SEC=2 EVOX_WATCHDOG_SLEEP_SEC=1 timeout 20 bash "$WD/service.sh" >"$T/w2" 2>&1 ); rc=$?
ck "timeout do watchdog falha" "exit" "$rc" "1"
ck "timeout desativa o módulo (disable)" "existe" "$([ -f "$WD/disable" ] && echo sim || echo nao)" "sim"
ck "timeout pede reboot para modo seguro" "reboot" "$(wc -l < "$REBOOT_OUT" | tr -d ' ')" "1"
rm -f "$WD/disable"; : > "$REBOOT_OUT"
rc=$(cd "$WD" && PATH="$STUBS:/usr/bin:/bin" FAKE_BOOT=0 EVOX_WATCHDOG_TIMEOUT_SEC=2 EVOX_WATCHDOG_SLEEP_SEC=0 timeout 20 bash service.sh >/dev/null 2>&1; echo $?)
ck "sleep 0 não trava o watchdog" "exit" "$rc" "1"

# ---------------- runtime_module_tester (Estágio B, adb stubado) ------------------------------
cat > "$STUBS/adb" <<'EOF'
#!/usr/bin/env bash
set -u
case "$1" in
  wait-for-device|root) exit 0 ;;
  shell)
    shift
    case "$1" in
      getprop)
        case "${2:-}" in
          init.svc.bootanim) echo stopped ;;
          *) echo "${FAKE_BOOT:-1}" ;;
        esac ;;
      logcat*)
        case "$1" in
          *FATAL*) echo "${FAKE_CRASH:-}" ;;
        esac ;;
      *) : ;;
    esac
    exit 0 ;;
  push|install) exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUBS/adb"
chmod +x "$STUBS/adb"
RUN="$SK/scripts/runtime_module_tester.sh"
mkdir -p "$T/rt/mods"
( cd "$T/rt" && PATH="$STUBS:/usr/bin:/bin" FAKE_BOOT=1 FAKE_CRASH="" bash "$RUN" "$T/rt/mods" >"$T/r1" 2>&1 ); rc=$?
ck "runtime sem crash aprova (com ressalva)" "exit" "$rc" "0"
has "runtime não promete boot do pong" "ressalva" "$(cat "$T/r1")" "nao prova boot do pong"
( cd "$T/rt" && PATH="$STUBS:/usr/bin:/bin" FAKE_BOOT=1 FAKE_CRASH="FATAL EXCEPTION: main" bash "$RUN" "$T/rt/mods" >"$T/r2" 2>&1 ); rc=$?
ck "runtime veta crash de Zygote" "exit" "$rc" "1"
has "runtime mostra o crash" "FATAL" "$(cat "$T/r2")" "FATAL EXCEPTION"

# ---------------- snapshot_branch_manager (git descartável) ----------------------------------
SNAP="$SK/scripts/snapshot_branch_manager.sh"
mkdir -p "$T/git1/work"; ( cd "$T/git1" && git init -q && git -c user.email=a@b -c user.name=t commit -q --allow-empty -m init )
printf 'imgbytes\n' > "$T/git1/work/boot.img"
( cd "$T/git1" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=a@b GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=a@b \
  bash "$SNAP" --layer teste --tag v-teste --source ./work --apply --allow-dirty >"$T/s1" 2>&1 ); rc=$?
ck "snapshot --apply conclui" "exit" "$rc" "0"
ck "branch de snapshot criada" "existe" "$( cd "$T/git1" && git branch --list snapshot/teste | wc -l | tr -d ' ')" "1"
ck "tag do snapshot criada" "existe" "$( cd "$T/git1" && git tag -l v-teste | wc -l | tr -d ' ')" "1"
ck "manifesto registra o artefato" "boot.img" \
  "$( cd "$T/git1" && git show snapshot/teste:work/snapshot_manifest.json | python3 -c 'import json,sys;print(",".join(json.load(sys.stdin)["artifacts"]))')" "boot.img"
ck "snapshot commita apenas o manifesto" "1" \
  "$( cd "$T/git1" && git show --pretty=format: --name-only snapshot/teste | grep -c . )" "1"
( cd "$T/git1" && git checkout -q -B "arena/protegida" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=a@b GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=a@b \
  bash "$SNAP" --layer x --tag v-x --source ./work --apply --allow-dirty >"$T/s2" 2>&1 ); rc=$?
ck "snapshot recusa branch protegida arena/*" "exit" "$rc" "4"
( cd "$T/git1" && git checkout -q main 2>/dev/null || git checkout -q master; printf 'sujo\n' > sujo.txt; GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=a@b GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=a@b \
  bash "$SNAP" --layer y --tag v-y --source ./work >"$T/s3" 2>&1 ); rc=$?
ck "worktree sujo bloqueia snapshot" "exit" "$rc" "4"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
