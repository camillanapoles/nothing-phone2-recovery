#!/usr/bin/env bash
# test_install_graph_v2.sh — o grafo fundido so vale se REPROVAR pai ausente,
# conflito ativo, ciclo, ordem invertida e pin solto. Sem rede, sem aparelho.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-58s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-58s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }
has(){ case "$3" in *"$4"*) ok "$1" "$2";; *) bad "$1" "$2 (faltou '$4' em: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-700))";; esac; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G="$ROOT/docs/skills/install-graph-v2.json"

cat > "$T/validate.py" <<'PY'
import json, sys
path = sys.argv[1]
try:
    d = json.load(open(path, encoding="utf-8"))
except Exception as e:
    print(f"JSON_INVALIDO {e}"); sys.exit(1)
err = []
def bad(code, msg): err.append(f"{code}:{msg}")
if d.get("schema") != "evox-best-install-graph/2": bad("schema", d.get("schema"))
layers = d.get("layers") or []
ids = [l.get("id") for l in layers]
if len(ids) != len(set(ids)) or any(not i for i in ids): bad("unique_ids", "camada")
L = {l.get("id"): l for l in layers}
ACTIVE = {"required", "conditional", "optional"}
for l in layers:
    if l.get("status") not in ACTIVE | {"deferred_candidate"}:
        bad("status", f"{l.get('id')}={l.get('status')}")
conhecidos = set(ids) | {c.get("id") for c in d.get("candidates") or []} | {f.get("id") for f in d.get("forbidden") or []}
# pais existem, estao ativos e nao formam ciclo
for l in layers:
    for p in l.get("parents") or []:
        if p not in L: bad("parents_exist", f"{l.get('id')}->{p}")
        elif l.get("status") in ACTIVE and L[p].get("status") not in ACTIVE:
            bad("parents_active", f"{l.get('id')}->{p} inativo")
        if p == l.get("id"): bad("parents_dag", f"self {p}")
estado = {}
def visita(n, pilha):
    if estado.get(n) == 1: bad("parents_dag", "->".join(pilha + [n])); return
    if estado.get(n) == 2 or n not in L: return
    estado[n] = 1
    for m in L[n].get("parents") or []: visita(m, pilha + [n])
    estado[n] = 2
for n in list(L): visita(n, [])
# estagios e passos: pai nunca depois do filho
stages = d.get("stages") or []
sids = [s.get("id") for s in stages]
if sids != [f"S{i}" for i in range(len(sids))]: bad("stage_order", str(sids))
sidx = {s: i for i, s in enumerate(sids)}
step_pos, step_ids = {}, []
k = 0
for s in stages:
    for st in s.get("steps") or []:
        step_ids.append(st.get("id")); k += 1
        lid = st.get("layer")
        if lid not in L: bad("step_order", f"passo {st.get('id')} camada {lid}")
        if not str(st.get("pass") or "").strip(): bad("layer_contracts", f"passo {st.get('id')} sem PASS")
        if lid in L and sidx.get(s.get("id"), -1) < sidx.get(L[lid].get("stage"), 99): bad("stage_order", f"{lid} declara {L[lid].get('stage')} executa antes em {s.get('id')}")
        if lid not in step_pos: step_pos[lid] = k
if len(step_ids) != len(set(step_ids)): bad("unique_ids", "passo")
for l in layers:
    if l.get("status") in ACTIVE and l.get("id") not in step_pos: bad("step_order", f"{l.get('id')} sem passo")
    for p in l.get("parents") or []:
        if p in L and sidx.get(L[p].get("stage"), 99) > sidx.get(l.get("stage"), -1): bad("stage_order", f"{l.get('id')} antes do pai {p}")
        if p in step_pos and l.get("id") in step_pos and step_pos[p] > step_pos[l.get("id")]: bad("step_order", f"{l.get('id')} executa antes do pai {p}")
# conflitos simetricos e nenhum ativo x ativo
cmap = {l.get("id"): set(l.get("conflicts") or []) for l in layers}
for c in d.get("candidates") or []: cmap[c.get("id")] = set(c.get("conflicts") or [])
for a, alvos in list(cmap.items()):
    for b in alvos:
        if b not in conhecidos: bad("conflicts_symmetric", f"{a}->{b} desconhecido")
        if b in cmap and a not in cmap[b]: bad("conflicts_symmetric", f"{a}->{b} sem volta")
ativos = {l.get("id") for l in layers if l.get("status") in ACTIVE}
for a in ativos:
    for b in cmap.get(a, set()):
        if b in ativos: bad("no_active_conflict", f"{a}x{b}")
for f in d.get("forbidden") or []:
    if not f.get("why"): bad("forbidden_absent", f"{f.get('id')} sem why")
    if f.get("id") in ativos: bad("forbidden_absent", f.get("id"))
# dono unico por funcao
for kind in ("root_engine", "metamodule", "zygisk_provider", "keystore_engine"):
    n = [l.get("id") for l in layers if l.get("kind") == kind and l.get("status") in ACTIVE]
    if len(n) != 1: bad("single_owners", f"{kind}={n}")
