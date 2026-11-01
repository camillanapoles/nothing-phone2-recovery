#!/usr/bin/env bash
# =============================================================================
# EVOX-CI v2.0 — Instalador Local Idempotente & CLI Wrapper (evox-ci)
# Compativel com Linux (Pop!_OS / Ubuntu / Debian) e Android Termux
# =============================================================================
set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
WORKSPACE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init-workspace) WORKSPACE_DIR="$2"; shift 2 ;;
    --bin-dir) BIN_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "======================================================================="
echo " [EVOX-CI v2.0] Iniciando Instalacao Local da Skill evox-rom-ci-optimizer"
echo "======================================================================="

mkdir -p "$BIN_DIR"
chmod +x "$SKILL_ROOT"/scripts/*.sh "$SKILL_ROOT"/assets/*.sh

# 1. Verificar dependencias basicas
MISSING_DEPS=()
for cmd in bash unzip sha256sum python3 grep awk sed find; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING_DEPS+=("$cmd")
  fi
done

if [ "${#MISSING_DEPS[@]}" -gt 0 ]; then
  echo "[AVISO] Dependencias ausentes detectadas: ${MISSING_DEPS[*]}"
  if command -v pkg >/dev/null 2>&1; then
    echo "Ambiente Termux detectado. Execute: pkg install ${MISSING_DEPS[*]}"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "Ambiente Debian/Ubuntu/Pop!_OS detectado. Execute: sudo apt-get install ${MISSING_DEPS[*]}"
  fi
else
  echo "[OK] Todas as ferramentas POSIX essenciais estao presentes."
fi

# 2. Criar wrapper CLI `evox-ci` em ~/.local/bin/evox-ci
cat << EOF > "$BIN_DIR/evox-ci"
#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$SKILL_ROOT"
CMD="\${1:-help}"
shift || true

case "\$CMD" in
  audit)
    exec "\$SKILL_DIR/scripts/audit_rom_conflicts.sh" "\$@"
    ;;
  extract)
    exec "\$SKILL_DIR/scripts/extract_evox_base.sh" "\$@"
    ;;
  patch-boot)
    exec "\$SKILL_DIR/scripts/patch_boot_offline.sh" "\$@"
    ;;
  bundle)
    exec "\$SKILL_DIR/scripts/build_safe_module_bundle.sh" "\$@"
    ;;
  check)
    exec make -C "\$SKILL_DIR" check
    ;;
  *)
    echo "Uso: evox-ci {check|extract|audit|patch-boot|bundle} [opcoes]"
    echo "Diretorio da Skill: \$SKILL_DIR"
    exit 0
    ;;
esac
EOF
chmod +x "$BIN_DIR/evox-ci"
echo "[OK] CLI instalada em: $BIN_DIR/evox-ci"

# 3. Se solicitado, inicializar workspace de staging para GitHub Actions
if [[ -n "$WORKSPACE_DIR" ]]; then
  echo "[INFO] Inicializando Workspace GitHub Actions em: $WORKSPACE_DIR"
  mkdir -p "$WORKSPACE_DIR"/{.github/workflows,modules,kernel_patches,tweaks,scripts,references,assets,workspace/base_rom,workspace/extracted,workspace/out}
  cp -f "$SKILL_ROOT/references/evox-ci-validator.yml" "$WORKSPACE_DIR/.github/workflows/evox-11-11-prevalidate.yml"
  cp -f "$SKILL_ROOT/references/android16-evox-safelist.json" "$WORKSPACE_DIR/references/"
  cp -f "$SKILL_ROOT/scripts/"*.sh "$WORKSPACE_DIR/scripts/"
  cp -f "$SKILL_ROOT/assets/"* "$WORKSPACE_DIR/assets/"
  cp -f "$SKILL_ROOT/Makefile" "$WORKSPACE_DIR/Makefile"
  cp -f "$SKILL_ROOT/README.md" "$WORKSPACE_DIR/README.md"
  chmod +x "$WORKSPACE_DIR/scripts/"*.sh "$WORKSPACE_DIR/assets/"*.sh
  if [ ! -d "$WORKSPACE_DIR/.git" ] && command -v git >/dev/null 2>&1; then
    git -C "$WORKSPACE_DIR" init -b main >/dev/null 2>&1 || git -C "$WORKSPACE_DIR" init >/dev/null 2>&1
  fi
  echo "[OK] Workspace pronto em: $WORKSPACE_DIR"
fi

echo "======================================================================="
echo " Instalacao concluida! Teste agora com: make check (ou evox-ci check)"
echo "======================================================================="
