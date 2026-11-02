#!/system/bin/sh
# =============================================================================
# 00_slot_router.sh — isolamento de módulos entre os slots A/B (Android 16)
# -----------------------------------------------------------------------------
# INSTALAÇÃO:  /data/adb/post-fs-data.d/00_slot_router.sh   (chmod 755)
# CONFIG:      /data/adb/slot_router.conf
# ESTADO:      /data/adb/slot_router/{attempts,last_slot,state,log,staged.list,approved.list}
#
# O QUE ESTE SCRIPT **NÃO** FAZ (e por quê):
#   • não faz `mount --bind` sobre /data/adb/modules — o gerenciador de root
#     (APatch/KernelSU/Magisk) já leu /data/adb/modules antes deste hook rodar;
#     bind aqui não desfaz o que já entrou no namespace e pode quebrar o mount
#     do próprio gerenciador. Quarentena é por marcador `disable` (oficial).
#   • não apaga módulo nenhum (nenhum `rm -rf`): só cria/remove arquivo `disable`.
#   • não toca em /persist, /metadata nem em partições.
#
# MODELO DE SEGURANÇA (a parte que a internet erra):
#   /data é COMPARTILHADO entre os slots. Se o slot B entra em bootloop e o
#   bootloader cai para o A, o A lê o MESMO /data/adb/modules e também quebra.
#   Como um hook `post-fs-data.d` roda DEPOIS dos scripts dos módulos, ele não
#   salva o boot em curso: ele salva o PRÓXIMO.
#   Logo a proteção real é em duas camadas:
#     1) HOST  : `quarantine` ANTES de trocar de slot/flashar (determinístico).
#     2) DEVICE: `guard` conta tentativas e, ao exceder o limite, desabilita os
#                módulos experimentais — o boot seguinte já vem limpo.
#
# COMMANDOS:
#   guard       (default) roda no boot; conta tentativa e aplica política
#   quarantine  marca `disable` em todos os módulos de staged.list
#   activate    remove `disable` só dos módulos aprovados (approved.list)
#   status      imprime estado em KEY=VALUE (consumido pelo CI)
#   reset       zera contador/estado (mantém o log)
#
# EXIT: 0 ok · 2 uso/config inválida · 3 recusa por segurança · 4 estado ausente
#
# TESTABILIDADE: SR_ROOT=<dir> isola tudo em um diretório (usado nos testes);
#                SR_GETPROP=<cmd> injeta o leitor de propriedades.
# =============================================================================
set -u

case "${1:-}" in
  -h|--help)
    echo "uso: 00_slot_router.sh {guard|quarantine|activate|status|reset} [--root DIR] [--max-attempts N]"
    sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
esac


SR_ROOT="${SR_ROOT:-}"
GETPROP="${SR_GETPROP:-getprop}"
BASE="$SR_ROOT/data/adb"
CONF="${SR_CONF:-$BASE/slot_router.conf}"
STATE="$BASE/slot_router"
MODULES="${SR_MODULES_ROOT:-$BASE/modules}"
STAGED="$STATE/staged.list"
APPROVED="$STATE/approved.list"
LOG="$STATE/log"
MODE="${1:-guard}"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '-')" "$*" >>"$LOG" 2>/dev/null || true; }
say() { printf '[slot-router] %s\n' "$*"; }
die() { say "ERRO: $*"; log "error: $*"; exit "${2:-3}"; }

# ── Configuração (defaults seguros) ─────────────────────────────────────────
STAGING_SLOT="_b"
MAX_ATTEMPTS=3
ENFORCE_ON_PRODUCTION=1
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF" 2>/dev/null || die "config inválida: $CONF" 2
fi

# ── Recusas de segurança (nunca operar em raiz perigosa) ────────────────────
case "$MODULES" in
  ""|"/"|"/data"|"/data/adb"|"/system"|"/vendor"|"/persist"|"/metadata")
    die "MODULES_ROOT inseguro: '$MODULES'" 3 ;;
esac
mkdir -p "$STATE" || die "não foi possível criar $STATE" 3

# ── Lock simples (evita corrida entre hook de boot e comando do host) ───────
LOCK="$STATE/.lock"
acquire_lock() {
  i=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -ge 10 ] && die "lock preso em $LOCK (remova manualmente)" 3
    sleep 1
  done
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
}

slot_now() { "$GETPROP" ro.boot.slot_suffix 2>/dev/null | tr -d '\r\n ' ; }

ensure_list() { [ -f "$1" ] || : >"$1"; }

