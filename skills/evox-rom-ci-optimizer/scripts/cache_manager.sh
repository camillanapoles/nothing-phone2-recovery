#!/usr/bin/env bash
# =============================================================================
# cache_manager.sh — cache versionado das partes bem-sucedidas do pipeline
# -----------------------------------------------------------------------------
# Regra: fase verde deixa artefato endereçável por SHA-256. Pequeno (≤25 MB) vai
# para o repo; grande entra como referência externa (path + hash) para não inchar.
#
# Uso:
#   ./cache_manager.sh put    --phase extract --file ./workspace/rom_assets/boot.img [--state ./cache]
#   ./cache_manager.sh get    --phase extract --name boot.img --to /tmp/boot.img [--state ./cache]
#   ./cache_manager.sh list   --state ./cache [--json]
#   ./cache_manager.sh verify --state ./cache
#   ./cache_manager.sh prune  --state ./cache [--days 90]
#
# Exit: 0 = ok · 3 = cache miss / hash divergente / referência externa ausente · 2 = uso · 4 = entrada inválida
# =============================================================================
set -uo pipefail

case "${1:-}" in -h|--help)
  echo "uso: $(basename "$0") <comando> [opções] — comandos:"
  echo "  put|get|list|verify|prune  (ver cabeçalho)"
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0 ;;
esac

CMD="${1:-}"; shift || true
STATE="./cache"; PHASE=""; FILE=""; NAME=""; TO=""; PROVEN=""; MAXMB=25; JSON=0; DAYS=90
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) STATE="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --proven-by) PROVEN="$2"; shift 2 ;;
    --max-inline-mb) MAXMB="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$CMD" ]] || { echo "Uso: $0 {put|get|list|verify} --state DIR [...]" >&2; exit 2; }

exec python3 - "$CMD" "$STATE" "$PHASE" "$FILE" "$NAME" "$TO" "$PROVEN" "$MAXMB" "$JSON" "$DAYS" <<'PY'
import hashlib, json, os, shutil, sys, time

cmd, state, phase, src, name, dst, proven, maxmb, as_json, days = sys.argv[1:]
maxmb = int(maxmb); as_json = as_json == "1"; days = int(days)
man_p = os.path.join(state, "manifest.json")

def now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""): h.update(c)
    return h.hexdigest()
def load():
    if not os.path.isfile(man_p): return {"schema": "evox-cache/1", "entries": []}
    try: return json.load(open(man_p))
    except Exception as exc:
        print(f"[ERRO] manifesto inválido: {exc}", file=sys.stderr); sys.exit(4)
def save(d):
    os.makedirs(state, exist_ok=True)
    tmp = man_p + ".tmp"
    json.dump(d, open(tmp, "w"), indent=2, ensure_ascii=False)
    os.replace(tmp, man_p)
def emit(status, msg, code, extra=None):
    if as_json: print(json.dumps({"status": status, "message": msg, "exit_code": code,
                                 **(extra or {})}, indent=2, ensure_ascii=False))
    else: print(f"[cache] {msg}")
    sys.exit(code)

if cmd == "put":
    if not phase or not src: emit("usage", "put exige --phase e --file", 2)
    if not os.path.isfile(src): emit("invalid", f"arquivo inexistente: {src}", 4)
    name = name or os.path.basename(src)
    h, size = sha(src), os.path.getsize(src)
    d = load(); entries = d["entries"]
    old = next((e for e in entries if e["phase"] == phase and e["name"] == name), None)
    if old and old["sha256"] == h:
        emit("unchanged", f"{phase}/{name} já cacheado com o mesmo hash", 0, {"entry": old})
    external = size > maxmb * 1024 * 1024
    target = os.path.join(state, phase, name)
    if external:
        path = os.path.relpath(os.path.abspath(src), os.getcwd())
    else:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copy2(src, target); path = os.path.relpath(target, os.getcwd())
    entry = {"phase": phase, "name": name, "sha256": h, "size_bytes": size,
             "external": external, "path": path, "created_at": now(),
             "proven_by": proven or None}
    entries = [e for e in entries if not (e["phase"] == phase and e["name"] == name)] + [entry]
    d["entries"] = entries; save(d)
    where = "referência externa" if external else "copiado para o repo"
    emit("stored", f"{phase}/{name} ({size} B) → {where}", 0, {"entry": entry})

if cmd == "get":
    if not phase or not name or not dst: emit("usage", "get exige --phase, --name e --to", 2)
    d = load(); e = next((x for x in d["entries"] if x["phase"] == phase and x["name"] == name), None)
    if not e: emit("miss", f"{phase}/{name} não está no cache", 3)
    origin = e["path"] if e["external"] else os.path.join(state, phase, name)
    if not os.path.isfile(origin): emit("miss", f"origem do cache ausente: {origin}", 3)
    if sha(origin) != e["sha256"]: emit("corrupt", f"hash do cache divergiu para {phase}/{name}", 3)
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    shutil.copy2(origin, dst)
    emit("restored", f"{phase}/{name} restaurado em {dst}", 0, {"entry": e})

if cmd == "list":
    d = load(); entries = d["entries"]
    if as_json: emit("ok", f"{len(entries)} entradas", 0, {"entries": entries})
    print(f"[cache] {len(entries)} entradas em {state}")
    for e in entries:
        tag = "externo" if e["external"] else "inline "
        print(f"  {e['phase']:<10} {e['name']:<24} {tag} {e['sha256'][:12]}… {e['size_bytes']} B")

if cmd == "prune":
    d = load(); entries = d["entries"]; cutoff = time.time() - days * 86400
    keep, dropped = [], []
    for e in entries:
        try:
            ts = time.mktime(time.strptime(e["created_at"], "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
        except Exception:
            ts = 0
        if ts < cutoff:
            if not e["external"]:
                p = os.path.join(state, e["phase"], e["name"])
                if os.path.isfile(p): os.remove(p)
            dropped.append(f"{e['phase']}/{e['name']}")
        else:
            keep.append(e)
    d["entries"] = keep; save(d)
    emit("pruned", f"{len(dropped)} entrada(s) removida(s), {len(keep)} mantida(s)",
         0, {"dropped": dropped, "kept": len(keep)})

if cmd == "verify":
    d = load(); bad = []
    for e in d["entries"]:
        p = e["path"] if e["external"] else os.path.join(state, e["phase"], e["name"])
        if not os.path.isfile(p): bad.append(f"{e['phase']}/{e['name']}: arquivo ausente"); continue
        if sha(p) != e["sha256"]: bad.append(f"{e['phase']}/{e['name']}: hash divergente")
    if bad: emit("corrupt", "; ".join(bad), 3, {"problems": bad})
    emit("ok", f"{len(d['entries'])} entradas verificadas", 0)

emit("usage", f"comando desconhecido: {cmd}", 2)
PY
