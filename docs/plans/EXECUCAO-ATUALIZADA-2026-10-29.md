---
title: "Plano de Execução Atualizada — Nothing Phone 2 → EvolutionX 11.11"
created: 2026-10-29
author: "el Gentleman (Pi) + Claude"
status: "active"
tags: ["recuperação", "evolutionx", "pong", "sideload", "apatch", "bootloop", "execução"]
related:
  - "2026-10-29-recuperacao-evolutionx-11.11.md"
  - "AGENTS.md"
---

# Plano de Execução Atualizado — Nothing Phone 2 (Pong) → EvolutionX 11.11

**Data da atualização:** 2026-10-29 17:15  
**Device:** Nothing Phone 2 (Pong, SM8475, serial `9f51ecb9`)  
**Status:** ✅ **ROM EvolutionX 11.11 INSTALADA E BOOTADA** — `BP4A.251205.006` no slot `_b`.  
**Status do plano original:** `docs/plans/2026-10-29-recuperacao-evolutionx-11.11.md` — incorporado, corrigido e validado contra logs reais.

---

## ✅ CONCLUÍDO (2026-10-29 17:15)

| Etapa | Estado | Evidência |
|-------|--------|-----------|
| Factory reset | ✅ Concluído | `fastboot -w` → `Erasing 'userdata' OKAY` + `format successful` |
| SHA256 ROM validada | ✅ | `79236f9b4259cf5df124dcd7176f8b4c30de0d755e189e8a4224a03e365422fb` |
| Sideload EvolutionX 11.11 | ✅ Concluído | `Install complete with status 0` |
| Boot no sistema | ✅ | `ro.build.display.id` = `BP4A.251205.006`, `ro.boot.slot_suffix` = `_b` |
| Slot ativo | ✅ `_b` | `getprop ro.boot.slot_suffix` = `_b` |

> **Nota:** A versão `11.9` que aparece na tela do recovery é a versão do **binary do recovery** (baseado em 11.9), não do sistema. O sistema boota corretamente em 11.11 (`BP4A.251205.006`). Isso é normal.

---

## ⚠️ CORREÇÕES CRÍTICAS (contra o plano original)

| Item no plano original | Realidade verificada | Impacto |
|------------------------|----------------------|---------|
| Estado diz "slot _a online, bootloop no slot _b" | Log `/tmp/revory.log` confirma: recovery Evolution X, **todas as partições no slot `_b`** (`system_b`, `vendor_b`, etc.), factory reset **concluído** (`Data wipe complete.`, `Enabled ADB.`) | O device **já está no slot _b em recovery**, não no bootloop descrito |
| SHA256 da ROM marcado como `pendente` | `sha256sum` executado → `79236f9b4259cf5df124dcd7176f8b4c30de0d755e189e8a4224a03e365422fb` | ROM validada contra integridade |
| Fase 3 (factory reset + sideload) como se não tivesse acontecido | Log mostra wipe completo + ADB habilitado | **Pular wipe** — dados já foram apagados |
| Bootloader não listado como passo imediato | `fastboot getvar unlocked` deve ser verificado antes de qualquer flash | Adicionado como pré-condição hard |

---

## 📊 ESTADO ATUAL VERIFICADO (2026-10-29, agora)

| Propriedade | Valor | Observação |
|-------------|-------|------------|
| **Recovery** | Evolution X Recovery (slot `_b`, log `/tmp/revory.log`) | Online — mas cabo USB desconectado agora |
| **ADB (recovery)** | Habilitado (`I: Enabled ADB.`) | Confirma recovery ativo |
| **Slot ativo** | `_b` (todas as partições `_b` no log) | ✅ Alvo correto |
| **Factory reset** | **Concluído** (`Data wipe complete.`) | Fase 3 wipe = feito |
| **ROM EvolutionX 11.11** | `/home/cnmfs/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip` — 3.6 GB | SHA256: `79236f9b4259cf5df124dcd7176f8b4c30de0d755e189e8a4224a03e365422fb` |
| **Recovery img** | `/home/cnmfs/nothing-phone2/downloads/recovery.img` — 100 MB | Já flashado (recovery está rodando) |
| **Boot images** | `stock_boot.img` (SHA `6f2c638f…`) + `apatch_patched_boot.img` (SHA `f57c7db7…`) em `backups/snapshot-4-root-active/` | Checksums validados |
| **Root** | ❌ Não aplicado | APatch pendente (Fase 5) |
| **Bootloader** | ? (precisa confirmar via fastboot) | Deve estar `unlocked: yes` |

