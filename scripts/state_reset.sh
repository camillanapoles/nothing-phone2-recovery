#!/usr/bin/env bash
# =============================================================================
# state_reset.sh — higiene de estado do workspace (zero conflito com o passado)
#
# O que faz:
#   1. Inventaria dados de sessões antigas (estado, evidência, planos, índices).
#   2. Move esse material para state/quarantine/<UTC>/ (nunca apaga sem cópia).
#   3. Limpa o banco do FSM que orquestra os backends (audit-fsm.db), registrando
#      quantas linhas existiam por tabela antes da limpeza.
#   4. Grava MANIFEST.json + SHA256SUMS — prova auditável do que saiu de cena.
#
# O que NUNCA toca (contrato preservado):
#   skills/ · audit-fsm/src · audit-fsm/tests · scripts/ · config/ · docs/skills/
#
# Uso:
#   scripts/state_reset.sh                # dry-run: só mostra o plano
#   scripts/state_reset.sh --apply        # executa
#   scripts/state_reset.sh --apply --json # saída JSON (para CI)
#   STATE_RESET_ROOT=/caminho ... --apply # raiz alternativa (usado nos testes)
#
# Exit: 0 = ok/limpo · 1 = erro · 3 = nada a fazer (já limpo)
# =============================================================================
set -euo pipefail

APPLY=0
JSON=0
ROOT="${STATE_RESET_ROOT:-}"

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "arg desconhecido: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
ROOT="$(cd "$ROOT" && pwd)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SLUG="$(date -u +%Y%m%dT%H%M%SZ)"
QDIR="$ROOT/state/quarantine/$SLUG"

# Material de sessões anteriores: instruções/dados que não valem mais como contrato.
STALE_PATHS=(
  "init_plan.md"
  "modules.md"
  "O advisory tinha razão — usar o boot.md"
  ".atl"
  ".pi/tasks"
  ".claude/kpi"
  "docs/plans"
  "docs/ssot"
  "docs/wiki/.pending"
  "docs/GOVERNANCE.md"
)

# Bancos do FSM (backends). Ordem: env explícita, raiz, pasta do pacote.
DB_CANDIDATES=()
if [ -n "${AUDIT_FSM_DB_URL:-}" ]; then
  case "$AUDIT_FSM_DB_URL" in
    sqlite*:///*) DB_CANDIDATES+=("${AUDIT_FSM_DB_URL#sqlite*:///}") ;;
  esac
fi
DB_CANDIDATES+=("$ROOT/audit-fsm.db" "$ROOT/audit-fsm/audit-fsm.db")

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

PLAN="$workdir/plan.txt"      # relpath<TAB>kind
: > "$PLAN"

for rel in "${STALE_PATHS[@]}"; do
  [ -e "$ROOT/$rel" ] || continue
  if [ -d "$ROOT/$rel" ]; then
    while IFS= read -r -d '' f; do
      printf '%s\tfile\n' "${f#"$ROOT"/}" >> "$PLAN"
    done < <(find "$ROOT/$rel" -type f -print0 | sort -z)
  else
    printf '%s\tfile\n' "$rel" >> "$PLAN"
  fi
done

# ── Banco do FSM: inventário de linhas por tabela (sqlite3 da stdlib) ────────
db_report="$workdir/db.json"
python3 - "$db_report" "${DB_CANDIDATES[@]}" <<'PY'
import json, os, sqlite3, sys
out, cands = sys.argv[1], sys.argv[2:]
report = []
for path in cands:
    if not path or not os.path.isfile(path):
        continue
    entry = {"path": path, "exists": True, "tables": {}, "rows": 0, "error": None}
    try:
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        names = [r[0] for r in con.execute(
            "select name from sqlite_master where type='table' "
            "and name not like 'sqlite_%' order by name")]
        for t in names:
            n = con.execute(f'select count(*) from "{t}"').fetchone()[0]
            entry["tables"][t] = n
            entry["rows"] += n
        con.close()
    except Exception as exc:                       # banco corrompido ≠ falha silenciosa
        entry["error"] = f"{type(exc).__name__}: {exc}"
    report.append(entry)
json.dump(report, open(out, "w"), indent=2)
PY

rows_total="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(sum(e["rows"] for e in d))' "$db_report")"
files_total="$(wc -l < "$PLAN" | tr -d ' ')"

