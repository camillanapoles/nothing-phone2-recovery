# Plano de Recuperação — Nothing Phone 2 travado em fastboot

## Contexto

A sessão anterior (`af543f54-4740-4b4c-9411-8049ddf8f324`) estava a executar as Fases 5d/5e do projeto Droidspaces:
- ✅ **Fases 1-4**: Diagnóstico via ADB concluído (4 subagentes paralelos)
- ❌ **Fase 5e**: `fastboot boot new-boot.img` **falhou** com `reap_urb(0) failed: Protocol error`
- 🔴 **Estado atual**: Dispositivo **travado em fastboot**
- 🎯 **Objetivo**: Recuperar o device SEM perda de dados (GUARD 4 HARD)

## Problema identificado

O `new-boot.img` foi construído em 2026-08-10 (há ~71 dias) via script `build_pong.sh`:
- Base: `stock_boot.img` (100MB, formato GKI 2.0)
- Substituição: `Image.gz` custom (18MB, PID_NS+IPC_NS ativados)
- Ramdisk: original do stock (`ramdisk.cpio`, 5MB)
- **Problema provável**: Incompatibilidade entre ramdisk original e kernel customizado, ou formato do boot image não correto para o bootloader do Pong

## Plano de recuperação (3 fases)

### Fase R1: Recuperar o dispositivo (prioridade máxima)

**Objetivo**: Reboot para o kernel stock no slot _b, sem tocar em dados

```bash
# 1. Verificar estado atual
fastboot devices
fastboot getvar current-slot
fastboot getvar is-userspace

# 2. Tentar reboot normal (deve voltar ao slot _b stock automaticamente)
fastboot reboot

# 3. Se falhar, forçar reboot para slot _b
fastboot --set-active=b
fastboot reboot

# 4. Se ainda falhar, reboot para recovery
fastboot reboot recovery

# 5. Verificar via ADB após reboot (aguardar 60s)
adb devices
adb shell getprop ro.boot.slot_suffix  # deve ser _b
```

**Critério de sucesso**: Device online via ADB, slot _b ativo, kernel stock a correr.

### Fase R2: Investigar o formato do boot image

**Objetivo**: Entender por que o `new-boot.img` falhou

```bash
# 1. Analisar o stock_boot.img (formato GKI 2.0 esperado)
file /home/cnmfs/nothing-phone2/kernel-build/boot-work/stock_boot.img
python3 -c "import struct; f=open('/home/cnmfs/nothing-phone2/kernel-build/boot-work/stock_boot.img','rb'); print('Magic:', f.read(8))"

# 2. Comparar com new-boot.img
file /home/cnmfs/nothing-phone2/kernel-build/boot-work/new-boot.img
md5sum /home/cnmfs/nothing-phone2/kernel-build/boot-work/{stock_boot.img,new-boot.img}

# 3. Verificar se magiskboot está disponível para unpack
which magiskboot
find /home/cnmfs -name "magiskboot" 2>/dev/null | head -3

# 4. Se magiskboot disponível, unpack para inspecionar estrutura
cd /tmp && magiskboot unpack /home/cnmfs/nothing-phone2/kernel-build/boot-work/stock_boot.img
ls -la /tmp/{kernel,ramdisk.cpio,header} 2>/dev/null
```

**Saída esperada**: Documento com:
- Formato do header (Android boot image v3/v4? GKI específico?)
- Tamanho e checksum de kernel + ramdisk
- Compatibilidade com bootloader do Pong (versão `00979.4-WAIPIO-1`)

### Fase R3: Reconstruir e testar (só após R1+R2 completas)

**Objetivo**: Construir novo boot image com formato correto e testar via `fastboot boot`

**Pré-requisitos**:
- R1: Device recuperado e online
- R2: Formato do boot image documentado
- Espaço em `/vendor`, `/vendor_dlkm`, `/odm` libertado (diagnóstico anterior mostrou 100% full)

**Passos**:
1. Extrair ramdisk do slot _b atual (não do stock_boot.img antigo)
2. Reconstruir `new-boot.img` com:
   - Kernel custom `Image.gz` (build-artifacts atualizado)
   - Ramdisk do slot _b (garante compatibilidade)
   - Header correto (formato GKI 2.0 validado em R2)
3. Testar via `fastboot boot new-boot.img` (sem gravar)
4. Se bootar, verificar PID_NS/IPC_NS via `ls -l /proc/1/ns/`
5. Se passar, flash definitivo para slot _b (com confirmação explícita do utilizador)

## Arquivos críticos

- `/home/cnmfs/nothing-phone2/kernel-build/boot-work/stock_boot.img` — base original (100MB)
- `/home/cnmfs/nothing-phone2/kernel-build/boot-work/new-boot.img` — tentativa falhada
- `/home/cnmfs/nothing-phone2/kernel-build/build-artifacts/Image.gz` — kernel custom (18MB, PID_NS+IPC_NS)
- `/home/cnmfs/nothing-phone2/kernel-build/build_pong.sh` — script de build
- `/home/cnmfs/.claude/projects/-home-cnmfs-nothing-phone2/memory/flash-policy-pong.md` — política de flash (só slot _b)

## Verificação final

Após R1 (recuperação):
```bash
adb shell getprop ro.boot.slot_suffix  # _b
adb shell uname -r                     # 5.10.246-gki-g4ec5491f6b5f
adb shell dmesg | grep -i "booting Linux" | tail -1
```

Após R3 (kernel custom):
```bash
ls -l /proc/1/ns/ | grep -E 'pid|ipc'  # deve mostrar pid:[...] ipc:[...]
adb shell cat /proc/config.gz | gunzip | grep -E 'PID_NS|IPC_NS'  # =y
```

## Riscos e mitigações

| Risco | Probabilidade | Mitigação |
|-------|---------------|-----------|
| Perda de dados no reboot | Muito baixa | Slot _b já ativo, fastboot reboot não grava nada |
| Bootloop após flash | Baixa | `fastboot boot` é temporário; reboot volta ao stock |
| Partições 100% cheias impedem operações | Alta | Priorizar limpeza de `/vendor` antes de R3 |
| Ramdisk incompatível | Média | Extrair ramdisk do slot _b atual, não usar stock_boot.img antigo |

## Notas

- **Nenhum dado será perdido** — todas as operações são reversíveis ou read-only
- Slot _a existe mas está desatualizado (snapshot de versão anterior) — **não usar**
- Kernel custom tem vermagic `5.10.246-gki-g4ec5491f6b5f` (bate exato com stock)
- APatch via kallsyms (não KernelSU LKM, que falha no Pong)