#!/usr/bin/env bash
# test_script_contracts.sh — todo script CLI responde a --help e NÃO tem efeito colateral.
# Garante que rodar/inspecionar um script nunca mexe em git, branch ou arquivos.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SK="$(cd "$HERE/.." && pwd)"; ROOT="$(cd "$SK/../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

snap(){ git -C "$ROOT" rev-parse --abbrev-ref HEAD; git -C "$ROOT" rev-parse HEAD; git -C "$ROOT" status --porcelain | sort; }
BEFORE="$(snap)"

SCRIPTS=(
  "$SK/scripts/audit_rom_conflicts.sh"
  "$SK/scripts/build_safe_module_bundle.sh"
  "$SK/scripts/extract_evox_base.sh"
  "$SK/scripts/forge_patcher.sh"
  "$SK/scripts/patch_boot_offline.sh"
  "$SK/scripts/runtime_module_tester.sh"
  "$SK/scripts/snapshot_branch_manager.sh"
  "$SK/scripts/rom_artifact_fetch.sh"
  "$SK/scripts/abl_fallback_probe.sh"
  "$SK/scripts/guard4_verify.sh"
  "$SK/scripts/kernel_compat_check.sh"
  "$SK/scripts/rollout_gate.sh"
  "$SK/scripts/cache_manager.sh"
  "$SK/scripts/session_open.py"
  "$SK/scripts/architecture_guard.py"
  "$SK/scripts/contradiction_scan.py"
  "$SK/scripts/kernel_build_gate.py"
  "$SK/scripts/continuity_gate.py"
  "$SK/scripts/closure_gate.py"
  "$SK/scripts/debt_ledger.py"
  "$SK/assets/00_slot_router.sh"
  "$SK/assets/watchdog_anti_bootloop_service.sh"
  "$ROOT/scripts/audit-flashable-zip.sh"
  "$ROOT/scripts/build-kernel-pong.sh"
  "$ROOT/scripts/generate-build-matrix.sh"
  "$ROOT/scripts/package-anykernel3.sh"
  "$ROOT/scripts/patch-manager.sh"
  "$ROOT/scripts/resolve-kernel-source.sh"
  "$ROOT/scripts/validate-cuttlefish.sh"
  "$ROOT/scripts/kernel-fragment.py"
)

for s in "${SCRIPTS[@]}"; do
  n="$(basename "$s")"
  [ -f "$s" ] || { bad "$n --help" "arquivo ausente"; continue; }
  case "$s" in
    *.py) out="$(timeout 10 python3 "$s" --help 2>&1)"; rc=$? ;;
    *)    out="$(timeout 10 bash "$s" --help 2>&1)"; rc=$? ;;
  esac
  ck "$n responde --help sem erro" "exit 0" "$rc" "0"
  ck "$n --help mostra uso" "sim" "$(echo "$out" | grep -qiE 'uso|usage|--' && echo sim || echo nao)" "sim"
done

AFTER="$(snap)"
ck "--help não troca de branch" "igual" "$([ "$(echo "$BEFORE" | head -1)" = "$(echo "$AFTER" | head -1)" ] && echo igual || echo mudou)" "igual"
ck "--help não cria commit" "igual" "$([ "$(echo "$BEFORE" | sed -n 2p)" = "$(echo "$AFTER" | sed -n 2p)" ] && echo igual || echo mudou)" "igual"
ck "--help não altera arquivos" "igual" "$([ "$BEFORE" = "$AFTER" ] && echo igual || echo mudou)" "igual"
ck "nenhuma branch snapshot foi criada" "0" "$(git -C "$ROOT" branch --list 'snapshot/*' | wc -l | tr -d ' ')" "0"

# snapshot_branch_manager: dry-run e recusa em branch protegida
ck "snapshot recusa branch protegida" "exit" \
  "$(cd "$ROOT" && bash "$SK/scripts/snapshot_branch_manager.sh" --layer x >/dev/null 2>&1; echo $?)" "4"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
