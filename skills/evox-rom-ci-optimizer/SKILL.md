---
name: evox-rom-ci-optimizer
version: 3.2.0
description: >
  Sistema multi-agente (EVOX-FORGE, CI-SANDBOX-PROBE, CONFLICT-INQUISITOR, SNAPSHOT-KEEPER)
  especialista em engenharia pre-flash Dual-Stage da ROM Evolution X 11.11 (Android 16 / API 36)
  para Nothing Phone 2 (pong / SM8475): extracao deterministica de payload.bin, patch offline de
  kernel/root (APatch+KPM, KernelSU, Magisk/Zygisk), validacao em AVD (API 36) no GitHub
  Actions com trava de custo zero, gestao de snapshots em branches/tags e validacao incremental
  de 15 componentes + 3 plataformas externas (MaxManager, Duck-ToolBox, Qualcomm GenieX).
  Use quando a usuaria pedir otimizacao/validacao de ROM antes do flash, criacao de imagem base
  Evolution X no GitHub, injecao de root/KMI, matriz de conflitos de modulos ou prevencao de
  bootloop em pipeline CI/CD.
license: uso interno — Camilla N. / fabrica-de-agentes
---

# EVOX-CI v3.2 — Dual-Stage ROM & QEMU CI Orchestrator (instrução canônica + engine executável)

> **Composicao deste arquivo:** esta skill e a fusao **nao-destrutiva** de duas geracoes:
> **v3.0** (spec de orquestracao: 4 sub-agentes, 5 ondas, 15 modulos, 10 testes binarios) e
> **v2.0** (pacote operacional completo: `scripts/`, `references/`, `assets/`, `Makefile`,
> `install_local.sh` e catalogo de tecnicas T01–T10). Nada foi descartado:
> o documento canonico v2.0 esta em `references/archive/evox-ci-v2.0-canonical-drive-export.md`
> e o resumo v2.0 em `references/archive/evox-ci-v2.0-SKILL.md`.

Sistema operacional cognitivo multi-agente sob arquitetura `Atomic-DAG-SoC` para engenharia
pre-flash, versionamento particionado e validacao incremental na ROM **Evolution X 11.11
(Android 16 / API 36 / Baklava)** antes de qualquer contato com o cabo USB.

## Regra de precedência (instrução > repositório)

Este repositório é **incompleto por desenho**: ele registra o que já rodou, não o que foi
prometido. A hierarquia de verdade é:

1. `references/module-matrix-5w1h.md` — **a instrução** (15 módulos + 3 plataformas, 5W1H). Vence sempre.
2. `references/external-engines-arbitration.md` — regras `R01..R09` que o scanner deve aplicar.
3. `SKILL.md` (este arquivo) — como o agente se comporta.
4. `scripts/` — o que a máquina realmente executa hoje.
5. Resto do repositório (`docs/`, `.github/`) — evidência histórica, não contrato.

Se (4) divergir de (1)/(2), **corrija o script** — não reescreva a instrução para caber no código.

---

## 0. Delta de capacidade (o que a v3.1 adiciona sobre v2.0 e sobre v3.0 isolada)

| Eixo | v2.0 (pacote) | v3.0 (spec) | **v3.2 (esta skill)** |
|---|---|---|---|
| Sub-agentes | 3 (FORGE, PROBE, INQUISITOR) | 4 (+ `SNAPSHOT-KEEPER`) | 4 com backend executavel para cada um |
| Escopo de modulos | "conjunto de modulos" | 15 componentes em 5 ondas | 15 componentes + `M12A/M12B/M08` + matriz 5W1H rastreavel |
| Validacao | 10 testes binarios (v2) | 10 testes binarios (v3, com `static_conflict_scanner.py`) | 10 testes com runner (`Makefile`) e evidencia por artefato |
| Backends | 4 scripts | nenhum script (spec pura) | **8 scripts** + 13 testes de regra (R00–R09) |
| Estado/snapshot | backup ad-hoc | `snapshot/<camada>/<tag>` + manifesto | `snapshot_branch_manager.sh` + manifesto SHA-256 por artefato |
| Custo CI | `timeout-minutes` | trava dupla (`cancel-in-progress` + timeout + `.devcontainer`) | trava dupla + `references/devcontainer.json` versionado |
| Rastreabilidade | README | narrativa | `Makefile` (`check/scan/forge/audit/bundle/snapshot/runtime-test/run-act`) |

---

## I. Fundamento filosofico e arquitetura Dual-Stage (fisica vs. virtualizacao)

1. **Estagio A — Engenharia offline da ROM (`EVOX-FORGE`):** desempacotamento de `payload.bin`,
   configuracao de `boot.img`, `init_boot.img` e `system.img`, verificacao de KMI (GKI 2.0),
   patch de root/KPM e analise estatica de conflitos (`CONFLICT-INQUISITOR`).
2. **Estagio B — Validacao dinamica em emulador (`CI-SANDBOX-PROBE`):** execucao automatizada
   sobre AVD no GitHub Actions para testar modulos, scripts de inicializacao e estabilidade
   de `SystemServer`/`Zygote`, com encerramento automatico por inatividade
   (`cancel-in-progress: true` + `timeout-minutes`).

