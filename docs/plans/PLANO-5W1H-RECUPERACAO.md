---
title: "Plano 5W1H — Recuperação e Atualização Nothing Phone 2"
created: 2026-10-28
author: "Claude Code"
status: "draft"
tags: ["recuperação", "evolutionx", "pong", "fastboot", "apatch"]
related: ["EXECUÇÃO-RECUPERAÇÃO-EVOLUTIONX.md", "flash-policy-pong.md"]
---

# Plano 5W1H — Recuperação e Atualização Nothing Phone 2 (Pong)
## Validação Etapa por Etapa com Critérios de Sucesso

**Objetivo:** EvolutionX atualizado + Google desbloqueado + Fingerprint funcionando + Zero conflitos

---

## ESTADO ATUAL DO DEVICE

| Propriedade | Valor Atual | Status |
|-------------|-------------|--------|
| **Slot** | `_a` | ⚠️ Incorreto (deve ser `_b`) |
| **Build** | BP4A.251205.006 (EvolutionX 11.11) | ✅ Versão recente |
| **Root** | `su` inacessível | ❌ Quebrado |
| **APatch app** | Instalada | ✅ Presente |
| **Verified Boot** | `green` | ✅ Intacto |
| **Fingerprint** | Não testado | ❓ Desconhecido |

---

## TABELA RESUMO 9 ETAPAS

| # | What | Why | Where | When | Who | How (Validação) |
|---|------|-----|-------|------|-----|-----------------|
| 1 | Entrar no Fastboot | Device instável, precisa acessar bootloader | Hardware (botões) | Agora | Usuário + Agente | `fastboot devices` retorna serial |
| 2 | Flash stock → slot_b | Restaurar boot funcional conhecido | Partição `boot_b` | Após Etapa 1 | Agente | `fastboot getvar slot-successful:b` |
| 3 | Reboot + validar | Confirmar que sistema inicia | Sistema Android | Após Etapa 2 | Usuário + Agente | `sys.boot_completed = 1` |
| 4 | Restaurar APatch root | Root necessário para módulos | Partição `boot_b` | Após Etapa 3 | Agente | `su -c id` = uid=0(root) |
| 5 | Auditar módulos | Remover conflitos (mountify, etc.) | `/data/adb/modules/` | Após Etapa 4 | Agente | Apenas zygisknext/tricky_store/playintegrityfix ativos |
| 6 | Validar Fingerprint | Biometria é requisito do usuário | Hardware sensor | Após Etapa 5 | Usuário | Teste físico no dispositivo |
| 7 | Atualizar EvolutionX | Versão 11.11+ requerida | Sistema via sideload | Após Etapa 6 | Agente + Usuário | `ro.build.display.id` mostra 11.11+ |
| 8 | Configurar Google | GMS, YouTube, WebView funcionem | Google Play Services | Após Etapa 7 | Agente + Usuário | Apps abrem sem erro |
| 9 | Otimizações finais | Freeform, permissões, áudio | Config sistema | Após Etapa 8 | Agente + Usuário | Testes funcionais de cada recurso |

---

## DETALHAMENTO 5W1H POR ETAPA

### ETAPA 1: Entrar no Fastboot

**What:** Forçar entrada no modo bootloader/fastboot  
**Why:** Device em slot `_a` sem root funcional; precisa acessar fastboot para comutação  
**Where:** Hardware do device (botões físicos) → interface fastboot  
**When:** Imediatamente — antes de qualquer comando fastboot  
**Who:** Usuário executa (botões), Agente monitora (comando)  
**How:** `fastboot devices` → espera resposta  

```bash
# Comando (executar após usuário pressionar botões)
timeout 30 fastboot devices
# Esperado: 9f51ecb9  fastboot
```

**Critério de Sucesso:**
```
fastboot devices → retorna "9f51ecb9  fastboot"
```

**Risco:** Cabo USB solto → verificar conexão física  
**Rollback:** Repetir combinação de botões (Vol Up + Vol Down + Power, 10s)

---