normalize_module() {  # só aceita nome simples (sem / e sem ..)
  case "$1" in ""|*/*|.|..) return 1 ;; esac
  printf '%s' "$1"
}

set_disabled() {  # set_disabled <module> <1|0>
  name="$(normalize_module "$1")" || { log "skip inválido: '$1'"; return 0; }
  dir="$MODULES/$name"
  [ -d "$dir" ] || { log "skip ausente: $name"; return 0; }
  if [ "$2" = "1" ]; then
    [ -f "$dir/disable" ] || : >"$dir/disable"
    log "disable: $name"
  else
    [ -f "$dir/disable" ] && rm -f "$dir/disable"
    log "enable: $name"
  fi
}

mark_all() {  # mark_all <arquivo-lista> <1|0>
  ensure_list "$1"
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    case "$m" in \#*) continue ;; esac
    set_disabled "$m" "$2"
  done <"$1"
}

write_state() { printf '%s\n' "$1" >"$STATE/state"; }

# ── Comandos ────────────────────────────────────────────────────────────────
cmd_status() {
  slot="$(slot_now)"
  attempts="$(cat "$STATE/attempts" 2>/dev/null || echo 0)"
  state="$(cat "$STATE/state" 2>/dev/null || echo init)"
  last="$(cat "$STATE/last_slot" 2>/dev/null || echo none)"
  staged_n="$(grep -vc '^#' "$STAGED" 2>/dev/null || echo 0)"
  approved_n="$(grep -vc '^#' "$APPROVED" 2>/dev/null || echo 0)"
  disabled_n=0
  [ -d "$MODULES" ] && disabled_n="$(find "$MODULES" -maxdepth 2 -name disable -type f 2>/dev/null | wc -l | tr -d ' ')"
  printf 'state=%s\ncurrent_slot=%s\nlast_slot=%s\nstaging_slot=%s\nattempts=%s\nmax_attempts=%s\nmodules_root=%s\nstaged=%s\napproved=%s\ndisabled=%s\n' \
    "$state" "$slot" "$last" "$STAGING_SLOT" "$attempts" "$MAX_ATTEMPTS" "$MODULES" \
    "$staged_n" "$approved_n" "$disabled_n"
}

cmd_quarantine() {
  mark_all "$STAGED" 1
  write_state quarantined
  log "quarantine aplicado (slot=$(slot_now) staging=$STAGING_SLOT)"
  say "quarentena aplicada — módulos experimentais desabilitados"
  cmd_status
}

cmd_activate() {
  ensure_list "$APPROVED"
  if [ ! -s "$APPROVED" ]; then
    say "approved.list vazio — nada a ativar"
    return 0
  fi
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    case "$m" in \#*) continue ;; esac
    set_disabled "$m" 0
  done <"$APPROVED"
  write_state active
  log "activate: $(grep -vc '^#' "$APPROVED") módulo(s)"
  say "módulos aprovados ativados"
  cmd_status
}

cmd_reset() {
  printf '0\n' >"$STATE/attempts"
  write_state init
  log "reset manual"
  say "contador zerado"
  cmd_status
}

cmd_guard() {
  slot="$(slot_now)"
  [ -n "$slot" ] || die "não consegui ler ro.boot.slot_suffix" 4
  last="$(cat "$STATE/last_slot" 2>/dev/null || echo none)"
  attempts="$(cat "$STATE/attempts" 2>/dev/null || echo 0)"
  case "$attempts" in ''|*[!0-9]*) attempts=0 ;; esac

  if [ "$last" != "$slot" ]; then
    attempts=0                       # slot mudou ⇒ ciclo novo
    log "slot mudou: $last -> $slot (contador zerado)"
  fi
  attempts=$((attempts + 1))
  printf '%s\n' "$attempts" >"$STATE/attempts"
  printf '%s\n' "$slot" >"$STATE/last_slot"

  # Marca de boot: prova que ESTE boot chegou ao userspace (post-fs-data).
  # Sem marca + sem boot_completed ⇒ falha antes do userspace (kernel/bootloader).
  # Com marca + sem boot_completed ⇒ travamento pós-kernel (system_server/watchdog).
  mkdir -p "$STATE/marks" 2>/dev/null || true
  _up="$(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo '?')"
  _mk="$STATE/marks/${slot#_}_${attempts}.mark"
  printf 'slot=%s\nattempt=%s\nuptime=%s\nat=%s\n' "$slot" "$attempts" "$_up" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '-')" >"$_mk" 2>/dev/null || true
  # mantém no máximo 20 marcas
  ls -1t "$STATE/marks" 2>/dev/null | tail -n +21 | while read -r old; do
    [ -n "$old" ] && rm -f "$STATE/marks/$old"
  done

  if [ "$slot" = "$STAGING_SLOT" ]; then
    if [ "$attempts" -gt "$MAX_ATTEMPTS" ]; then
      mark_all "$STAGED" 1
      write_state staging-failed
      log "staging excedeu $MAX_ATTEMPTS tentativas — experimentais desabilitados"
      say "staging falhou ${attempts}x — quarentena automática (próximo boot limpo)"
      cmd_status
      exit 0
    fi
    write_state staging
    log "staging ok (tentativa $attempts/$MAX_ATTEMPTS)"
    cmd_status
    exit 0
  fi

  # Slot de produção: o objetivo é NÃO repetir bootloop por módulo experimental.
  if [ "$ENFORCE_ON_PRODUCTION" = "1" ]; then
    mark_all "$STAGED" 1
  fi
  if [ "$attempts" -gt 1 ]; then
    write_state production-fallback
    log "fallback detectado: slot=$slot tentativa=$attempts (módulos experimentais desabilitados)"
    say "boot caiu em $slot (tentativa $attempts) — experimentais desabilitados"
  else
    write_state production
    log "produção: slot=$slot tentativa=$attempts"
  fi
  cmd_status
}

case "$MODE" in
  guard)       acquire_lock; cmd_guard ;;
  quarantine)  acquire_lock; cmd_quarantine ;;
  activate)    acquire_lock; cmd_activate ;;
  status)      cmd_status ;;
  reset)       acquire_lock; cmd_reset ;;
  -h|--help|help)
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           printf 'uso: %s {guard|quarantine|activate|status|reset}\n' "$0" >&2; exit 2 ;;
esac