---

## ✅ O QUE FAZER AGORA (continuidade)

### Passo 1: Reconectar device e confirmar estado
```bash
# 1. Reconectar cabo USB ao device que está no recovery Evolution X
# 2. Verificar ADB:
adb devices
# Esperado: 9f51ecb9  recovery  (ou "unauthorized" → autorizar na tela)

# 3. Confirmar slot de verdade via recovery:
adb shell getprop ro.boot.slot_suffix
# Esperado: _b
```

### Passo 2: Validar integridade da ROM antes do sideload
```bash
sha256sum /home/cnmfs/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip
# Esperado: 79236f9b4259cf5df124dcd7176f8b4c30de0d755e189e8a4224a03e365422fb
```

### Passo 3: Sideload EvolutionX 11.11 (timeout garantido)
```bash
# No recovery: Apply Update → Apply from ADB
# No PC (timeout ≥ 1800s — o zip tem 3.6 GB):
timeout 1800 adb sideload /home/cnmfs/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip
```
- **NÃO cancelar** se parecer travado em ~47% (é normal — Lição #7).
- Após 100%, clicar **YES** na tela quando pedir "reboot recovery to install additional packages".

### Passo 4: Reboot system + validar boot
```bash
# No recovery: Reboot system now
# Aguardar 90-120s, depois:
adb devices
# Esperado: 9f51ecb9  device
adb shell getprop sys.boot_completed
# Esperado: 1
adb shell getprop ro.build.display.id
# Esperado: BP4A.251205.006
```

### Passo 4.5: Validar compatibilidade do harness com a versão 11.11
**Por quê:** O EvolutionX 11.11 (BP4A.251205.006) mudou APIs do framework; ferramentas de root/tricks que funcionavam em 11.9 podem falhar em 11.11.

```bash
# Verificar versões do kernel e do framework
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.incremental
adb shell getprop ro.build.fingerprint
adb shell getprop ro.kernel.version

# Verificar se o recovery (Evolution X) é compatível com o slot _b
adb shell getprop ro.build.display.id
# Esperado: BP4A.251205.006
```

**Regra:** Antes de aplicar root, módulos ou tricks, confirmar que a versão 11.11 é suportada pela ferramenta. Se a ferramenta só suporta 11.9, **não tentar forçar** — isso quebra o fingerprint e a biometria.

---

### Passo 5: Root APatch (após boot estável)
```bash
adb reboot bootloader
fastboot getvar unlocked        # deve ser "yes"
fastboot --set-active=b         # garantir slot _b
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
sha256sum -c <<< "f57c7db7d948a906ebe63370e6cb481e72a5bebd1b7e0b027bab883bf70df7b4  /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img"
fastboot reboot
```

### Passo 6: Auditar módulos (após root)
```bash
adb shell su -c 'ls -la /data/adb/modules/'
# Desabilitar não-essenciais:
adb shell su -c 'touch /data/adb/modules/mountify/disable'
adb shell su -c 'touch /data/adb/modules/zygisk_shamiko/disable'
# Manter ativos: zygisknext, tricky_store, playintegrityfix
```

---

## 📱 TAREFAS COMPLEMENTARES (a serem executadas após o boot estável)

### T1 — Desbloqueio Google (GMS / Play Store / YouTube)
**Por quê:** A versão Vanilla não inclui os apps Google. Sem GMS, Play Store e YouTube não funcionam.

**Como:**
```bash
# 1. Baixar o pacote GApps compatível com Android 16 / EvolutionX 11.11
#    (OpenGApps pico ou nano, ou MicroG para Vanilla)
# 2. No recovery: Apply Update → Apply from ADB
# 3. No PC:
timeout 1800 adb sideload <caminho-do-gapps.zip>
# 4. Clicar YES na tela quando pedir "reboot recovery"
# 5. Reboot system now
```

**Critério de verificação:**
```bash
adb shell pm list packages | grep -iE 'com.google.android.gms|com.android.vending|com.youtube'
# Esperado: com.google.android.googleapis, com.android.vending (Play Store), com.youtube.android
```

**⚠️ Compatibilidade do harness:** O GApps deve ser da versão correta para Android 16 (API 36). Usar GApps builds compatíveis com o build BP4A.251205.006.

---

### T2 — Fingerprint / Biometria
**Por quê:** Requisito explícito do usuário. O fingerprint pode quebrar após root (APatch) ou após instalação de módulos.

**Como (após root):**
```bash
# Verificar serviço de biometria
adb shell pm list packages | grep -iE 'biometric|fingerprint'
adb shell dumpsys sensorservice | grep -i fingerprint | head -5

# Teste manual: Settings → Security → Fingerprint → Registrar → Testar desbloqueio
```

**Critério de verificação:**
- [ ] Fingerprint registra (até 5 dedos)
- [ ] Fingerprint desbloqueia a tela
- [ ] Fingerprint funciona em apps de banco (se houver)

**⚠️ Compatibilidade do harness:** APatch + ZygiskNext pode interferir no fingerprint. Se quebrar:
1. Desativar ZygiskNext temporariamente
2. Testar fingerprint
3. Se funcionar, configurar ZygiskNext para não interceptar biometria

---

### T3 — Câmera Otimizada
**Por quê:** A câmera do Nothing Phone 2 depende do vendor blob e do kernel. ROMs custom podem causar câmera lenta, travamento ou falha de abertura.

**Como:**
```bash
# Verificar se a câmera abre
adb shell am start -n com.android.camera/com.android.camera.CaptureActivity
# Se travar, tentar a câmera de terceiros (GCam, etc.)

# Verificar vendor blob e HALs
adb shell getprop ro.vendor.camera.hal.version
adb shell getprop ro.camera.feature.forced

# Verificar logs de câmera
adb shell logcat -b main -t 100 | grep -iE 'camera|camcorder' | head -20
```

**Critério de verificação:**
- [ ] Câmera abre sem crash
- [ ] Foto é tirada e salva na galeria
- [ ] Vídeo grava sem travamento
- [ ] Câmera frontal funciona

**⚠️ Compatibilidade do harness:** EvolutionX 11.11 pode ter configuração de câmera específica. Verificar se há opções de "force camera2" ou "disable camera2 probe" no settings do EvolutionX.

---

### T4 — Google Play Store / YouTube
**Por quê:** YouTube não funciona sem GMS. Depois de instalar GApps (T1), testar YouTube.

**Como:**
```bash
# Verificar YouTube
adb shell pm list packages | grep com.youtube
adb shell am start -n com.youtube.android/com.youtube.android.activity.MainActivity

# Teste manual: Abrir YouTube → reproduzir um vídeo
```

**Critério de verificação:**
- [ ] YouTube abre
- [ ] Vídeo reproduz sem travamento
- [ ] Login funciona (se houver conta Google)

---

### T5 — Tricks / Otimizações
**Por quê:** Melhorar experiência do EvolutionX 11.11.

**Como:**
```bash
# Verificar opções de otimização no EvolutionX
adb shell settings get global ntp_server
adb shell settings get system animation_scale

# Verificar freeform windows
adb shell pm list packages | grep freeform

# Verificar áudio
adb shell settings get system audio_sfx_enabled
```

**Tricks comuns:**
- Ativar freeform windows (se disponível)
- Ajustar animações (animation_scale 0.5x para mais velocidade)
- Desativar efeitos sonoros se causarem problemas

---

## 🚫 O QUE **NÃO** FAZER (do / don't list)

### ❌ NÃO faça nunca

1. **Flashar para slot `_a`** — a política `flash-policy-pong.md` é HARD: _"só slot _b, nunca _a"_. Slot `_a` tem snapshots mais antigos → Frankenstein garantido → bootloop (provado 2026-08-10).

2. **Sobrescrever `snapshot-4-root-active/`** — fazer backup de novo timestamp antes de qualquer modificação. Regra documentada no AGENTS.md.

3. **Cancelar sideload em ~47%** — Lição #7: parece travado mas está progredindo normalmente. Cancelar = reiniciar do zero (3.6 GB ≈ 5-8 min).

4. **Assumir slot sem confirmar** — Erro #1 do AGENTS.md. Sempre `getprop ro.boot.slot_suffix` antes de flash.

5. **Flashar boot sem validar SHA256** — Erro #4 do AGENTS.md. SHA mismatch = abortar.

6. **Ignorar `fastboot getvar unlocked`** — se bootloader estiver travado, flash falha. Verificar primeiro.

7. **Flashar APatch sem `fastboot boot` teste prévio** — política diz: testar via `fastboot boot` primeiro, flash definitivo só após KMI/CRC verificado.

### ❌ Não faça (neste momento)

8. **Aplicar root via APatch se o boot ainda não terminou** — Fase 5 só após `sys.boot_completed = 1` (Fase 4).

9. **Habilitar todos os módulos de uma vez** — Lição #6: módulo incompatível = bootloop. Ativar apenas `zygisknext` + `tricky_store` + `playintegrityfix` inicialmente.

---

## 🆘 ROLLBACK (se algo der errado)

```bash
# Se bootloop após APatch:
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot --set-active=b
fastboot reboot

# Se slot _b totalmente quebrado:
fastboot --set-active=a
fastboot reboot
# (slot _a deve ter fallback stock ou 11.11 também)

# Se nenhum slot boota:
# Force reboot (Power + Vol Down 20s) → fastboot
# Segurar Vol Up + Vol Down + conectar USB para EDL (precisa firehose)
```

---

## 🔗 REFERÊNCIAS CRUZADAS

- **flash-policy-pong.md** — regra hard: slot `_b` apenas, `fastboot boot` para teste
- **AGENTS.md** — 6 lições de erro + checklist pré-flash obrigatório
- **device-topology-pong.md** — SM8475, EvolutionX 16, slots A/B, vermagic esperado
- **awesome-android-root/docs/rooting-guides/** — referências:
  - `how-to-root-nothing-phone.md` — passo a passo Nothing Phone
  - `apatch-guide.md` — APatch (KernelSU alternative)
  - `custom-rom-installation.md` — sideload + recovery workflow
  - `troubleshooting.md` — 44 KB de soluções de problemas comuns

---

## 📋 CHECKLIST ATUALIZADA (para marcar no recovery)

### Pré-sideload
- [x] Backup 23 GB concluído
- [x] Recovery Evolution X flashado (está rodando em recovery)
- [x] Factory reset concluído (log confirma `Data wipe complete.`)
- [x] SHA256 da ROM validada (`79236f9b42…`)
- [ ] GUARD 4: confirmação do usuário antes do sideload ✅ **[VOCÊ ESTÁ AQUI]**

### Sideload + boot
- [ ] Conectar cabo USB, `adb devices` retorna `9f51ecb9 recovery`
- [ ] `adb shell getprop ro.boot.slot_suffix` = `_b`
- [ ] Sideload EvolutionX 11.11 com `timeout 1800` → 100% + YES na tela
- [ ] Reboot system → `sys.boot_completed = 1`
- [ ] `ro.build.display.id` = `BP4A.251205.006`

### Root + módulos
- [ ] `fastboot getvar unlocked` = yes
- [ ] Flash `apatch_patched_boot.img` para `boot_b` (SHA verificado)
- [ ] `su -c id` = `uid=0(root)`
- [ ] Módulos: apenas `zygisknext`, `tricky_store`, `playintegrityfix` ativos

---

> **Próximo passo imediato:** Reconectar o cabo USB, confirmar `adb devices` mostra o device em recovery, validar SHA256 da ROM, e iniciar o sideload com `timeout 1800`. GUARD 4 — aguarde confirmação explícita antes de flashar o boot APatch.
