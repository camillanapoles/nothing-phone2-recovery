> **SUPERSEDIDO para o combo e para a ordem de instalação (2026-11-02).** A fila vigente é
> `docs/skills/INSTALL-SEQUENCE.md`, derivada de `references/install-stack.json` e cobrada por
> `make stack`. Este documento continua válido como **histórico da Decisão C** (fila M01–M15 sob
> APatch) e como registro dos conflitos declarados; qualquer instrução de módulo aqui que contrarie
> o `install-stack.json` **perde**.

# Sequência aprovada de instalação e módulos — Decisão C (ratificada 2026-11-01)

> **Escopo:** `pong` (Nothing Phone 2) · build pinada `EvolutionX-16.0-20260915-Pong-11.11` (A16/API 36)
> **Como o par é decidido:** `make pack` avalia **todos** os pares (motor × kernel) contra as
> **10 condições** (`references/pack-conditions.json`) e devolve `PAR_GARANTIDO`/`FALTA_PROVA`/
> `IMPOSSIVEL`/`AMBIGUO`. Não há motor nem kernel fixado no código nem lista de proibidos; o arquivo
> `references/root-decision.json` é **gerado** pelo solver. Hoje: nenhum par fecha as 10 — a única
> condição aberta dos três melhores pares é **C06** (CONFIG_* provadas no kernel compilado).
> **Regra de execução:** um módulo por vez, reiniciar, provar (`boot.ok`, `crashes=0`, 10 min de
> uptime), só então o próximo — `rollout_gate.sh` bloqueia o contrário.

Legenda de estado: **APROVADO** (entra na fila) · **CONDICIONADO** (prova pendente, não instalar
ainda) · **NÃO APROVADO** (fora da decisão) · **BLOQUEADO** (a decisão atual impede).

---

## 0. Pré-requisitos (antes de qualquer módulo)

| # | Passo | Comando / prova | Estado |
|---|---|---|---|
| P0.1 | ZIP oficial + sha256 da build pinada | `scripts/rom_artifact_fetch.sh --expect-sha256 <pin>` | **APROVADO** (pin já registrado) |
| P0.2 | **L4**: `boot.img`, `vendor_boot`, `vbmeta`, KMI e `CONFIG_*` extraídos **do pacote** | `scripts/extract_rom_assets.sh` → `workspace/l4/` | **CONDICIONADO** — falta rodar; é o que destrava M01/M05 |
| P0.3 | Backup stock byte-idêntico + `.sha256` | `scripts/guard4_verify.sh --boot … --backup …` | **APROVADO** (obrigatório antes do flash) |
| P0.4 | Gate do motor | `root_engine_gate.py --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces` | **CONDICIONADO** → hoje **PENDENTE (3)**: falta kernel certificado |
| P0.5 | Gate do M05 (contrato) | `droidspaces_preflight.py --static` → **PRONTO** | **APROVADO** |
| P0.6 | Gate do M05 (kernel) | `droidspaces_preflight.py --kernel-evidence <kernel build>` | **CONDICIONADO** (depende do build) |
| P0.7 | Configs do motor+containers na build: `CONFIG_KSU`/`KPM`/`SUSFS` + trio de ABI + `USER_NS`/`PID_NS` | mesma evidência do kernel compilado | **CONDICIONADO** (depende do build) |
| P0.8 | Garantia prévia dos 5 requisitos | `make garantia` → 0 só com prova de cada um | **PENDENTE** (1/5 provado) |

---

## 1. F0 — fundação (root + containers)

| Pos. | ID | Módulo / artefato | Como | Gate antes do próximo | Estado |
|---|---|---|---|---|---|
| 1 | **M01** | **KernelSU-Next v3.4.2** sobre o kernel compilado | flash do `boot.img` **do nosso build** (`fastboot flash boot_<slot>`) → instalar KSU-Next Manager (APK do release) → reboot · **backup do `boot.img` stock já feito no P0.3** | `id -u` = 0 · Manager concede root · `getenforce` = Enforcing · `guard4_verify` = VERIFIED · SUSFS ativo (`ksud` reporta) | **CONDICIONADO** ao build certificado |
| 2 | **M05** | **DroidSpaces** v7.1.0 (`Droidspaces-universal-v7.1.0-4344dc5.apk`, `sha256:36ab4466…930b6`) | `ksud module install /sdcard/modules/Droidspaces.zip` — **sem reiniciar com o daemon subindo** | `/proc/sysvipc/{shm,sem,msg}` e `posix-mqueue/qsize` legíveis · `droidspaces_preflight.py --device --expect-installed` → 0 | **CONDICIONADO** ao P0.6 |
| — | — | **Isolamento obrigatório do M05** | namespaces nativos do kernel | `CONFIG_USER_NS` + `CONFIG_PID_NS` (`y`) e namespaces `user`/`pid` presentes | **CONDICIONADO** — exigido por contrato; prova na L4 |

