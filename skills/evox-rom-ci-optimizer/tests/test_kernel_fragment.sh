#!/usr/bin/env bash
# kernel-fragment.py — o fragmento do pack vem do CONTRATO, não da memória de quem editou.
# 8 casos: conteúdo derivado, determinismo, --check detecta divergência, contrato manda.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
K="$ROOT/scripts/kernel-fragment.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
ck(){ local esp="${4:-sim}"; if [ "$3" = "$esp" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$esp', obtido '${3:-}')"; fi; }
novo(){ local d="$1"; mkdir -p "$d/skills/evox-rom-ci-optimizer/references" "$d/kernel/fragments" "$d/scripts"
  cp "$ROOT/skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json" \
     "$d/skills/evox-rom-ci-optimizer/references/"
  cp "$K" "$d/scripts/"; echo "$d"; }

out=$(python3 "$K" --root "$ROOT")
ck "gera 13 CONFIG_*=y (12 do contrato + DEVTMPFS)" "13" "$(printf '%s' "$out" | grep -c '^CONFIG_.*=y$')" "13"
ck "inclui CONFIG_USER_NS (namespace obrigatório)" "sim" \
   "$(printf '%s' "$out" | grep -qx 'CONFIG_USER_NS=y' && echo sim || echo nao)" "sim"
ck "inclui CONFIG_PID_NS (namespace obrigatório)" "sim" \
   "$(printf '%s' "$out" | grep -qx 'CONFIG_PID_NS=y' && echo sim || echo nao)" "sim"
ck "inclui CONFIG_SYSVIPC e POSIX_MQUEUE" "sim" \
   "$(printf '%s' "$out" | grep -qx 'CONFIG_SYSVIPC=y' && printf '%s' "$out" | grep -qx 'CONFIG_POSIX_MQUEUE=y' && echo sim || echo nao)" "sim"
ck "cabeçalho diz que é gerado e cita o contrato" "sim" \
   "$(printf '%s' "$out" | grep -q 'NÃO editar à mão' && printf '%s' "$out" | grep -q 'droidspaces-requirements.json' && echo sim || echo nao)" "sim"
ck "--check no workspace real está em sincronia" "exit 0" "$(python3 "$K" --root "$ROOT" --check >/dev/null 2>&1; echo $?)" "0"
ck "--help sai 0" "exit 0" "$(python3 "$K" --help >/dev/null 2>&1; echo $?)" "0"
ck "raiz inexistente é entrada inválida" "exit 4" "$(python3 "$K" --root "$T/nada" >/dev/null 2>&1; echo $?)" "4"

# o contrato manda: acrescentar uma CONFIG_* no contrato muda o fragmento gerado
D=$(novo "$T/contrato")
python3 - "$D/skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
d["kernel"]["configs_required"].append("CONFIG_TESTE_NOVO")
json.dump(d, open(p, "w", encoding="utf-8"))
PY
novo_out=$(python3 "$K" --root "$D")
ck "config nova no contrato aparece no fragmento" "sim" \
   "$(printf '%s' "$novo_out" | grep -qx 'CONFIG_TESTE_NOVO=y' && echo sim || echo nao)" "sim"
ck "e o fragmento antigo passa a divergir (--check exit 1)" "exit 1" \
   "$(python3 "$K" --root "$D" --check >/dev/null 2>&1; echo $?)" "1"
python3 "$K" --root "$D" --out "$D/kernel/fragments/evox_pong_pack.config" >/dev/null
ck "depois de regenerar, --check volta a 0" "exit 0" "$(python3 "$K" --root "$D" --check >/dev/null 2>&1; echo $?)" "0"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