**Filosofia operacional (herdada da v2.0):** *nenhum byte modificado toca a flash do aparelho
antes de provar estabilidade matematica num runner efemero.* O emulador no CI e o escudo
descartavel; o Nothing Phone 2 fisico e o santuario intocavel.

**Anti-identidade:** nunca recomendar `fastboot flash` de modulo experimental sem pipeline;
nunca tratar a ROM como caixa-preta; nunca aceitar "deve funcionar" como evidencia — aprovacao
exige `sys.boot_completed=1` e matriz de colisao `CLEAN`.

---

## II. Quando usar

- Criar/manter a imagem base da Evolution X 11.11 em repositorio GitHub (payload.bin → particoes
  → imagem de teste para CI).
- Injetar offline root e kernel: **APatch** (`.kpm`/`.apm`, `kptools`, superkey), **KernelSU**,
  **Magisk + Zygisk**, validando `(versao-patchlevel-androidrelease-KMI)`.
- Rodar a matriz estatica de conflitos antes de combinar 2+ modulos (OverlayFS / Magic Mount).
- Executar smoke test de boot na AVD (API 36) e capturar `logcat`/`dmesg`/`dumpsys`.
- Empacotar release artefato pre-USB com manifesto SHA-256, relatorio `conflict_report.json`
  e script de rollback.
- Handoff: `android16-root-guardian` (pos-flash no device) e `act-github-pat` (rodar workflows
  localmente com `nektos/act`).

---

## III. Topologia de validacao incremental em 5 ondas (Waves 1–5)

- **Wave 1 — Fundacao de kernel e containers**
  - **M01 Kernel & Root Management (Guard-4):** valida `boot.img`/`init_boot.img` com backup
    SHA-256 obrigatorio → `scripts/patch_boot_offline.sh`, `scripts/forge_patcher.sh`.
  - **M05 DroidSpaces:** namespaces de kernel (`PID`, `IPC`, `UTS`, `NET`, `USER`, `CGROUPS`)
    para systemd/LXC.
- **Wave 2 — Servicos Google Android 16 e atestacao**
  - **M03 GApps A16:** permissoes `sysconfig` e overlays AOSP.
  - **M07/M08 Device Profile, Play Integrity & `Duck-ToolBox`:** props de build e contrato
    modular (`duckd` CLI + WebUI).
- **Wave 3 — Governanca termica, performance, camera e IA local**
  - **M12A `MaxManager`:** unico arbitro de CPU/GPU/RAM/ZRAM/Thermal (`Max Atlas` + `Max AI`).
  - **M12B `qualcomm/GenieX`:** runtime local QAIRT para GGUF em NPU/GPU/CPU.
  - **M02 Camera (GCam + HAL):** Camera2/RAW sem colisao em `/vendor/etc/camera`.
- **Wave 4 — Janelas, captura, storage e rede**
  - **M04/M06 Screen Capture & Free-Form Windows.**
  - **M09 SAF:** provedores de armazenamento e permissoes de diretorio.
  - **M10/M11 Rede por UID & Port-Forward intranet.**
- **Wave 5 — Continuidade CI, snapshots e release pre-USB**
  - **M13 Ambient Open CI:** execucao continua com trava de custo.
  - **M14 Snapshot Backup por partes (`SNAPSHOT-KEEPER`):** `snapshot/<camada>/<versao-tag>`.
  - **M15 Release Artifact Pre-USB:** bundle homologado + `conflict_report.json` + rollback.

---

## IV. Sub-agentes e mapa de backend executavel

| Sub-agente | Papel | Backend nesta skill |
|---|---|---|
| `EVOX-FORGE` | Extracao, patch offline, empacotamento | `scripts/extract_evox_base.sh`, `scripts/forge_patcher.sh`, `scripts/patch_boot_offline.sh`, `scripts/build_safe_module_bundle.sh` |
| `CI-SANDBOX-PROBE` | Emulacao em AVD (API 36), runtime test, telemetria | `scripts/runtime_module_tester.sh`, `references/evox-ci-validator.yml`, `references/devcontainer.json` |
| `CONFLICT-INQUISITOR` | Auditoria hostil, matriz de colisao, veto | `scripts/audit_rom_conflicts.sh`, `scripts/static_conflict_scanner.py`, `references/android16-evox-safelist.json` |
| `SNAPSHOT-KEEPER` | Versionamento por branch/tag, manifesto | `scripts/snapshot_branch_manager.sh` |

Regras de arbitragem detalhadas (MaxManager, Duck-ToolBox, GenieX, DroidSpaces) em
`references/external-engines-arbitration.md`; escopo de cada módulo em
`references/module-matrix-5w1h.md`; matriz do `pong` em `references/pong-hardware-matrix.md`.

**Regra de veto:** `CONFLICT-INQUISITOR` tem poder de bloquear a release. Sem
`conflict_report.json` com `status == "CLEAN"`, `SNAPSHOT-KEEPER` nao cria tag e o bundle
nao sai do runner.

### Protocolo de handoff (template)

```text
HANDOFF: EVOX-FORGE -> CI-SANDBOX-PROBE -> CONFLICT-INQUISITOR -> SNAPSHOT-KEEPER
ALVO: Evolution X 11.11 (Android 16 / API 36) | <build-id> | KMI <string>
CAMADAS: base(SHA256) + root(engine/kpimg) + modulos(lista) + tweaks(lista)
CRITERIOS: 0 colisoes de arquivo | kallsyms OK | boot_completed<180s | 0 RescueParty
           | post-fs-data total < 8s | SELinux Enforcing
SE REJEITADO: apontar modulo + evidencia de log; devolver ao FORGE em <= 3 ciclos
```

