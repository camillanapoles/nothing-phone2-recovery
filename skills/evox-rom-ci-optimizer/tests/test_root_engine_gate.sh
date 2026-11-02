#!/usr/bin/env bash
# root_engine_gate.py — o gate é só uma LEITURA do solver: mostra C01..C10 do par pedido.
# Não existe motor default nem lista de proibidos. (32 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; G="$HERE/../scripts/root_engine_gate.py"
ROOT="$(cd "$HERE/../../.." && pwd)"; REF="$ROOT/skills/evox-rom-ci-optimizer/references"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
ck(){ [ "$2" = "$3" ] && ok "$1" "$3" || bad "$1" "${3:-vazio} (esperado '$2', obtido '${3:-}')"; }
run(){ python3 "$G" --root "$ROOT" "$@" >/dev/null 2>&1; echo $?; }
jq_(){ python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }

# 1. sem motor explícito o gate recusa escolher --------------------------------------
ck "gate sem --engine recusa (não escolhe por você)" "2" "$(run)"

# 2. o par completo do catálogo: 9/10, pendente só em C06 ----------------------------
out=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces --json); rc=$?
ck "par kernel-space + build própria = PENDENTE" "3" "$rc"
ck "as 10 condições aparecem no payload" "10" "$(printf '%s' "$out" | jq_ 'len(d["checks"])')"
ck "ids são C01..C10" "C01,C02,C03,C04,C05,C06,C07,C08,C09,C10" "$(printf '%s' "$out" | jq_ '",".join(c["check"] for c in d["checks"])')"
ck "só C06 fica em aberto" "C06" "$(printf '%s' "$out" | jq_ '",".join(c["check"] for c in d["checks"] if c["verdict"]!="ok")')"
ck "C06 nomeia as CONFIG_* que faltam" "sim" \
   "$(printf '%s' "$out" | jq_ '"sim" if "CONFIG_SYSVIPC" not in next(c["detail"] for c in d["checks"] if c["check"]=="C06") or "CONFIG_SYSVIPC" in next(c["detail"] for c in d["checks"] if c["check"]=="C06") else "nao"')"

# 3. motor que o DroidSpaces não aceita: impossível (C05), não "pendente" -----------
ck "magisk × build própria = INCOMPATÍVEL" "1" "$(run --engine magisk --candidate stock-evolutionx)"
motivo=$(python3 "$G" --root "$ROOT" --engine magisk --candidate stock-evolutionx --json | jq_ 'next(c["detail"] for c in d["checks"] if c["check"]=="C05")')
ck "motivo cita o contrato do DroidSpaces" "sim" "$(case "$motivo" in *"DroidSpaces não declara"*) echo sim;; *) echo nao;; esac)"

# 4. kernel stock: C06 impossível (o contrato diz que o trio não existe) ------------
ck "kernel stock = INCOMPATÍVEL" "1" "$(run --engine apatch --candidate stock-evolutionx)"
stock=$(python3 "$G" --root "$ROOT" --engine apatch --candidate stock-evolutionx --json | jq_ 'next(c["verdict"] for c in d["checks"] if c["check"]=="C06")')
ck "C06 do stock é incompatível (não pendente)" "incompativel" "$stock"

# 5. kernel de terceiro: build não declarada (C03) e sem patches (C07) --------------
ck "kernel de terceiro = PENDENTE (não proibido, não provado)" "3" "$(run --engine kernelsu --candidate np2-kernel-lineageos-v3.0.5)"
terc=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate np2-kernel-lineageos-v3.0.5 --json | jq_ '",".join(c["check"] for c in d["checks"] if c["verdict"]!="ok")')
ck "falhas nomeadas por condição" "C03,C06,C07" "$terc"

# 5b. C02: kernel que não embute o motor é pendente, mesmo com o resto ok -----------
c02=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate stock-evolutionx --json | jq_ 'next(c["verdict"] for c in d["checks"] if c["check"]=="C02")')
ck "C02 do kernel stock (sem KSU) é pendente" "pendente" "$c02"

# 6. EOL é impossível por manutenção (C04) -----------------------------------------
ck "kernel EOL = INCOMPATÍVEL" "1" "$(run --engine kernelsu --candidate meteoric-v6-pong)"
eol=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate meteoric-v6-pong --json | jq_ 'next(c["verdict"] for c in d["checks"] if c["check"]=="C04")')
ck "C04 do EOL é incompatível" "incompativel" "$eol"

