---
name: evox-pong-ci-architect
description: Guia de arquitetura e engenharia de CI/CD no GitHub Actions para pre-validacao de configuracoes, compatibilidade de pacotes e organizacao de snapshots para Android 16 (Evolution X 11.11) no Nothing Phone 2 (Pong / Snapdragon 8+ Gen 1). Use quando a usuaria solicitar revisao de workflows GitHub Actions com encerramento automatico por inatividade, verificacao de conflitos de configuracao entre os 12 componentes (Root/Kernel, Camera, GApps, Screen Capture, Free-Form Windows, Fingerprint, Play Integrity, Ambient CI, CPU/GPU/RAM/Battery/Containers, Audio, Continuidade CI/CD e Snapshot Backup em branches separadas) e preparacao de Release Artifacts antes da instalacao via USB.
---

# Guia de Arquitetura: EVOX-PONG-CI-ARCHITECT

## Resumo

Este guia estrutura a verificacao automatizada de customizacoes para a ROM Evolution X 11.11 (Android 16 / API 36) voltada ao hardware Nothing Phone 2 (`pong`, Qualcomm Snapdragon 8+ Gen 1 / SM8475). Ele aplica a metodologia da Fabrica de Agentes para validar configuracoes no GitHub Actions com encerramento automatico por inatividade, auditar conflitos entre os 12 modulos do projeto e organizar backups em branches separadas antes da conexao USB.

## Quando Usar

* Configurar ou otimizar pipelines no GitHub Actions com emulador Android (QEMU/KVM) e limites de custo/inatividade.
* Auditar compatibilidade e evitar colisoes de arquivos XML, propriedades de sistema e permissoes entre os 12 modulos definidos para o Nothing Phone 2.
* Estruturar a estrategia de Snapshot em duas frentes no mesmo repositorio (estado de sistema e arquivos de configuracao).
* Gerar o checklist de Release Artifact antes de aplicar atualizacoes no dispositivo fisico via USB.

## 1. Fundamentos de Engenharia (Hardware vs. Emulador)

Para garantir precisao tecnica no Nothing Phone 2 (`pong`), a validacao pre-instalacao e dividida em dois niveis complementares:

1. **Verificacao Estrutural (Estatica):** Analisa os pacotes, arquivos de permissao XML, bibliotecas de 64 bits (`arm64-v8a`), propriedades `system.prop` e ausencia de sobreposicao de arquivos criticos da ROM Evolution X 11.11.
2. **Verificacao Comportamental (QEMU/KVM no GitHub Actions):** Utiliza uma imagem oficial do Android Emulator (API 35/36) sobre QEMU com aceleracao KVM para validar a inicializacao do sistema, configuracoes de janela livre (Free-Form) e scripts de configuracao sem risco para o aparelho fisico.

## 2. Matriz de Verificacao dos 12 Componentes + Release Artifact