---

## V. Protocolo de validacao — 10 testes binarios

| # | Teste | PASS se | FAIL se | Acao se FAIL |
|---|---|---|---|---|
| 1 | Trava de custos CI/Codespaces | `cancel-in-progress: true`, `timeout-minutes` e `.devcontainer` presentes | Qualquer trava ausente | Injetar travas antes de rodar |
| 2 | Guard-4 Backup & KMI | `boot_patched.img` com KMI compativel e `boot_stock_rollback.img` salvo | KMI divergente ou sem backup | Abortar Estagio A |
| 3 | Colisao estatica zero | `static_conflict_scanner.py` retorna `CLEAN` (0 colisoes de arquivo/prop) | `status == "CONFLICT"` | Mesclar ou isolar modulo |
| 4 | Compatibilidade DroidSpaces | namespaces presentes e montagens limpas para containers | namespace ausente / conflito de mount | Ajustar config antes da Wave 2 |
| 5 | Arbitragem MaxManager / Duck-ToolBox | `Max Atlas` sem scripts concorrentes e `duckd` sem conflito de contrato | conflito de escrita | Desativar script redundante |
| 6 | Boot e soft-reboot no QEMU | `sys.boot_completed=1` em `< 180s` e estavel apos restart | timeout ou reboot | Bisect automatico da onda |
| 7 | Zero crashes nativos/Java | 0 `FATAL EXCEPTION`, `SIGSEGV`, `RescueParty` no logcat | ≥1 crash | Reverter ultimo modulo |
| 8 | Regras de rede e port-forward | M10 (por app) e M11 (intranet) operacionais | erro de rede/socket | Corrigir config |
| 9 | Snapshot branch & tag | branch `snapshot/<layer>` + tag semantica + manifesto SHA-256 | ausencia de tag/manifesto | Rodar `snapshot_branch_manager.sh` |
| 10 | Gate pre-USB release artifact | bundle com imagens validadas, relatorio `CLEAN` e rollback | qualquer item ausente | Bloquear liberacao para USB |

---

## VI. Como operar (CLI objetiva)

```bash
cd skills/evox-rom-ci-optimizer
chmod +x install_local.sh scripts/*.sh assets/*.sh

make help           # catalogo de alvos
make check          # bash -n + JSON schema + self-test do auditor (cenario limpo)
make extract ROM_PATH=/caminho/EvolutionX_11.11_ota.zip
make scan           # scanner estatico dos 15 modulos (JSON + codigo de saida)
make test           # regressao das regras R00..R09 (13 cenarios sinteticos)
make audit          # matriz de conflitos -> workspace/out/conflict_matrix_report.md
make forge ENGINE=apatch SUPERKEY="<superkey>"
make bundle         # All-in-One + Watchdog Anti-Bootloop 120s
make snapshot LAYER=wave1 TAG=v11.11-w1-clean
make runtime-test   # AVD (API 36) + ADB (requer device/emulador acessivel)
make run-act        # executa references/evox-ci-validator.yml via nektos/act
```

Contrato de pastas de trabalho: `modules/` (`.zip` Magisk/KSU/APM), `kernel_patches/` (`.kpm`),
`tweaks/` (`system.prop`, XML), `workspace/extracted/` (particoes), `workspace/out/` (artefatos).

---

## VI-A. Abertura de sessão: briefing obrigatório + pergunta Vanilla × GAPPS

Antes de qualquer Wave 1, o agente **explica e pergunta** — não decide sozinho qual build usar.
A pergunta só é legítima se vier com o trade-off explícito:

| Critério | Vanilla (`16_vanilla/…-11.11-Vanilla-Official.zip`) | GAPPS (`16/…-11.11-Official.zip`) |
|---|---|---|
| O que já vem | AOSP + Evolve, sem Google | AOSP + Google Apps + serviços |
| Play Services / banking | exige flash manual de GApps ou microG | pronto, com conta Google |
| M03 do escopo | **não satisfeita** até você instalar GApps | satisfeita de origem |
| Superfície de conflito | menor (menos priv-app, menos `.so`) | maior (GMS, sysconfig, permissões) |
| Tamanho / boot | menor, mais rápido | maior, mais serviços em background |
| Controle de identidade | total (você escolhe o pacote e o fingerprint) | fingerprint do build Evolve + Duck-ToolBox |
| Play Integrity | caminho mais longo (props manuais) | caminho mais curto (build já certificada) |
| Recomendado quando | mínimo, privacidade, laboratório, GApps própria | uso diário completo com IA/Google já funcionando |

**Regra:** registrar a escolha + a justificativa no `workspace/decision.json` (versão, URL, sha256
esperado) e só então baixar/extrair. Sem decisão registrada, o pipeline para (exit 2).

## VI-B. Fechar a lacuna L4 com o pacote da ROM (não com o aparelho)

L4 (kernel/KMI + hashes de `boot`/`vendor_boot`/`vbmeta`) **vem do `.zip` oficial**, porque é o
pacote que será gravado. O device não é fonte de hash — ele só confirma slot/fingerprint (read-only).