### 1.1 O DroidSpaces é possível com kernel stock? **Não.** (documentação oficial)

A doc oficial (`Documentation/Kernel-Configuration.md`) é explícita:

> *"Droidspaces needs kernel features that most stock Android kernels leave out: PID and IPC
> namespaces, a few networking pieces and devtmpfs."*

E, no caso do GKI (o nosso, 5.10):

> *"Several options Droidspaces needs — `CONFIG_SYSVIPC`, `CONFIG_IPC_NS` e `CONFIG_POSIX_MQUEUE` —
> add fields to core structures and shift the ABI. (...) **These are not optional.** Without the
> patch for your kernel version, enabling the IPC options bootloops the device."*

Ou seja: sob a **Decisão A** (kernel stock, `custom_kernel_allowed: false`) o M05 era
**IMPOSSÍVEL**, não "pendente". Não era falta de `CONFIG_USER_NS` isolada: é o **trio de ABI**
(`SYSVIPC`/`POSIX_MQUEUE`/`IPC_NS`) que **não existe** no kernel stock e cuja ativação exige patch
compilado.

**Você autorizou trocar o par ao obter aquele que garante tudo → Decisão C ratificada** (A
superseded). O M05 deixa de ser impossível e passa a ser **PENDENTE** (falta o build certificado):

| Decisão | Motor | Kernel | M05 | Ocultação |
|---|---|---|---|---|
| A (revogada) | APatch | stock da ROM | IMPOSSÍVEL | sem SUSFS |
| B (revisit_if) | APatch | próprio, **sem** SUSFS | possível | sem SUSFS de kernel |
| **C (vigente)** | **KernelSU-Next v3.4.2** | **próprio** com KSU + SUSFS + patches DroidSpaces | **PENDENTE de certificação** | **SUSFS** primário + Zygisk Next |

O que sustenta C: o README do DroidSpaces recomenda KernelSU; o `simonpunk/susfs4ksu` aplica em
KernelSU; e o kernel é nosso, então os três `CONFIG_*` de ABI entram **com** o patch de kABI na mesma
build (sem bootloop). Custo: nós compilamos e mantemos o kernel (OTA manual: rebuild + refazer M01).
Se o build falhar em `kernel_compat_check`/boot, `revisit_if` manda cair para **B** e depois **A2**.
Matriz completa: `references/kernel-pair-options.json`.

---

## 2. F1 — identidade e integridade (a camada que você descreveu)

| Pos. | ID | Módulo / artefato | Papel | Observação | Estado |
|---|---|---|---|---|---|
| 3 | **M03** | GApps A16 | base de serviços Google | a build precisa ser a variante **GApps** ou receber o pacote — P1 ainda em aberto | **APROVADO** (pendente de P1) |
| 4 | **M07** | Fingerprint/props + **PlayIntegrityFork** (`custom.pif.json`) | `MEETS_BASIC_INTEGRITY` / `MEETS_DEVICE_INTEGRITY` | config-map: *APatch + PIFork → OK* | **APROVADO** |
| 5 | **M08** | **Duck-ToolBox** = hub de atestação + **Zygisk Next** (base) + **Tricky Store** (KeyMint/keybox) | atestação de chave e integridade sem tocar TEE | config-map: *APatch + ZygiskNext → OK* · *APatch + Tricky Store → OK* | **APROVADO** |

Ordem interna do M08 (a mesma do `install-guide` Step 6): **Zygisk Next → Tricky Store →
PlayIntegrityFork → (Droidspaces, se ainda não instalado)**. Um único dono da escrita de identidade
(R04): não empilhar spoofers concorrentes.

---

## 3. F2–F5 — desempenho, mídia, janelas, continuidade

| Fase | Pos. | ID | Módulo | Estado |
|---|---|---|---|---|
| F2 | 6 | **M12A** | MaxManager (CPU/GPU/thermal/I-O) | **APROVADO** |
| F2 | 7 | **M12B** | GenieX (NPU/QAIRT) | **APROVADO** |
| F3 | 8 | **M02** | Camera (GCam + flags HAL) | **APROVADO** |
| F4 | 9 | **M04** | Screen capture irrestrito | **APROVADO** |
| F4 | 10 | **M06** | Free-form windows | **APROVADO** |
| F4 | 11 | **M09** | SAF | **APROVADO** |
| F4 | 12 | **M10** | Rede/socket por app (netfilter/eBPF) | **APROVADO** (kernel-level: mesma prova do pacote) |
| F4 | 13 | **M11** | Port-forward intranet | **APROVADO** |
| F5 | 14 | **M13** | Ambient Open CI | **APROVADO** |
| F5 | 15 | **M14** | Snapshots por camada | **APROVADO** |
| F5 | 16 | **M15** | Release Artifact pré-USB | **APROVADO** (último, por definição) |

