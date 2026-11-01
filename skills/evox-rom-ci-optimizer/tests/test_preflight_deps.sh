#!/usr/bin/env bash
# =============================================================================
# Regressão do preflight de dependências (L3) — PATH controlado, sem instalar nada.
# Casos: tudo presente (exit 0), exigido ausente (exit 1), lista --require
#        customizada, saída JSON parseável e --hints com instrução de instalação.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/preflight_deps.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok()  { printf 'PASS  %-46s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
bad() { printf 'FAIL  %-46s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }

# PATH mínimo com stubs: controla exatamente o que "existe"
mk_path() { # mk_path <dir> <bins...>
  local dir="$1"; shift
  mkdir -p "$dir"
  local b
  for b in "$@"; do
    printf '#!/bin/sh\nexit 0\n' > "$dir/$b"
    chmod +x "$dir/$b"
  done
  for t in bash sh sed grep cat wc command dirname; do
    ln -sf "$(command -v $t)" "$dir/$t" 2>/dev/null || { echo "fixture: $t não instalado"; exit 1; }
  done
  echo "$dir"
}

# ---- caso 1: exigidos presentes ---------------------------------------------
P1="$(mk_path "$WORK/p1" python3 unzip sha256sum)"
PATH="$P1" "$SCRIPT" --json > "$WORK/r1.json" 2>"$WORK/r1.err"
rc=$?
[ "$rc" -eq 0 ] && ok "exigidos presentes" "exit=0" || bad "exigidos presentes" "exit=$rc"

python3 - "$WORK/r1.json" <<'PY' && ok "saída JSON válida" "results/required/missing_*" || bad "saída JSON válida" "json inválido"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["results"] and d["required"] == "python3,unzip,sha256sum"
assert d["missing_required"] == ""
assert any(r["bin"] == "python3" and r["state"] == "present" for r in d["results"])
PY

# ---- caso 2: exigido ausente -------------------------------------------------
P2="$(mk_path "$WORK/p2" python3)"
PATH="$P2" "$SCRIPT" --json > "$WORK/r2.json" 2>"$WORK/r2.err"
rc=$?
[ "$rc" -eq 1 ] && ok "exigido ausente bloqueia" "exit=1" || bad "exigido ausente bloqueia" "exit=$rc"

grep -q 'unzip' "$WORK/r2.err" && ok "motivo do bloqueio explícito" "unzip no stderr" || bad "motivo do bloqueio explícito" "stderr sem motivo"

# ---- caso 3: --require customizado ------------------------------------------
PATH="$P1" "$SCRIPT" --require "python3,gh" --json > "$WORK/r3.json" 2>/dev/null
rc=$?
[ "$rc" -eq 1 ] && ok "--require detecta dependência não listada" "gh ausente → exit=1" || bad "--require detecta dependência não listada" "exit=$rc"

python3 - "$WORK/r3.json" <<'PY' && ok "--require refletido no JSON" "missing_required=gh" || bad "--require refletido no JSON" "campo incorreto"
import json, sys
assert json.load(open(sys.argv[1]))["missing_required"] == "gh"
PY

# ---- caso 4: --hints ---------------------------------------------------------
PATH="$P2" "$SCRIPT" --hints > "$WORK/r4.txt" 2>/dev/null
grep -q "como instalar" "$WORK/r4.txt" && ok "--hints explica instalação" "seção 'como instalar'" || bad "--hints explica instalação" "seção ausente"
grep -qi "unzip" "$WORK/r4.txt" && ok "--hints cobre o binário faltante" "hint do unzip" || bad "--hints cobre o binário faltante" "hint ausente"

echo "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "[OK] preflight conforme contrato."