### ETAPA 2: Flash stock_boot.img para slot _b

**What:** Flash imagem stock conhecida para partição `boot_b`  
**Why:** Slot `_b` está com kernel custom que causa bootloop; stock é estável  
**Where:** Partição `boot_b` do dispositivo  
**When:** Após Etapa 1 confirmada (fastboot devices OK)  
**Who:** Agente executa via `fastboot flash`  
**How:** Verificar SHA256 → flash → validar  

```bash
# Verificar integridade da imagem
sha256sum /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
# Esperado: 6f2c638f2d9f99713da8bc896d2c606c6c8b414484502f21c69c056503bf97c1

# Flash
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
# Esperado: OKAY [ tempo ]

# Verificar status
fastboot getvar slot-successful:b
# Esperado: slot-successful:b: no (ainda não testado)
```

**Critério de Sucesso:**
```
fastboot flash boot_b → "OKAY"
fastboot getvar slot-successful:b → resposta sem erro
```

**Risco:** Imagem corrompida → verificar SHA256 antes  
**Rollback:** Repetir flash; se falhar repetidamente, usar modo EDL

---

### ETAPA 3: Reboot e Validar Boot

**What:** Reboot do device e validação de boot bem-sucedido  
**Why:** Confirmar que o flash funcionou e o sistema inicia  
**Where:** Sistema Android (slot _b)  
**When:** Imediatamente após Etapa 2  
**Who:** Usuário observa tela, Agente monitora ADB  
**How:** `fastboot reboot` → aguardar 60s → validar com ADB  

```bash
# Reboot
fastboot reboot
# Aguardar boot completo (60 segundos)
sleep 60

# Validar
adb shell getprop sys.boot_completed
# Esperado: "1"

adb shell getprop ro.boot.slot_suffix
# Esperado: "_b"

adb shell getprop ro.build.display.id
# Esperado: EvolutionX-16.0-...-Pong-11.9-Vanilla-Official
```

**Critério de Sucesso:**
```
sys.boot_completed = 1
ro.boot.slot_suffix = _b
ro.build.display.id contém "EvolutionX"
```

**Risco:** Bootloop persiste → verificar se imagem stock está correta  
**Rollback:** Repetir Etapa 2; se falhar, verificar cabo USB

---

### ETAPA 4: Restaurar APatch Root

**What:** Restabelecer root APatch no slot _b  
**Why:** Root necessário para módulos Zygisk, Play Integrity, e otimizações  
**Where:** Partição `boot_b` (substituir kernel)  
**When:** Após Etapa 3 validada (boot_completed=1)  
**Who:** Agente via `fastboot flash`  
**How:** Flash apatch_patched_boot.img → reboot → validar `su -c id`  

```bash
# Entrar no fastboot novamente
adb reboot bootloader
sleep 3

# Verificar imagem
sha256sum /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
# Esperado: f57c7db7d948a906ebe63370e6cb481e72a5bebd1b7e0b027bab883bf70df7b4

# Flash
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
fastboot set_active b
fastboot reboot

# Aguardar boot
sleep 60

# Validar root
adb shell su -c 'id'
# Esperado: uid=0(root) gid=0(root)

adb shell su -c 'getenforce'
# Esperado: Enforcing
```

**Critério de Sucesso:**
```
su -c id → uid=0(root)
getenforce → Enforcing
```

**Risco:** Root não restaura → verificar se APatch app está instalada  
**Rollback:** Repetir Etapa 2 (stock_boot.img) para restaurar estado anterior

---

### ETAPA 5: Auditar e Limpar Módulos

**What:** Listar e desabilitar módulos conflitantes  
**Why:** Mountify e outros módulos podem causar bootloop e conflitos  
**Where:** `/data/adb/modules/` no dispositivo  
**When:** Após Etapa 4 (root ativo)  
**Who:** Agente via `adb shell su`  
**How:** Listar módulos → criar arquivos `disable` nos problemáticos  