---

## 4. O que **não** entra (e por quê)

| Item | Estado | Motivo (verificável) |
|---|---|---|
| **APatch** | **NÃO APROVADO** | `decisao_motor` → exit 1 (superseded pela Decisão C) |
| **Magisk** | **NÃO APROVADO** | `decisao_motor` → exit 1; o próprio DroidSpaces não suporta Magisk |
| **SukiSU / ReSukiSU** | **NÃO APROVADO** | motor único é KernelSU-Next; `decisao_motor` → exit 1 |
| **Kernel de terceiro** (Meteoric, NP², de outro aparelho) | **NÃO APROVADO** | `origin: third-party` → exit 1, mesmo se certificado; `third_party_kernel_allowed: false` |
| **SUSFS fora do kernel compilado** (userspace avulso) | **NÃO APROVADO** | só entra como patch da nossa build; ZIP solto → exit 1 |
| **Shamiko / Mountify / LSPosed-Riru** | **NÃO APROVADO** | conflito declarado no config-map do aparelho e nas `constraints` do M05 |
| **Zygisk Assistant** | **APROVADO na fonte, pendente de prova** | o README do projeto declara explicitamente "KernelSU & APatch users: 1. Install ZygiskNext; 2. habilitar *Umount modules / Exclude modifications* no APatch Manager; 3. desligar *Enforce DenyList*". Está registrado em `references/hiding-stack.json` e no M08 (`hiding_base`). **Falta:** `sha256` do ZIP (release não publica digest) e a medição por app |
| **LSPosed (qualquer variante)** | **NÃO APROVADO** | não faz parte dos 15 módulos aprovados; se você quiser, entra como módulo novo com gate próprio |

### Sobre a ocultação para bancos / gov.br

A cadeia aprovada cobre **integridade de dispositivo** (Tricky Store + PIFork via M07/M08). Ela
**não** prova, hoje, ocultação de root por app (`br.gov.br` faz detecção própria além do Play
Integrity). Sem SUSFS e sem Shamiko/Zygisk Assistant, essa ocultação depende de:
`APatch` (o que ele já esconde nativamente) + `DenyList/Zygisk` + proxy do M10 — isso é **prova a
fazer no aparelho**, não afirmação. Enquanto não houver evidência, o estado correto do item é
**CONDICIONADO**, não "aprovado".

---

## 4.1 A pilha de ocultação sob a Decisão C (com fonte primária)

| Camada | O que faz | Fonte | Estado |
|---|---|---|---|
| **SUSFS** (`simonpunk/susfs4ksu`, patch do nosso kernel) | esconde mount/arquivos do root **no kernel** — é a camada primária | repo do susfs4ksu (sem release: tag/commit pinado) | **obrigatória**; entra no build |
| **KernelSU-Next v3.4.2** | motor + *umount modules* por app | release oficial (2026-10-13) | **decidido** |
| **Zygisk Next v1.5.2** (2026-10-15) · 6 714 344 B · `sha256:ce50b13f…9a96` | fornece a API Zygisk (base do M08) | release oficial | **obrigatória** |
| **Zygisk Assistant v2.1.4** (2025-02-23) · 392 961 B | reforço userspace (proc/su/mounts) | README do projeto | **opcional**: só se SUSFS colidir com os patches kABI |
| **Tricky Store + PIFork** (M07/M08) | integridade/atestado — não é ocultação | config-map do aparelho | suportado na fonte |

Ordem: kernel com SUSFS → KernelSU-Next + Manager → Zygisk Next → Tricky Store → PIFork.
Se o SUSFS quebrar o boot (conflito com `001…below-kernel-6.12`/`002…posix_mqueue`), cai o fallback
já declarado: build **sem** SUSFS + Zygisk Next + Zygisk Assistant (é o par **B** em ocultação).

**Limite honesto:** "ocultação perfeita" não é demonstrável — existe sempre superfície de detecção
(syscalls, timing, atestação). O que é demonstrável é a lista de apps testados com PASS, e é isso que
o `make garantia` cobra (`device.hide_tested_apps`).

## 4.2 Verdade sobre Zygisk × motor de root (a pergunta que você fez)

**Zygisk não é nativo do APatch — mas funciona com ele via Zygisk Next; e com KernelSU-Next ele é
suportado de origem.** O README do Zygisk Next lista KernelSU e Magisk como pré-requisitos; o Zygisk
Assistant documenta o caminho do APatch. Sob a Decisão C (KernelSU-Next) a base Zygisk é nativa, a
ocultação primária vem do **SUSFS no kernel** e o Zygisk Assistant fica como **reforço opcional**.
Tudo isso continua **sem prova no seu aparelho** até rodarmos a fila.