```bash
# 1. binário que desempacota payload.bin (única dependência dura da L4)
go install github.com/ssut/payload-dumper-go@latest   # ou o release pré-compilado

# 2. extrair e fechar L4 (hash do zip como trava anti-ROM-trocada)
./scripts/extract_rom_assets.sh \
  --zip EvolutionX-16.0-20260915-Pong-11.11-Official.zip \
  --expect-sha256 <sha256 publicado/baixado> \
  --out ./workspace/rom_assets --json

# 3. conferir (exit 0 = L4 fechada)
jq '{kernel_version, kmi, l4_closed, l4_missing, images}' ./workspace/rom_assets/rom_assets.json
```

Contrato: `exit 0` L4 fechada · `2` uso · `3` falta `payload-dumper-go` (nada é inventado) ·
`4` zip inválido/sem `payload.bin` · `5` hash do zip não confere · `6` extraiu mas L4 não fecha.
Regressão: `./tests/test_extract_rom_assets.sh` (15 cenários, stub, sem rede e sem device).

O que cada imagem entrega depois:

| Imagem | Uso |
|---|---|
| `boot.img` | base do patch (APatch/KernelSU-Next) e leitura do kernel/KMI |
| `boot_stock_rollback.img` | cópia **byte-idêntica** do `boot.img` da ROM, com `.sha256` (Guard-4) |
| `vendor_boot.img` | módulos vendor/KMI, base do módulo de watchdog |
| `vbmeta.img` | referência de AVB/verity para saber o que o patch vai invalidar |
| `init_boot.img` · `dtbo.img` | initramfs e overlay de device tree (contexto do estágio A) |

## VI-C. Binários externos: o que instalar e por quê

| Binário | Necessário para | Instalação |
|---|---|---|
| `payload-dumper-go` | **L4** e Wave 1 (extrair payload.bin) | `go install github.com/ssut/payload-dumper-go@latest` ou release em `github.com/ssut/payload-dumper-go/releases` |
| `strings` (binutils) | ler `Linux version`/KMI do `boot.img` | `apt install -y binutils` |
| `unzip` · `python3` · `sha256sum` | manifesto, hashes, scanner | `apt install -y unzip python3 coreutils` |
| `kptools` | patch APatch/KPM (M01) | release `github.com/bmax121/KernelPatch/releases` |
| `magiskboot` | unpack/repack de `boot.img` | `github.com/topjohnwu/Magisk` (MagiskBoot) |
| `abootimg` | fallback de unpack legado | `apt install -y abootimg` |
| `adb` | estágio B no device e coleta pós-flash | `apt install -y android-tools-adb` |
| `qemu-system-x86_64` | estágio B emulador (opcional) | `apt install -y qemu-system-x86` |

Diagnóstico único: `./scripts/preflight_deps.sh --hints` e, para exigir só o da L4:
`./scripts/preflight_deps.sh --require payload-dumper-go,unzip,python3,sha256sum`.

## VI-D. Gates obrigatórios: kernel, rollout canário, cache e rollback

Nenhum deles é opcional; cada um tem script e teste próprios.

| Gate | Pergunta que responde | Script | Exit |
|---|---|---|---|
| **G-kernel** | este kernel serve para ESTA build no `pong`? | `kernel_compat_check.sh --rom-assets … --candidate …` | 0 compatível · 3 incompatível |
| **G-debitos** | quais débitos existem **agora** e o que cada um trava? | `debt_ledger.py --root . [--json\|--markdown\|--open-only]` | 0 tudo fechado · 3 há débito aberto · 1 débito sem passo |
| **G-closure** | o plano de fechamento é executável e ordenado? | `closure_gate.py --root . [--json]` | 0 executável · 1 quebrado · 4 entrada |
| **G-continuidade** | a instrução de handoff ainda serve para continuar? | `continuity_gate.py --root .` | 0 íntegra · 1 cláusula faltando · 4 entrada |
| **G-kernel-plan** | o plano do kernel atende item por item **antes** de buildar? | `kernel_build_gate.py --root . [--prebuild --kernel-tree … --config-json … --build-dir …]` | 0 pronto · 3 pendente · 1 falha · 4 entrada |
| **G-pack** | qual par (motor × kernel) faz as 10 condições serem verdadeiras? | `root_pair_solver.py --root . [--json] [--selftest] [--write-decision]` | 0 par garantido · 3 falta prova · 1 impossível/ambíguo |
| **G-motor** | o par escolhido fecha as 10 condições? | `root_engine_gate.py --engine … [--candidate …] [--kernel-evidence …] [--show-policy]` | 0 compatível · 3 pendente · 1 incompatível |
| **G-escopo** | o que está valendo é deste workspace, ou é legado que manda o contrário? | `legacy_scope.py --root .` | 0 escopo limpo · 3 legado ativo |
| **G-garantia** | os 5 requisitos do sucesso têm prova registrada? | `success_guarantee.py --root . [--evidence ev.json]` | 0 garantido · 3 pendente · 1 impossível sob a decisão |
| **G-m05** | o DroidSpaces entra na hora e no kernel que o app manda? | `droidspaces_preflight.py --static\|--kernel-evidence F\|--device --adb adb` | 0 pronto · 3 pendente |
| **G-rollout** | posso instalar o próximo módulo? | `rollout_gate.sh start/record/status` | 0 liberado · 3 bloqueado |
| **G-cache** | o artefato testado é o artefato usado? | `cache_manager.sh put/get/verify` | 0 ok · 3 miss/divergente |
| **G-rollback** | o backup é byte-idêntico à ROM oficial? | `guard4_verify.sh --boot … --backup …` | 0 verificado · 3 ausente · 4 divergente |

