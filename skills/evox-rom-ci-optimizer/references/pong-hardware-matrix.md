# Matriz de Hardware — Nothing Phone 2 (`pong`, SM8475)

> **Origem:** absorve e substitui a skill autônoma `evox-pong-ci-architect` (descontinuada na
> v3.1 para eliminar duas fontes de verdade sobre o mesmo pipeline).
> **Alvo:** Evolution X 11.11 / Android 16 (API 36) em Nothing Phone 2 — Snapdragon 8+ Gen 1
> (`SM8475`, cortex-X2/A710/A510 + Adreno 730), leitor Goodix óptico, câmeras Sony IMX890 + JN1.
> **Uso:** consultado pela Wave 2 (Device Profile), Wave 3 (performance/câmera) e pelo Gate 10
> (release pre-USB) do `SKILL.md`.

## 1. Dois níveis de verificação

| Nível | O que valida | Ferramenta |
|---|---|---|
| **Estrutural (estático)** | pacotes, XML de permissão, bibliotecas `arm64-v8a`, `system.prop`, sobreposição de arquivos críticos | `scripts/static_conflict_scanner.py`, `scripts/audit_rom_conflicts.sh` |
| **Comportamental (QEMU/KVM)** | inicialização do sistema, Free-Form/WindowManager, scripts de boot, estabilidade de `system_server` | `scripts/runtime_module_tester.sh` + `references/evox-ci-validator.yml` (o `evox-ci-pipeline.yml` antigo está em `references/archive/`) |

> O emulador **não** reproduz sensor físico proprietário (Goodix/IMX890) nem o TEE do SoC:
> aprovação comportamental não substitui a matriz estática nem libera `persist`.

## 2. Matriz PASS/FAIL por componente (12 + release artifact)

| # | Componente | Foco no `pong` | PASS se | FAIL se |
|---|---|---|---|---|
| 1 | **APatch / Kernel Config** | KMI GKI 2.0 compatível com a build 11.11; tamanho da imagem ≤ partição | KMI casa com `boot.img` e o repack preserva compressão | KMI diverge, imagem excede partição ou sem `boot_stock_rollback.img` |
| 2 | **Camera (GCam + HAL)** | IMX890/JN1, `Camera2API Level 3`, `priv-app` | todo `priv-app` tem `privapp-permissions-*.xml` válido (`xmllint`) e nenhum `.so` de câmera é sobrescrito | falta XML de permissão ou colisão em `/vendor/etc/camera` |
| 3 | **Google Unlocked (GApps A16)** | só `arm64-v8a`, API 36 | sem pacote duplicado contra GApps nativos da Evolution X | duplicata de pacote ou ABI divergente |
| 4 | **Screen Capture** | captura sem conflito com `surfaceflinger` | serviço gráfico sobe sem erro de classe no boot test | crash de `SurfaceFlinger`/`SystemUI` |
| 5 | **DroidSpaces / Free-Form** | `enable_freeform_support`, namespaces | props de multi-janela aplicadas sem restart da UI; namespaces presentes | restart de UI ou namespace ausente |
| 6 | **Fingerprint (Goodix óptico)** | calibração em `persist` | nenhum pacote toca `persist` nem arquivos `fingerprint.*` | qualquer escrita em `persist` → **FAIL fatal irreversível** |
| 7 | **Play Integrity / bancos** | SELinux `Enforcing` | `getenforce == Enforcing` e JSON/XML de config íntegros | SELinux `Permissive` ou config inválida |
| 8 | **Ambient Open CI** | custo/idle | `timeout-minutes ≤ 25`, `concurrency` com `cancel-in-progress` | ausência das travas |
| 9 | **CPU/GPU/RAM/Bateria** | `schedutil`/`walt`, ZRAM, freezer | parâmetros dentro do envelope X2/A710/A510 + Adreno 730 | valor fora de faixa ou escritor concorrente de `sysfs` |
| 10 | **Áudio** | Dolby/ViPER | **um único** `audio_effects.xml` consolidado e validado | duas árvores XML concorrentes |
| 11 | **Continuidade CI/CD** | cache de ferramentas | pipeline estático + emulado dentro da janela planejada | estouro de tempo/custo |
| 12 | **Snapshot Backup duplo** | duas branches dedicadas | `backup/pong-system` (manifestos, hashes de `boot`/`init_boot`/`persist`) e `backup/pong-userdata` (GCam XML, áudio, preferências) versionados separadamente | backup misturado ao código principal |
| 13 | **Release Artifact (pre-USB)** | pacote homologado | 12 itens PASS + `SHA256SUMS` + rollback | qualquer item pendente → **bloquear USB** |

## 3. Gotchas do modelo (erros já observados)

1. **`persist` é sagrado.** Guarda a calibração de fábrica do leitor óptico. `dd`/`rm`/`fastboot
   erase` em `persist` = perda permanente de biometria. O scanner trata qualquer escrita como
   conflito fatal (regra `R06_PERSIST_WRITE`).
2. **SELinux `Enforcing` é requisito de produto** (bancos + Play Integrity), não preferência.
3. **`priv-app` sem XML de permissão impede o boot** no Android 16 — não é "feature ausente".
4. **Backups em repositório privado** obrigatoriamente (hashes de partição + dados de conta).
5. **`Adreno 730` + cluster X2**: valores de governor copiados de outros SoCs superaquecem ou
   derrubam o `system_server`; só aceitar presets derivados do `pong`.
6. **Slot A/B**: confirmar `ro.boot.slot_suffix` antes de qualquer conclusão sobre "qual boot
   está rodando" (lição registrada no `AGENTS.md`).

## 4. Snapshot duplo (nomenclatura canônica do `pong`)

| Branch | Conteúdo |
|---|---|
| `snapshot/rom-base` | manifesto da ROM + hashes de `boot`, `init_boot`, `vendor_boot`, `vbmeta` |
| `snapshot/kernel-kpm` | `boot_patched.img`, `boot_stock_rollback.img` + `.sha256`, `.kpm` embutidos |
| `snapshot/modules-wave1` … `wave4` | bundle All-in-One por onda + `conflict_report.json` |
| `backup/pong-system` | manifestos de pacotes e hashes de partições críticas |
| `backup/pong-userdata` | perfis GCam, áudio, preferências de apps |

Tags semânticas: `v11.11-w<N>-clean`. Todo snapshot carrega `snapshot_manifest.json`
(gerado por `scripts/snapshot_branch_manager.sh`).