## 5. Conflitos documentais declarados (resolvidos por regra, não escondidos)

1. **Ordem do DroidSpaces.** O `install-guide` do aparelho (Step 6) lista *ZygiskNext → TrickyStore →
   PIFork → LSPosed → Droidspaces por último*; a ordem ratificada em
   `references/module-rollout-order.md` coloca o **M05 em F0, posição 2** (logo depois do root).
   Regra adotada: **módulo kernel-level primeiro**, porque ele depende do kernel e não da pilha
   Zygisk — e o M05 é incompatível com Shamiko/Mountify/Riru. Se você preferir seguir literalmente a
   ordem do guia, é uma linha no contrato (`install.position` + `before`) e o gate acompanha.
2. **Kernel próprio do DroidSpaces.** `zeroharcoderd/knowledge/modules/droidspaces.md` descreve
   compilar kernel `droidspaces-android14-5.10` com patches `sysvipc` — era **proibido** pela
   Decisão A e hoje é **exigido** pela C. O contrato marca
   `custom_kernel_path: required_under_decision_C` e `droidspaces_preflight.py` compara o `source`
   do contrato com a decisão vigente (stock → reprova; build próprio → segue para a evidência).
3. **`config/pong.env`** ainda carrega `SUSFS_BRANCH`/`GKI_BRANCH` de outra linhagem — config morta
   sob a Decisão A; limpeza pendente (mexe em CI, preciso do seu ok).

---

## 6. Como rodar a fila (um comando por trava)

```bash
make m05                                                             # contrato do M05 + gate do motor
python3 skills/evox-rom-ci-optimizer/scripts/root_engine_gate.py --root . --engine kernelsu \
  --candidate custom-build-pong-ksu-susfs-droidspaces
python3 skills/evox-rom-ci-optimizer/scripts/droidspaces_preflight.py --root . --kernel-evidence workspace/l4/kernel-config.json
python3 skills/evox-rom-ci-optimizer/scripts/rollout_gate.sh status
bash skills/evox-rom-ci-optimizer/tests/{test_root_decision,test_root_engine_gate,test_droidspaces_preflight}.sh
```

**Nada vai ao cabo enquanto:** L4 não fechar · `guard4_verify` ≠ VERIFIED · algum módulo anterior
sem PASS · `HIL A/B` não aprovado (pré-gate, nunca prova final).

---

## 6.1 "Garantia prévia de sucesso" — como ela existe de verdade

Garantia não é promessa: é **critério de aceitação executável**. `scripts/success_guarantee.py`
(=`make garantia`) avalia os cinco pedidos e só retorna **GARANTIA_CONFIRMADA (0)** quando cada um
tem prova registrada; caso contrário devolve **3** dizendo exatamente o que falta, e **1
(IMPOSSÍVEL)** quando a decisão vigente impede (ex.: kernel stock + kernel próprio proibido) — que
é diferente de "ainda não provei".

| # | Requisito | Estado hoje | O que falta (comando) |
|---|---|---|---|
| R1 | motor único ratificado (KernelSU-Next) | **PROVADO** | — |
| R2 | root oculto para apps alvo | FALTA_PROVA | `hiding-stack.json` + medição por app |
| R3 | integridade/fingerprint | FALTA_PROVA | `MEETS_DEVICE_INTEGRITY` medido no aparelho |
| R4 | zero conflito | FALTA_PROVA | `static_conflict_scanner.py` sobre os ZIPs reais |
| R5 | DroidSpaces conforme doc oficial | FALTA_PROVA | build com o trio de ABI + patch kABI + L4 + instalação observada |

Nada aqui foi "aprovado por texto": sem `--evidence`, o script devolve 3 mesmo com todo o repo verde.

## 7. Pendências que travam a fila (ordem de ataque)

1. **P0.2 — L4 do pacote**: sem ela, nem M01 nem M05 saem de **CONDICIONADO**.
2. **Build do kernel C**: defconfig com `CONFIG_KSU/KPM/SUSFS/SYSVIPC/POSIX_MQUEUE/IPC_NS/DEVTMPFS/
   NET_NS/USER_NS/PID_NS` + patches `001…below-kernel-6.12` e `002…posix_mqueue`; sha256 reprodutível.
3. **P1 — Vanilla × GApps**: define se o M03 é módulo ou já vem na build.
4. **Certificação do par C**: `kernel_compat_check.sh` sobre o kernel compilado + boot em AVD;
   até lá o gate devolve **3**, não 0.
5. **Limpeza do `config/pong.env`** (SUSFS/GKI branch mortos) — agora que SUSFS voltou ao escopo,
   revisar em vez de apagar.
