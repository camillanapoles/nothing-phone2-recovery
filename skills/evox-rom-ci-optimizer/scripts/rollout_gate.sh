#!/usr/bin/env bash
# =============================================================================
# rollout_gate.sh — canário: 1 módulo por vez, com evidência antes do próximo
# -----------------------------------------------------------------------------
# Uso:
#   ./rollout_gate.sh start  --state ./workspace/rollout.json --wave W1 --module M01 \
#                            [--artifact ./out/boot_patched.img] [--sha256 <hex>]
#   ./rollout_gate.sh record --state ./workspace/rollout.json --module M01 \
#                            --evidence ./evidence/evidence.json [--min-uptime 10] [--fail "motivo"]
#   ./rollout_gate.sh status --state ./workspace/rollout.json [--json]
#   ./rollout_gate.sh reset  --state ./workspace/rollout.json --module M01
#
# Regras: nunca 2 módulos abertos; módulo só abre se o anterior PASS; onda não regride.
# Exit: 0 = liberado/ok · 3 = bloqueado (pendência) · 2 = uso · 4 = evidência/entrada inválida
# =============================================================================
set -uo pipefail

CMD="${1:-}"; shift || true
STATE="./workspace/rollout.json"; WAVE=""; MODULE=""; ARTIFACT=""; SHA=""; EVID=""
MIN_UP=10; FAILMSG=""; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) STATE="$2"; shift 2 ;;
    --wave) WAVE="$2"; shift 2 ;;
    --module) MODULE="$2"; shift 2 ;;
    --artifact) ARTIFACT="$2"; shift 2 ;;
    --sha256) SHA="$2"; shift 2 ;;
    --evidence) EVID="$2"; shift 2 ;;
    --min-uptime) MIN_UP="$2"; shift 2 ;;
    --fail) FAILMSG="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo "arg desconhecido: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$CMD" ]] || { echo "Uso: $0 {start|record|status|reset} --state FILE [...]" >&2; exit 2; }

exec python3 - "$CMD" "$STATE" "$WAVE" "$MODULE" "$ARTIFACT" "$SHA" "$EVID" "$MIN_UP" "$FAILMSG" "$JSON" <<'PY'
import hashlib, json, os, sys, time

cmd, state_p, wave, module, artifact, sha, evid_p, min_up, failmsg, as_json = sys.argv[1:]
min_up = int(min_up); as_json = as_json == "1"

def now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def load():
    if not os.path.isfile(state_p):
        return {"schema": "evox-rollout/1", "modules": []}
    try:
        return json.load(open(state_p))
    except Exception as exc:
        print(f"[ERRO] ledger inválido: {exc}", file=sys.stderr); sys.exit(4)

def save(d):
    os.makedirs(os.path.dirname(os.path.abspath(state_p)), exist_ok=True)
    tmp = state_p + ".tmp"
    json.dump(d, open(tmp, "w"), indent=2, ensure_ascii=False)
    os.replace(tmp, state_p)

def emit(status, msg, code, extra=None):
    if as_json:
        print(json.dumps({"status": status, "message": msg, "exit_code": code,
                          **(extra or {})}, indent=2, ensure_ascii=False))
    else:
        print(f"[rollout] {msg}")
    sys.exit(code)

d = load(); mods = d["modules"]

if cmd == "start":
    if not wave or not module:
        emit("usage", "start exige --wave e --module", 2)
    opened = [m for m in mods if m["state"] == "open"]
    if opened:
        emit("blocked", f"já existe módulo aberto ({opened[0]['module']}): "
                        "feche com record --evidence antes do próximo", 3,
             {"open": opened[0]["module"]})
    failed = [m for m in mods if m["state"] == "failed"]
    if failed:
        emit("blocked", f"{failed[0]['module']} está FAILED ({failed[0].get('reason')}): "
                        "corrija, use reset e feche o teste antes de abrir o próximo", 3,
             {"failed": failed[0]["module"]})
    if any(m["module"] == module for m in mods):
        emit("blocked", f"{module} já registrado no ledger (use reset para reabrir)", 3)
    passed_waves = [m["wave"] for m in mods if m["state"] == "passed"]
    if passed_waves and wave < max(passed_waves):
        emit("blocked", f"onda {wave} regride em relação a {max(passed_waves)} (R09)", 3)
    if not os.path.isfile(artifact):
        emit("invalid", f"artefato do módulo não existe: {artifact}", 4)
    real = hashlib.sha256(open(artifact, "rb").read()).hexdigest()
    if sha and sha.lower() != real:
        emit("invalid", f"sha256 do artefato não confere (ledger {sha[:12]}… ≠ real {real[:12]}…)", 4)
    mods.append({"wave": wave, "module": module, "artifact": artifact,
                 "sha256": real, "state": "open", "started_at": now()})
    save(d)
    emit("open", f"{module} ({wave}) aberto — instale SÓ ele, reinicie e colete evidência", 0,
         {"module": module, "sha256": real})

if cmd == "record":
    if not module:
        emit("usage", "record exige --module", 2)
    entry = next((m for m in mods if m["module"] == module and m["state"] == "open"), None)
    if entry is None:
        emit("blocked", f"{module} não está aberto no ledger", 3)
    if failmsg:
        entry.update(state="failed", reason=failmsg, recorded_at=now()); save(d)
        emit("failed", f"{module} marcado FAILED — rollback e correção antes de novo start", 3)
    if not os.path.isfile(evid_p):
        emit("invalid", f"evidência não encontrada: {evid_p}", 4)
    try:
        ev = json.load(open(evid_p))
    except Exception as exc:
        emit("invalid", f"evidência não é JSON: {exc}", 4)
    boot = ev.get("boot") or {}
    stab = ev.get("stability") or {}
    crashes = ev.get("crashes")
    crashes_n = crashes if isinstance(crashes, int) else len(crashes or [])
    uptime = float(stab.get("uptime_min") or ev.get("uptime_min") or 0)
    facts = {"boot_ok": boot.get("ok") is True, "crashes": crashes_n,
             "uptime_min": uptime, "avc_denials": ev.get("avc_denials")}
    reasons = []
    if not facts["boot_ok"]: reasons.append("boot.ok != true")
    if crashes_n != 0: reasons.append(f"crashes={crashes_n}")
    if uptime < min_up: reasons.append(f"uptime {uptime} < {min_up} min")
    if reasons:
        entry.update(state="failed", reason="; ".join(reasons), evidence=facts, recorded_at=now())
        save(d); emit("failed", f"{module} FAILED — " + "; ".join(reasons), 3, facts)
    entry.update(state="passed", evidence=facts, recorded_at=now()); save(d)
    emit("passed", f"{module} PASS — próximo módulo liberado (uma única vez)", 0, facts)

if cmd == "status":
    passed = [m["module"] for m in mods if m["state"] == "passed"]
    open_ = [m["module"] for m in mods if m["state"] == "open"]
    failed = [m["module"] for m in mods if m["state"] == "failed"]
    emit("status", f"{len(passed)} passed · {len(open_)} open · {len(failed)} failed", 0,
         {"passed": passed, "open": open_, "failed": failed, "modules": mods})

if cmd == "reset":
    if not module:
        emit("usage", "reset exige --module", 2)
    entry = next((m for m in mods if m["module"] == module), None)
    if entry is None:
        emit("invalid", f"{module} não existe no ledger", 4)
    entry.update(state="open", reason=None, evidence=None, started_at=now()); save(d)
    emit("reset", f"{module} reaberto (novo teste obrigatório)", 0)

emit("usage", f"comando desconhecido: {cmd}", 2)
PY
