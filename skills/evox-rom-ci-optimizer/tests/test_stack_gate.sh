#!/usr/bin/env bash
# stack_gate.py — o contrato do combo/sequência só vale se REPROVAR quando o dado quebra.
# 27 casos: 9 de sanidade/CLI, 16 de invariante (cada um isolado no seu próprio fixture) + 2 de PENDENTE.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
K="$ROOT/scripts/stack_gate.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
SKD="skills/evox-rom-ci-optimizer/references"
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
ck(){ if [ "$3" = "$2" ]; then ok "$1" "$2"; else bad "$1" "esperado '$2', obtido '${3:-}'"; fi; }

cat > "$T/mut.py" <<'PY'
import json, sys
p, op = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding="utf-8"))
L = {l["id"]: l for l in d["layers"]}

def step(i):
    for ph in d["phases"]:
        for st in ph["steps"]:
            if st["id"] == i:
                return st
    raise SystemExit("passo inexistente " + i)

if op == "dup_layer":
    d["layers"].append(dict(d["layers"][0]))
elif op == "bad_pin":
    d["layers"][0]["pin"] = "latest"
elif op == "missing_require":
    d["layers"][0]["requires"] = ["camada-fantasma"]
elif op == "cycle":
    L["firmware-pong"]["requires"] = ["evox-vanilla"]
elif op == "order_invert":
    L["firmware-pong"]["requires"] = ["gms-doze"]
elif op == "asym_conflict":
    L["evox-gapps"]["conflicts"] = ["nikgapps-core"]
elif op == "active_conflict":
    L["evox-gapps"]["status"] = "optional"
elif op == "forbidden_present":
    d["layers"].append({"id": "shamiko", "name": "x", "kind": "hide", "pin": "tag:x",
                        "requires": [], "conflicts": [], "verify": "x", "status": "not_installed"})
elif op == "step_no_pass":
    step("0.1")["pass"] = ""
elif op == "phase_gap":
    d["phases"][2]["id"] = "F9"
elif op == "kernel_pin":
    L["kernel-build-e03"]["pin"] = "commit:" + "0" * 40
elif op == "rom_pin":
    L["evox-vanilla"]["pin"] = "build:EvolutionX-16.0-20260101-Pong-9.9"
elif op == "no_flavor":
    del d["decisions"]["flavor"]
elif op == "bad_commit":
    d["decisions"]["screen_search"]["pin"] = "v0.5"
elif op == "phantom_config":
    L["kernel-build-e03"]["must_deliver"].append("CONFIG_INVENTADA")
elif op == "no_decided_by":
    del d["decisions"]["hiding"]["decided_by"]
else:
    raise SystemExit("op desconhecida " + op)
json.dump(d, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
PY

novo(){ local d="$1"; mkdir -p "$d/$SKD" "$d/kernel/fragments" "$d/scripts"
  cp "$ROOT/$SKD/install-stack.json" "$ROOT/$SKD/kernel-build-plan.json" \
     "$ROOT/$SKD/rom-artifacts.json" "$ROOT/$SKD/droidspaces-requirements.json" "$d/$SKD/"
  cp "$ROOT/kernel/fragments/evox_pong_pack.config" "$d/kernel/fragments/"
  cp "$K" "$d/scripts/"; printf '%s' "$d"; }

falha(){ local d="$1" op="$2" nome="$3"
  python3 "$T/mut.py" "$d/$SKD/install-stack.json" "$op" || return 1
  local js; js=$(python3 "$d/scripts/stack_gate.py" --root "$d" --json 2>/dev/null)
  local rc=$?
  printf '%s' "$js" | python3 -c '
import json,sys
nome=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: print("nao-json"); raise SystemExit(0)
m=[c for c in d.get("checks",[]) if c["check"]==nome]
print("fail" if m and m[0]["state"]=="fail" else "nao-falhou")
' "$nome"; return $rc; }

# ---------------------------------------------------------------- sanidade / CLI
out=$(python3 "$K" --root "$ROOT"); rc=$?
ck "workspace real: contrato íntegro (exit 0)" "0" "$rc"
ck "declara as 9 fases F0..F8" "9" "$(printf '%s' "$out" | sed -n 's/.*· \([0-9]\+\) fases ·.*/\1/p')"
ck "declara 21 camadas" "21" "$(printf '%s' "$out" | sed -n 's/.*· \([0-9]\+\) camadas ·.*/\1/p')"
ck "15/15 invariantes verdes" "15/15" "$(printf '%s' "$out" | sed -n 's/.*OK · \([0-9]\+\)\/\([0-9]\+\) invariantes.*/\1\/\2/p')"
ck "--json devolve veredito OK" "OK" "$(python3 "$K" --root "$ROOT" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["verdict"])')"
ck "--help sai 0" "0" "$(python3 "$K" --help >/dev/null 2>&1; echo $?)"
ck "raiz inexistente é entrada inválida" "4" "$(python3 "$K" --root "$T/nada" >/dev/null 2>&1; echo $?)"

# TODA camada e TODO passo têm prova declarada
ck "todo passo tem PASS (nenhum vazio)" "0" \
  "$(python3 - "$ROOT/$SKD/install-stack.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(1 for ph in d["phases"] for st in ph["steps"] if not str(st.get("pass","")).strip()))
PY
)"
ck "todo vetado tem justificativa" "0" \
  "$(python3 - "$ROOT/$SKD/install-stack.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(1 for f in d["forbidden"] if not f.get("why")))
PY
)"

# ---------------------------------------------------------------- invariantes (um por fixture)
falha_em(){ local op="$1" nome="$2" rotulo="$3"; local d; d=$(novo "$T/$op")
  ck "$rotulo" "fail" "$(falha "$d" "$op" "$nome")"; }

falha_em dup_layer       unique_ids          "id repetido reprova (unique_ids)"
falha_em bad_pin         pins_format         "pin 'latest' reprova (pins_format)"
falha_em missing_require requires_exist      "requires para camada inexistente reprova"
falha_em cycle           requires_dag        "ciclo em requires reprova (requires_dag)"
falha_em order_invert    phase_order         "dependência depois do dependente reprova"
falha_em asym_conflict   conflicts_symmetric "conflito não recíproco reprova"
falha_em active_conflict no_active_conflict  "duas camadas em conflito ativas reprovam"
falha_em forbidden_present forbidden_absent  "camada vetada presente reprova"
falha_em step_no_pass    steps_have_pass     "passo sem critério de PASS reprova"
falha_em phase_gap       phases_contiguous   "fase fora de sequência reprova"
falha_em kernel_pin      foreign_pin_kernel  "pin do kernel divergente do plano reprova"
falha_em rom_pin         foreign_pin_rom     "pin da ROM divergente do manifesto reprova"
falha_em no_flavor       decisions_complete  "decisão de flavor ausente reprova"
falha_em bad_commit      decisions_complete  "screen_search sem commit pinado reprova"
falha_em no_decided_by   decisions_complete  "decisão sem decided_by reprova"
falha_em phantom_config  contract_configs    "CONFIG_ prometida e não provada reprova"

# insumo canônico ausente = PENDENTE (3), não 'verde'
D=$(novo "$T/pendente"); rm -f "$D/$SKD/kernel-build-plan.json"
ck "plano do kernel ausente vira PENDENTE (exit 3)" "3" \
  "$(python3 "$D/scripts/stack_gate.py" --root "$D" >/dev/null 2>&1; echo $?)"
ck "e o veredito diz PENDENTE" "PENDENTE" \
  "$(python3 "$D/scripts/stack_gate.py" --root "$D" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("verdict"))')"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
