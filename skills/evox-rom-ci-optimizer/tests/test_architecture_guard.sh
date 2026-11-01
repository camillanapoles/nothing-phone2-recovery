#!/usr/bin/env bash
# architecture_guard.py — trava da arquitetura decidida (6 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; G="$HERE/../scripts/architecture_guard.py"; ROOT="$HERE/../../.."
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "self-test detecta as 10 violações simuladas" "exit" \
  "$(python3 "$G" --self-test >/dev/null 2>&1; echo $?)" "0"
ck "repositório respeita a arquitetura" "exit" \
  "$(python3 "$G" --root "$ROOT" >/dev/null 2>&1; echo $?)" "0"
ck "JSON tem todas as regras" "contagem" \
  "$(python3 "$G" --root "$ROOT" --json | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["results"]))')" "15"

# fixture mínima com violação injetada: o guard tem de reprovar
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/skills/evox-rom-ci-optimizer/"{references,assets,scripts,tests} "$T/workflows-local"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/evox-ci-validator.yml" "$T/skills/evox-rom-ci-optimizer/references/" 2>/dev/null || true
cp "$ROOT/workflows-local/pong-ab-hil.yml" "$T/workflows-local/" 2>/dev/null || true
cp "$ROOT/skills/evox-rom-ci-optimizer/assets/00_slot_router.sh" "$T/skills/evox-rom-ci-optimizer/assets/" 2>/dev/null || true
cp "$ROOT/skills/evox-rom-ci-optimizer/scripts/abl_fallback_probe.sh" "$T/skills/evox-rom-ci-optimizer/scripts/" 2>/dev/null || true
cp "$ROOT/skills/evox-rom-ci-optimizer/SKILL.md" "$T/skills/evox-rom-ci-optimizer/" 2>/dev/null || true
cp "$ROOT/AGENTS.md" "$T/" 2>/dev/null || true
cp "$ROOT/skills/evox-rom-ci-optimizer/Makefile" "$T/skills/evox-rom-ci-optimizer/" 2>/dev/null || true
printf '\n      - run: fastboot flash boot_b boot.img\n' >> "$T/skills/evox-rom-ci-optimizer/references/evox-ci-validator.yml"
ck "cloud com fastboot é reprovado" "exit" "$(python3 "$G" --root "$T" >/dev/null 2>&1; echo $?)" "3"
ck "violação aponta AG1" "AG1" \
  "$(python3 "$G" --root "$T" --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print([r["rule"] for r in d["results"] if not r["ok"]][0])')" "AG1"
ck "sem arquivos obrigatórios reprova AG7" "AG7" \
  "$(rm "$T/AGENTS.md"; python3 "$G" --root "$T" --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print("AG7" if any(not r["ok"] and r["rule"]=="AG7" for r in d["results"]) else "ok")')" "AG7"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
