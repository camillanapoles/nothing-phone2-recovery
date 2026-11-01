# Matriz 5W1H — 15 Módulos + 3 Plataformas Externas (contrato de escopo da v3.1)

> **Papel deste arquivo:** é a **instrução-fonte** (o que a usuária pediu), separada da execução
> (o que os scripts fazem). Quando repo e instrução divergirem, **a instrução vence** e o script
> deve ser corrigido. Nada aqui é aspiracional: cada linha tem agente responsável e onda.
>
> Legenda de agentes: `FORGE` = EVOX-FORGE · `PROBE` = CI-SANDBOX-PROBE ·
> `INQ` = CONFLICT-INQUISITOR · `KEEP` = SNAPSHOT-KEEPER · `GOV` = agent-governance-orchestrator.

## CLASSE 1 — Governança & Orquestração

| 1.1 Meta-orquestração | `GOV` | **O quê:** instanciar e reger sub-agentes com KDI (injeção de conhecimento), contrato de ferramentas e *Ownership Ledger*; **entrega:** grafo DAG + parecer de auditoria. **Quando:** Fase 0, antes de qualquer pipeline. **Onde:** ecossistema de skills + repo central. **Como:** separação atômica (FORGE/INQ/PROBE/KEEP) + 8 testes binários de governança. **Por quê:** impede agente sem governança, elimina condição de corrida sobre a mesma partição. |
|---|---|---|
| 1.2 Controle determinístico de custos | `PROBE` + `GOV` | **O quê:** blindar Actions/Codespaces contra ociosidade; **entrega:** workflow com travas + `devcontainer.json`. **Quando:** todo disparo de workflow ou abertura de Codespace. **Onde:** `.github/workflows/` + `.devcontainer/`. **Como:** `concurrency.cancel-in-progress: true`, `timeout-minutes: 25` (job), `timeout-minutes: 10` (step QEMU), `sleep 1800 && sudo poweroff`. **Por quê:** custo zero por bootloop ou VM esquecida. |

## CLASSE 2 — Imagem base, Kernel & Containers (Wave 1)

| 2.1 Imagem base Evolution X 11.11 | `FORGE` (`extract_evox_base.sh`) | **O quê:** extrair e cachear a ROM (A16/API 36); **entrega:** partições + `evox_base_manifest.json`. **Quando:** Wave 1 ou nova OTA. **Onde:** runner `ubuntu-24.04` + cache (`workspace/extracted`). **Como:** `payload-dumper-go` em `boot`, `init_boot`, `vendor_boot`, `system`, `product`, `system_ext` + SHA-256. **Por quê:** fundação imutável e cacheada (não rebaixar ~6 GB por teste). |
|---|---|---|
| 2.2 **M01** APatch Root (Guard-4) + kernel | `FORGE` (`forge_patcher.sh`) | **O quê:** patch `kpimg` + embutir `.kpm` sob Guard-4; **entrega:** `boot_patched.img` + `boot_stock_rollback.img`. **Quando:** Wave 1, logo após extrair a base. **Onde:** `workspace/extracted/boot.img`. **Como:** `abootimg`/`magiskboot` unpack → `kptools -p --image kernel --skey $APATCH_SUPERKEY --kpimg kpimg --kpm *.kpm` → repack preservando compressão. **Por quê:** root em espaço de kernel (GKI 2.0) com símbolos `kallsyms` validados offline. |
| 2.3 **M05** DroidSpaces (containers Linux) | `FORGE` + `INQ` | **O quê:** validar requisitos de kernel e instalar daemon LXC/systemd; **entrega:** checklist de namespaces + binário em `/data/local/Droidspaces/bin`. **Quando:** Wave 1, junto a kernel/root. **Onde:** kernel config + `/data/local/Droidspaces/bin` + `/data/adb/service.d/`. **Como:** checar `PID/IPC/UTS/NET/USER/CGROUPS`, subir daemon via boot module (evita bloqueio `seccomp` de shell) e **proibir** mount-hide global do SuSFS. **Por quê:** Ubuntu/Debian/Alpine/OpenWrt com systemd em velocidade nativa, sem VM. |

