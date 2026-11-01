# Sequência aprovada de instalação e módulos — Decisão A (ratificada 2026-11-01)

> **Escopo:** `pong` (Nothing Phone 2) · build pinada `EvolutionX-16.0-20260915-Pong-11.11` (A16/API 36)
> **Travas vigentes:** motor único `apatch` · kernel `stock-rom` · `custom_kernel_allowed: false` ·
> `susfs_allowed: false` (`skills/evox-rom-ci-optimizer/references/root-decision.json`).
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
| P0.4 | Gate do motor | `root_engine_gate.py --engine apatch` → **0** | **APROVADO** |
| P0.5 | Gate do M05 (contrato) | `droidspaces_preflight.py --static` → **PRONTO** | **APROVADO** |
| P0.6 | Gate do M05 (kernel) | `droidspaces_preflight.py --kernel-evidence workspace/l4/kernel-config.json` | **CONDICIONADO** (depende de P0.2) |
| P0.7 | Kernel do APatch: `CONFIG_KALLSYMS=y` + `CONFIG_KALLSYMS_ALL=y` | mesma evidência da L4 (README do APatch) | **CONDICIONADO** (depende de P0.2) |
| P0.8 | Garantia prévia dos 5 requisitos | `make garantia` → 0 só com prova de cada um | **PENDENTE** (1/5 provado) |

---

## 1. F0 — fundação (root + containers)

| Pos. | ID | Módulo / artefato | Como | Gate antes do próximo | Estado |
|---|---|---|---|---|---|
| 1 | **M01** | **APatch** (`kptools`/`kpimg` no `boot.img` da ROM) | patch do `boot.img` oficial → `fastboot flash boot_<slot>` → reboot | `id -u` = 0 · APatch Manager concede root · `getenforce` = Enforcing · `guard4_verify` = VERIFIED | **APROVADO** |
| 2 | **M05** | **DroidSpaces** v7.1.0 (`Droidspaces-universal-v7.1.0-4344dc5.apk`, `sha256:36ab4466…930b6`) | `apd module install /sdcard/modules/Droidspaces.zip` — **sem reiniciar com o daemon subindo** | `/proc/sysvipc/{shm,sem,msg}` e `posix-mqueue/qsize` legíveis · `droidspaces_preflight.py --device --expect-installed` → 0 | **CONDICIONADO** ao P0.6 |
| — | — | **Isolamento obrigatório do M05** | namespaces nativos do kernel | `CONFIG_USER_NS` + `CONFIG_PID_NS` (`y`) e namespaces `user`/`pid` presentes | **CONDICIONADO** — exigido por contrato; prova na L4 |

### 1.1 O DroidSpaces é possível com kernel stock? **Não.** (documentação oficial)

A doc oficial (`Documentation/Kernel-Configuration.md`) é explícita:

> *"Droidspaces needs kernel features that most stock Android kernels leave out: PID and IPC
> namespaces, a few networking pieces and devtmpfs."*

E, no caso do GKI (o nosso, 5.10):

> *"Several options Droidspaces needs — `CONFIG_SYSVIPC`, `CONFIG_IPC_NS` e `CONFIG_POSIX_MQUEUE` —
> add fields to core structures and shift the ABI. (...) **These are not optional.** Without the
> patch for your kernel version, enabling the IPC options bootloops the device."*

Ou seja: sob a **Decisão A** (kernel stock, `custom_kernel_allowed: false`) o M05 é
**IMPOSSÍVEL**, não "pendente" — e isso agora é veredito de máquina (`make garantia` → R5 com
estado `IMPOSSIVEL`, exit 1). Não é falta de CONFIG_USER_NS isolada: é o **trio de ABI**
(`SYSVIPC`/`POSIX_MQUEUE`/`IPC_NS`) que **não existe** no kernel stock e cuja ativação exige patch
compilado.

**As três saídas possíveis** (nenhuma delas é "maquiar o gate"):

| Saída | O que muda | Entrega DroidSpaces? | Estado |
|---|---|---|---|
| **A2** manter A e desistir do M05 | nada | não | possível hoje |
| **B** APatch + **kernel próprio sem SUSFS** com os patches do DroidSpaces | `custom_kernel_allowed: true` | **sim** | recomendada (mantém motor único e a proibição de SUSFS) |
| **C** KernelSU-Next/SukiSU + kernel próprio **com SUSFS** + patches | troca o motor e libera SUSFS | sim, com ocultação de kernel | alternativa "máxima ocultação" |

Matriz completa com releases de 2026 e custo de cada par: `references/kernel-pair-options.json`.

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
| **SUSFS** (kernel ou userspace) | **NÃO APROVADO** | `susfs_allowed: false`; `--engine kernelsu/sukisu` → exit 1; `decisao_susfs` no gate |
| **Magisk** | **NÃO APROVADO** | `decisao_motor` → exit 1; o próprio DroidSpaces não suporta Magisk |
| **KernelSU / SukiSU / ReSukiSU** | **NÃO APROVADO** | exigem kernel próprio — proibido por `custom_kernel_allowed: false` |
| **Kernel de terceiro** (Meteoric, NP², build própria) | **NÃO APROVADO** | `origin: third-party` → exit 1, mesmo se certificado |
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