```bash
# Listar módulos
adb shell su -c 'ls -la /data/adb/modules/'

# Desabilitar módulos problemáticos
adb shell su -c 'touch /data/adb/modules/mountify/disable'
adb shell su -c 'touch /data/adb/modules/zygisk_shamiko/disable'
adb shell su -c 'touch /data/adb/modules/LSPosed/disable'  # Opcional

# Manter apenas essenciais
# zygisknext, tricky_store, playintegrityfix
```

**Critério de Sucesso:**
```
ls /data/adb/modules/ | grep -v disable
# Esperado: apenas zygisknext, tricky_store, playintegrityfix
```

**Verificação de conflito:**
```bash
adb shell logcat -b boot -t 100 | grep -iE 'error|fail|denied'
# Nenhum erro crítico esperado
```

**Risco:** Remover módulo essencial pode quebrar funcionalidade  
**Rollback:** Remover arquivo `disable` para reativar módulo

---

### ETAPA 6: Validar Fingerprint/Biometria

**What:** Testar funcionamento do leitor de impressão digital  
**Why:** Usuário relatou que fingerprint não funciona  
**Where:** Hardware de biometria do Pong  
**When:** Após Etapa 5 (módulos limpos)  
**Who:** Usuário executa teste físico  
**How:** Settings → Security → Fingerprint → registrar e testar  

```bash
# Verificação prévia
adb shell pm list packages | grep -iE 'biometric|fingerprint|face'
```

**Teste do Usuário:**
1. Abra **Settings** → **Security** → **Fingerprint**
2. Tente registrar uma nova impressão digital
3. Bloqueie a tela e desbloqueie com o fingerprint

**Critério de Sucesso:**
- Impressão digital registrada com sucesso
- Desbloqueio funciona consistentemente
- Nenhuma mensagem de erro

**Risco:** Sensor defeituoso (hardware) ou driver do kernel  
**Rollback:** Não há rollback (teste não modifica o sistema); documentar falha

---

### ETAPA 7: Atualizar EvolutionX para Última Versão

**What:** Instalar EvolutionX 11.11+ via sideload  
**Why:** Usuário deseja versão mais recente  
**Where:** Sistema via recovery mode (sideload)  
**When:** Após Etapa 6 (fingerprint validado ou documentado)  
**Who:** Agente (download), Usuário (recovery)  
**How:** Download ROM → reboot recovery → sideload  

```bash
# Verificar versão atual
adb shell getprop ro.build.display.id
```

**Passo a passo:**
1. Baixar EvolutionX-16.0-XXXXXX-Pong-11.11-Vanilla-Official.zip
2. `adb reboot recovery`
3. No recovery: Apply Update → Apply from ADB
4. `adb sideload EvolutionX-16.0-2026XXXX-Pong-11.11-Vanilla-Official.zip`
5. Aguardar conclusão e reboot

**Validação:**
```bash
adb shell getprop ro.build.display.id
# Esperado: EvolutionX-16.0-2026XXXX-Pong-11.11-Vanilla-Official
```

**Critério de Sucesso:**
```
ro.build.display.id contém "11.11" ou superior
sys.boot_completed = 1
```

**Risco:** Download corrompido ou incompatible  
**Rollback:** Usar ROM de backup em `/home/cnmfs/nothing-phone2/downloads/`

---

### ETAPA 8: Configurar Google e Desbloquear Serviços

**What:** Configurar GMS, YouTube, WebView para funcionar  
**Why:** Usuário precisa de apps Google desbloqueados  
**Where:** Sistema Android (Google Play Services)  
**When:** Após Etapa 7 (update concluído)  
**Who:** Agente (configuração), Usuário (teste)  
**How:** Verificar packages → ajustar permissões → testar apps  

```bash
# Verificar packages Google
adb shell pm list packages | grep -iE 'google|gms|youtube|webview|microg'

# Verificar status do GMS
adb shell dumpsys package com.google.android.gms | grep enabled

# Verificar Play Integrity
adb shell su -c 'java -jar /data/adb/tricky_store/tricky_store.jar integrity'
```

