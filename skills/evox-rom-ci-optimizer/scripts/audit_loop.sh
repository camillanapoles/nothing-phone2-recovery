#!/usr/bin/env bash
# audit_loop.sh — harness de convergência: roda a auditoria em loop até o resultado estabilizar.
#
# Cada iteração: travas de arquitetura (AG) → varredura de contradições (C) → cobertura (COV)
#                → suíte completa de testes (opcional com --skip-tests).
# Convergiu = duas iterações seguidas com o mesmo "fingerprint" (códigos + contagens).
# Verde = convergiu E tudo zerado. Qualquer deriva entre iterações é reportada.
#
# Uso: audit_loop.sh [--root DIR] [--max-iter N] [--skip-tests] [--json]
# Exit: 0 verde e convergido · 3 vermelho/instável · 2 uso
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../.." && pwd)"
MAX=3; SKIPTESTS=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$(cd "$2" && pwd)"; shift 2 ;;
    --max-iter) MAX="$2"; shift 2 ;;
    --skip-tests) SKIPTESTS=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "[ERRO] argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

SC="$ROOT/skills/evox-rom-ci-optimizer/scripts"
mkdir -p "$ROOT/workspace/audit"
prev=""; converged=0; iters=0; last=""
hist=()
while [ "$iters" -lt "$MAX" ]; do
  iters=$((iters+1))
  g=0; s=0; errs=0; warns=0; cov=0; gaps=0; t=0
  [ -f "$SC/architecture_guard.py" ] && { python3 "$SC/architecture_guard.py" --root "$ROOT" >/dev/null 2>&1; g=$?; }
  if [ -f "$SC/contradiction_scan.py" ]; then
    python3 "$SC/contradiction_scan.py" --root "$ROOT" --json > "$ROOT/workspace/audit/scan.json" 2>/dev/null
    s=$?
    errs=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["errors"])' "$ROOT/workspace/audit/scan.json" 2>/dev/null || echo 0)
    warns=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["warnings"])' "$ROOT/workspace/audit/scan.json" 2>/dev/null || echo 0)
  fi
  if [ -f "$SC/coverage_matrix.py" ]; then
    python3 "$SC/coverage_matrix.py" --root "$ROOT" --json > "$ROOT/workspace/audit/coverage.json" 2>/dev/null
    cov=$?
    gaps=$(python3 -c 'import json,sys;print(json.load(sys.stdin)["gaps"])' < "$ROOT/workspace/audit/coverage.json" 2>/dev/null || echo 0)
  fi
  if [ "$SKIPTESTS" -eq 0 ]; then
    for tst in "$ROOT"/skills/evox-rom-ci-optimizer/tests/test_*.sh "$ROOT"/tests/test_*.sh; do
      [ -x "$tst" ] || { [ -f "$tst" ] && t=3; continue; }
      "$tst" >/dev/null 2>&1 || t=3
    done
  fi
  fp="guard=$g scan_rc=$s err=$errs warn=$warns cov_rc=$cov gaps=$gaps tests=$t"
  hist+=("$fp")
  last="$fp"
  if [ "$fp" = "$prev" ]; then converged=1; break; fi
  prev="$fp"
done

clean=1
case "$last" in *"guard=0"*) ;; *) clean=0 ;; esac
case "$last" in *"scan_rc=0"*) ;; *) clean=0 ;; esac
case "$last" in *"cov_rc=0"*) ;; *) clean=0 ;; esac
case "$last" in *"tests=0"*) ;; *) clean=0 ;; esac

mkdir -p "$ROOT/workspace/audit"
printf '{"schema":"evox-audit-loop/1","iterations":%d,"max_iter":%d,"converged":%s,"clean":%s,"fingerprints":[%s]}\n' \
  "$iters" "$MAX" "$([ "$converged" -eq 1 ] && echo true || echo false)" \
  "$([ "$clean" -eq 1 ] && echo true || echo false)" \
  "$(printf '"%s",' "${hist[@]}" | sed 's/,$//')" > "$ROOT/workspace/audit/audit-loop.json"

if [ "$JSON" -eq 1 ]; then cat "$ROOT/workspace/audit/audit-loop.json"; else
  echo "[loop] iterações=$iters convergiu=$converged limpo=$clean"
  i=0; for h in "${hist[@]}"; do i=$((i+1)); echo "  #$i $h"; done
fi
[ "$converged" -eq 1 ] && [ "$clean" -eq 1 ] && exit 0 || exit 3