## CLASSE 3 — Identidade, Google Core & Atestação (Wave 2)

| 3.1 **M03 + M07** GApps A16 + Fingerprint | `FORGE` | **O quê:** habilitar serviços Google do A16 e alinhar `ro.build.fingerprint`; **entrega:** overlays `sysconfig` + `system.prop` validado. **Quando:** Wave 2, após kernel/root/DroidSpaces estáveis. **Onde:** `/system/product/etc/sysconfig` + `system.prop`. **Como:** XML de features Google/Pixel para API 36 + sincronizar props RKP/build sem colisão de chave. **Por quê:** desbloqueia IA/ecossistema A16 mantendo assinatura coerente. |
|---|---|---|
| 3.2 **M08** + Duck-ToolBox (banking/Play Integrity) | `FORGE` + `PROBE` | **O quê:** integrar Duck-ToolBox + `Zygisk-Next` + `TrickyStore`; **entrega:** módulo unificado com `duckd` CLI e WebUI ativa. **Quando:** Wave 2, depois do fingerprint base. **Onde:** `/data/adb/modules/duck-toolbox` + Zygote64. **Como:** backend Rust `duckd` gere perfis RKP, X.509/P-256 e ferramentas por contrato JSON versionado. **Por quê:** substitui vários módulos avulsos de spoofing por um hub, sem tocar TEE/bootloader. |

## CLASSE 4 — Performance, IA NPU & Câmera (Wave 3)

| 4.1 **Motor externo 1 — MaxManager** | `INQ` + `PROBE` | **O quê:** integrar MaxManager como plano de controle único de hardware; **entrega:** `MaxManager-V2.zip` auditado. **Quando:** Wave 3. **Onde:** `/data/adb/modules/` + nós `/sys/devices/system/cpu`, `/sys/class/thermal`. **Como:** *Max Atlas* mapeia rotas com *ownership ledger* e read-back; *Max AI* ajusta CPU/GPU/ZRAM/I/O/TCP/carga por app. **Por quê:** elimina corrida de escrita em `sysfs` (proíbe scripts térmicos paralelos) e habilita perfis por app com rollback. |
|---|---|---|
| 4.2 **Motor externo 3 — Qualcomm GenieX** | `FORGE` + `PROBE` | **O quê:** integrar GenieX + `geniex-qairt-plugin`; **entrega:** binários/libs QAIRT pré-validados para NPU/GPU/CPU. **Quando:** Wave 3, junto a performance/ZRAM. **Onde:** `/data/local/tmp/geniex` ou container DroidSpaces com `/dev/adsprpc-smd`. **Como:** QAIRT para modelos GGUF (LLM/VLM) no Hexagon NPU + Adreno. **Por quê:** inferência local sem API externa. |
| 4.3 **M02** Camera (GCam + HAL) | `FORGE` + `INQ` | **O quê:** injetar GCam e flags Camera2/RAW; **entrega:** camada de câmera sem colisão em `/product` e `/vendor`. **Quando:** Wave 3 (fecha hardware/multimídia). **Onde:** `/product/priv-app/` + `persist.vendor.camera.*`. **Como:** scanner garante que ninguém sobrescreve XML de câmera ou `.so` de imagem. **Por quê:** qualidade fotográfica + lentes auxiliares sem crash do `cameraserver`. |

## CLASSE 5 — Janelas, Storage (SAF) & Rede (Wave 4)