# cobertura canonica + apps da proposta B
canon = set()
for l in layers:
    if l.get("status") in ACTIVE: canon.update(l.get("canonical_ids") or [])
need = {"M01","M02","M03","M04","M05","M06","M07","M08","M09","M10","M11","M12A","M12B","M13","M14","M15"}
if need - canon: bad("canonical_coverage", ",".join(sorted(need - canon)))
for u in ("gemini", "circletosearch", "morphe"):
    if u not in ativos: bad("user_apps_coverage", u)
# contrato minimo de cada camada ativa + pin ou gate aberto nomeando a camada
gates = " ".join(" ".join(g.get("blocks") or []) for g in d.get("open_gates") or [])
for l in layers:
    if l.get("status") not in ACTIVE: continue
    for campo in ("parent_requirements", "restrictions", "pass", "evidence"):
        if not l.get(campo): bad("layer_contracts", f"{l.get('id')}.{campo}")
    if not str(l.get("rollback") or "").strip(): bad("layer_contracts", f"{l.get('id')}.rollback")
    pin = l.get("pin") or {}
    val = str(pin.get("value") or "")
    if pin.get("state") == "pinned" and (not val or val.lower() in {"latest", "master", "main"}): bad("pin_or_open_gate", l.get("id"))
    if pin.get("state") == "pending" and l.get("id") not in gates: bad("pin_or_open_gate", f"{l.get('id')} pendente sem gate")
    if pin.get("state") not in {"pinned", "pending"}: bad("pin_or_open_gate", f"{l.get('id')} estado {pin.get('state')}")
# regras duras aprendidas na auditoria (pai nomeado, nao generico)
hard = {
    "susfs-userspace": {"ksu-next-builtin", "kernel-custom"},
    "hma-oss": {"zygisk-next"},
    "pifork": {"zygisk-next", "nikgapps-core"},
    "morphe": {"youtube-stock", "ksu-next-builtin"},
    "droidspaces": {"ksu-next-builtin", "kernel-custom"},
    "port-forward": {"network-per-app"},
    "meta-overlayfs": {"ksu-next-builtin", "kernel-custom"},
}
for lid, pais in hard.items():
    faltam = pais - set((L.get(lid) or {}).get("parents") or [])
    if faltam: bad("hard_parent_rules", f"{lid} sem {sorted(faltam)}")
if step_pos.get("droidspaces", 999) > step_pos.get("zygisk-next", -1): bad("hard_parent_rules", "M05 depois da ocultacao")
if "shamiko" not in {f.get("id") for f in d.get("forbidden") or []}: bad("hard_parent_rules", "shamiko nao vetado")
if err:
    print("\n".join(sorted(set(err)))); sys.exit(1)
print(f"OK layers={len(layers)} active={len(ativos)} stages={len(stages)} steps={len(step_ids)}")
PY

mut(){ # arquivo operacao
python3 - "$1" "$2" <<'PY'
import json, sys
p, op = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding="utf-8")); L = {l["id"]: l for l in d["layers"]}
if op == "drop_parent": L["hma-oss"]["parents"] = []
elif op == "cycle": L["rom-zip"]["parents"] = ["final-certification"]
elif op == "activate_conflict": L["duck-toolbox"]["status"] = "optional"
elif op == "pin_latest": L["zygisk-next"]["pin"] = {"state": "pinned", "value": "latest"}
elif op == "drop_m05": L["droidspaces"]["canonical_ids"] = []
elif op == "second_zygisk":
    d["layers"].append(dict(L["zygisk-next"], id="rezygisk", conflicts=["zygisk-next"]))
    L["zygisk-next"]["conflicts"] = list(set(L["zygisk-next"]["conflicts"] + ["rezygisk"]))
else: raise SystemExit(op)
json.dump(d, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
PY
}

out=$(python3 "$T/validate.py" "$G" 2>&1); rc=$?
ck "grafo real e estruturalmente integro" "exit" "$rc" "0"
has "validador conta camadas/etapas" "OK layers=" "$out" "OK layers="
ck "JSON parseia" "exit" "$(python3 -m json.tool "$G" >/dev/null 2>&1; echo $?)" "0"

espera_falha(){
  local op="$1" codigo="$2" rotulo="$3" m="$T/$1.json"
  cp "$G" "$m"; mut "$m" "$op"
  local o; o=$(python3 "$T/validate.py" "$m" 2>&1); local r=$?
  ck "$rotulo (exit)" "exit" "$r" "1"
  has "$rotulo (codigo)" "$codigo" "$o" "$codigo"
}
espera_falha drop_parent      "hard_parent_rules"   "remover pai do HMA reprova"
espera_falha cycle            "parents_dag"         "ciclo de pais reprova"
espera_falha activate_conflict "no_active_conflict" "Duck+PIFork ativos reprova"
espera_falha pin_latest       "pin_or_open_gate"    "pin 'latest' reprova"
espera_falha drop_m05         "canonical_coverage"  "sumir com o M05 reprova"
espera_falha second_zygisk    "single_owners"       "dois provedores Zygisk reprova"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
