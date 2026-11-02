#!/usr/bin/env bash
# kernel_build_gate.py — o plano do kernel é completo e cada item do plano é falseável.
# 20 regras de plano + 7 de pré-build; cada uma tem um contra-exemplo aqui. (30 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K="$HERE/../scripts/kernel_build_gate.py"
ROOT="$(cd "$HERE/../../.." && pwd)"; REF="$ROOT/skills/evox-rom-ci-optimizer/references"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
ck(){ [ "$2" = "$3" ] && ok "$1" "$3" || bad "$1" "${3:-vazio} (esperado '$2', obtido '${3:-}')"; }
j(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
# raiz de fixture com plano + contratos
novo_root(){ local d="$1"; mkdir -p "$d/skills/evox-rom-ci-optimizer/references" "$d/kernel" "$d/scripts"
  cp "$REF"/{kernel-build-plan,droidspaces-requirements,module-requirements}.json \
     "$d/skills/evox-rom-ci-optimizer/references/"
  cp -a "$ROOT/kernel/patches" "$ROOT/kernel/fragments" "$d/kernel/"
  cp "$ROOT/scripts/kernel-fragment.py" "$d/scripts/"
  echo "$d/skills/evox-rom-ci-optimizer/references"; }
falhas(){ python3 "$K" --root "$1" --json | j | true; }

# 1. o plano real passa inteiro ------------------------------------------------------
rc=$(python3 "$K" --root "$ROOT" >/dev/null 2>&1; echo $?)
ck "plano real fecha (exit 0)" "0" "$rc"
out=$(python3 "$K" --root "$ROOT" --json)
ck "20 itens de plano avaliados" "20" "$(printf '%s' "$out" | j 'len(d["checks"])')"
ck "todos ok" "20" "$(printf '%s' "$out" | j 'len([c for c in d["checks"] if c["state"]=="ok"])')"
ck "schema do gate" "evox-kernel-build-gate/1" "$(printf '%s' "$out" | j 'd["schema"]')"
ck "--help sai 0" "0" "$(python3 "$K" --help >/dev/null 2>&1; echo $?)"
ck "prebuild sem insumos = PENDENTE (3)" "3" "$(python3 "$K" --root "$ROOT" --prebuild >/dev/null 2>&1; echo $?)"
ck "prebuild nomeia as lacunas restantes" "3" \
   "$(python3 "$K" --root "$ROOT" --prebuild --json | j 'len([c for c in d["checks"] if c["state"]=="pendente"])')"

# 2. cada regra de plano é load-bearing (um contra-exemplo por regra) ---------------
teste_quebra(){ # nome, arquivo-json, expressão python que muta o plano, check esperado
  local nome="$1" expr="$2" esperado="$3" d="$T/q$((P+F+1))" r
  r=$(novo_root "$d")
  python3 - "$r/kernel-build-plan.json" "$expr" <<'PY'
import json, sys
p, expr = sys.argv[1], sys.argv[2]
d = json.load(open(p))
exec(expr)
json.dump(d, open(p, "w"))
PY
  local falhou; falhou=$(python3 "$K" --root "$d" --json | j '",".join(sorted(c["check"] for c in d["checks"] if c["state"]!="ok"))')
  ck "$nome" "sim" "$(case ",$falhou," in *",$esperado,"*) echo sim;; *) echo nao;; esac)"
}
teste_quebra "P01: alvo sem KMI reprova"            'd["target"].pop("kmi")' "P01_alvo"
teste_quebra "P02: fonte sem licença reprova"       'd["source"].pop("license_check")' "P02_fonte"
teste_quebra "P03: toolchain sem imagem reprova"    'd["toolchain"].pop("image")' "P03_toolchain"
teste_quebra "P04: build sem fragmento do pack"     'd["build"]["pack_fragment"]="nao/esta/na/lista.config"' "P04_build"
teste_quebra "P05: patch sem politica reprova"      'd["build"]["patch_set"][0].pop("on_reject")' "P05_patches"
teste_quebra "P06: config do contrato ausente"      'd["configs"]["contract"].remove("CONFIG_SYSVIPC")' "P06_configs_contrato"
teste_quebra "P07: config de módulo sem origem"     'd["configs"]["module_specific"][0].pop("confirm_in")' "P07_configs_modulo"
teste_quebra "P08: menos de 10 funcionais"          'd["requirements"]["functional"]=d["requirements"]["functional"][:3]' "P08_requisitos_funcionais"
teste_quebra "P09: menos de 10 não-funcionais"      'd["requirements"]["non_functional"]=d["requirements"]["non_functional"][:2]' "P09_requisitos_nao_funcionais"
teste_quebra "P10: requisito sem falsificação"      'd["requirements"]["functional"][0].pop("falsified_by")' "P10_requisito_falseavel"
teste_quebra "P11: id duplicado"                    'd["requirements"]["functional"][1]["id"]=d["requirements"]["functional"][0]["id"]' "P11_ids_unicos"
teste_quebra "P12: placeholder no plano"            'd["requirements"]["functional"][0]["statement"]="TODO definir"' "P12_sem_placeholder"
teste_quebra "P13: ação sem SHA declarado"          'd["actions"][0].pop("sha")' "P13_acoes_declaradas"
teste_quebra "P14: versão de ação fora do padrão"   'd["actions"][0]["version"]="main"' "P14_acoes_versoes"
teste_quebra "P15: nenhuma alternativa avaliada"    'd["actions_avoided"]=[]' "P15_acoes_evitadas"
teste_quebra "P16: artefato essencial ausente"      'd["artifacts"]=[a for a in d["artifacts"] if a["name"]!="boot.img"]' "P16_artefatos"
teste_quebra "P17: artefato sem prova de hash"       'd["artifacts"][0]["sha256_required"]=False' "P17_artefatos_hash"
teste_quebra "P18: deploy sem guard4_verify"        'd["deploy"]["steps"]=["flashar"]' "P18_deploy"
teste_quebra "P19: módulo sem critério"             'd["validation"]=[v for v in d["validation"] if v["module"]!="M10"]' "P19_cobertura_de_modulos"
teste_quebra "P19: critério de módulo não falseável" 'd["validation"][0].pop("falsified_by")' "P19_cobertura_de_modulos"
teste_quebra "P20: risco sem mitigação"             'd["risks"][0].pop("mitigation")' "P20_riscos"

# 3. paridade com o pack: o contrato do DroidSpaces manda ---------------------------
D="$T/paridade"; R=$(novo_root "$D")
python3 - "$R/droidspaces-requirements.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["kernel"]["configs_required"].append("CONFIG_FOO_NAO_PLANEJADO")
json.dump(d, open(p, "w"))
PY
ck "config nova no contrato quebra o plano (paridade)" "sim" \
   "$(python3 "$K" --root "$D" --json | j '"sim" if any(c["check"]=="P06_configs_contrato" and c["state"]=="falha" for c in d["checks"]) else "nao"')"

# 3a. pin do source: só 40 hex fecha B01 ---------------------------------------------------
PD="$T/pinsem"; RPD=$(novo_root "$PD"); PR="$(cd "$RPD/../../.." && pwd)"
python3 - "$PR/skills/evox-rom-ci-optimizer/references/kernel-build-plan.json" <<'PY2'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
d["source"]["pin"] = "a-fixar-no-primeiro-build"
json.dump(d, open(p, "w", encoding="utf-8"))
PY2
ck "pin fora do padrão de 40 hex deixa B01 PENDENTE" "pendente" \
   "$(python3 "$K" --root "$PR" --prebuild --json | j 'next(c["state"] for c in d["checks"] if c["check"]=="B01_fonte_pinada")')" "pendente"

# 3b. material da árvore (B08): patches pinados + fragmento gerado do contrato --------------
ck "B08 ok com material íntegro" "ok" \
   "$(python3 "$K" --root "$ROOT" --prebuild --json | j 'next(c["state"] for c in d["checks"] if c["check"]=="B08_material_da_arvore")')" "ok"
MD="$T/material"; RM=$(novo_root "$MD"); MR="$(cd "$RM/../../.." && pwd)"
printf '\n# adulterado\n' >> "$MR/kernel/patches/002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch"
ck "patch adulterado deixa B08 PENDENTE" "pendente" \
   "$(python3 "$K" --root "$MR" --prebuild --json | j 'next(c["state"] for c in d["checks"] if c["check"]=="B08_material_da_arvore")')" "pendente"
FD="$T/fragmento"; RF=$(novo_root "$FD"); FR="$(cd "$RF/../../.." && pwd)"
printf 'CONFIG_EXTRA=y\n' >> "$FR/kernel/fragments/evox_pong_pack.config"
T2="$T/material2"; RT2=$(novo_root "$T2"); TR2="$(cd "$RT2/../../.." && pwd)"
python3 - "$TR2" <<'PY2'
import hashlib, json, os, sys
root = sys.argv[1]
patch = os.path.join(root, "kernel/patches/002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch")
open(patch, "a").write("\n# trocado junto com o plano\n")
novo = hashlib.sha256(open(patch, "rb").read()).hexdigest()
plano = os.path.join(root, "skills/evox-rom-ci-optimizer/references/kernel-build-plan.json")
d = json.load(open(plano, encoding="utf-8"))
for p in d["build"]["patch_set"]:
    if p.get("id") == "002-mqueue-padding":
        p["sha256"] = novo
json.dump(d, open(plano, "w", encoding="utf-8"))
PY2
ck "patch trocado junto com o plano ainda é pego pelo manifesto" "pendente" \
   "$(python3 "$K" --root "$TR2" --prebuild --json | j 'next(c["state"] for c in d["checks"] if c["check"]=="B08_material_da_arvore")')" "pendente"

ck "fragmento divergente do contrato deixa B08 PENDENTE" "pendente" \
   "$(python3 "$K" --root "$FR" --prebuild --json | j 'next(c["state"] for c in d["checks"] if c["check"]=="B08_material_da_arvore")')" "pendente"
ND="$T/semmanifesto"; RN=$(novo_root "$ND"); NR="$(cd "$RN/../../.." && pwd)"
rm -f "$NR/kernel/patches/SHA256SUMS"
ck "sem SHA256SUMS deixa B08 PENDENTE" "pendente" \
   "$(python3 "$K" --root "$NR" --prebuild --json | j 'next(c["state"] for c in d["checks"] if c["check"]=="B08_material_da_arvore")')" "pendente"

# 4. vacuidade e entrada inválida ---------------------------------------------------
V="$T/vazio"; RV=$(novo_root "$V")
python3 - "$RV/kernel-build-plan.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d.pop("requirements")
json.dump(d, open(p, "w"))
PY
ck "plano sem requisitos é recusado (exit 4)" "4" "$(python3 "$K" --root "$V" >/dev/null 2>&1; echo $?)"
mkdir -p "$T/nada"
ck "raiz sem plano é recusada (exit 4)" "4" "$(python3 "$K" --root "$T/nada" >/dev/null 2>&1; echo $?)"

# 5. prebuild com insumos materializados fica PRONTO -------------------------------
B="$T/prebuild"; RB=$(novo_root "$B")
TREE="$T/tree"; mkdir -p "$TREE/arch/arm64/configs" "$TREE/patches"
for p in 001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch \
         002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch; do
  : > "$TREE/patches/$p"
done
: > "$TREE/arch/arm64/configs/evox_pong_pack.config"
BD="$T/build"; mkdir -p "$BD"
for a in Image boot.img dtbo.img evox_pong_pack.config kernel-config.json "AnyKernel3 zip" SHA256SUMS; do : > "$BD/$a"; done
python3 - "$RB/kernel-build-plan.json" "$TREE" <<'PY'
import json, sys
p, tree = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["source"]["pin"] = "a" * 40
for patch in d["build"]["patch_set"]:
    if patch.get("file"):
        patch["file"] = patch["file"].split("/")[-1]
json.dump(d, open(p, "w"))
PY
python3 - "$R/droidspaces-requirements.json" "$T/cfg.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
cfgs = sorted(set(d["kernel"]["configs_required"] + d["isolation"]["required_configs"]))
json.dump({"kmi": "android13-5.10", "configs": {c: "y" for c in cfgs}}, open(sys.argv[2], "w"))
PY
rc=$(python3 "$K" --root "$B" --prebuild --kernel-tree "$TREE" --config-json "$T/cfg.json" --build-dir "$BD" >/dev/null 2>&1; echo $?)
ck "prebuild com tudo materializado = PRONTO (0)" "0" "$rc"
python3 - "$T/cfg.json" "$T/cfg2.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["configs"].pop("CONFIG_SYSVIPC", None)
json.dump(d, open(sys.argv[2], "w"))
PY
rc=$(python3 "$K" --root "$B" --prebuild --kernel-tree "$TREE" --config-json "$T/cfg2.json" --build-dir "$BD" >/dev/null 2>&1; echo $?)
ck "sem SYSVIPC o prebuild volta a PENDENTE (3)" "3" "$rc"
ck "e nomeia a config que falta" "sim" \
   "$(python3 "$K" --root "$B" --prebuild --kernel-tree "$TREE" --config-json "$T/cfg2.json" --build-dir "$BD" --json | j '"sim" if "CONFIG_SYSVIPC" in next(c["detail"] for c in d["checks"] if c["check"]=="B05_configs_provadas") else "nao"')"

# 6. determinismo ------------------------------------------------------------------
python3 "$K" --root "$ROOT" --json > "$T/a.json"; python3 "$K" --root "$ROOT" --json > "$T/b.json"
cmp -s "$T/a.json" "$T/b.json" && ok "duas execuções idênticas" "sim" || bad "duas execuções idênticas" "divergiu"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