Regras curtas:

1. **Kernel** só entra com `model=pong`, API 36, **KMI igual** ao da ROM, mesma base `major.minor`
   e suporte declarado à build exata. "Funciona em A16" não é suporte.
2. **Um módulo por vez**: `start` → instalar só ele → reiniciar → `record` com evidência
   (`boot.ok=true`, `crashes=0`, `uptime ≥ 10 min`). Módulo `FAILED` trava o próximo até `reset`.
3. **Cache**: toda fase verde deixa artefato endereçável por SHA-256; ≤ 25 MB vai para o repo,
   acima disso vira referência externa. `verify` recomputa tudo — cache corrompido não passa.
4. **Rollback**: antes de qualquer flash, `guard4_verify.sh` tem que devolver `VERIFIED`
   (backup existe, `.sha256` confere e é igual ao `boot.img` do pacote oficial).

Referências detalhadas: [`references/kernel-selection-gate.md`](references/kernel-selection-gate.md)
(tríade kernel × ROM × device, escolha da versão estável, matriz de compatibilidade de módulo) e
[`references/rollout-and-cache.md`](references/rollout-and-cache.md) (canário, ondas, política de cache).

## VI-E. Estágio B: emulação no GitHub Actions (o que é real)

**Premissa corrigida:** a ROM do `pong` é arm64 com `vendor` do SM8475 — ela **não inicia** em
runner x86_64. O que roda é uma **AVD API 36 x86_64 com KVM**, que valida a *camada de módulos*
(overlay, props, scripts, sepolicy, Zygote), não o vendor do aparelho.

| Estágio | Onde | O que prova |
|---|---|---|
| A · forge | runner x86_64 sem KVM | payload → hashes (L4) → gate de kernel → scanner → patch → rollback verificado |
| B · sandbox | runner x86_64 **com KVM** | boot da AVD → 1 módulo por vez via `adb` → crash/AVC/uptime → evidência |
| C · release | runner x86_64 | pacote pré-USB com `SHA256SUMS` e `flash_and_rollback.sh` |
| D · device | **humano, com o cabo** | flash assistido + `collect_evidence.sh` |

Cobertura honesta do Stage B: **6 módulos validam de fato, 5 parcialmente, 4 não** (kernel-space,
NPU, câmera HAL, `sysfs` do device). A tabela por módulo está em
[`references/emulation-sandbox.md`](references/emulation-sandbox.md) §3.

Workflow pronto e lintado: [`references/evox-ci-validator.yml`](references/evox-ci-validator.yml)
· travas verificadas por `scripts/ci_workflow_lint.py` (11 regras; 12 PASS no teste) ·
injeção sequencial por `scripts/sandbox_rollout.sh` (9 PASS).

## VI-E2. HIL local (`act` + slots A/B): quando usar, o que corrigir

A AVD valida a camada de módulos; **não** valida kernel, HAL nem `/data` compartilhado. Para isso o
gate final antes do USB é o **HIL local**: `act` com o aparelho no USB, flash no slot de staging,
watchdog e rollback. Arquitetura híbrida (AVD como pré-gate barato, HIL como gate autoritativo):
[`references/act-ab-hil-review.md`](references/act-ab-hil-review.md).

Regra que evita o bootloop clássico de A/B: **`/data` é único**. Módulo experimental em
`/data/adb/modules` derruba também o slot estável no fallback. Por isso `quarantine` roda **no host,
antes** de trocar de slot, e `guard` desabilita os experimentais quando o contador estoura.
Nunca `mount --bind` sobre `/data/adb/modules` (o gerenciador de root já leu a pasta).

## VI-F. Ordem incremental ratificada (15 módulos → 6 fases)

```text
F0 fundação    M01 APatch/kernel · M05 DroidSpaces
F1 identidade  M03 GApps · M07 fingerprint · M08 Duck-ToolBox (consolida 7+8)
F2 desempenho  M12A MaxManager · M12B GenieX
F3 mídia       M02 Câmera
F4 sistema     M04 Screen Capture · M06 Free-Form · M09 SAF · M10 rede/socket · M11 port-forward
F5 entrega     M13 CI · M14 Snapshots · M15 Release pré-USB
```

A numeração original foi preservada como intenção; o que mudou (câmera de #2 → F3, captura de #4 →
F4) está justificado em [`references/module-rollout-order.md`](references/module-rollout-order.md)
§2 e §4. `rollout_gate.sh` recusa módulo fora de ordem e módulo seguinte sem PASS.

## VII. Referencias e assets embarcados

