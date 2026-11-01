#!/system/bin/sh

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "uso: $(basename "$0") — este comando só executa com argumentos explícitos"
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi
# =============================================================================
# EVOX-CI v2.0 — Watchdog Anti-Bootloop & Post-Boot Optimizer (Android 16)
# Se sys.boot_completed nao atingir 1 em 120 segundos, desativa todos os
# modulos recem-injetados e reinicia o dispositivo em modo seguro.
# =============================================================================
MODDIR=${0%/*}
TIMEOUT_SEC=120
ELAPSED=0

while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [ "$ELAPSED" -ge "$TIMEOUT_SEC" ]; then
    touch "$MODDIR/disable"
    log -p e -t "EVOX-CI-WATCHDOG" "Timeout de 120s atingido! Desativando modulo $MODDIR para prevenir bootloop."
    reboot
    exit 1
  fi
done

# Boot concluido com sucesso! Zera o contador de tentativas do post-fs-data.sh
rm -f "$MODDIR/boot_attempt_count"
log -p i -t "EVOX-CI-WATCHDOG" "Boot Android 16 concluido em ${ELAPSED}s. Aplicando ajustes pos-boot."

# Ajustes nao-bloqueantes pos-boot (VM & I/O Scheduler)
if [ -w /proc/sys/vm/swappiness ]; then
  echo 100 > /proc/sys/vm/swappiness
fi

for q in /sys/block/sd*/queue/scheduler /sys/block/mmcblk*/queue/scheduler; do
  if [ -w "$q" ] && grep -q "mq-deadline" "$q" 2>/dev/null; then
    echo "mq-deadline" > "$q" 2>/dev/null || true
  fi
done

exit 0
