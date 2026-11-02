#!/usr/bin/env bash
# =============================================================================
# test_extract_rom_assets.sh — prova que a L4 fecha pelo PACOTE da ROM (11 casos)
# Sem rede, sem device, sem payload-dumper-go real: usa stub determinístico.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/extract_rom_assets.sh"
PASS=0; FAIL=0

ok()   { printf 'PASS  %-46s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
bad()  { printf 'FAIL  %-46s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
check(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; mkdir -p "$BIN"

# stub: finge o payload e escreve imagens com assinatura de kernel verificável
cat > "$BIN/payload-dumper-go" <<'STUB'
#!/usr/bin/env bash
out="./out"; parts="boot"
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -p) parts="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$out"
IFS=',' read -r -a LIST <<< "$parts"
for p in "${LIST[@]}"; do
  echo "stub image $p" > /dev/null
  { printf '\x7fELF fake %s\n' "$p"; printf 'Linux version 6.1.75-android14-11-g9f2c638f-dirty (builder@evox) #1 SMP\n'; } > "$out/$p.img"
done
exit 0
STUB
chmod +x "$BIN/payload-dumper-go"

# stub que não produz nada (para provar exit 6)
cat > "$BIN/dumper-vazio" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$BIN/dumper-vazio"

# ROM sintética
python3 - "$TMP" <<'PY'
import os, sys, zipfile
tmp = sys.argv[1]
def mk(path, names):
    with zipfile.ZipFile(path, "w") as z:
        for n in names:
            z.writestr(n, b"payload-body")
mk(os.path.join(tmp, "ok.zip"), ["payload.bin", "META-INF/com/android/metadata"])
mk(os.path.join(tmp, "sem_payload.zip"), ["boot.img"])
open(os.path.join(tmp, "nao_zip.zip"), "wb").write(b"isto nao e um zip")
PY

ZIP="$TMP/ok.zip"
GOOD_SHA="$(sha256sum "$ZIP" | awk '{print $1}')"

# 1-4: contratos de erro
out="$("$SCRIPT" 2>&1)"; check "sem --zip pede uso" "exit=$?" "$?" "2"
out="$("$SCRIPT" --zip "$TMP/nao_existe.zip" 2>&1)"; check "zip inexistente" "exit=$?" "$?" "4"
out="$("$SCRIPT" --zip "$TMP/nao_zip.zip" 2>&1)"; check "arquivo que não é zip" "exit=$?" "$?" "4"
out="$("$SCRIPT" --zip "$TMP/sem_payload.zip" 2>&1)"; check "zip sem payload.bin" "exit=$?" "$?" "4"
mkdir -p "$TMP/nounzip"
BASHBIN="$(command -v bash)"
out="$(PATH="$TMP/nounzip" "$BASHBIN" "$SCRIPT" --zip "$ZIP" --out "$TMP/o0" 2>&1)"; c=$?
check "sem unzip: falha explícita" "exit=$c" "$c" "3"
out="$(PAYLOAD_DUMPER="$TMP/nao_instalado" "$SCRIPT" --zip "$ZIP" --out "$TMP/o0" 2>&1)"; c=$?
check "sem payload-dumper-go: falha explícita" "exit=$c" "$c" "3"
check "sem ferramenta não inventa imagem" "nenhum .img" \
  "$(ls "$TMP/o0"/*.img 2>/dev/null | wc -l | tr -d ' ')" "0"

# 5-7: caminho feliz
out="$(PAYLOAD_DUMPER="$BIN/payload-dumper-go" "$SCRIPT" --zip "$ZIP" --out "$TMP/o1" 2>&1)"; c=$?
check "extração completa fecha L4" "exit=$c" "$c" "0"
check "manifesto gerado" "rom_assets.json" "$([ -f "$TMP/o1/rom_assets.json" ] && echo ok || echo ausente)" "ok"
check "sha256 do boot.img confere" "boot.img" \
  "$(python3 -c '
import hashlib,json,sys
d=json.load(open(sys.argv[1])); p=sys.argv[2]
h=hashlib.sha256(open(p,"rb").read()).hexdigest()
print("igual" if d["images"]["boot.img"]["sha256"]==h else "divergente")' "$TMP/o1/rom_assets.json" "$TMP/o1/boot.img")" "igual"
check "kernel e KMI extraídos do boot.img" "6.1.75 · android14-11" \
  "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(str(d["kernel_version"])+" · "+str(d["kmi"]))' "$TMP/o1/rom_assets.json")" \
  "6.1.75-android14-11-g9f2c638f-dirty · android14-11"
check "cinco imagens inventariadas" "boot/init_boot/vendor_boot/vbmeta/dtbo" \
  "$(python3 -c 'import json,sys;print(",".join(sorted(json.load(open(sys.argv[1]))["images"])))' "$TMP/o1/rom_assets.json")" \
  "boot.img,dtbo.img,init_boot.img,vbmeta.img,vendor_boot.img"

# 8: hash esperado divergente
out="$(PAYLOAD_DUMPER="$BIN/payload-dumper-go" "$SCRIPT" --zip "$ZIP" --out "$TMP/o2" --expect-sha256 "$(printf '0%.0s' {1..64})" 2>&1)"; c=$?
check "ROM trocada é rejeitada" "exit=$c" "$c" "5"

# 9: reuso sem reextrair
out="$(PAYLOAD_DUMPER="$BIN/payload-dumper-go" "$SCRIPT" --zip "$ZIP" --out "$TMP/o1" --no-extract 2>&1)"; c=$?
check "reexecução idempotente (--no-extract)" "exit=$c" "$c" "0"

# 10: extração sem imagens não finge sucesso
out="$(PAYLOAD_DUMPER="$BIN/dumper-vazio" "$SCRIPT" --zip "$ZIP" --out "$TMP/o3" 2>&1)"; c=$?
check "L4 incompleta não vira PASS" "exit=$c" "$c" "6"

# 11: JSON parseável
out="$(PAYLOAD_DUMPER="$BIN/payload-dumper-go" "$SCRIPT" --zip "$ZIP" --out "$TMP/o4" --json 2>/dev/null)"
check "saída --json parseável com exit_code" "0" \
  "$(printf '%s' "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin)["exit_code"])' 2>/dev/null || echo invalido)" "0"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
