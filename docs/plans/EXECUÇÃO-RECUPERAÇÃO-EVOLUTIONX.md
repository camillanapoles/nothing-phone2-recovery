---
title: "Plano de Recuperação e Atualização — Nothing Phone 2"
created: 2026-10-28
author: "Claude Code (Session fdd47776)"
status: "active"
tags: ["recovery", "evolutionx", "pong", "root", "fingerprint"]
---

# Plano de Execução — Nothing Phone 2 (Pong)
## Objetivo: EvolutionX atualizado + Google desbloqueado + Fingerprint funcionando

**Criado:** 2026-10-28
**Sessão original:** fdd47776-aa3d-4561-a20e-8e5a32a880fc
**Estado atual:** Device em bootloop no slot `_b`, precisa recuperação

---

## GOAL ORIGINAL (Solicitado pelo usuário)

1. **Atualizar EvolutionX** para última versão (11.11+)
2. **Google desbloqueado completo** — GMS, YouTube, WebView funcionando
3. **Fingerprint/Biometria** funcionando corretamente
4. **Zero conflitos de módulos** — remover desnecessários
5. **App de banco** funcionando (sem bloqueios de segurança)
6. **Otimização Android 16 unlocked 2026** — estado da arte

**NÃO necessário:** Droidspaces (PID_NS/IPC_NS)

---

## ESTADO ATUAL DO DEVICE

| Propriedade | Valor | Status |
|-------------|-------|--------|
| **Slot** | `_b` | ⚠️ Bootloop |
| **Build** | BP4A.251205.006 (EvolutionX 11.9) | Desatualizado |
| **Root** | APatch instalado mas `su` inacessível | ❌ Broken |
| **Verified Boot** | `green` | ✅ Intacto |
| **Fingerprint** | Não testado (bootloop) | ❓ Desconhecido |
| **SD Card** | 23GB backup no host | ✅ Protegido |

---

## KNOWLEDGE BASE CONSULTADA

### Fonte: awesome-android-root
- Práticas recomendadas de rooting Android
- Segurança: backup antes de qualquer ação
- Rootings seguros: APatch preferível a KSU para kernels modificados
- Módulo mountify pode causar conflitos

