#!/usr/bin/env bash
# test_wrapper_stages.sh — semântica dos wrappers de release (auditoria de ZIP e Cuttlefish).
# Foco: skip/insumo ausente NÃO pode ser sucesso, e o auditor não pode emitir a própria prova.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-52s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-52s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
has(){ case "$3" in *"$4"*) ok "$1" "$2";; *) bad "$1" "$2 (não achei '$4' em: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-900))";; esac; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
AUDIT="$ROOT/scripts/audit-flashable-zip.sh"
CUTTLE="$ROOT/scripts/validate-cuttlefish.sh"

# ---- audit-flashable-zip ------------------------------------------------------
mkdir -p "$T/rel"
( cd "$T/rel" && bash "$AUDIT" >"$T/a1" 2>&1 ); rc=$?
ck "auditoria sem ZIP recusa" "exit" "$rc" "1"
has "auditoria diz que não há ZIP" "No ZIP" "$(cat "$T/a1")" "No ZIP"

mkdir -p "$T/z1/META-INF/com/google/android"
printf 'script\n' > "$T/z1/META-INF/com/google/android/updater-script"
printf 'IMG\n' > "$T/z1/boot.img"
( cd "$T/z1" && zip -q -r "$T/rel/flashable.zip" META-INF boot.img )
( cd "$T/rel" && bash "$AUDIT" >"$T/a2" 2>&1 ); rc=$?
ck "ZIP sem manifesto de hash fica PENDENTE" "exit" "$rc" "3"
ck "auditor não gera o próprio sha256" "existe" "$([ -f "$T/rel/flashable.zip.sha256" ] && echo sim || echo nao)" "nao"

( cd "$T/rel" && sha256sum flashable.zip > flashable.zip.sha256 )
( cd "$T/rel" && bash "$AUDIT" >"$T/a3" 2>&1 ); rc=$?
ck "ZIP flashável válido passa" "exit" "$rc" "0"
has "auditoria confirma estrutura mínima" "OK" "$(cat "$T/a3")" "Estrutura mínima"

printf 'corrompido\n' > "$T/rel/flashable.zip"
( cd "$T/rel" && bash "$AUDIT" >"$T/a4" 2>&1 ); rc=$?
ck "hash divergente veta" "exit" "$rc" "1"
has "auditoria acusa mismatch" "mismatch" "$(cat "$T/a4")" "mismatch"

# ZIP sem updater-script porém com hash correto → VETO de conteúdo
mkdir -p "$T/z2"; printf 'IMG\n' > "$T/z2/boot.img"
( cd "$T/z2" && zip -q "$T/rel/ruim.zip" boot.img && sha256sum "$T/rel/ruim.zip" > "$T/rel/ruim.zip.sha256" )
( cd "$T/rel" && bash "$AUDIT" "$T/rel/ruim.zip" >"$T/a5" 2>&1 ); rc=$?
ck "ZIP sem updater-script é vetado" "exit" "$rc" "1"
has "veto nomeia o arquivo ausente" "updater-script" "$(cat "$T/a5")" "updater-script"

# ---- validate-cuttlefish -----------------------------------------------------
mkdir -p "$T/stub"
cat > "$T/stub/cvd" <<'EOF'
#!/usr/bin/env bash
case "$1" in list) echo "cvd-1 running" ;; *) : ;; esac
exit 0
EOF
chmod +x "$T/stub/cvd"
( PATH="/usr/bin:/bin" bash "$CUTTLE" >"$T/c1" 2>&1 ); rc=$?
ck "Cuttlefish ausente é PENDENTE (não sucesso)" "exit" "$rc" "3"
( PATH="$T/stub:/usr/bin:/bin" bash "$CUTTLE" >"$T/c2" 2>&1 ); rc=$?
ck "Cuttlefish sem boot.img recusa" "exit" "$rc" "1"
has "recusa cita boot image" "No boot image" "$(cat "$T/c2")" "No boot image"

# ---- wrappers de build: recusas puras (sem toolchain) ------------------------
( GITHUB_OUTPUT="" TOOLCHAIN=nao-existe bash "$ROOT/scripts/generate-build-matrix.sh" >"$T/g1" 2>&1 ); rc=$?
ck "matriz recusa toolchain desconhecida" "exit" "$rc" "1"
has "matriz aponta o toolchain inválido" "Unsupported toolchain" "$(cat "$T/g1")" "Unsupported toolchain"
mkdir -p "$T/kdir"
( bash "$ROOT/scripts/patch-manager.sh" "$T/kdir" nao-existe >"$T/g2" 2>&1 ); rc=$?
ck "patch-manager recusa manager desconhecido" "exit" "$rc" "1"
has "patch-manager aponta o manager inválido" "Unknown manager" "$(cat "$T/g2")" "Unknown manager"
( bash "$ROOT/scripts/patch-manager.sh" "$T/kernel-ausente" apatch >"$T/g2b" 2>&1 ); rc=$?
ck "patch-manager sem árvore fica PENDENTE" "exit" "$rc" "3"
has "patch-manager diz que nada foi aplicado" "nenhum patch aplicado" "$(cat "$T/g2b")" "nenhum patch aplicado"
( KERNEL_SOURCE=nao-existe bash "$ROOT/scripts/resolve-kernel-source.sh" >"$T/g3" 2>&1 ); rc=$?
ck "resolve-kernel recusa fonte desconhecida" "exit" "$rc" "1"
has "resolve-kernel aponta a fonte inválida" "Unknown kernel source" "$(cat "$T/g3")" "Unknown kernel source"