| Caminho | Funcao |
|---|---|
| `references/evox-ci-validator.yml` | Workflow cloud vigente (extract → audit → AVD API 36); o antigo `evox-ci-pipeline.yml` está em `references/archive/` |
| `references/android16-evox-safelist.json` | Whitelist deterministica de pacotes intocaveis |
| `references/devcontainer.json` | Trava de custo/idle-timeout em Codespaces |
| `references/module-matrix-5w1h.md` | **Instrução canônica**: 15 módulos + 3 plataformas em Classes 1–6, com agente/onda/5W1H |
| `references/external-engines-arbitration.md` | Regras `R01..R09` (MaxManager, Duck-ToolBox, GenieX, DroidSpaces, persist, priv-app, SELinux) |
| `references/pong-hardware-matrix.md` | Matriz PASS/FAIL do Nothing Phone 2 (`pong`) — absorve a antiga skill `evox-pong-ci-architect` |
| `references/ci-cost-locks.md` | As 4 travas de custo (concurrency, timeout 25/10, poweroff 1800 s) |
| `references/kernel-selection-gate.md` | **Gate 1**: tríade kernel × ROM × device, escolha da versão estável, compatibilidade de módulo, estratégia para o `pong` |
| `references/act-ab-hil-review.md` | **Revisão do HIL local**: 6 erros do draft (bind mount, rollback automático, `su` antes do root, `modules_stable` inexistente, AVB/`init_boot`, listas) e arquitetura híbrida corrigida |
| `scripts/abl_fallback_probe.sh` | **Captura de falha A/B**: classifica `OK` / `ABL_FALLBACK` / `HANG` / `HANG_EARLY` / `BOOTLOADER` / `NO_DEVICE`, coleta pstore/dmesg/logcat e força rollback |
| `scripts/rom_artifact_fetch.sh` | **Coleta determinística** dos dois zips da mesma build: pin por sha256, atômico, retomável, drift = exit 4, env fixo em `workspace/evox.env` |
| `references/rom-artifacts.json` | Manifesto pinado (Vanilla + GApps, build 2026-09-15) — única fonte de nome/URL/build |
| `tests/test_rom_artifact_fetch.sh` | 18 cenários: pin, idempotência, drift, sem rede, env, JSON |
| `scripts/mutation_check.py` | **Falseabilidade (Popper)**: injeta mutação real e exige que o teste falhe; sobrevivente = teste viciado. `--jobs N\|auto` paraleliza (cada mutante em cópia isolada) sem mudar o resultado |
| `scripts/proof_items.py` | **Retorno item a item**: converte o log de cada suíte em itens (`PASS`/`FAIL`), confere paridade `TOTAL` declarado × observado, emite digest sha256 e **valida de volta** (`--validate`): item apagado, status inventado, payload editado ou suíte vazia = exit 3 |
| `tests/test_proof_items.sh` | 18 cenários do retorno item a item (paridade, contiguidade de id, digest, gate contraditório, mutante vivo) |
| `references/proof-in-cloud.md` | **Onde a prova roda**: comparação medida de Actions × Cloudflare Workers × Colab × iximiuz Labs `labctl` × Linear, veredito e o fluxo com validação item a item |
| `scripts/test_vacuity_scan.py` | Análise estática de testes viciados (V1–V6: falha engolida, asserção impossível, suíte só-feliz) |
| `references/root-decision.json` | **decisão A ratificada** pela usuária (2026-11-01): motor único `apatch`, kernel `stock-rom`, `custom_kernel_allowed:false`, `susfs_allowed:false`, motores proibidos e `revisit_if` |
| `references/root-engines.json` | fatos por motor de root (mecanismo, kernel próprio, SUSFS, rollback) + `allowed` (só APatch) e `blocked_by` nos proibidos |
| `references/kernel-candidates.json` | candidatos de kernel com data, hash, suporte declarado à build pinada e `origin` (`stock-rom` × `third-party`) |
| `references/module-requirements.json` | contrato dos 15 módulos (root, motor, SUSFS, Zygisk, mount-hide) |
| `references/legacy-sources.json` | registro do que é **legado** (com carimbo "HISTÓRICO — NÃO EXECUTAR" obrigatório), do que foi **removido** (não pode voltar) e das fontes canônicas |
| `references/kernel-pair-options.json` | pares motor × kernel de 2026 com releases, custo e veredito para o DroidSpaces (A/B/C/D) |
| `references/hiding-stack.json` | pilha de ocultação sob a Decisão A com fonte primária por camada (APatch *Exclude modifications* → Zygisk Next v1.5.2 · `sha256:ce50b13f…` → Zygisk Assistant v2.1.4) e o que **não** é demonstrável |
| `references/droidspaces-requirements.json` | **M05 inteiro em dados**: app v7.1.0 + sha256 do APK, instalação em F0/W1 posição 2 depois do M01, 12 `CONFIG_*` de kernel, `proc_checks`, caminhos, R03, motores (`apatch/kernelsu/sukisu`), rollback |
| `references/mutation-catalog.json` | 168 mutantes (≥2 semânticos por arquivo, com `strength` declarada; timeout não conta como kill) + `costs` (segundos medidos por mutante) que balanceiam os shards de CI |
| `scripts/contradiction_scan.py` | Varredura de contradições (C1–C13): instrução ativa que ainda manda fazer o abandonado ou usa vocabulário ambíguo (`Gate 4`, `gate 10`, `init_boot` sem fonte) |
| `scripts/coverage_matrix.py` | Cobertura fechada: todo script tem teste ou isenção declarada (`references/audit-exemptions.json`) |
| `scripts/audit_loop.sh` | Harness de convergência: AG + scan + cobertura + suíte, em loop até estabilizar |
| `tests/test_script_contracts.sh` | 55 asserções: todo CLI responde `--help` **sem** efeito colateral (branch, commit, arquivo) |
| `scripts/architecture_guard.py` | Trava de arquitetura (AG1–AG12): impede voltar ao modelo antigo e valida que as correções seguem aplicadas |
| `tests/test_abl_probe.sh` | 12 cenários do probe (fallback, hang, hang precoce, sem device, rollback) |
| `assets/00_slot_router.sh` | Roteador A/B: `guard`/`quarantine`/`activate`/`status`/`reset` — quarentena por `disable`, sem `mount`, sem `rm -rf` |
| `tests/test_slot_router.sh` | 13 cenários do roteador (fallback, limite, ativação, recusas) |
| `references/session-opening.md` | **P1–P8 ratificados**: explicar Vanilla×GAPPS, pedir zip, autorizar binário item a item, kernel, módulos, canário, cache, USB |
| `scripts/session_open.py` | `questions` / `template` / `check` — sem `decision.json` completo, nada executa (exit 3) |
| `references/emulation-sandbox.md` | **Estágio B**: restrições reais (arm64 × x86_64, KVM), cobertura por módulo, travas de custo, alternativas avaliadas |
| `references/evox-ci-validator.yml` | Workflow de 3 estágios (forge → sandbox → release) com cache, timeouts e watchdog |
| `references/module-rollout-order.md` | **Ordem ratificada** dos 15 módulos em F0–F5, dependências e critério de saída por fase |
| `scripts/sandbox_rollout.sh` | Stage B: injeta 1 módulo por vez via `adb`, soft-reboot, coleta evidência e chama o ledger |
| `scripts/ci_workflow_lint.py` | Lint das travas de custo/segurança do workflow (11 regras) |
| `tests/test_session_open.sh` | 18 cenários: decisão incompleta trava, completa libera; P1 exige `flavor_source=user` e `auto` nunca herda variante |
| `tests/test_sandbox_rollout.sh` | 12 cenários com stub de `adb` (boot, crash, ordem, ledger) |
| `tests/test_root_pair_solver.sh` | 42 cenários: as 10 condições são avaliadas por dado, saída determinística (byte a byte e com chaves trocadas), zero literal de motor/kernel no código, vacuidade recusada, condição decorativa pega pelo selftest, AMBÍGUO quando dois pares fecham, decisão derivada não pode ser editada à mão |
| `tests/test_root_decision.sh` | 33 cenários: contrato do pack (objetivo, 10 condições falseáveis, catálogos sem lista de proibidos, decisão gerada e conferida) |
| `tests/test_root_engine_gate.sh` | 22 cenários: o gate é uma leitura do solver — C01..C10 por par, evidência de kernel injetada, sem motor default |
| `tests/test_droidspaces_preflight.sh` | 26 cenários: contrato completo, fixtures que reprovam (sha inválido, sem M01, mount-hide global, placeholder, versão divergente), evidência de kernel e device via stub de `adb` |
| `tests/test_closure_gate.sh` | 25 cenários: plano real executável, um contra-exemplo por regra K01–K16, entrada inválida, determinismo |
| `tests/test_debt_ledger.sh` | 29 cenários: estado real (7 abertos), derivação por gate (pin de 40 hex fecha B01 e não B05), débito sem passo = exit 1, fonte ausente = problema, `--open-only`/`--markdown`, determinismo |
| `tests/test_continuity_gate.sh` | 20 cenários: documento íntegro passa, cada cláusula removida reprova, caminho inexistente reprova, alvo `make` inexistente reprova, literal de motor no solver reprova, placeholder reprova, determinismo |
| `tests/test_kernel_build_gate.sh` | 35 cenários: plano real fecha 20/20, um contra-exemplo por regra (P01–P20), paridade com `droidspaces-requirements.json`, vacuidade recusada, pré-build PENDENTE sem insumo e PRONTO com árvore/config/artefatos materializados, determinismo |
| `tests/test_stage_logic.sh` | 54 cenários **semânticos** dos estágios A/B e do bundle, com fixtures e stubs (nenhum insumo ausente vira sucesso) |
| `tests/test_ci_workflow_lint.sh` | 12 cenários: cada trava removida é detectada |
| `references/rollout-and-cache.md` | **Gates 3–5**: rollout canário (1 módulo por vez), ondas, cache versionado por SHA-256, política de tamanho |
| `scripts/extract_rom_assets.sh` | Fecha a L4 pelo `.zip` oficial (kernel/KMI + hashes), sem depender do aparelho |
| `scripts/kernel_compat_check.sh` | Gate 1 executável: `COMPATIBLE`/`INCOMPATIBLE` com motivos |
| `scripts/debt_ledger.py` | **Ledger de débitos derivado**: roda `kernel_build_gate --prebuild`, `root_pair_solver`, `continuity_gate`, `session_open.py check` e o ledger canário, e lista cada débito com impacto, passo que o fecha, comando e critério (débito que fecha some sozinho; débito sem passo = exit 1) |
| `scripts/closure_gate.py` | **Plano de fechamento**: 16 regras (estrutura, ids únicos, passo completo, tipos, dependências existentes, DAG acíclico, ordem topológica, gate com comando+exit+critério, débito↔passo, débitos reais cobertos, decisão da usuária, comandos existem com as flags, staging antes do físico, sem placeholder, documentado) |
| `scripts/continuity_gate.py` | **Instrução de continuidade**: 20 cláusulas (cláusula pétrea do solver por dado, autoridade, método, mandato, PENDENTE/exit 3, requisitos, módulos, actions com SHA, box, anti-padrões, garantir, dúvida, retomada, prompt) + caminhos e alvos `make` citados existem + o solver não cita motor por nome |
| `scripts/kernel_build_gate.py` | **Plano do kernel**: `--plan` cobra 20 regras (alvo, fonte pinada, toolchain, defconfig+fragmentos, patches com política, configs do contrato e de módulo, FR/NFR falseáveis, ações com SHA, artefatos com hash, deploy, cobertura de módulos, riscos) e `--prebuild` cobra 7 (pin de 40 hex, ações com SHA, árvore com fragmento e patches, CONFIG_* provadas por evidência, artefatos gerados, paridade com o pack) |
| `scripts/root_pair_solver.py` | **Solver do pack**: enumera todos os pares (motor × kernel), avalia as 10 condições (`pack-conditions.json`) e devolve PAR_GARANTIDO/FALTA_PROVA/IMPOSSIVEL/AMBIGUO — determinístico, sem nome de motor no código, com `--selftest` de falseabilidade |
| `scripts/root_engine_gate.py` | Gate do motor: leitura do solver para um par — mostra C01..C10 com o motivo de cada falha e injeta evidência de kernel (`--kernel-evidence`) |
| `scripts/legacy_scope.py` | Guarda de escopo: legado marcado ou ausente, canônico presente, conflito declarado ainda escrito |
| `scripts/success_guarantee.py` | **Garantia prévia**: 5 requisitos (par único do pack, ocultação, integridade, zero conflito, DroidSpaces oficial) com estado PROVADO/FALTA_PROVA/IMPOSSÍVEL e o comando que fecha cada lacuna |
| `scripts/droidspaces_preflight.py` | Gate do M05: contrato estático, evidência de kernel (`--kernel-evidence`) e checagem no device (`--device --adb`, com `--expect-installed`) |
| `scripts/rollout_gate.sh` | Ledger canário: recusa 2 módulos abertos e módulo seguinte sem PASS |
| `scripts/cache_manager.sh` | Cache versionado das fases verdes (inline ≤25 MB, externo acima) |
| `scripts/guard4_verify.sh` | Prova de rollback: backup idêntico ao `boot.img` da ROM + `.sha256` |
| `tests/test_scanner_rules.sh` | Regressão das 13 regras do scanner (fixtures sintéticas, exit code contratual) |
| `tests/test_extract_rom_assets.sh` | 15 cenários: L4 pelo pacote, exits 3/4/5/6 |
| `tests/test_kernel_compat_check.sh` | 10 cenários: modelo, API, KMI, base, build, suporte declarado |
| `tests/test_rollout_gate.sh` | 13 cenários: módulo único, FAILED trava, onda não regride |
| `tests/test_cache_and_guard4.sh` | 13 cenários: cache íntegro/corrompido/externo + rollback VERIFIED |
| `references/archive/evox-ci-v2.0-canonical-drive-export.md` | Documento canonico v2.0 (33 KB, export do Google Drive) |
| `references/archive/evox-ci-v2.0-SKILL.md` | Resumo v2.0 empacotado (T01–T10) |
| `assets/watchdog_anti_bootloop_service.sh` | Auto-desativacao de modulos se `boot_completed != 1` em 120s |
| `assets/evox_tuning_preset.prop` | Preset seguro (ART speed-profile, 120 Hz, ZRAM LZ4, scheduler) |
| `Makefile` / `install_local.sh` | Orquestracao local + instalador idempotente (Linux/Termux, CLI `evox-ci`) |

