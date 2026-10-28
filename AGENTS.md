# AGENTS.md — Nothing Phone 2 (Pong) Recovery Playbook

> **Última atualização:** 2026-10-28  
> **Status:** Pós-batalha — erros coletados, lições documentadas  
> **Device:** Nothing Phone 2 (codinome `Pong`, SM8475)

---

## 🚨 LIÇÕES DA BATALHA (O que ERROU hoje e sempre)

### Erro #1: Assumir slot sem verificar
**O que aconteceu:** Plano dizia "slot _b em bootloop", mas device estava em `_a` (online, stock).  
**Correção:** SEMPRE confirmar `fastboot getvar current-slot` ANTES de qualquer flash.  
**Regra:** Nunca flashar no slot ativo sem confirmação explícita do usuário.

### Erro #2: Assumir causa do bootloop sem diagnosticar
**O que aconteceu:** Plano assumiu que `stock_boot.img` consertaria o bootloop no slot _b.  
**Realidade:** Bootloop foi causado por incompatibilidade APatch + módulos stock.  
**Correção:** Antes de flashar, verificar logs (`logcat -b boot`, `dmesg`) para entender causa raiz.

### Erro #3: Ignorar permissões do harness
**O que aconteceu:** Tentou executar `fastboot flash` sem permissão no `settings.local.json`.  
**Correção:** Verificar `.claude/settings.local.json` antes de qualquer comando destrutivo.  
**Regra:** Se comando requer permissão não-listada, PAUSAR e pedir ao usuário para adicionar.

### Erro #4: Não validar SHA256 antes de flash
**O que aconteceu:** Flash executado sem verificar integridade da imagem.  
**Correção:** Sempre rodar `sha256sum <arquivo>` e comparar com checksum conhecido.  
**Regra:** SHA256 mismatch = ABORTAR imediatamente.

### Erro #5: Confundir APatch com KernelSU
**O que aconteceu:** Plano usava APatch, mas user mencionou "kernel su" (possível KSU).  
**Correção:** Verificar método de root atual antes de decidir qual usar.  
**Regra:** APatch ≠ KernelSU. Verificar com `adb shell su -c 'cat /data/adb/apatch/version'` ou similar.

### Erro #6: Não verificar compatibilidade kernel × módulos
**O que aconteceu:** Kernel custom APatch incompatível com módulos stock do vendor.  
**Correção:** Após flash custom kernel, auditar módulos (`/data/adb/modules/`) e desabilitar problemáticos.  
**Regra:** Módulo desconhecido = risco de bootloop.

---

## ✅ CHECKLIST PRÉ-FLASH (obrigatório)

Antes de qualquer `fastboot flash`:

- [ ] `fastboot devices` → serial aparece
- [ ] `fastboot getvar current-slot` → confirma slot alvo
- [ ] `fastboot getvar unlocked` → deve ser `yes`
- [ ] `sha256sum <imagem>` → bate com checksum conhecido
- [ ] `.claude/settings.local.json` contém permissão para o comando
- [ ] Usuário confirmou ação (GUARD 4)
- [ ] Backup de dados críticos existe (não confiaria em `/data`)

---

## 🔧 COMANDOS DE DIAGNÓSTICO RÁPIDO

```bash
# Estado atual do device
fastboot getvar current-slot
fastboot getvar slot-successful:a
fastboot getvar slot-successful:b
adb shell getprop ro.build.display.id
adb shell getprop ro.boot.slot_suffix
adb shell su -c 'id' 2>&1 || echo "Root: INACESSÍVEL"

# Logs de boot (para diagnosticar bootloop)
adb shell logcat -b boot -t 200 | grep -iE 'error|fail|panic|watchdog'

# Módulos instalados (se root disponível)
adb shell su -c 'ls -la /data/adb/modules/'
```

---

## 🛡️ ROLLBACK SEGURO

Se algo der errado:

```bash
# Rollback para slot _a (fallback)
fastboot --set-active=a
fastboot reboot

# Se _a também estiver quebrado:
# Entrar em EDL mode (Qualcomm 9008) requer hardware tool específico
```

---

## 📁 ESTRUTURA DE BACKUP

```
backups/
├── snapshot-4-root-active/     # Último estado conhecido como "bom"
│   ├── stock_boot.img          # Kernel stock (SHA: 6f2c638f...)
│   ├── apatch_patched_boot.img # Kernel APatch (SHA: f57c7db7...)
│   ├── checksums.txt           # Hashes de todos os arquivos
│   ├── build_info.txt          # Build ID + fingerprint
│   └── modules/                # Módulos APatch usados
└── ...
```

**Regra:** Nunca sobrescrever snapshot sem criar novo timestamp.

---

## 🎯 FLUXO DE RECUPERAÇÃO (passo a passo)

```
1. Diagnosticar estado atual (slots, root, logs)
2. Validar causas do problema (não assumir)
3. Confirmar com usuário qual slot usar
4. Verificar permissões harness
5. Validar SHA256 da imagem
6. Executar flash (com log)
7. Reboot e validar boot
8. Se bootloop: rollback imediato
```

---

## 📚 REFERÊNCIAS

| Recurso | URL |
|---------|-----|
| Evolution X Pong | https://evolution-x.org/devices/Pong |
| APatch Docs | https://github.com/bmax121/APatch |
| KernelSU Docs | https://kernelsu.org |
| Nothing Phone 2 XDA | https://forum.xda-developers.com/c/nothing-phone-2 |

---

> **Nota:** Este arquivo é vivo. Atualizar após cada sessão com novos erros/lições.
