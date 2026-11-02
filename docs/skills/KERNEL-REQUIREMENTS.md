# Requisitos do kernel — o que a kernel do pack precisa atender para 100%

**Alvo:** `pong` (Nothing Phone 2) · SM8475 · EvolutionX-16.0-20260915-Pong-11.11 · KMI `android13-5.10` · GKI
**Fonte do plano:** `skills/evox-rom-ci-optimizer/references/kernel-build-plan.json`
**Gate:** `skills/evox-rom-ci-optimizer/scripts/kernel_build_gate.py --root . [--prebuild]`
**Regra:** nenhum requisito entra sem `verified_by` **e** `falsified_by`. Sem contra-exemplo = decoração = reprovado.

Estado de hoje: plano **20/20 OK**; pré-build **22/26 OK**, com 4 PEND nomes e sobrenomes
(`B01` pin, `B03` árvore, `B05` configs → é o que trava `C06`, `B06` artefatos).
**Nenhum requisito abaixo está provado no device ainda** — todos são condição de aceitação.

---

## 1. Requisitos funcionais (11)

| ID | Requisito | Prova (`verified_by`) | Falsificação (`falsified_by`) |
|---|---|---|---|
| **FR-01** | Sobe no `pong` com a build pinada: boot completo, sem kernel panic | `boot.ok` + `dmesg` sem `Kernel panic` + 10 min de uptime (staging, depois físico) | flash do `boot.img` + reboot: qualquer panic/loop reprova |
| **FR-02** | KernelSU-Next v3.4.2 concede root (Manager abre, `su -c id -u` = 0) | `ksud`/Manager + `su -c 'id -u'` | sem root ou Manager recusando o kernel |
| **FR-03** | SUSFS ativo e listando (ou fallback declarado sem SUSFS) | `ksud susfs`/proc + `/sys/fs/susfs` presente | patch aplicado e a interface não existe |
| **FR-04** | DroidSpaces sobe container com PID/IPC/UTS/NET/USER namespaces | app Droidspaces → *Check Requirements* + container real | qualquer requisito marcado faltando no app |
| **FR-05** | SYSVIPC/POSIX_MQUEUE utilizáveis dentro do container | `/proc/sysvipc/{shm,sem,msg}` e `/dev/mqueue` no container | `ENOSYS`/`EINVAL` ao criar shm/mq |
| **FR-06** | Rede por app (M10): netfilter `owner` + eBPF carregam | `iptables -m owner` + carga de programa BPF | regra `owner` não aplica ou BPF rejeitado |
| **FR-07** | Faixas de CPU/GPU e thermal controláveis (M12A) | `cpufreq`/`devfreq` + zonas térmicas legíveis e alteráveis | nó ausente ou escrita negada |
| **FR-08** | NPU/QAIRT abre sem regressão (M12B) | log de init `libcdsprpc`/NPU + inferência de fumaça | timeout/crash no primeiro uso |
| **FR-09** | Integridade mantida (M07/M08): `MEETS_DEVICE_INTEGRITY` | Play Integrity API com PIFork + TrickyStore | `MEETS_DEVICE_INTEGRITY` falso |
| **FR-10** | Rollback byte-idêntico ao kernel stock da build | `guard4_verify.sh` (backup + sha256) antes de qualquer flash | hash divergente ou backup ausente → bloqueia |
| **FR-11** | OTA tem plano: rebuild com o mesmo patch set + refazer M01 | documento do par + script de rebuild reprodutível | build nova sem pin de source/patch |

## 2. Requisitos não funcionais (10)