---

## VIII. KPIs

1. **Pre-Flight Catch Rate:** 100% das colisoes OverlayFS, duplicidades Zygisk, erros de
   SELinux e incompatibilidades KMI detectadas antes do flash fisico.
2. **Convergencia do pipeline:** extracao + auditoria estatica + boot smoke em `< 12 min`/run.
3. **Zero bootloops em producao:** 0 hard bootloops apos os 10 testes + watchdog 120s.

---

## IX. Proveniencia

- v2.0 (skill ID Drive `159t6guozDs2cKN-Lb46bgEwurulLKW6B`): `SKILL.md` canonico, `Makefile`,
  `install_local.sh`, 8 scripts, 3 references, 2 assets.
- v3.0 (skill ID Drive `1AERBRL3F2uGyYHvxtRFF9BTY0qRCFLyO`): spec de orquestracao
  (4 sub-agentes, 5 ondas, M01–M15, 10 testes).
- v2.0-full empacotado (`1dPTanP6heM83UQhbiMPzZMTM-Lp7DTPz`): resumo v2.0 arquivado.
- Fusao v3.1: este arquivo + `Makefile` com alvos `scan/forge/snapshot/runtime-test`.
- v3.2 (2026-11-01): absorve `evox-pong-ci-architect` como `references/pong-hardware-matrix.md`;
  materializa a instrução em `references/module-matrix-5w1h.md`; implementa as regras
  `R01..R09` no scanner (antes só `R00` + duas regras parciais); adiciona `tests/` com 13
  cenários; CLI do scanner ganha `--modules-dir/--out/--strict/--json` e status `CLEAN|WARN|CONFLICT`.
