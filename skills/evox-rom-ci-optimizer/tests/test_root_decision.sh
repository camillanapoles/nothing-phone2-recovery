#!/usr/bin/env bash
# test_root_decision.sh — decisão A ratificada: UM motor (APatch), UM kernel (o da ROM)
# Nenhum outro método de root pode ser usado no projeto; e a metodologia de kernel é a mesma
# para todo módulo. Se qualquer um desses invariantes cair, esta suíte falha. (41 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../.." && pwd)"
SK="skills/evox-rom-ci-optimizer"; G="$HERE/../scripts/root_engine_gate.py"
D="$HERE/../scripts/droidspaces_preflight.py"
DEC="$ROOT/$SK/references/root-decision.json"
P=0; F=0
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok(){ printf 'PASS  %-56s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-56s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

q(){ python3 -c "import json,sys;d=json.load(open('$DEC'));print($1)"; }

# ---------- 1. o registro da decisão existe e está preenchido -----------------
ck "arquivo de decisão existe" "sim" "$([ -f "$DEC" ] && echo sim || echo nao)" "sim"
ck "schema correto" "evox-root-decision/1" "$(q 'd["schema"]')" "evox-root-decision/1"
ck "decisão C (supersede A)" "C" "$(q 'd["decision"]')" "C"
ck "supersede registrado" "A" "$(q 'd["supersedes"]')" "A"
ck "ratificada por quem decide" "user" "$(q 'd["decided_by"]')" "user"
ck "ratificada de fato" "True" "$(q 'str(d["ratified"])')" "True"
ck "data registrada" "2026-11-01" "$(q 'd["decided_at"]')" "2026-11-01"
ck "motor fixado" "kernelsu" "$(q 'd["engine"]')" "kernelsu"
ck "kernel compilado por nós" "custom-build" "$(q 'd["kernel_source"]')" "custom-build"
ck "kernel compilado permitido (exigido)" "True" "$(q 'str(d["custom_kernel_allowed"])')" "True"
ck "binário de terceiro continua proibido" "False" "$(q 'str(d["third_party_kernel_allowed"])')" "False"
ck "SUSFS permitido com fallback" "True" "$(q 'str(d["susfs_allowed"])')" "True"
ck "fala em motor único" "True" "$(q 'str(d["exclusive_single_engine"])')" "True"
forb=$(q '",".join(sorted(d["forbidden_engines"]))')
ck "lista de motores proibidos completa" "apatch,magisk,sukisu" "$forb" "apatch,magisk,sukisu"

# ---------- 2. os artefatos do projeto obedecem à decisão ---------------------
n_allowed=$(python3 - "$ROOT/$SK/references/root-engines.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(sorted(e["id"] for e in d["engines"] if e.get("allowed"))))
PY
)
ck "só um motor permitido no catálogo" "kernelsu" "$n_allowed" "kernelsu"
sem_motivo=$(python3 - "$ROOT/$SK/references/root-engines.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(e["id"] for e in d["engines"] if not e.get("allowed") and not e.get("blocked_by")))
PY
)
ck "todo motor proibido diz por quê" "" "$sem_motivo" ""

orig=$(python3 - "$ROOT/$SK/references/kernel-candidates.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(sorted(c["id"] for c in d["candidates"] if c.get("origin") == "custom-build")))
PY
)
ck "existe exatamente 1 candidato de build próprio" "custom-build-pong-ksu-susfs-droidspaces" "$orig" "custom-build-pong-ksu-susfs-droidspaces"
sem_orig=$(python3 - "$ROOT/$SK/references/kernel-candidates.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(c["id"] for c in d["candidates"] if c.get("origin") not in ("stock-rom", "third-party", "custom-build")))
PY
)
ck "todo candidato declara a origem" "" "$sem_orig" ""

mgr=$(python3 - "$ROOT/config/managers.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(sorted(m["id"] for m in d["managers"] if m.get("selected"))))
PY
)
ck "config/managers.json espelha a decisão" "kernelsu-next" "$mgr" "kernelsu-next"

# isonomia de metodologia de kernel: quem é kernel-level prova pelo pacote da ROM
iso=$(python3 - "$ROOT/$SK/references/module-requirements.json" "$ROOT/$SK/references/root-decision.json" <<'PY'
import json, sys
mods = json.load(open(sys.argv[1]))["modules"]
dec = json.load(open(sys.argv[2]))
src = dec.get("kernel_evidence_source")
ruins = [m["id"] for m in mods
         if m.get("kernel_level") and (m.get("kernel_evidence") != src
                                       or m.get("kernel_gate") != "kernel_compat_check.sh")]
print(",".join(ruins))
PY
)
ck "todo módulo kernel-level usa a mesma prova" "" "$iso" ""

# ---------- 3. o gate recusa qualquer outro método ---------------------------
for eng in apatch magisk sukisu; do
  rc=$(python3 "$G" --root "$ROOT" --engine "$eng" >/dev/null 2>&1; echo $?)
  ck "gate recusa $eng (INCOMPATÍVEL)" "exit" "$rc" "1"
done
rc_c=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces >/dev/null 2>&1; echo $?)
ck "par C existe e fica PENDENTE até certificar o kernel" "exit" "$rc_c" "3"
motivo=$(python3 "$G" --root "$ROOT" --engine apatch --json |
  python3 -c 'import json,sys;d=json.load(sys.stdin);print(next((c["detail"] for c in d["checks"] if c["check"]=="decisao_motor"),""))')
