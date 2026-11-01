#!/usr/bin/env bash
# =============================================================================
# SNAPSHOT-KEEPER v3.0 — [M14] Gestor de Snapshots Modulares por Branches e Tags
# =============================================================================
set -euo pipefail

LAYER="modules-wave1"
TAG_NAME="v11.11-w1-clean"
SOURCE_DIR="./work"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer) LAYER="$2"; shift 2 ;;
    --tag) TAG_NAME="$2"; shift 2 ;;
    --source) SOURCE_DIR="$2"; shift 2 ;;
    *) shift ;;
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
  git checkout -B "$BRANCH_NAME"
  git add "$SOURCE_DIR/snapshot_manifest.json" 2>/dev/null || true
  git commit -m "snapshot(${LAYER}): checkpoint validado ${TAG_NAME}" --allow-empty
  git tag -f "$TAG_NAME"
  git checkout "$CURRENT_BRANCH"
fi
echo "[OK] Snapshot '$TAG_NAME' registrado para a camada '$BRANCH_NAME'."