### Fonte: Projeto (arquivos locais)
- **flash-policy-pong.md**: Flash apenas para slot `_b`, nunca `_a`
- **AGENT.md**: Procedimento de flash recovery + sideload
- **audit-20260925/RELATORIO.md**: Estado histórico dos slots
- **kernel-build/**: Scripts de build de kernel custom

---

## ANÁLISE DE IMPACTO (evidências)

### O que MUDA:
| Arquivo/Partição | Antes | Depois | Risco |
|-----------------|-------|--------|-------|
| `boot_b` | Kernel custom (falho) | `stock_boot.img` | Baixo |
| `slot-successful:b` | `no` | `yes` (após flash) | — |
| Root APatch | Quebrado | Restaurado (fase 3) | — |

### O que NÃO muda:
- `/data` (apps, configs, Termux)
- `/sdcard` (DCIM, Documents, Downloads)
- Slot `_a` (permanece como fallback)
- Partições system/vendor/product

---

## PLANO DE EXECUÇÃO (6 FASES)

### FASE 1: Recuperação do slot `_b`
**Objetivo:** Restaurar boot funcional com kernel stock

```bash
# 1.1 Verificar device em fastboot
fastboot devices

# 1.2 Flash stock_boot.img para slot_b
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img

# 1.3 Confirmar slot ativo
fastboot --set-active=b

# 1.4 Reboot
fastboot reboot

# 1.5 Validar boot (aguardar 60s)
sleep 60
adb -s 9f51ecb9 shell "getprop ro.boot.slot_suffix"  # Deve retornar _b
adb -s 9f51ecb9 shell "getprop ro.build.display.id"  # EvolutionX 11.9
```

**DoD (Definition of Done):**
- [ ] Device bootou normalmente (não em bootloop)
- [ ] Slot `_b` ativo confirmado
- [ ] ADB conectado (`adb devices` mostra `device`)

---

### FASE 2: Restaurar Root APatch
**Objetivo:** Reativar root no slot `_b`

```bash
# 2.1 Verificar se su está acessível
adb -s 9f51ecb9 shell "su -c 'id'"  # Esperado: uid=0(root)

# 2.2 Se falhar, flash apatch_patched_boot.img
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
fastboot set_active b
fastboot reboot

# 2.3 Validar root após boot
adb -s 9f51ecb9 shell "su -c 'id'"
adb -s 9f51ecb9 shell "su -c 'getenforce'"  # Deve retornar Enforcing
```

**DoD:**
- [ ] `su -c id` retorna `uid=0(root)`
- [ ] SELinux em `Enforcing`
- [ ] APatch app instalada e funcional

---

### FASE 3: Auditar e Limpar Módulos
**Objetivo:** Remover módulos conflitantes e desnecessários

```bash
# 3.1 Listar módulos instalados
adb -s 9f51ecb9 shell "su -c 'ls -la /data/adb/modules/'"

# 3.2 Desabilitar módulos potencialmente problemáticos
adb -s 9f51ecb9 shell "su -c 'touch /data/adb/modules/mountify/disable'"
adb -s 9f51ecb9 shell "su -c 'touch /data/adb/modules/zygisk_shamiko/disable'"

# 3.3 Manter apenas essenciais
# - ZygiskNext (necessário para LSPosed)
# - TrickyStore (Play Integrity)
# - PlayIntegrityFork (bypass de segurança)
```

**Módulos para manter:**
- `zygisknext` — Base para módulos Zygisk
- `tricky_store` — Play Integrity spoofing
- `playintegrityfix` — Bypass de verificação

**Módulos para remover/desabilitar:**
- `mountify` — Causa conflitos conhecidos
- `zygisk_shamiko` — Root hiding (opcional)
- `LSPosed` — Se não necessário para bancos

**DoD:**
- [ ] Apenas módulos essenciais ativos
- [ ] Nenhuma mensagem de erro nos logs (logcat)
- [ ] Apps de banco funcionam

---

### FASE 4: Atualizar EvolutionX
**Objetivo:** Instalar versão mais recente (11.11+)

```bash
# 4.1 Verificar versão atual
adb -s 9f51ecb9 shell "getprop ro.build.display.id"

# 4.2 Download da última EvolutionX para Pong
# URL: https://evolution-x.org/devices/Pong/
# Arquivo: EvolutionX-16.0-XXXXXX-Pong-11.11-Vanilla-Official.zip

# 4.3 Sideload via recovery
adb -s 9f51ecb9 reboot bootloader
fastboot flash recovery recovery.img  # Se necessário
fastboot reboot recovery

# No recovery: Apply Update → Apply from ADB
adb sideload EvolutionX-16.0-2026XXXX-Pong-11.11-Vanilla-Official.zip
```

**Nota:** Se 11.11 não disponível, usar última versão estável.

**DoD:**
- [ ] Build display.id mostra 11.11 ou superior
- [ ] Sistema boota sem erros
- [ ] Root APatch ainda funciona

---

### FASE 5: Configurar Google e Biometria
**Objetivo:** Garantir funcionamento de apps Google e fingerprint

```bash
# 5.1 Verificar status do Google Play Services
adb -s 9f51ecb9 shell "pm list packages | grep google"
adb -s 9f51ecb9 shell "pm list packages | grep gms"

# 5.2 Verificar Play Integrity
adb -s 9f51ecb9 shell "su -c 'java -jar /data/adb/tricky_store/tricky_store.jar integrity'"

# 5.3 Testar fingerprint
# Abrir Settings → Security → Fingerprint
# Registrar nova impressão digital

# 5.4 Verificar certificados
adb -s 9f51ecb9 shell "su -c 'cat /system/etc/security/cacerts/*' | head -50"
```

**DoD:**
- [ ] Google Play Services funciona
- [ ] YouTube abre e reproduz vídeos
- [ ] Fingerprint registrado e funciona
- [ ] Apps de banco abrem sem erro de segurança

---

### FASE 6: Otimizações Finais
**Objetivo:** Configurar freeform window, permissões, áudio

```bash
# 6.1 Freeform window (já instalado: com.libremobileos.freeform)
adb -s 9f51ecb9 shell "pm list packages | grep freeform"

# 6.2 Verificar permissões de apps de banco
adb -s 9f51ecb9 shell "dumpsys package br.com.bb.android | grep -A 20 'granted=true'"

# 6.3 Otimização de áudio
# Desabilitar melhorias de áudio do sistema
adb -s 9f51ecb9 shell "settings put sound audio_sfx_enabled 0"
```

**DoD:**
- [ ] Freeform window funciona
- [ ] Permissões de banco OK
- [ ] Áudio limpo (sem distorção)

---

## CHECKLIST DE SEGURANÇA

- [x] Backup SD card confirmado (23GB no host)
- [x] Backup Termux confirmado (`/home/cnmfs/backups/termux/`)
- [x] Backup RikkaHub confirmado (`/home/cnmfs/nothing-phone2/downloads/rikkahub-backup/`)
- [x] Imagens stock disponíveis (`backups/snapshot-4-root-active/`)
- [x] Política de flash respeitada (só slot `_b`)
- [x] GUARD 4 aplicado (confirmação explícita do usuário antes de flash)

---

## COMANDOS DE RECUPERAÇÃO (Rollback)

Se qualquer fase falhar:

```bash
# Rollback para estado anterior
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot set_active b
fastboot reboot
```

---

## PRÓXIMA SESSÃO — Instruções de Continuidade

1. **Iniciar nova sessão** com:
   ```bash
   claude
   ```

2. **Carregar contexto:**
   ```bash
   /harness-work 1
   ```

3. **Verificar estado inicial:**
   ```bash
   adb devices
   fastboot devices
   ```

4. **Executar FASE 1** (recuperação do slot `_b`)

5. **Reportar progresso** após cada fase

---

*Plano criado com base em conhecimento do projeto e referência awesome-android-root.*