| ID | Requisito | Prova | Falsificação |
|---|---|---|---|
| **NFR-01** | Reprodutível: mesmo (source pin, configs, patch set) ⇒ mesmo sha256 de `Image`/`.config` | dois builds no CI comparando sha256 | sha diferente em execuções idênticas |
| **NFR-02** | Build ≤ 90 min em `ubuntu-latest` 4 vCPU com ccache frio | tempo do job no CI | job > 90 min ou timeout |
| **NFR-03** | Nenhum patch com `--force`/fuzz > 0 (rejeição = falha) | `git apply --check` + `patch --dry-run` no log | `.rej` ou fuzz aceito |
| **NFR-04** | Todo artefato publicado tem sha256 + proveniência | release com `SHA256SUMS` + `attest-build-provenance` | artefato sem hash/proveniência |
| **NFR-05** | Ações do workflow pinadas por SHA de 40 hex | `kernel_build_gate.py` (`B02`) + lint de CI | `@vN` sem SHA |
| **NFR-06** | Sem regressão de estabilidade: 0 panic/crash em 72 h de uso | `pstore`/`ramoops` + `dmesg` + uptime | qualquer panic/oom-kill anômalo |
| **NFR-07** | Performance ≤ 3% de perda vs kernel stock | mesma bateria antes/depois | queda > 3% |
| **NFR-08** | `boot.img` ≤ stock + 5% (cabe no slot sem reparticionar) | tamanho do artefato vs stock | exceder o limite do slot |
| **NFR-09** | GPL-2.0 cumprida: fonte modificada publicada com o binário | tag/release com diff do patch set | binário sem fonte correspondente |
| **NFR-10** | Build sem segredo: roda em fork público sem PAT | `workflow_dispatch` em fork limpo | falha por secret ausente |

---

## 3. Mapa requisito → condição do pack (`C01`–`C10`) → prova

As 10 condições vivem em `references/pack-conditions.json` e são avaliadas **sobre o par**, nunca
sobre um nome. O kernel do pack contribui assim:

| Condição | O que ela cobra do kernel | Requisitos que a sustentam | Prova no gate |
|---|---|---|---|
| **C01** motor entrega root | o kernel embute o motor (KSU embutido) ou não precisa dele | FR-02 | `P05` (integr. 003) + `kernel_supports` no candidato |
| **C02** kernel serve o motor | `kernel_supports` declarado no candidato | FR-02, FR-03 | solver + `root_engine_gate --kernel-evidence` |
| **C03** kernel declara build/modelo/API | candidato com `supported_rom_builds` = `…20260915-Pong-11.11` | FR-01, FR-11 | `P01` + selftest de C03 |
| **C04** kernel mantido (não EOL) | `developer_support.declared` | FR-01, NFR-06 | selftest de C04 |
| **C05** DroidSpaces aceita o motor | nada do kernel; é contrato do runtime | FR-04 | `droidspaces-requirements.json /constraints/supported_engines` |
| **C06** kernel tem as CONFIG_* do pack | **12 CONFIG_\*** provadas por evidência | FR-04, FR-05, FR-06 | `B05` (`--config-json`) + `B07` paridade + `P06` |
| **C07** patches kABI aplicados | `001` (sysvipc kABI) + `002` (mqueue padding) | FR-05, NFR-03 | `B04` (patches na árvore) + `P05` (política) |
| **C08** camada de ocultação utilizável | SUSFS na árvore liga/desliga a camada | FR-03, FR-09 | `P05` (004 `drop_patch`) + `M08` |
| **C09** módulos têm as capacidades | configs de módulo (`M10`, `M12*`) | FR-06, FR-07, FR-08 | `P07` + `P19` |
| **C10** rollback e plano de OTA | rebuild reprodutível | FR-10, FR-11 | `P18` (deploy) + `guard4_verify.sh` |

**NFR-01…NFR-10 não mapeiam para `C01`–`C10`.** São condições de aceitação **do artefato**, medidas
no CI e na fase de teste. Dizer o contrário seria inflar cobertura: o pack decide *o que* instalar;
os NFR decidem *se o que foi construído é confiável*.

---

## 4. Critério de 100% por módulo (um PASS por vez)