## 4.1 A pilha de ocultação sob a Decisão A (com fonte primária)

| Camada | O que faz | Fonte | Estado |
|---|---|---|---|
| **APatch — "Exclude modifications"** por app | faz umount dos módulos para o app alvo (é o mecanismo nativo de ocultação do APatch) | README do Zygisk Assistant, seção *KernelSU & APatch users* | suportado na fonte |
| **Zygisk Next v1.5.2** (2026-10-15) · 6 714 344 B · `sha256:ce50b13f…9a96` | fornece a API Zygisk que o APatch não tem embutida | release oficial + README do Zygisk Assistant | suportado na fonte |
| **Zygisk Assistant v2.1.4** (2025-02-23) · 392 961 B | esconde root/Zygisk do app (proc, su, mounts) | README do projeto (APatch) | **fonte antiga (616 dias)**; sem digest publicado → hash calculado no download |
| **Tricky Store + PIFork** (M07/M08) | integridade/atestado — não é ocultação | config-map do aparelho | suportado na fonte |

Ordem de configuração (a do README, literal): APatch Manager → *Exclude modifications* por app →
Zygisk Next instalado → *Enforce DenyList* desligado → Zygisk Assistant por último.

**Limite honesto:** "ocultação perfeita" não é demonstrável — existe sempre superfície de detecção
(syscalls, timing, atestação). O que é demonstrável é a lista de apps testados com PASS, e é isso que
o `make garantia` cobra (`device.hide_tested_apps`).

## 4.2 Verdade sobre Zygisk × APatch (a pergunta que você fez)

**Zygisk não é nativo do APatch — mas funciona com ele via Zygisk Next.** O README do próprio
Zygisk Next só lista KernelSU e Magisk como pré-requisitos; quem documenta o caminho do APatch é o
Zygisk Assistant ("KernelSU & APatch users: install ZygiskNext…"). Ou seja: `APatch + Zygisk Next +
Zygisk Assistant` é combinação **declarada por fonte primária**, não invenção — e continua sem prova
no seu aparelho até rodarmos a fila.

## 5. Conflitos documentais declarados (resolvidos por regra, não escondidos)

1. **Ordem do DroidSpaces.** O `install-guide` do aparelho (Step 6) lista *ZygiskNext → TrickyStore →
   PIFork → LSPosed → Droidspaces por último*; a ordem ratificada em
   `references/module-rollout-order.md` coloca o **M05 em F0, posição 2** (logo depois do root).
   Regra adotada: **módulo kernel-level primeiro**, porque ele depende do kernel e não da pilha
   Zygisk — e o M05 é incompatível com Shamiko/Mountify/Riru. Se você preferir seguir literalmente a
   ordem do guia, é uma linha no contrato (`install.position` + `before`) e o gate acompanha.
2. **Kernel próprio do DroidSpaces.** `zeroharcoderd/knowledge/modules/droidspaces.md` descreve
   compilar kernel `droidspaces-android14-5.10` com patches `sysvipc`. Isso é **proibido** pela
   Decisão A; o contrato marca `custom_kernel_path: forbidden_by_decision_A` e
   `droidspaces_preflight.py` reprova `source != stock-rom`.
3. **`config/pong.env`** ainda carrega `SUSFS_BRANCH`/`GKI_BRANCH` de outra linhagem — config morta
   sob a Decisão A; limpeza pendente (mexe em CI, preciso do seu ok).

---

## 6. Como rodar a fila (um comando por trava)

```bash
make m05                                                             # contrato do M05 + gate do motor
python3 skills/evox-rom-ci-optimizer/scripts/root_engine_gate.py --root . --engine apatch
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
(IMPOSSÍVEL)** quando a própria Decisão A impede — que é diferente de "ainda não provei".

| # | Requisito | Estado hoje | O que falta (comando) |
|---|---|---|---|
| R1 | motor único APatch | **PROVADO** | — |
| R2 | root oculto para apps alvo | FALTA_PROVA | `hiding-stack.json` + medição por app |
| R3 | integridade/fingerprint | FALTA_PROVA | `MEETS_DEVICE_INTEGRITY` medido no aparelho |
| R4 | zero conflito | FALTA_PROVA | `static_conflict_scanner.py` sobre os ZIPs reais |
| R5 | DroidSpaces conforme doc oficial | FALTA_PROVA | L4 do kernel + instalação observada |

Nada aqui foi "aprovado por texto": sem `--evidence`, o script devolve 3 mesmo com todo o repo verde.

## 7. Pendências que travam a fila (ordem de ataque)

1. **P0.2 — L4 do pacote**: sem ela, nem M01 nem M05 saem de **CONDICIONADO**.
2. **P1 — Vanilla × GApps**: define se o M03 é módulo ou já vem na build.
3. **Prova de `CONFIG_USER_NS`/`CONFIG_PID_NS`** no kernel stock (isolamento do DroidSpaces).
4. **Decisão sobre `Zygisk Assistant`**: registrar como módulo com gate, ou ficar sem ocultação de
   root por app (e assumir que gov.br pode reprovar).
5. **Limpeza do `config/pong.env`** (SUSFS/GKI branch mortos).