| 5.1 **M04 + M06** Screen Capture + Free-Form | `PROBE` (`runtime_module_tester.sh`) | **O quê:** habilitar captura irrestrita e multi-janela livre; **entrega:** flags de WindowManager/SurfaceFlinger validadas. **Quando:** Wave 4. **Onde:** `settings global` (`enable_freeform_support=1`, `force_resizable_activities=1`). **Como:** injeta no QEMU, `stop; start` no Zygote e checa estabilidade de SurfaceFlinger/SystemUI. **Por quê:** janelas desktop sem deadlock gráfico no A16. |
|---|---|---|
| 5.2 **M09** SAF (Storage Access Framework) | `FORGE` + `PROBE` | **O quê:** gestão completa de diretórios no SAF; **entrega:** overlay/patch de `ExternalStorageProvider`. **Quando:** Wave 4. **Onde:** `/system/priv-app/ExternalStorageProvider` + mount namespace. **Como:** validar R/W em `/Android/data` e `/Android/obb` com `--mount-master` para apps autorizados. **Por quê:** gerenciadores de arquivos, backup local e containers acessam áreas restritas. |
| 5.3 **M10 + M11** Rede/socket por app + port-forward intranet | `PROBE` | **O quê:** controlar socket/porta por UID e redirecionar portas para intranet; **entrega:** regras `netfilter`/`iptables`/eBPF + túneis `socat`/`adb reverse`. **Quando:** Wave 4 (último serviço de sistema). **Onde:** stack de rede do kernel (`iptables -m owner --uid-owner`, `nat PREROUTING`) + containers. **Como:** firewall por UID + port-forward no QEMU, checando estabilidade do `ConnectivityService`. **Por quê:** isola tráfego por app e expõe serviços do celular/DroidSpaces na intranet. |

## CLASSE 6 — CI Contínuo, Snapshots & Release (Wave 5)

| 6.1 **M13 + M14** Ambient Open CI + Snapshots | `KEEP` (`snapshot_branch_manager.sh`) | **O quê:** validação contínua a cada commit + backup modular (ROM, kernel, módulos, apps); **entrega:** branches `snapshot/<layer>` + tags + `snapshot_manifest.json`. **Quando:** Wave 5, após cada onda aprovada. **Onde:** branches `snapshot/rom-base`, `snapshot/kernel-kpm`, `snapshot/modules-wave1..4`. **Como:** SHA-256 por artefato aprovado + commit na branch da camada + tag `v11.11-wN-clean`. **Por quê:** restaurar qualquer peça isolada do Android a qualquer momento. |
|---|---|---|
| 6.2 **M15** Release Artifact pre-USB | todos + gatekeeper | **O quê:** pacote final homologado **antes** do cabo USB; **entrega:** `evox-11.11-optimized-images` + `conflict_report.json` + `flash_and_rollback.sh`. **Quando:** Wave 5, só com 10/10 testes `PASS`. **Onde:** Actions Artifacts/Releases → download para PC/celular. **Como:** empacota `boot_patched.img`, `boot_stock_rollback.img`, bundle com watchdog 120 s e `SHA256SUMS`. **Por quê:** evidência de execução em emulador antes de tocar o hardware físico. |

## Mapa rápido módulo → onda → teste que o valida

| Módulo | Onda | Gates aplicáveis |
|---|---|---|
| M01 Kernel/Root | W1 | 2 (Guard-4/KMI), 3 (colisão) |
| M05 DroidSpaces | W1 | 4 (namespaces) |
| M03 GApps A16 | W2 | 3, 7 (crashes) |
| M07/M08 Device Profile + Duck-ToolBox | W2 | 5 (arbitragem), 7 |
| M12A MaxManager | W3 | 5 (exclusividade de escrita) |
| M12B GenieX | W3 | 7, 8 (rede p/ NPU service) |
| M02 Camera | W3 | 3 (colisão de `.so`/XML), 7 |
| M04/M06 Screen Capture + Free-Form | W4 | 6 (boot/soft-reboot), 7 |
| M09 SAF | W4 | 7 |
| M10/M11 Rede + port-forward | W4 | 8 |
| M13 Ambient CI | W5 | 1 (trava de custo) |
| M14 Snapshots | W5 | 9 (branch/tag/manifesto) |
| M15 Release | W5 | 10 (gate pre-USB) |
