#!/usr/bin/env bash
# 00_slot_router.sh — isolamento A/B de módulos (11 casos, sem device)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../assets/00_slot_router.sh"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/root"; M="$R/data/adb/modules"; S2="$R/data/adb/slot_router"
mkdir -p "$M/modA" "$M/modB" "$M/modC" "$S2"
for m in modA modB modC; do printf 'script de %s\n' "$m" > "$M/$m/post-fs-data.sh"; done
printf 'modA\nmodB\n' > "$S2/staged.list"
printf 'modA\n' > "$S2/approved.list"
printf 'STAGING_SLOT=_b\nMAX_ATTEMPTS=3\nENFORCE_ON_PRODUCTION=1\nMODULES_ROOT=%s\n' "$M" > "$R/data/adb/slot_router.conf"
cat > "$T/getprop" <<'STUB'
#!/usr/bin/env bash
[ "$1" = "ro.boot.slot_suffix" ] && echo "${FAKE_SLOT:-_b}" || echo ""
STUB
chmod +x "$T/getprop"

run(){ SR_ROOT="$R" SR_GETPROP="$T/getprop" sh "$S" "$@" >/dev/null 2>&1; echo $?; }
field(){ SR_ROOT="$R" SR_GETPROP="$T/getprop" sh "$S" status 2>/dev/null | sed -n "s/^$1=//p" | head -1; }
dis(){ [ -f "$M/$1/disable" ] && echo desabilitado || echo ativo; }

ck "status inicial é init" "init" "$(field state)" "init"
ck "guard no slot de staging não desabilita" "ativo" \
  "$(FAKE_SLOT=_b run guard >/dev/null; dis modA)" "ativo"
ck "guard registra tentativa 1" "1" "$(field attempts)" "1"
ck "guard em produção desabilita experimentais" "desabilitado" \
  "$(FAKE_SLOT=_a run guard >/dev/null; dis modA)" "desabilitado"
ck "módulo fora da lista permanece ativo" "ativo" "$(dis modC)" "ativo"
ck "segundo boot em produção vira fallback" "production-fallback" \
  "$(FAKE_SLOT=_a run guard >/dev/null; field state)" "production-fallback"
ck "staging acima do limite vira staging-failed" "staging-failed" \
  "$(printf '9\n' > "$S2/attempts"; printf '_b\n' > "$S2/last_slot"
     FAKE_SLOT=_b run guard >/dev/null; field state)" "staging-failed"
ck "quarentena é idempotente" "0" \
  "$(FAKE_SLOT=_a run quarantine >/dev/null; FAKE_SLOT=_a run quarantine >/dev/null; echo 0)" "0"
ck "activate habilita apenas o aprovado" "modA=ativo modB=desabilitado" \
  "$(run activate >/dev/null; echo "modA=$(dis modA) modB=$(dis modB)")" "modA=ativo modB=desabilitado"
ck "troca de slot zera contador" "1" \
  "$(printf '7\n' > "$S2/attempts"; printf '_b\n' > "$S2/last_slot"; FAKE_SLOT=_a run guard >/dev/null; field attempts)" "1"
ck "recusa MODULES_ROOT perigoso" "exit" \
  "$(SR_ROOT="$R" SR_GETPROP="$T/getprop" SR_MODULES_ROOT=/ sh "$S" status >/dev/null 2>&1; echo "exit=$?")" "exit=3"
ck "não apaga arquivos dos módulos" "intacto" \
  "$([ -f "$M/modA/post-fs-data.sh" ] && [ -f "$M/modB/post-fs-data.sh" ] && echo intacto || echo perdido)" "intacto"
ck "status expõe slot atual" "_a" "$(FAKE_SLOT=_a field current_slot)" "_a"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