# ---- empacotamento: sem artefatos não há ZIP; template não é inventado -------
PKG="$ROOT/scripts/package-anykernel3.sh"
mkdir -p "$T/rel2/keep"
printf 'sentinela\n' > "$T/rel2/keep/nao-apagar.txt"
( cd "$T/rel2" && bash "$PKG" kernel-source "$T/rel2/dist-ausente" apatch >"$T/p1" 2>&1 ); rc=$?
ck "empacotar sem dist fica PENDENTE" "exit" "$rc" "3"
has "mensagem diz que falta o dist" "diretório de artefatos ausente" "$(cat "$T/p1")" "diretório de artefatos ausente"
ck "release dir não é apagado antes de validar" "existe" "$([ -f "$T/rel2/keep/nao-apagar.txt" ] && echo sim || echo nao)" "sim"
mkdir -p "$T/rel2/dist-vazio"
( cd "$T/rel2" && bash "$PKG" kernel-source "$T/rel2/dist-vazio" apatch >"$T/p1b" 2>&1 ); rc=$?
ck "dist sem imagem fica PENDENTE" "exit" "$rc" "3"
has "mensagem diz que o ZIP não seria flashável" "não seria flashável" "$(cat "$T/p1b")" "não seria flashável"
mkdir -p "$T/rel2/dist"; printf 'IMG\n' > "$T/rel2/dist/boot.img"
# O resultado deste trecho NÃO pode depender da máquina: template e PATH são controlados aqui.
# (o mutante M98 sobrevivia no CI porque lá existe rsync e a rede deixa clonar o template)
mkdir -p "$T/ak3tpl"; printf 'kernel.string=teste\n' > "$T/ak3tpl/anykernel.sh"
mkdir -p "$T/bin-nor" "$T/bin-rs"
for c in bash mkdir dirname basename cat cp rm sed sort mktemp find; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$T/bin-nor/$c"
done
cp -a "$T/bin-nor/." "$T/bin-rs/" 2>/dev/null
# shim de rsync: copia recursiva honrando --exclude=..., sem depender do binário do host
cat > "$T/bin-rs/rsync" <<'RS'
#!/usr/bin/env bash
ex=""; pos=()
for a in "$@"; do
  case "$a" in
    --exclude=*) ex="${a#--exclude=}" ;;
    -a|--archive|-av) ;;
    *) pos+=("$a") ;;
  esac
done
src="${pos[0]:-.}"; dst="${pos[1]:-.}"
mkdir -p "$dst"
for f in "$src"* "$src".[!.]*; do
  [ -e "$f" ] || continue
  [ -n "$ex" ] && [ "$(basename "$f")" = "$ex" ] && continue
  cp -a "$f" "$dst/" || exit 1
done
RS
chmod +x "$T/bin-rs/rsync"
( cd "$T/rel2" && AK3_TEMPLATE="$T/ak3tpl" PATH="$T/bin-nor" bash "$PKG" kernel-source "$T/rel2/dist" apatch >"$T/p2" 2>&1 ); rc=$?
ck "sem rsync o empacotamento fica PENDENTE" "exit" "$rc" "3"
has "rsync ausente é dito explicitamente" "rsync" "$(cat "$T/p2")" "rsync"
( cd "$T/rel2" && AK3_TEMPLATE="$T/ak3tpl" PATH="$T/bin-rs" bash "$PKG" kernel-source "$T/rel2/dist" apatch >"$T/p2b" 2>&1 ); rc=$?
ck "com rsync o empacotamento segue (não PENDENTE por ferramenta)" "diferente de 3" "$([ "$rc" = "3" ] && echo 3 || echo outro)" "outro"

# ---- build de kernel: árvore ausente é PENDENTE, não sucesso ----------------
( bash "$ROOT/scripts/build-kernel-pong.sh" "$T/kernel-inexistente" >"$T/k1" 2>&1 ); rc=$?
ck "build sem árvore de kernel fica PENDENTE" "exit" "$rc" "3"
has "build diz que nada foi compilado" "nada foi compilado" "$(cat "$T/k1")" "nada foi compilado"

# ---- identidade do build: matriz e resolução levam os valores reais ----------
( GITHUB_OUTPUT="$T/matrix.out" TOOLCHAIN=llvm-22.1.8 LTO=full bash "$ROOT/scripts/generate-build-matrix.sh" >/dev/null 2>&1 )
ck "label da matriz identifica manager/kernel/toolchain/lto" \
  "apatch-prebuilt-evolutionx-llvm-22.1.8-ltofull" \
  "$(python3 -c 'import json,re,sys;t=open(sys.argv[1]).read();print(json.loads(re.search(r"matrix=(\{.*\})",t,re.S).group(1))["label"])' "$T/matrix.out")" \
  "apatch-prebuilt-evolutionx-llvm-22.1.8-ltofull"
ck "matriz registra o LTO escolhido" "ltofull" "$(grep -o 'lto[a-z]*' "$T/matrix.out" | head -1)" "ltofull"
( GITHUB_OUTPUT="$T/matrix.1l" TOOLCHAIN=llvm-22.1.8 LTO=full bash "$ROOT/scripts/generate-build-matrix.sh" >/dev/null 2>&1 )
ck "file command do runner recebe UMA linha (JSON compacto)" "uma linha" \
  "$(wc -l < "$T/matrix.1l" | tr -d ' ')" "1"
( GITHUB_ENV="$T/env.out" KERNEL_SOURCE=lineage-pong bash "$ROOT/scripts/resolve-kernel-source.sh" >/dev/null 2>&1 )
ck "resolução exporta a ref do kernel" "lineage-23.2" \
  "$(grep -m1 '^SOURCE_REF=' "$T/env.out" | cut -d= -f2)" "lineage-23.2"
ck "resolução marca tipo git" "git" "$(grep -m1 '^SOURCE_TYPE=' "$T/env.out" | cut -d= -f2)" "git"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
