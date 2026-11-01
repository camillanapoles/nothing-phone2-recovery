#!/usr/bin/env bash
# test_root_decision.sh — decisão A ratificada: UM motor (APatch), UM kernel (o da ROM)
# Nenhum outro método de root pode ser usado no projeto; e a metodologia de kernel é a mesma
# para todo módulo. Se qualquer um desses invariantes cair, esta suíte falha. (34 casos)
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
ck "decisão A" "A" "$(q 'd["decision"]')" "A"
ck "ratificada por quem decide" "user" "$(q 'd["decided_by"]')" "user"
ck "ratificada de fato" "True" "$(q 'str(d["ratified"])')" "True"
ck "data registrada" "2026-11-01" "$(q 'd["decided_at"]')" "2026-11-01"
ck "motor fixado" "apatch" "$(q 'd["engine"]')" "apatch"
ck "kernel fixado no pacote da ROM" "stock-rom" "$(q 'd["kernel_source"]')" "stock-rom"
ck "kernel de terceiro proibido" "False" "$(q 'str(d["custom_kernel_allowed"])')" "False"
ck "SUSFS fora do escopo" "False" "$(q 'str(d["susfs_allowed"])')" "False"
ck "fala em motor único" "True" "$(q 'str(d["exclusive_single_engine"])')" "True"
forb=$(q '",".join(sorted(d["forbidden_engines"]))')
ck "lista de motores proibidos completa" "kernelsu,magisk,sukisu" "$forb" "kernelsu,magisk,sukisu"

# ---------- 2. os artefatos do projeto obedecem à decisão ---------------------
n_allowed=$(python3 - "$ROOT/$SK/references/root-engines.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(sorted(e["id"] for e in d["engines"] if e.get("allowed"))))
PY
)
ck "só um motor permitido no catálogo" "apatch" "$n_allowed" "apatch"
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
print(",".join(sorted(c["id"] for c in d["candidates"] if c.get("origin") == "stock-rom")))
PY
)
ck "só o kernel da ROM é origem stock" "stock-evolutionx" "$orig" "stock-evolutionx"
sem_orig=$(python3 - "$ROOT/$SK/references/kernel-candidates.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(c["id"] for c in d["candidates"] if c.get("origin") not in ("stock-rom", "third-party")))
PY
)
ck "todo candidato declara a origem" "" "$sem_orig" ""

mgr=$(python3 - "$ROOT/config/managers.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(",".join(sorted(m["id"] for m in d["managers"] if m.get("selected"))))
PY
)
ck "config/managers.json espelha a decisão" "apatch" "$mgr" "apatch"

# isonomia de metodologia de kernel: quem é kernel-level prova pelo pacote da ROM
iso=$(python3 - "$ROOT/$SK/references/module-requirements.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ruins = [m["id"] for m in d["modules"]
         if m.get("kernel_level") and (m.get("kernel_evidence") != "rom_package"
                                       or m.get("kernel_gate") != "kernel_compat_check.sh")]
print(",".join(ruins))
PY
)
ck "todo módulo kernel-level usa a mesma prova" "" "$iso" ""

# ---------- 3. o gate recusa qualquer outro método ---------------------------
for eng in magisk kernelsu sukisu; do
  rc=$(python3 "$G" --root "$ROOT" --engine "$eng" >/dev/null 2>&1; echo $?)
  ck "gate recusa $eng (INCOMPATÍVEL)" "exit" "$rc" "1"
done
rc_ap=$(python3 "$G" --root "$ROOT" --engine apatch >/dev/null 2>&1; echo $?)
ck "gate libera APatch no kernel stock" "exit" "$rc_ap" "0"
motivo=$(python3 "$G" --root "$ROOT" --engine kernelsu --json |
  python3 -c 'import json,sys;d=json.load(sys.stdin);print(next((c["detail"] for c in d["checks"] if c["check"]=="decisao_motor"),""))')
case "$motivo" in *"motor único"*) ok "recusa cita motor único" "$motivo" ;; *) bad "recusa cita motor único" "$motivo" ;; esac
rc_tp=$(python3 "$G" --root "$ROOT" --engine apatch --candidate np2-kernel-lineageos-v3.0.5 >/dev/null 2>&1; echo $?)
ck "gate recusa kernel de terceiro" "exit" "$rc_tp" "1"
rc_st=$(python3 "$G" --root "$ROOT" --engine apatch --candidate stock-evolutionx >/dev/null 2>&1; echo $?)
ck "kernel stock segue PENDENTE (falta L4), não proibido" "exit" "$rc_st" "3"
rc_pre=$(python3 "$D" --root "$ROOT" --static --engine kernelsu >/dev/null 2>&1; echo $?)
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
{"schema":"evox-root-decision/1","decision":"fx","ratified":true,"decided_by":"fixture","decided_at":"2026-01-01","engine":"kernelsu","kernel_source":"third-party","custom_kernel_allowed":true,"susfs_allowed":false,"exclusive_single_engine":true,"forbidden_engines":[]}
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

# ---------- 4. a decisão está escrita nos documentos que valem ---------------
grep -q "Decisão A ratificada" "$ROOT/docs/skills/ARCHITECTURE-DECISION.md" &&
  ok "decisão registrada em ARCHITECTURE-DECISION.md" "sim" ||
  bad "decisão registrada em ARCHITECTURE-DECISION.md" "não encontrada"
grep -qi "um único motor" "$ROOT/AGENTS.md" &&
  ok "invariante de motor único em AGENTS.md" "sim" ||
  bad "invariante de motor único em AGENTS.md" "não encontrado"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