emit() {  # emit <status> <message>
  if [ "$JSON" -eq 1 ]; then
    python3 - "$1" "$2" "$ROOT" "$QDIR" "$files_total" "$rows_total" "$APPLY" "$db_report" <<'PY'
import json, sys
status, msg, root, qdir, files, rows, applied, dbrep = sys.argv[1:9]
print(json.dumps({
    "status": status, "message": msg, "root": root, "quarantine": qdir,
    "stale_files": int(files), "db_rows_before": int(rows),
    "applied": bool(int(applied)), "databases": json.load(open(dbrep)),
}, indent=2, ensure_ascii=False))
PY
  else
    echo "[state] $1 — $2"
  fi
}

if [ "$files_total" -eq 0 ] && [ "$rows_total" -eq 0 ]; then
  emit "clean" "nada a limpar (já em estado de sessão única)"
  exit 3
fi

if [ "$APPLY" -eq 0 ]; then
  if [ "$JSON" -eq 1 ]; then
    emit "plan" "dry-run: nada foi alterado"
  else
    echo "[state] dry-run — nada será alterado sem --apply"
    echo "[state] arquivos a quarentenar: $files_total -> $QDIR"
    [ "$files_total" -gt 0 ] && sed 's/^/  - /' "$PLAN" | cut -f1 | head -40
    echo "[state] linhas no banco do FSM: $rows_total"
    python3 -c 'import json,sys
for e in json.load(open(sys.argv[1])):
    p, r, t = e["path"], e["rows"], e["tables"]
    print(f"  - {p}: {r} linhas {t}")' "$db_report"
  fi
  exit 0
fi

# ── Aplicar: mover arquivos (git mv quando versionado, mv quando não) ───────
mkdir -p "$QDIR"
moved=0
while IFS=$'\t' read -r rel kind; do
  src="$ROOT/$rel"; dst="$QDIR/$rel"
  mkdir -p "$(dirname "$dst")"
  if git -C "$ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
    git -C "$ROOT" mv -f "$rel" "${dst#"$ROOT"/}"
  else
    mv -f "$src" "$dst"
  fi
  moved=$((moved + 1))
done < "$PLAN"

# remove diretórios que ficaram vazios
for rel in "${STALE_PATHS[@]}"; do
  [ -d "$ROOT/$rel" ] && find "$ROOT/$rel" -depth -type d -empty -delete 2>/dev/null || true
done

# ── Aplicar: limpar bancos do FSM (cópia antes, depois remoção) ─────────────
python3 - "$QDIR" "$db_report" <<'PY'
import json, os, shutil, sys
qdir, rep = sys.argv[1], json.load(open(sys.argv[2]))
for e in rep:
    if not e.get("exists"):
        continue
    dst = os.path.join(qdir, "audit-fsm-db", os.path.basename(e["path"]))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(e["path"], dst)
    os.remove(e["path"])
    e["wiped"] = True
    e["backup"] = os.path.relpath(dst, os.path.dirname(qdir))
json.dump(rep, open(sys.argv[2], "w"), indent=2)
PY

# ── Prova: manifesto + checksums ────────────────────────────────────────────
( cd "$QDIR" && find . -type f ! -name SHA256SUMS ! -name MANIFEST.json -print0 \
    | sort -z | xargs -0 -r sha256sum > SHA256SUMS )

python3 - "$QDIR" "$TS" "$ROOT" "$PLAN" "$db_report" <<'PY'
import json, os, subprocess, sys
qdir, ts, root, plan, dbrep = sys.argv[1:6]
paths = [l.split("\t")[0] for l in open(plan).read().splitlines() if l.strip()]
head = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"],
                      capture_output=True, text=True).stdout.strip() or "no-git"
manifest = {
    "generated_at": ts,
    "reason": "isolamento de sessão: somente instruções/dados desta sessão valem",
    "git_head": head,
    "root": root,
    "quarantined_files": paths,
    "databases": json.load(open(dbrep)),
    "protected": ["skills/", "audit-fsm/src", "audit-fsm/tests", "scripts/",
                  "config/", "docs/skills/"],
}
json.dump(manifest, open(os.path.join(qdir, "MANIFEST.json"), "w"),
          indent=2, ensure_ascii=False)
PY

if command -v sha256sum >/dev/null 2>&1; then
  ( cd "$QDIR" && sha256sum -c --quiet SHA256SUMS >/dev/null 2>&1 ) \
    && verif="OK" || verif="FALHOU"
else
  verif="sha256sum ausente"
fi

printf '%s\n' "$QDIR" > "$ROOT/state/.last-quarantine"
emit "applied" "$moved arquivo(s) quarentenado(s) · $rows_total linha(s) de FSM removida(s) · manifesto $verif"