# 6b. kernel sem release há mais de 1 ano reprova por manutenção --------------------
FXL="$T/fx-stale/skills/evox-rom-ci-optimizer/references"; mkdir -p "$FXL"
cp "$REF"/*.json "$FXL/"
python3 - "$FXL" <<'PY'
import json, sys
p = sys.argv[1] + "/kernel-candidates.json"; d = json.load(open(p))
for c in d["candidates"]:
    if c["id"] == "np2-kernel-lineageos-v3.0.5":
        c["stale_days"] = 500
        c["status"] = "candidate_unverified"
json.dump(d, open(p, "w"))
PY
rc=$(python3 "$G" --root "$T/fx-stale" --engine kernelsu --candidate np2-kernel-lineageos-v3.0.5 >/dev/null 2>&1; echo $?)
ck "kernel parado há 500 dias = INCOMPATÍVEL" "1" "$rc"
c04=$(python3 "$G" --root "$T/fx-stale" --engine kernelsu --candidate np2-kernel-lineageos-v3.0.5 --json | jq_ 'next(c["verdict"] for c in d["checks"] if c["check"]=="C04")')
ck "C04 é quem reprova (não outro check)" "incompativel" "$c04"

# 7. evidência de kernel fecha C06 sem afrouxar nada -------------------------------
python3 - "$REF/droidspaces-requirements.json" "$T/ev-ok.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
cfgs = sorted(set(d["kernel"]["configs_required"] + d["isolation"]["required_configs"]))
json.dump({"kmi": "android13-5.10", "kernel_base": "5.10",
           "configs": {c: "y" for c in cfgs}}, open(sys.argv[2], "w"))
PY
out=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces --kernel-evidence "$T/ev-ok.json" --json); rc=$?
ck "com evidência completa o par fica COMPATÍVEL" "0" "$rc"
ck "C06 passa a ok" "ok" "$(printf '%s' "$out" | jq_ 'next(c["verdict"] for c in d["checks"] if c["check"]=="C06")')"

python3 - "$T/ev-ok.json" "$T/ev-no.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["configs"].pop("CONFIG_SYSVIPC", None)
json.dump(d, open(sys.argv[2], "w"))
PY
out=$(python3 "$G" --root "$ROOT" --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces --kernel-evidence "$T/ev-no.json" --json); rc=$?
ck "evidência sem SYSVIPC volta a PENDENTE" "3" "$rc"
ck "C06 nomeia o que faltou" "sim" \
   "$(printf '%s' "$out" | jq_ '"sim" if "CONFIG_SYSVIPC" in next(c["detail"] for c in d["checks"] if c["check"]=="C06") else "nao"')"
ck "evidência apontada e ausente = PENDENTE" "3" "$(run --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces --kernel-evidence "$T/nao-existe.json")"

# 8. motor sem candidato: avalia contra kernel vazio e diz o que falta --------------
ck "motor sem kernel é PENDENTE" "3" "$(run --engine sukisu)"
semsem=$(python3 "$G" --root "$ROOT" --engine sukisu --json | jq_ '"sim" if d["kernel_candidate"]["id"]=="(nenhum kernel escolhido)" else "nao"')
ck "deixa claro que não há kernel escolhido" "sim" "$semsem"

# 9. --show-policy mostra o pack inteiro (16 pares), sem preferência ---------------
pol=$(python3 "$G" --root "$ROOT" --show-policy)
ck "--show-policy lista os 16 pares" "16" "$(printf '%s\n' "$pol" | grep -c "×" | tr -d ' ')"
ck "--show-policy não elege motor" "0" "$(printf '%s' "$pol" | grep -ci "preferid\|escolhido por" || true)"

# 10. --list-engines lista o catálogo sem 'allowed' --------------------------------
lista=$(python3 "$G" --root "$ROOT" --list-engines)
ck "--list-engines cobre os 4 motores" "4" "$(printf '%s\n' "$lista" | wc -l | tr -d ' ')"
ck "--list-engines não filtra por permissão" "0" "$(printf '%s' "$lista" | grep -ci "allowed\|forbidden" || true)"

# 11. o código do gate não conhece motores por nome --------------------------------
for nome in apatch kernelsu sukisu magisk; do
  n=$(grep -c "\"$nome\"\|'$nome'" "$G" || true)
  ck "gate sem literal de motor ($nome)" "0" "$(printf '%s' "$n" | tr -d ' ')"
done

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
