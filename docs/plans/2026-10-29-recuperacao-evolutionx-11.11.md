---
title: "Plano Consolidado — Recuperação Nothing Phone 2 → EvolutionX 11.11"
created: 2026-10-29
author: "el Gentleman (Pi)"
status: "active"
tags: ["recuperação", "evolutionx", "pong", "sideload", "apatch", "bootloop"]
related:
  - "PLANO-5W1H-RECUPERACAO.md"
  - "EXECUÇÃO-RECUPERAÇÃO-EVOLUTIONX.md"
  - "2026-10-20-recuperacao-fastboot-pong.md"
---

# Plano Consolidado — Recuperação Nothing Phone 2 (Pong) → EvolutionX 11.11

**Data:** 2026-10-29
**Device:** Nothing Phone 2 (Pong, SM8475, serial `9f51ecb9`)
**ROM alvo:** EvolutionX-16.0-20260915-Pong-11.11-Official.zip
**Arquivo:** `/home/cnmfs/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip` (3.6 GB, SHA256 pendente)
**Recovery:** `/home/cnmfs/nothing-phone2/downloads/recovery.img` (100 MB, Evolution X 11.9)

---

## 1. ESTADO ATUAL (2026-10-29)

| Propriedade | Valor | Observação |
|-------------|-------|------------|
| **USB PID** | `05c6:a4a1` | CDC NCM — kernel sobe parcialmente, boot não completa |
| **ADB** | ❌ Indisponível | PID a4a1 não expõe ADB |
| **Fastboot** | ❌ Indisponível | Device não está em bootloader |
| **EDL 9008** | ❌ Não detectado | Sem firehose disponível |
| **Slot ativo** | `_b` (último confirmado) | Sideload 11.11 foi direcionado ao slot_b |
| **Build no slot_b** | BP4A.251205.006 (11.11) | Confirmado via getprop antes do reboot |
| **Root** | ❌ Não aplicado | APatch/KernelSU pendente |
| **Bootloader** | Unlockado (confirmado anteriormente) | `fastboot getvar unlocked: yes` |

### Histórico da sessão (resumo)
1. Device estava em bootloop no slot_b após flash incorreto de stock_boot.img
2. Entrou em EDL (05c6:9008), recuperado via force reboot para fastboot
3. Flash recovery Evolution X → reboot recovery → slot_b
4. Factory reset no slot_b
5. Sideload EvolutionX 11.11 → transferiu até ~47%, timeout interrompeu
6. Retentativas falharam por `unauthorized` e `connection closed`
7. Sideload final completou (build BP4A.251205.006 confirmada no slot_b)
8. Recovery pediu "reboot recovery to install additional packages" → YES
9. Device rebootou no slot_a com 11.11, depois trocou para slot_b → bootloop
10. Novo factory reset + sideload no slot_b → completou novamente
11. Após reboot: PID `05c6:a4a1` (CDC NCM), sem ADB/fastboot

---

## 2. OBJETIVO

1. Boot estável no Evolution X 11.11 no slot_b
2. Root funcional (APatch preferido — reverterível)
3. Módulos essenciais ativos (ZygiskNext, TrickyStore, PlayIntegrityFix)
4. Fingerprint/biometria funcional
5. Apps Google (GMS, YouTube, WebView) operacionais
6. Apps de banco sem bloqueio de segurança
7. Zero conflitos de módulos

---

## 3. PLANO DE EXECUÇÃO (8 FASES)

### FASE 1: Sair do CDC NCM (0xa4a1) → Fastboot
**Por quê:** O PID `0xa4a1` não permite adb nem fastboot. Precisamos forçar o device para bootloader.

**Como (usuário executa):**
1. Desconecte o cabo USB
2. Segure **Power + Vol Down** por **20 segundos** (force power off)
3. Solte tudo, aguarde 3s
4. Segure **Vol Down + Power** simultaneamente até aparecer a tela do fastboot (texto pequeno, fundo preto)
5. Reconecte o cabo USB

**Critério de verificação:**
```bash
fastboot devices
# Esperado: 9f51ecb9  fastboot

lsusb | grep 05c6
# Esperado: PID diferente de a4a1 (geralmente 9008 ou dispositivo fastboot)
```

**Rollback:** Se não entrar em fastboot, tentar Vol Up + Vol Down + Power por 15s.

---

