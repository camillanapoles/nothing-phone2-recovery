---
name: evox-rom-ci-optimizer
description: Sistema multi-agente (EVOX-FORGE, CI-SANDBOX-PROBE, CONFLICT-INQUISITOR) especialista em engenharia pre-flash, customizacao offline e validacao em emulador Android via GitHub Actions da ROM Evolution X 11.11 (Android 16 / API 36). Use quando o usuario solicitar otimizacao de ROM antes de instalar no celular, criacao de imagem base Evolution X no GitHub, injecao de root (APatch/KPM, KernelSU, Magisk/Zygisk), ajustes de kernel/KMI, desbloqueio de features ou deteccao preventiva de conflitos de modulos e bootloop em pipeline CI/CD.
---

# EVOLUTION X 11.11 PRE-FLIGHT ROM & CI EMULATOR ARCHITECT (EVOX-CI v2.0)

Sistema operacional cognitivo multi-agente sob arquitetura `Atomic-DAG-SoC` para engenharia pre-flash, empacotamento deterministico e validacao automatizada em emulador Android (KVM/Cuttlefish/AVD em GitHub Actions) da ROM **Evolution X 11.11 (Android 16 / API 36 - Baklava)** antes do deploy em dispositivo fisico (producao).

## Quando Usar Esta Skill

- Criacao e manutencao de imagem base da **Evolution X 11.11** em repositorio GitHub (extracao de `payload.bin`, conversao de particoes dinamicas `super.img` e geracao de imagem de teste para CI/CD).
- Injecao offline (pre-flash) de ajustes de kernel (GKI 2.0 / KMI, LKM, AnyKernel3, `kptools`), solucoes de Root (**APatch** `.kpm`/`.apm`, **KernelSU**, **Magisk** + **Zygisk**) e desbloqueio de funcionalidades (`build.prop`, `system.prop`, overlays RRO, `sepolicy.rule`, spoofing e debloat).
- Execucao de **Staging / Pre-Validacao em Emulador Android no GitHub Actions** para detectar conflitos de modulos (colisao de arquivos OverlayFS/Magic Mount, simbolos de kernel ausentes, loops em `post-fs-data.sh`, `avc: denied` e `RescueParty`) antes de instalar no celular fisico.
- Integracao pre-producao com `user:android16-root-guardian` (pos-flash) e `user:act-github-pat` (execucao local de workflows via `nektos/act`).

## Recursos Embutidos na Skill

- `Makefile`: Orquestrador local (`make check`, `make audit`, `make extract`, `make patch-boot`, `make bundle`, `make run-act`).
- `install_local.sh`: Instalador idempotente para Linux (Pop!_OS/Ubuntu) e Termux, configurando o comando CLI `evox-ci` e a estrutura de repositorio GitHub.
- `scripts/audit_rom_conflicts.sh`: Varredura deterministica de colisao de inodes, duplicidade Zygisk/Root, `post-fs-data.sh`, `kallsyms` KMI e pacotes protegidos contra `RescueParty`.
- `scripts/extract_evox_base.sh`: Extrator automatizado do `payload.bin` da Evolution X 11.11 com geracao de manifesto SHA-256 e dump de `kallsyms`.
- `scripts/patch_boot_offline.sh`: Injetor offline de Root e KPMs em `boot.img` / `init_boot.img` (APatch `kptools`, KernelSU, Magisk) com geracao automatica de imagem de rollback.
- `scripts/build_safe_module_bundle.sh`: Construtor de modulo consolidado All-in-One com injecao do Watchdog Anti-Bootloop de 120s.
- `references/evox-ci-pipeline.yml`: Workflow completo do GitHub Actions com emulador KVM Android 16 (API 36).
- `references/android16-evox-safelist.json`: Lista canonica de pacotes intocaveis da Evolution X 11.11 / Android 16.
- `assets/watchdog_anti_bootloop_service.sh` e `assets/evox_tuning_preset.prop`: Templates operacionais prontos para injecao.
