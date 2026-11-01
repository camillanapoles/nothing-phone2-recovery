# Arbitragem das 3 Plataformas Externas + DroidSpaces

> Regras que o `CONFLICT-INQUISITOR` aplica **antes** do boot. Cada regra tem um ID estável
> (`R0x`) e é verificada por `scripts/static_conflict_scanner.py` (código de violação listado).

## 1. Inventário das plataformas

| Plataforma | Repositório | Papel | Ponto de contato |
|---|---|---|---|
| **MaxManager** | `nader295/MaxManager` | plano de controle único de CPU/GPU/RAM/ZRAM/Thermal/TCP/ART | nós `sysfs`, `/data/adb/modules/` |
| **Duck-ToolBox** | `eltavine/Duck-ToolBox` | hub de atestação/perfis RKP + ferramentas via `duckd` (Rust) + WebUI | `/data/adb/modules/duck-toolbox`, Zygote64 |
| **Qualcomm GenieX** | `qualcomm/GenieX` + `qualcomm/geniex-qairt-plugin` | runtime QAIRT para GGUF em NPU Hexagon/Adreno/CPU | `/data/local/tmp/geniex`, `/dev/adsprpc-smd` |
| **DroidSpaces** | `ravindu644/droidspaces-oss` (doc: `Documentation/Installation-Android.md`) | containers Linux (LXC/systemd) em velocidade nativa | kernel namespaces, `/data/local/Droidspaces/bin` |

## 2. Regras de arbitragem (IDs consumidos pelo scanner)

| ID | Regra | Severidade | Evidência que o scanner exige | Violação |
|---|---|---|---|---|
| `R01_MAXMANAGER_EXCLUSIVITY` | Com `MaxManager` presente, CPU/GPU/Thermal/ZRAM/TCP pertencem **só** ao *Max Atlas* | FAIL | módulos concorrentes com `thermal`, `governor`, `fde`, `lkt`, `sysctl` de tuning | `MAXMANAGER_ARBITER_COLLISION` |
| `R02_MAXMANAGER_SYSCTL_SCOPE` | Com `MaxManager`, `sysctl.conf` manual só pode conter forwarding de intranet (M11) | WARN | chaves em `net.ipv4.ip_forward`, `net.*.tcp_*`, `vm.swappiness` | `SYSCTL_SCOPE_OVERLAP` |
| `R03_DROIDSPACES_SUSFS` | `DroidSpaces` + `SuSFS` = desabilitar *Hide sus mounts for all processes* | WARN (obrigatório) | ambos presentes em `modules/` | `DROIDSPACES_SUSFS_INTERACTION` |
| `R04_DUCK_TOOLBOX_CONSOLIDATION` | `Duck-ToolBox` já entrega M07/M08 + ferramentas: módulos avulsos de spoofing/RKP devem ser removidos | WARN | `Duck-ToolBox` + (`trickystore`, `pif`, `playintegrityfix`, `spoof`, `rkp`) | `DUCK_TOOLBOX_DUPLICATE_SCOPE` |
| `R05_GENIEX_NPU_PATH` | GenieX exige `/dev/adsprpc-smd` acessível; em DroidSpaces precisa de bind explícito | WARN | `geniex` presente e nenhuma referência a `adsprpc-smd` no bundle | `GENIEX_NPU_DEVICE_UNBOUND` |
| `R06_PERSIST_WRITE` | Qualquer escrita em `persist` (calibração Goodix) é fatal e irreversível | **FAIL** | membros do zip sob `persist/` ou comandos `dd`/`erase`/`rm` em `persist` | `PERSIST_WRITE_FORBIDDEN` |
| `R07_PRIVAPP_PERMISSIONS` | `priv-app` adicionado sem `privapp-permissions-*.xml` impede o boot no A16 | FAIL | app em `product/priv-app`/`system/priv-app` sem XML de permissão no módulo | `PRIVAPP_PERMISSION_MISSING` |
| `R08_SELINUX_ENFORCING` | `setenforce 0` / `selinux=permissive` quebra bancos e Play Integrity | FAIL | `setenforce 0`, `ro.boot.selinux=permissive` em scripts/props | `SELINUX_PERMISSIVE` |
| `R09_WAVE_ORDER` | Módulos de onda superior não podem depender de componente de onda inferior ausente | WARN | ordem declarada vs. presença (ex.: `maxmanager` sem kernel patch) | `WAVE_ORDER_VIOLATION` |

> **Contrato:** o scanner retorna `status: CLEAN|WARN|CONFLICT`; `CONFLICT` ⇒ `exit 1` e
> `SNAPSHOT-KEEPER` não cria tag; `WARN` ⇒ release permitida apenas com aceite explícito da
> usuária registrado no relatório.

## 3. As 3 interseções arquiteturais (por que as regras existem)

### 3.1 Duck-ToolBox já é M07 + M08 + ferramentas de sistema

Ele compila crates Rust de propósito único em um binário JSON CLI (`duckd`) com WebUI modular
baseada em contratos versionados: leitura de perfis RKP das props AOSP, geração/assinatura local
de chaves (`p256`, `p384`, `ed25519`, `x509-cert`), sumário de dispositivo/módulos, histórico de
comandos e controle de atualização/reboot — **sem tocar TEE/bootloader**.
→ Instalar dezenas de scripts soltos de spoofing ao lado dele cria conflito de escopo, não
capacidade. Regra `R04`: o hub vence, os avulsos saem.

### 3.2 MaxManager tem exclusividade de escrita (vs. M01 e M10)

Três camadas: *Max Atlas* (mapeia rotas reais do kernel), *Control Plane* (ownership ledger com
read-back) e *Max AI* (CPU, GPU, ZRAM, limites térmicos, ART/DEX, congestionamento TCP, I/O
scheduler). Dois escritores no mesmo nó `sysfs` = corrida e crash.
→ Regras `R01`/`R02`: com `MaxManager` presente, `sysctl.conf` manual fica restrito a
port-forward de intranet (M11).

### 3.3 DroidSpaces × SuSFS (incompatibilidade documentada)

A opção *"Hide sus mounts for all processes"* do `SuSFS` impede os containers Linux de darem
boot; filtros `seccomp` de shells interativos bloqueiam syscalls de container — o daemon precisa
subir como boot module em `/data/local/Droidspaces/bin`, não a partir de um shell.
→ Regra `R03`: coexistência é permitida **somente** com mount-hide global desabilitado para os
UIDs/processos do `droidspaces`.

## 4. Checklist manual (quando o scanner não alcança)

- [ ] `Max Atlas` sem `thermal-engine` concorrente ativo (`ps -A | grep -i thermal`).
- [ ] `duckd --status` responde e a WebUI carrega contrato versionado.
- [ ] `droidspaces` sobe container de teste (`ubuntu:24.04`) após `R03` aplicado.
- [ ] GenieX carrega modelo GGUF pequeno em CPU e em NPU (`/dev/adsprpc-smd` legível).
- [ ] `getenforce` = `Enforcing`; `ro.boot.slot_suffix` confere com o slot testado.