**Testes do Usuário:**
1. Abrir **Google Play Store** → fazer login
2. Abrir **YouTube** → reproduzir vídeo
3. Abrir **Chrome** → navegar em site

**Critério de Sucesso:**
- Google Play Services instalado e habilitado
- YouTube abre e reproduz vídeos
- WebView funciona (apps que usam webview funcionam)
- Play Integrity passa (DEVICE_INTEGRITY)

**Risco:** GMS corrompido após update  
**Rollback:** Limpar cache: `adb shell pm clear com.google.android.gms`

---

### ETAPA 9: Otimizações Finais

**What:** Configurar freeform window, permissões de banco, áudio  
**Why:** Usuário deseja experiência Android 16 otimizada  
**Where:** Configurações do sistema  
**When:** Após Etapa 8 (Google funcionando)  
**Who:** Agente (comandos), Usuário (teste)  
**How:** Configurações via adb shell + testes funcionais  

```bash
# Freeform window (já instalado: com.libremobileos.freeform)
adb shell pm list packages | grep freeform

# Desabilitar melhorias de áudio do sistema
adb shell settings put sound audio_sfx_enabled 0

# Verificar permissões de apps de banco
adb shell dumpsys package br.com.bb.android | grep granted=true
```

**Testes do Usuário:**
1. **Freeform:** Abrir app → multitarefa → janela flutuante
2. **Banco:** Abrir app do banco → verificar se não bloqueia
3. **Áudio:** Reproduzir música → verificar qualidade

**Critério de Sucesso:**
- Freeform window funciona
- Apps de banco abrem sem erro de segurança
- Áudio limpo (sem distorção)

---

## CHECKLIST DE SEGURANÇA (Pré-Execução)

- [x] Backup SD card confirmado (`/home/cnmfs/backups/` — 23GB)
- [x] Backup Termux confirmado (`/home/cnmfs/backups/termux/`)
- [x] Backup RikkaHub confirmado (`downloads/rikkahub-backup/`)
- [x] Imagens stock verificadas (SHA256)
- [x] Política de flash respeitada (só slot `_b`)
- [ ] GUARD 4 aplicado (confirmação do usuário em cada fase crítica)

---

## MATRIZ DE RISCO

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Bootloop após flash | Média | Alto | Rollback para stock_boot.img |
| Perda de dados | Baixa | Alto | Backup prévio confirmado |
| Root não restaura | Baixa | Médio | Verificar apatch_patched_boot.img |
| App de banco bloqueia | Média | Médio | PlayIntegrityFork + TrickyStore |
| Fingerprint não funciona | Alta | Médio | Testar com stock primeiro |
| Update ROM falha | Baixa | Alto | Repositório de backup da ROM |

---

## CRONOGRAMA ESTIMADO

| Etapa | Tempo Estimado | Acumulativo |
|-------|---------------|-------------|
| 1. Fastboot | 5 min | 5 min |
| 2. Flash stock | 5 min | 10 min |
| 3. Reboot validar | 2 min | 12 min |
| 4. Restaurar root | 5 min | 17 min |
| 5. Auditar módulos | 3 min | 20 min |
| 6. Validar fingerprint | 5 min | 25 min |
| 7. Atualizar EvolutionX | 15 min | 40 min |
| 8. Configurar Google | 5 min | 45 min |
| 9. Otimizações | 5 min | 50 min |

**Total estimado:** ~50 minutos

---

## COMANDOS DE RECUPERAÇÃO DE EMERGÊNCIA

```bash
# Rollback completo (tudo para estado inicial)
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot set_active b
fastboot reboot

# Se device não entrar no fastboot
# Forçar: Volume Up + Volume Down + Power (10s)
```

---

## PRÓXIMA SESSÃO — Continuidade

**Para continuar:**
```bash
claude
# Carregar contexto:
cat docs/plans/PLANO-5W1H-RECUPERACAO.md
# Iniciar execução:
/harness-work 1
```

---

*Plano elaborado com base em conhecimento do projeto, awesome-android-root, e políticas de flash do Pong.*