| # | Componente | Foco de Otimizacao (Nothing Phone 2 - Pong) | Criterio de Validacao (PASS/FAIL) |
| :--- | :--- | :--- | :--- |
| **1** | **APatch / Kernel Config** | Compatibilidade de versao de kernel GKI 2.0 e organizacao de modulos no diretorio padrao. | PASS se a versao de KMI for compativel com a imagem `boot.img` da build 11.11 e o tamanho da imagem respeitar o limite da particao. |
| **2** | **Camera (GCam + Otimizacao)** | Suporte aos sensores Sony IMX890 / Samsung JN1 (`Camera2API` Level 3) e permissoes de `priv-app`. | PASS se todo aplicativo privilegiado possuir seu arquivo `privapp-permissions-*.xml` valido (validado via `xmllint`). |
| **3** | **Google Unlocked (GApps A16)** | Pacotes base compativeis com Android 16 (API 36) apenas em 64 bits (`arm64-v8a`). | PASS se nao houver conflito de pacotes duplicados com os GApps nativos da Evolution X. |
| **4** | **Screen Capture** | Ajustes de captura de tela e janela sem conflito com o `system_server`. | PASS se o servico grafico iniciar normalmente no teste de emulacao sem erros de classe. |
| **5** | **DroidSpaces / Free-Form** | Ativacao de janelas livres (`enable_freeform_support`) e suporte a namespaces/containers no Android 16. | PASS se as propriedades de multi-janela forem aplicadas sem causar reinicializacao da UI. |
| **6** | **Fingerprint (Goodix Optical)** | Preservacao da calibracao optica na particao `persist` e das bibliotecas originais do sensor. | PASS se nenhum pacote modificar arquivos de biometria (`fingerprint.*` ou `/mnt/vendor/persist`). |
| **7** | **Compatibilidade Bancaria (Play Integrity)** | Manutencao do SELinux em modo `Enforcing` e validacao de arquivos de configuracao JSON/XML. | PASS se nenhum modulo alterar o SELinux para `Permissive` e os arquivos JSON tiverem sintaxe integra. |
| **8** | **Ambient Open CI (GitHub Actions)** | Execucao do pipeline com `timeout-minutes` curto e cancelamento automatico de runs duplicadas. | PASS se o workflow tiver `timeout-minutes <= 25` e controle de `concurrency` configurado. |
| **9** | **CPU/GPU/RAM/Bateria & Box** | Ajustes de escalonamento para Snapdragon 8+ Gen 1 (`schedutil`/`walt`), ZRAM e suporte ao `Cached App Freezer`. | PASS se os parametros respeitarem os limites da Adreno 730 e dos clusters Cortex-X2/A710/A510. |
| **10** | **Som (Audio Effects)** | Unificacao de efeitos de audio (Dolby / ViPER) em um unico `audio_effects.xml` para evitar conflitos. | PASS se existir apenas uma arvore XML consolidada e validada para o subsistema de audio. |
| **11** | **Continuidade CI/CD** | Cache de ferramentas no GitHub Actions e execucao automatica a cada alteracao na pasta de configuracoes. | PASS se o pipeline concluir a checagem estatica e emulada dentro da janela planejada. |
| **12** | **Snapshot Backup Duplo** | Separacao em duas branches dedicadas no mesmo repositorio: `backup/pong-system` e `backup/pong-userdata`. | PASS se o manifesto de sistema e o pacote de configuracoes forem versionados separadamente do codigo principal. |
| **13** | **Release Artifact (Pre-USB)** | Empacotamento final com lista de verificacao e hashes `SHA-256` antes da conexao via cabo USB. | PASS se todos os 12 itens anteriores estiverem aprovados e os checksums conferidos. |

## 3. Fluxo Operacional em 4 Etapas

1. **Coleta e Auditoria de Conflitos (DAG):**
   * Liste todos os caminhos de arquivos presentes nos 12 modulos.
   * Verifique se dois modulos tentam modificar o mesmo arquivo de sistema (por exemplo, `audio_effects.xml` ou `system.prop`). Caso positivo, unifique as alteracoes antes do build.
2. **Controle de Custos e Inatividade no GitHub:**
   * Em workflows do GitHub Actions, configure sempre `timeout-minutes: 25` e `concurrency` com `cancel-in-progress: true`.
   * Em ambientes GitHub Codespaces, configure o tempo de desligamento automatico (`Idle Timeout`) para 15 ou 30 minutos nas configuracoes da conta.
3. **Teste em Emulador (QEMU/KVM):**
   * Utilizando `reactivecircus/android-emulator-runner` com aceleracao KVM no Ubuntu, inicie uma instancia enxuta (`-no-window -no-audio -no-boot-anim`), aplique as propriedades de sistema e verifique se `sys.boot_completed` atinge o valor `1` sem travamentos do `system_server`.
4. **Organizacao de Snapshots e Geracao da Release:**
   * Mantenha duas branches independentes (orfas) no repositorio privado:
     * `backup/pong-system`: guarda manifestos de pacotes, hashes de particoes criticas (`boot`, `init_boot`, `persist`) e referencias da versao da ROM.
     * `backup/pong-userdata`: guarda perfis XML da GCam, preferencias de audio e configuracoes de modulos.
   * Gere a Release com arquivo `SHA256SUMS` e mecanismo de seguranca contra bootloop antes de conectar o aparelho via USB.

## 4. Regras de Ouro e Prevencao de Erros (Gotchas)

* **Protecao do Sensor Digital (Nothing Phone 2):** Nunca modifique ou limpe a particao `persist` do aparelho, pois ela armazena a calibracao de fabrica do leitor optico de digitais.
* **SELinux Enforcing:** Para que aplicativos bancarios e verificacoes de integridade funcionem (Item 7), o SELinux deve permanecer em modo `Enforcing`. Rejeite configuracoes que desativem o SELinux globalmente.
* **Permissoes de Priv-App no Android 16:** Qualquer aplicativo adicionado em `/system/priv-app` ou `/product/priv-app` (como portes de camera) exige um arquivo XML correspondente em `etc/permissions/`. A ausencia desse arquivo impede a inicializacao do Android.
* **Repositorio Privado para Backups:** Certifique-se de que o repositorio do GitHub esteja configurado como **Privado** antes de sincronizar snapshots nas branches de backup.