`M12A` e `M12B` são módulos distintos de prova. Um módulo só recebe **PASS** quando **as três**
condições valem:

1. o `check` do módulo (tabela abaixo) passa com o `expected` observado;
2. o `falsified_by` **não** ocorre (contra-exemplo testado e ausente);
3. as condições `C` de que ele depende estão **fechadas por evidência** (não por intenção).

E o PASS é **bloqueante**: `M(n+1)` não começa sem `M(n)` com PASS registrado. Antes do primeiro
flash: `guard4_verify.sh` (backup + sha256 do stock).

| Módulo | Critério de PASS | Esperado | Depende de |
|---|---|---|---|
| **M01** | `su -c 'id -u'` = 0 + Manager reconhece o kernel | root ativo, SELinux `Enforcing` | C01, C02, C03, C07 |
| **M02** | câmera abre e grava (GCam + flags HAL) com o kernel novo | sem erro de HAL | C09 |
| **M03** | Play Store e serviços Google sobem | login e sync ok | C03 |
| **M04** | captura de tela irrestrita funciona | captura sem bloqueio | C09 |
| **M05** | Droidspaces *Check Requirements* + container real (PID/IPC/UTS/NET/USER) | todos OK; shm/mq utilizáveis | **C05, C06, C07** |
| **M06** | janelas free-form abrem e redimensionam | multi-janela ok | C09 |
| **M07** | Play Integrity (PIFork + TrickyStore) | `MEETS_DEVICE_INTEGRITY` | C08 |
| **M08** | ocultação por app (lista R08) + SUSFS ativo | app alvo não detecta root | C08 |
| **M09** | SAF monta diretório externo | leitura/escrita ok | C09 |
| **M10** | netfilter `owner` + carga de BPF por app | regra aplicada só ao app | C06, C09 |
| **M11** | port-forward intranet responde | porta acessível na LAN | C09 |
| **M12A** | `cpufreq`/GPU/thermal legíveis e controláveis | controle efetivo | C09 |
| **M12B** | NPU/QAIRT inicializa e roda inferência de fumaça | sem erro | C09 |
| **M13** | pipeline do CI de ambiente roda ponta a ponta | job verde | — |
| **M14** | snapshot por camada restaura estado | rollback fiel | C10 |
| **M15** | Release Artifact validado antes de qualquer USB | artefato + hash conferidos | NFR-04 |

**`M05` é o gargalo atual:** depende de `C06` (12 CONFIG_* sem prova) e `C07` (patches kABI). Enquanto
`C06` estiver pendente, `M05` **não pode** receber PASS — nem por leitura de código, nem por confiança
no kernel de terceiro.

---

## 5. Configs: contrato × específicas de módulo

- **Contrato (12 + `CONFIG_DEVTMPFS` = 13 no plano):** `CGROUPS`, `CGROUP_FREEZER`, `CGROUP_PIDS`,
  `NAMESPACES`, `PID_NS`, `IPC_NS`, `UTS_NS`, `NET_NS`, `USER_NS`, `SECCOMP`, `SYSVIPC`,
  `POSIX_MQUEUE` (+ `DEVTMPFS`). Fonte única: `references/droidspaces-requirements.json`
  (lida pelo gate — `P06` falha se o plano esquecer alguma).
- **Namespaces obrigatórios (regra da usuária):** `CONFIG_USER_NS` **e** `CONFIG_PID_NS`.
- **Específicas de módulo (19):** `CONFIG_KSU`, `CONFIG_KPM`, `CONFIG_KALLSYMS`, `CONFIG_KALLSYMS_ALL`,
  `CONFIG_SUSFS`, `CONFIG_NETFILTER`, `CONFIG_NETFILTER_XT_MATCH_OWNER`, … — cada uma com `module`,
  `kind` (`contract`/`to_confirm`) e `confirm_in` (onde será confirmada). `P07` reprova config sem
  origem ou sem lugar de confirmação.
