#!/usr/bin/env bash
# =============================================================================
# test_state_reset.sh — prova que a higiene de estado funciona (8 casos)
# Roda em repo temporário: não toca no workspace real.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/state_reset.sh"
PASS=0
FAIL=0

ok()   { printf 'PASS  %-46s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
bad()  { printf 'FAIL  %-46s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
check(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo"
mkdir -p "$R/docs/plans" "$R/docs/skills" "$R/.atl" "$R/skills/core" "$R/audit-fsm/src" "$R/scripts"
printf 'plano velho\n' > "$R/init_plan.md"
printf 'modulos velhos\n' > "$R/modules.md"
printf 'plano antigo\n' > "$R/docs/plans/plano.md"
printf 'indice de outra maquina\n' > "$R/.atl/skill-registry.md"
printf '# GOVERNANCA ANTIGA\n' > "$R/docs/GOVERNANCE.md"
printf 'contrato vivo\n' > "$R/docs/skills/SKILLS-INVENTORY.md"
printf 'skill viva\n' > "$R/skills/core/SKILL.md"
printf 'fsm src\n' > "$R/audit-fsm/src/core.py"
printf 'script gerente\n' > "$R/scripts/manager.sh"

# banco do FSM com dados "preenchidos"
python3 - "$R/audit-fsm.db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("create table runs(id text)")
con.execute("create table probes(id text)")
con.executemany("insert into runs values(?)", [("r1",), ("r2",)])
con.executemany("insert into probes values(?)", [("p1",), ("p2",), ("p3",)])
con.commit(); con.close()
PY

cd "$R" && git init -q . && git add -A && \
  git -c user.email=t@t -c user.name=t commit -qm "estado antigo" >/dev/null
BASE_HEAD="$(git rev-parse HEAD)"

# 1. dry-run não altera nada
out="$(STATE_RESET_ROOT="$R" bash "$SCRIPT" 2>&1)"; code=$?
check "dry-run sai com 0" "exit=$code" "$code" "0"
check "dry-run preserva arquivo antigo" "init_plan existe" "$([ -f "$R/init_plan.md" ] && echo existe || echo sumiu)" "existe"
check "dry-run preserva banco" "db existe" "$([ -f "$R/audit-fsm.db" ] && echo existe || echo sumiu)" "existe"

# 2. apply
out="$(STATE_RESET_ROOT="$R" bash "$SCRIPT" --apply 2>&1)"; code=$?
check "apply sai com 0" "exit=$code" "$code" "0"
check "arquivos antigos saíram da raiz" "init_plan/modules/.atl/docs-plans" \
  "$([ ! -e "$R/init_plan.md" ] && [ ! -e "$R/modules.md" ] && [ ! -e "$R/.atl/skill-registry.md" ] && [ ! -e "$R/docs/plans/plano.md" ] && echo limpos || echo restaram)" "limpos"
check "banco do FSM removido (limpo p/ próxima sessão)" "db" \
  "$([ ! -e "$R/audit-fsm.db" ] && echo removido || echo presente)" "removido"
check "backends preservados" "skills/docs-skills/scripts/audit-fsm-src" \
  "$([ -f "$R/skills/core/SKILL.md" ] && [ -f "$R/docs/skills/SKILLS-INVENTORY.md" ] && [ -f "$R/scripts/manager.sh" ] && [ -f "$R/audit-fsm/src/core.py" ] && echo intactos || echo danificados)" "intactos"

Q="$(cat "$R/state/.last-quarantine" 2>/dev/null)"
check "manifesto criado" "MANIFEST.json" "$([ -f "$Q/MANIFEST.json" ] && echo ok || echo ausente)" "ok"
check "manifesto registra 5 linhas de banco" "db_rows=5" \
  "$(python3 -c 'import json,sys;print(sum(d["rows"] for d in json.load(open(sys.argv[1]))["databases"]))' "$Q/MANIFEST.json" 2>/dev/null || echo erro)" "5"
check "SHA256SUMS verifica" "sha256sum -c" \
  "$(cd "$Q" && sha256sum -c --quiet SHA256SUMS >/dev/null 2>&1 && echo ok || echo falhou)" "ok"
check "commit não foi criado pela limpeza" "HEAD inalterado" \
  "$(cd "$R" && git rev-parse HEAD)" "$BASE_HEAD"

# 3. idempotência
out2="$(STATE_RESET_ROOT="$R" bash "$SCRIPT" --apply 2>&1)"; code2=$?
check "segunda execução: já limpo (exit 3)" "exit=$code2" "$code2" "3"

# 4. JSON é JSON
R2="$TMP/repo2"; mkdir -p "$R2"; printf 'x\n' > "$R2/init_plan.md"
j="$(STATE_RESET_ROOT="$R2" bash "$SCRIPT" --json 2>/dev/null)"
check "saída --json é parseável" "json" \
  "$(printf '%s' "$j" | python3 -c 'import json,sys;print(json.load(sys.stdin)["status"])' 2>/dev/null || echo invalido)" "plan"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