### FASE 2: Confirmar slot e flash recovery 11.11
**Por quê:** Garantir que o recovery correto está na partição do slot_b.

**Como:**
```bash
# Confirmar slot atual
fastboot getvar current-slot
# Esperado: _b (ou _a — anotar qual)

# Se estiver em _a, trocar para _b
fastboot --set-active=b

# Flash recovery
fastboot flash recovery /home/cnmfs/nothing-phone2/downloads/recovery.img
# Esperado: OKAY

# Reboot para recovery
fastboot reboot recovery
```

**Critério de verificação:**
```bash
# Após recovery subir (aguardar 15s):
adb devices
# Esperado: 9f51ecb9  recovery  (ou unauthorized — autorizar na tela)
```

---

### FASE 3: Factory Reset + Sideload 11.11 (se necessário)
**Por quê:** Se o slot_b ainda tem dados corrompidos do bootloop anterior, limpar antes do sideload.

**Pré-condição:** Esta fase só é necessária se o slot_b NÃO tiver o 11.11 já instalado corretamente. Se o build BP4A.251205.006 já está no slot_b (confirmado anteriormente), pular para Fase 4.

**Como (no recovery):**
1. Navegar: **Factory Reset** → **Format Data/Factory Reset** → Confirmar
2. Voltar: **Apply Update** → **Apply from ADB**
3. No PC:
```bash
adb sideload /home/cnmfs/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip
# TIMEOUT: usar bg_run ou timeout >= 1800s (30 min)
# O arquivo tem 3.6 GB, transferência leva ~5-8 min
```

**⚠️ REGRA CRÍTICA DE TIMEOUT:**
- NUNCA usar timeout < 1800s para o sideload deste zip
- O sideload mostra progresso ~0% a ~47% e pode parecer travado — NÃO CANCELAR
- Quando chegar a 100%, o recovery exibe "to install additional packages you need to reboot recovery first"
- Clicar **YES** na tela do device

**Critério de verificação:**
```bash
# Após clicar YES e recovery reiniciar:
adb shell getprop ro.build.display.id
# Esperado: BP4A.251205.006

adb shell getprop ro.boot.slot_suffix
# Esperado: _b
```

---

### FASE 4: Primeiro Boot no Sistema
**Por quê:** Validar que o Evolution X 11.11 sobe sem bootloop.

**Como (no recovery):**
1. Menu principal → **Reboot system now**
2. Aguardar até 120s para o sistema subir

**Critério de verificação:**
```bash
# Após boot (aguardar 60s):
adb devices
# Esperado: 9f51ecb9  device  (autorizar USB debugging na tela do Android)

adb shell getprop sys.boot_completed
# Esperado: 1

adb shell getprop ro.build.display.id
# Esperado: BP4A.251205.006

adb shell getprop ro.boot.slot_suffix
# Esperado: _b
```

**Se bootloop:**
```bash
# Forçar fastboot (Vol Down + Power 20s)
fastboot --set-active=a
fastboot reboot
# Slot_a deve ter 11.11 também (foi instalado anteriormente)
```

---

### FASE 5: Aplicar Root (APatch)
**Por quê:** Root necessário para módulos Zygisk, Play Integrity, otimizações.

**Pré-condição:** Sistema boota estável no slot_b.

**Como:**
```bash
# Verificar imagem APatch patcheada
sha256sum /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
# Esperado: f57c7db7d948a906ebe63370e6cb481e72a5bebd1b7e0b027bab883bf70df7b4

# Reboot para fastboot
adb reboot bootloader
sleep 5

# Flash APatch kernel no slot_b
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
fastboot --set-active=b
fastboot reboot
```

**Critério de verificação:**
```bash
# Após boot (aguardar 60s):
adb shell su -c 'id'
# Esperado: uid=0(root) gid=0(root) context=u:r:su:s0

adb shell su -c 'getenforce'
# Esperado: Enforcing

adb shell su -c 'cat /data/adb/apatch/version' 2>/dev/null || echo "APatch version check failed"
```

**Rollback:** Se APatch causar bootloop:
```bash
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot --set-active=b
fastboot reboot
```

---

