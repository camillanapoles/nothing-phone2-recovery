#!/usr/bin/env bash
# =============================================================================
# SNAPSHOT-KEEPER v3.0 — [M14] Gestor de Snapshots Modulares por Branches e Tags
# =============================================================================
set -euo pipefail

# --help nunca executa nada
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USO'
uso: snapshot_branch_manager.sh --layer <nome> [--tag <tag>] [--source DIR] --apply

  Sem --apply é DRY-RUN: mostra o plano e não toca no git.
  Recusa rodar: em branch protegida (arena/*), com worktree sujo, ou detached HEAD.
  Cria apenas a branch/tag do snapshot; nunca `git add -A` (só o manifesto).
USO
  exit 0
fi

LAYER="modules-wave1"
TAG_NAME="v11.11-w1-clean"
SOURCE_DIR="./work"
APPLY=0; ALLOW_DIRTY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer) LAYER="$2"; shift 2 ;;
    --tag) TAG_NAME="$2"; shift 2 ;;
    --source) SOURCE_DIR="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    *) echo "[ERRO] argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

BRANCH_NAME="snapshot/${LAYER}"
mkdir -p "$SOURCE_DIR"

python3 - "$SOURCE_DIR" "$LAYER" "$TAG_NAME" << 'PYEOF'
import hashlib, json, os, sys, time
src_dir, layer, tag = sys.argv[1], sys.argv[2], sys.argv[3]
artifacts = {}
for root, _, files in os.walk(src_dir):
    for f in sorted(files):
        if f.endswith((".img", ".zip", ".kpm", ".prop", ".json", ".conf")):
            p = os.path.join(root, f)
            h = hashlib.sha256()
            with open(p, "rb") as fp:
                for chunk in iter(lambda: fp.read(65536), b""):
                    h.update(chunk)
            artifacts[os.path.relpath(p, src_dir)] = {"sha256": h.hexdigest(), "size_bytes": os.path.getsize(p)}
manifest = {"layer": layer, "tag": tag, "branch": f"snapshot/{layer}", "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "artifacts": artifacts}
with open(os.path.join(src_dir, "snapshot_manifest.json"), "w", encoding="utf-8") as out:
    json.dump(manifest, out, indent=2)
PYEOF

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  case "$CURRENT_BRANCH" in
    HEAD) echo "[ERRO] detached HEAD: snapshot nao e seguro" >&2; exit 4 ;;
    arena/*) echo "[ERRO] branch protegida ($CURRENT_BRANCH): snapshot fora dela" >&2; exit 4 ;;
  esac
  if [ "$ALLOW_DIRTY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
    echo "[ERRO] worktree sujo: commite ou use --allow-dirty (evita engolir edicoes alheias)" >&2
    exit 4
  fi
  if [ "$APPLY" -eq 0 ]; then
    echo "[dry-run] criaria branch '$BRANCH_NAME', commit do manifesto e tag '$TAG_NAME' (use --apply)"
    exit 0
  fi
  git checkout -B "$BRANCH_NAME"
  git add -- "$SOURCE_DIR/snapshot_manifest.json" 2>/dev/null || true
  git commit -m "snapshot(${LAYER}): checkpoint validado ${TAG_NAME}" --allow-empty
  git tag -f "$TAG_NAME"
  git checkout "$CURRENT_BRANCH"
fi
echo "[OK] Snapshot '$TAG_NAME' registrado para a camada '$BRANCH_NAME'."