case "$motivo" in *"motor único"*) ok "recusa cita motor único" "$motivo" ;; *) bad "recusa cita motor único" "$motivo" ;; esac
rc_tp=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate np2-kernel-lineageos-v3.0.5 >/dev/null 2>&1; echo $?)
ck "gate recusa kernel de terceiro" "exit" "$rc_tp" "1"
rc_st=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate stock-evolutionx >/dev/null 2>&1; echo $?)
ck "kernel stock é recusado pela decisão C" "exit" "$rc_st" "1"
rc_pre=$(python3 "$D" --root "$ROOT" --static --engine apatch >/dev/null 2>&1; echo $?)
ck "preflight do M05 também recusa motor fora da decisão" "exit" "$rc_pre" "3"

# ---------- 3b. casos isolados: cada trava é provada sozinha -----------------
# (fixtures mínimas: só a condição testada pode ser a causa do exit 1)
FIX="$T/skills/evox-rom-ci-optimizer/references"; mkdir -p "$FIX"
cat > "$FIX/root-decision.json" <<'J'
{"schema":"evox-root-decision/1","decision":"A","ratified":true,"decided_by":"user","decided_at":"2026-11-01","engine":"apatch","kernel_source":"stock-rom","custom_kernel_allowed":false,"susfs_allowed":false,"exclusive_single_engine":true,"forbidden_engines":["magisk","kernelsu","sukisu"]}
J
cat > "$FIX/root-engines.json" <<'J'
{"schema":"evox-root-engines/1","engines":[
 {"id":"apatch","name":"APatch","mechanism":"kernel-space","requires_custom_kernel":false,"supports_susfs":false,"supports_zygisk":true,"status":"baseline_recommended","allowed":true},
 {"id":"magisk","name":"Magisk","mechanism":"userspace","requires_custom_kernel":false,"supports_susfs":false,"supports_zygisk":true,"status":"fallback","allowed":false},
 {"id":"kernelsu","name":"KernelSU","mechanism":"kernel-space","requires_custom_kernel":true,"supports_susfs":true,"supports_zygisk":true,"status":"second_wave","allowed":false}]}
J
cat > "$FIX/kernel-candidates.json" <<'J'
{"schema":"evox-kernel-candidates/1","candidates":[
 {"id":"bom","status":"certified","kernel_supports_susfs":true,"origin":"third-party"}]}
J
cat > "$FIX/module-requirements.json" <<'J'
{"schema":"evox-module-requirements/1","modules":[
 {"id":"M01","is_root_engine":true,"root_required":true}]}
J
rc_iso=$(python3 "$G" --root "$T" --engine magisk >/dev/null 2>&1; echo $?)
iso_why=$(python3 "$G" --root "$T" --engine magisk --json 2>/dev/null |
  python3 -c 'import json,sys;d=json.load(sys.stdin);print(",".join(c["check"] for c in d["checks"] if c["verdict"]=="incompativel"))')
ck "Magisk isolado: só a decisão reprova" "exit" "$rc_iso" "1"
ck "Magisk isolado: motivo é decisao_motor" "decisao_motor" "$iso_why" "decisao_motor"

python3 - "$FIX" <<'PY'
import json, sys
p = sys.argv[1] + "/root-engines.json"; d = json.load(open(p))
d["engines"][2]["allowed"] = True
json.dump(d, open(p, "w"))
PY
rc_iso2=$(python3 "$G" --root "$T" --engine apatch >/dev/null 2>&1; echo $?)
iso2_why=$(python3 "$G" --root "$T" --engine apatch --json 2>/dev/null |
  python3 -c 'import json,sys;d=json.load(sys.stdin);print(",".join(c["check"] for c in d["checks"] if c["verdict"]=="incompativel"))')
ck "dois motores permitidos: reprova" "exit" "$rc_iso2" "1"
ck "dois motores permitidos: motivo é motor_unico" "motor_unico" "$iso2_why" "motor_unico"