### FASE 6: Auditar e Limpar Módulos
**Por quê:** Módulos incompatíveis causam bootloop (lição documentada no AGENTS.md Erro #6).

**Pré-condição:** Root APatch funcional.

**Como:**
```bash
# Listar todos os módulos
adb shell su -c 'ls -la /data/adb/modules/'

# Desabilitar módulos problemáticos conhecidos
adb shell su -c 'touch /data/adb/modules/mountify/disable'
adb shell su -c 'touch /data/adb/modules/zygisk_shamiko/disable'

# Manter apenas essenciais:
# - zygisknext (base Zygisk)
# - tricky_store (Play Integrity spoofing)
# - playintegrityfix (bypass verificação)

# Verificar quais estão ativos
adb shell su -c 'ls /data/adb/modules/ | while read m; do [ ! -f /data/adb/modules/$m/disable ] && echo "ATIVO: $m"; done'
```

**Critério de verificação:**
```bash
# Apenas zygisknext, tricky_store, playintegrityfix devem estar ATIVOS
# Nenhum erro crítico nos logs:
adb shell logcat -b boot -t 200 | grep -iE 'error|fail|panic|watchdog' | head -20
# Esperado: vazio ou apenas warnings benignos
```

---

### FASE 7: Validar Fingerprint e Serviços Google
**Por quê:** Requisitos explícitos do usuário.

**Fingerprint:**
```bash
# Verificar serviço de biometria
adb shell pm list packages | grep -iE 'biometric|fingerprint'
adb shell dumpsys sensorservice | grep -i fingerprint | head -5
```
**Teste manual:** Settings → Security → Fingerprint → Registrar → Testar desbloqueio.

**Google Services:**
```bash
# Verificar GMS
adb shell pm list packages | grep -i 'com.google.android.gms'
adb shell dumpsys package com.google.android.gms | grep -E 'enabled|versionName' | head -5

# Play Integrity (requer root + tricky_store)
adb shell su -c 'which playintegrity' 2>/dev/null || echo "playintegrity CLI not found"
```
**Teste manual:** Abrir Play Store → Login → YouTube → Reproduzir vídeo.

**Critério de verificação:**
- [ ] Fingerprint registra e desbloqueia
- [ ] Play Store abre e faz login
- [ ] YouTube reproduz vídeo
- [ ] Play Integrity passa DEVICE_INTEGRITY (verificar com app YASNAC ou similar)

---

### FASE 8: Otimizações Finais
**Por quê:** Experiência Android 16 otimizada.

```bash
# Freeform window
adb shell pm list packages | grep freeform
# Esperado: com.libremobileos.freeform ou similar

# Permissões de banco (verificar se app abre sem bloqueio)
adb shell dumpsys package br.com.bb.android 2>/dev/null | grep -E 'granted=true|permission' | head -10

# Áudio
adb shell settings get system audio_sfx_enabled
```

---

## 4. CHECKLIST CONSOLIDADO

### Pré-execução
- [x] Backup SD card (23GB em `/home/cnmfs/backups/`)
- [x] Backup Termux (`/home/cnmfs/backups/termux/`)
- x [x] Backup RikkaHub (`downloads/rikkahub-backup/`) -> nao tenho mais
- [x] Imagem stock_boot.img disponível (SHA: 6f2c638f...)
- [x] Imagem apatch_patched_boot.img disponível (SHA: f57c7db7...)
- [x] Recovery Evolution X disponível (100 MB)
- [x] ROM EvolutionX 11.11 disponível (3.6 GB em `/home/cnmfs/Downloads/`)
- [x] Bootloader unlockado
- [ ] GUARD 4: Confirmação explícita do usuário antes de cada flash

### Execução
- [ ] FASE 1: Force reboot → fastboot (`fastboot devices` OK)
- [ ] FASE 2: Confirmar slot_b + flash recovery
- [ ] FASE 3: Factory reset + sideload 11.11 (se necessário)
- [ ] FASE 4: Boot no sistema (`sys.boot_completed = 1`, build = BP4A.251205.006)
- [ ] FASE 5: Root APatch (`su -c id` = uid=0)
- [ ] FASE 6: Módulos auditados (apenas essenciais ativos)
- [ ] FASE 7: Fingerprint + Google validados
- [ ] FASE 8: Otimizações aplicadas

### Pós-execução
- [ ] Criar snapshot de backup pós-instalação
- [ ] Documentar SHA256 das imagens finais
- [ ] Atualizar AGENTS.md com novas lições aprendidas

---

## 5. CRITÉRIOS DE VERIFICAÇÃO (TABELA RESUMO)

| Fase | Comando/Teste | Resultado Esperado | Status |
|------|---------------|--------------------|--------|
| 1 | `fastboot devices` | `9f51ecb9  fastboot` | ⬜ |
| 2 | `fastboot getvar current-slot` | `b` | ⬜ |
| 2 | `fastboot flash recovery` | `OKAY` | ⬜ |
| 3 | `adb sideload` | 100% + prompt "reboot recovery" | ⬜ |
| 4 | `getprop ro.build.display.id` | `BP4A.251205.006` | ⬜ |
| 4 | `getprop ro.boot.slot_suffix` | `_b` | ⬜ |
| 4 | `getprop sys.boot_completed` | `1` | ⬜ |
| 5 | `su -c id` | `uid=0(root)` | ⬜ |
| 5 | `su -c getenforce` | `Enforcing` | ⬜ |
| 6 | `ls /data/adb/modules/` | Só essenciais ativos | ⬜ |
| 6 | `logcat -b boot` | Sem erros críticos | ⬜ |
| 7 | Fingerprint test | Registra + desbloqueia | ⬜ |
| 7 | Play Store + YouTube | Funcionam | ⬜ |
| 8 | App de banco | Abre sem bloqueio | ⬜ |

---

## 6. LIÇÕES APRENDIDAS (adendos outubro 2026)

### Lição #7: Sideload de 3.6 GB requer timeout ≥ 1800s
**O que aconteceu:** Sideload interrompido em ~47% por timeout de 60s e 600s.
**Correção:** Usar `timeout 1800` ou `bg_run` para transferências > 1 GB.
**Regra:** Nunca cancelar sideload que está progredindo, mesmo que pareça lento.

### Lição #8: PID 0xa4a1 = CDC NCM, não é ADB nem fastboot
**O que aconteceu:** Device apareceu como `05c6:a4a1` após boot parcial. Tentativas de `adb` e `edl` falharam.
**Correção:** Este PID indica que o kernel subiu mas o Android não completou o boot. Única saída: force reboot (Power + Vol Down 20s) → fastboot.
**Regra:** Se `lsusb` mostrar `0xa4a1`, não tentar adb/fastboot/edl — forçar reboot físico.

### Lição #9: Recovery Evolution X alterna slots automaticamente
**O que aconteceu:** Sideload feito no slot_b, mas após "reboot recovery" o device caiu no slot_a.
**Correção:** Sempre verificar `getprop ro.boot.slot_suffix` após reboot do recovery. Se mudou de slot, trocar manualmente via fastboot antes de prosseguir.

### Lição #10: "Install additional packages" = instalação base concluída
**O que aconteceu:** Mensagem interpretada como erro ("installation cancelled"). Na verdade, confirma que o ZIP principal foi instalado e o recovery pede reboot para aceitar addons opcionais.
**Correção:** Clicar YES → recovery reinicia → Reboot system now.

---

## 7. COMANDOS DE EMERGÊNCIA

```bash
# Rollback completo para slot_a (fallback seguro)
fastboot --set-active=a
fastboot reboot

# Se slot_a também falhar → stock boot no slot_a
fastboot flash boot_a /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot --set-active=a
fastboot reboot

# Force reboot físico (quando nenhum comando funciona)
# Segurar Power + Vol Down por 20 segundos

# Entrar em EDL (último recurso, precisa de firehose)
# Segurar Vol Up + Vol Down + conectar USB
# OU: fastboot oem edl (se suportado)
```

---

## 8. ARQUIVOS DE REFERÊNCIA

| Arquivo | Caminho |
|---------|---------|
| ROM EvolutionX 11.11 | `/home/cnmfs/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip` |
| ROM EvolutionX 11.9 | `/home/cnmfs/nothing-phone2/downloads/EvolutionX-16.0-20260802-Pong-11.9-Official.zip` |
| Recovery img | `/home/cnmfs/nothing-phone2/downloads/recovery.img` |
| Stock boot | `/home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img` |
| APatch boot | `/home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img` |
| Plano 5W1H original | `docs/plans/PLANO-5W1H-RECUPERACAO.md` |
| Plano execução original | `docs/plans/EXECUÇÃO-RECUPERAÇÃO-EVOLUTIONX.md` |
| AGENTS.md (lições) | `AGENTS.md` |

---

*Plano consolidado em 2026-10-29. Incorpora lições das sessões de 2026-10-20, 2026-10-28 e 2026-10-29.*

</content>