# política de fixture com SUSFS proibido e motor permitido: só decisao_susfs pode reprovar
cat > "$FIX/root-engines.json" <<'J'
{"schema":"evox-root-engines/1","engines":[
 {"id":"apatch","name":"APatch","mechanism":"kernel-space","requires_custom_kernel":false,"supports_susfs":false,"supports_zygisk":true,"status":"baseline_recommended","allowed":false},
 {"id":"kernelsu","name":"KernelSU","mechanism":"kernel-space","requires_custom_kernel":true,"supports_susfs":true,"supports_zygisk":true,"status":"second_wave","allowed":true}]}
J
cat > "$FIX/root-decision.json" <<'J'
{"schema":"evox-root-decision/1","decision":"fx","ratified":true,"decided_by":"fixture","decided_at":"2026-01-01","engine":"kernelsu","kernel_source":"custom-build","custom_kernel_allowed":true,"third_party_kernel_allowed":true,"susfs_allowed":false,"exclusive_single_engine":true,"forbidden_engines":[]}
J
cat > "$FIX/module-requirements.json" <<'J'
{"schema":"evox-module-requirements/1","modules":[
 {"id":"MS","root_required":true,"requires_susfs":true}]}
J
rc_iso3=$(python3 "$G" --root "$T" --engine kernelsu --candidate bom >/dev/null 2>&1; echo $?)
iso3_why=$(python3 "$G" --root "$T" --engine kernelsu --candidate bom --json 2>/dev/null |
  python3 -c 'import json,sys;d=json.load(sys.stdin);print(",".join(c["check"] for c in d["checks"] if c["verdict"]=="incompativel"))')
ck "SUSFS proibido reprova mesmo com motor/permissões ok" "exit" "$rc_iso3" "1"
ck "SUSFS proibido: motivo é decisao_susfs" "decisao_susfs" "$iso3_why" "decisao_susfs"

# ---------- 3c. a camada de conformidade está mapeada no contrato -----------
stack=$(python3 - "$ROOT/$SK/references/module-requirements.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
m07 = next(m for m in d["modules"] if m["id"] == "M07")
m08 = next(m for m in d["modules"] if m["id"] == "M08")
print("|".join([m08.get("zygisk_base", "-"), ",".join(m07.get("compliance_base") or []),
               ",".join(m08.get("compliance_base") or [])]))
PY
)
ck "M08 declara base Zygisk Next" "sim" "$(case "$stack" in "Zygisk Next|"*) echo sim;; *) echo nao;; esac)" "sim"
ck "M07 cobre PIFork" "sim" "$(case "$stack" in *"PlayIntegrityFork"*) echo sim;; *) echo nao;; esac)" "sim"
ck "M08 cobre Tricky Store" "sim" "$(case "$stack" in *"Tricky Store"*) echo sim;; *) echo nao;; esac)" "sim"
ocult=$(python3 - "$ROOT/$SK/references/module-requirements.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
m08 = next(m for m in d["modules"] if m["id"] == "M08")
h = m08.get("hiding_base") or {}
print(h.get("status", "-") + "|" + ("sim" if "Zygisk Assistant" in h.get("stack", "") else "nao"))
PY
)
ck "M08 declara pilha de ocultação com Zygisk Assistant" "source_approved_pending_device|sim" "$ocult" "source_approved_pending_device|sim"

# ---------- 3b. build próprio só passa quando a decisão manda build próprio ----
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/skills/evox-rom-ci-optimizer/references" "$FX/skills/evox-rom-ci-optimizer/scripts"
cp "$ROOT/$SK/references"/{root-decision,root-engines,kernel-candidates,module-requirements,hiding-stack}.json \
   "$FX/skills/evox-rom-ci-optimizer/references/"
python3 - "$FX/skills/evox-rom-ci-optimizer/references/root-decision.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d.update({"engine": "kernelsu", "kernel_source": "third-party",
          "third_party_kernel_allowed": True, "custom_kernel_allowed": False})
json.dump(d, open(p, "w"))
PY
rc_fx=$(python3 "$G" --root "$FX" --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces >/dev/null 2>&1; echo $?)
ck "build próprio é recusado se a decisão não o exige" "exit" "$rc_fx" "1"

# ---------- 4. a decisão está escrita nos documentos que valem ---------------
grep -q "Decisão C ratificada" "$ROOT/docs/skills/ARCHITECTURE-DECISION.md" &&
  ok "decisão registrada em ARCHITECTURE-DECISION.md" "sim" ||
  bad "decisão registrada em ARCHITECTURE-DECISION.md" "não encontrada"
grep -qi "um único motor" "$ROOT/AGENTS.md" &&
  ok "invariante de motor único em AGENTS.md" "sim" ||
  bad "invariante de motor único em AGENTS.md" "não encontrado"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
