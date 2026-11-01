# Auditoria — qual motor de root, qual kernel, e como ficam os módulos

**Data:** 2026-11-01 · **Device:** Nothing Phone (2) `pong` / SM8475 · **ROM alvo:** Evolution X
`16.0-20260915-Pong-11.11` (Android 16 / API 36, pinada) · **Pergunta:** Magisk, APatch ou
KernelSU(+SUSFS com kernel customizado)? E isso é compatível com a otimização limpa que foi pedida?

**Regra que vale aqui:** o agente verifica e recomenda com dado; **a escolha é sua**. Nada foi
flasheado, nada foi substituído — só auditado com fonte, data e hash.

> **Atualização 2026-11-01:** esta auditoria foi escrita quando a hipótese era "APatch + kernel de
> terceiro". Você autorizou trocar o par ao obter aquele que garante tudo, e a **Decisão C** foi
> ratificada (`references/root-decision.json`): **KernelSU-Next v3.4.2 + kernel compilado por nós**
> com SUSFS e os patches do DroidSpaces. As seções abaixo continuam válidas como **auditoria das
> alternativas** (por que não APatch, por que não Meteoric/NP²); o que mudou é o veredito.

---

## 1. Veredito em uma linha

> **O par vigente é KernelSU-Next v3.4.2 + kernel `pong` 5.10 compilado por nós** (KSU + SUSFS +
> patches `001…below-kernel-6.12` / `002…posix_mqueue` do DroidSpaces) — decisão da usuária em
> 2026-11-01, com estado **PENDENTE** até o build ser certificado. APatch deixou de ser o motor;
> kernel de terceiro (Meteoric, NP²) continua fora — a doc do DroidSpaces mostra que o stock não
> tem `SYSVIPC`/`POSIX_MQUEUE`/`IPC_NS` e que ativá-los sem patch kABI dá bootloop.

Isso não é opinião: é a saída do gate `root_engine_gate.py` (§6).

| Combinação | Veredito do gate |
|---|---|
| **KernelSU-Next + build própria (`custom-build-pong-ksu-susfs-droidspaces`)** | **PENDENTE (3)** — `kernel_certificado` + `m05_kernel_configs` até o build provar |
| APatch (qualquer kernel) | **INCOMPATÍVEL (1)** — `decisao_motor` (superseded) |
| SukiSU / Magisk | **INCOMPATÍVEL (1)** — motor único é KernelSU-Next |
| KernelSU + kernel stock da ROM (`stock-evolutionx`) | **INCOMPATÍVEL (1)** — `decisao_kernel` exige build próprio |
| KernelSU + kernel de terceiro (NP² v3.0.5) | **INCOMPATÍVEL (1)** — `third_party_kernel_allowed: false` |
| KernelSU + Meteoric V6 | **INCOMPATÍVEL (1)** — `rejected_eol` + terceiro |

## 2. Validação item a item do que você trouxe

| Afirmação | O que a verificação encontrou | Veredito |
|---|---|---|
| “Para o pong precisaremos de kernel customizado com KernelSU e SUSFS” | Correto **se** o requisito for ocultação em nível de kernel: no pong o kernel stock não tem `CONFIG_KSU`, e SUSFS é patch de kernel. Sem kernel próprio não há KSUN/SUSFS. | **Confirmado (condicional)** |
| “Meteoric integra KernelSU e SUSFS de forma estável” | O release `V6-Pong` de fato migra para KernelSU-Next + SUSFS. Mas é de **2025-06-19**; o repositório não recebe push desde **2025-07-02**; o guia do device lista **Meteoric (EOL)** e “não suporta NOS 4.0+”. | **Parcialmente verdadeiro, mas desatualizado** |
| “Informações de outubro e novembro de 2026 mostram o Meteoric em destaque” | Não há release, tag ou commit do Meteoric nesse período (último release há ~17 meses). O que está ativo em 2026 é **NP² Kernel (MiguVT)** — v3.0.5 de **2026-08-12**, ReSukiSU + SUSFS + BaseBandGuard. | **Falso** |
| “KernelSU é a melhor opção: mais estável e seguro por operar no nível do kernel” | O mecanismo está certo (root em espaço de kernel), mas *mais estável* não decorre disso: no pong isso obriga a **trocar o kernel oficial por um de terceiro**, o que aumenta variáveis, quebra OTA e adiciona um patch fora da árvore. *Mais seguro* também não é automático — depende de o kernel ser mantido; um kernel EOL é **menos** seguro. O ganho real do KSU/SUSFS é **detecção mais difícil**, não segurança intrínseca. | **Impreciso** |
| “Garanta que o kernel customizado substituirá o padrão da Evolution X” | Não é garantível hoje: (a) nenhum candidato declara suporte à build `2026-09-15`/A16; (b) a KMI e a base do kernel da build pinada **só saem da L4** (`payload.bin`), que ainda não foi extraída; (c) não há hash do Meteoric publicado na release. O gate recusa “garantir” sem esses dados. | **Não garantido (PENDENTE)** |

## 3. Matriz dos motores (dado, não preferência)

| | **APatch** | **Magisk** | **KernelSU / KernelSU-Next** | **SukiSU/ReSukiSU** |
|---|---|---|---|---|
| Onde o root vive | kernel (patch de kallsyms no `boot.img`) | userspace (ramdisk + `magiskd`) | kernel (`CONFIG_KSU` embutido ou LKM) | kernel (fork do KSU, com KPM) |
| Precisa de kernel customizado? | **Não** | **Não** | **Sim** (no pong o stock não tem KSU) | **Sim** |
| Dependência de KMI | baixa | nenhuma | **alta** (LKM exige KMI idêntico) | **alta** |
| Suporta SUSFS | não | não | **sim** | **sim** |
| Rollback | `boot_stock_rollback.img` (sha256) | idem | idem (volta ao kernel stock) | idem |
| Status no repo (Decisão C) | `blocked_by decisão C` | `blocked_by decisão C` | **`allowed` (único)** | `blocked_by decisão C` |

Fontes: `references/root-engines.json`; `config/managers.json`; aviso já existente nos workflows —
“KernelSU LKM has KMI mismatch on stock kernel”.

## 4. Candidatos de kernel (com data e hash)

| Candidato | Versão / data | KMI declarada | Suporte à sua build? | Status |
|---|---|---|---|---|
| **Kernel stock da ROM** | `boot.img` do `payload.bin` (build 2026-09-15) | sai da L4 | é a própria build | `baseline` (só referência: a C exige build própria) |
| **Build própria `pong` 5.10** (KSU + SUSFS + patches DroidSpaces) | a compilar | `android13-5.10` (L4) | **sim, é a nossa** | `candidate_unverified` |
| **NP² Kernel (LineageOS)** | v3.0.5 · **2026-08-12** | `android13-5.10` · Linux 5.10.246 | **não declara** a build EVOX 11.11 (A16) | `candidate_unverified` |
| **Meteoric V6-Pong** | **2025-06-19** (repo parado em 2025-07-02) | `android12-5.10` | **não declara**; guia do device: EOL | `rejected_eol` |

Hash público do NP² (v3.0.5, variante LineageOS):
`b9eb9f75f58a456cfd3f1b9ec858475738cd3844e1b48e533a2d497343aa641d` (22.622.811 bytes).
O Meteoric não publica hash na release — o que, sozinho, já o desqualifica pela regra do projeto
(“artefato sem sha256 não entra”).

## 5. Como ficam os 15 módulos sob cada motor

Legenda: **=** igual, **Δ** muda de forma, **✗** deixa de existir, **+** passa a ser necessário.

| Módulo | APatch (baseline) | KernelSU/SukiSU + SUSFS |
|---|---|---|
| **M01 Root engine** | patch `kptools`/`kpimg` no `boot.img` stock + `.kpm` | **Δ** vira “flashar kernel de terceiro já com KSU embutido”; o caminho Guard-4/`.kpm` **✗** |
| M02 Camera | = | = (mas só depois de provar estabilidade do kernel novo) |
| M03 GApps | = | = |
| M04 Screen capture | = | = |
| **M05 DroidSpaces** | = | **Δ** exige SUSFS com **mount-hide global desligado** (regra R03); se o kernel só funcionar com hide global → **✗** |
| M06 Free-form | = | = |
| M07 Fingerprint | = | = |
| M08 Duck-ToolBox | = (Zygisk via módulo) | **Δ** Zygisk no KSU usa módulo próprio; manter **um único dono** da identidade |
| M09 SAF | = | = |
| M10 Rede/socket | = | **Δ** ganha acesso a primitivas de kernel, mas eBPF/netfilter continuam vindo do kernel da ROM |
| M11 Port-forward | = | = |
| M12A MaxManager | = | = |
| M12B GenieX | = | = (NPU continua dependendo de `/dev/adsprpc-smd`) |
| M13 Ambient CI | = | = |
| M14 Snapshots | = | = |
| M15 Release pre-USB | = | **Δ** o artefato precisa incluir o ZIP do kernel e o `boot_stock_rollback.img` |
| — | — | **+** gerenciador do fork (SukiSU/ReSukiSU) e **+** ferramenta `ksu_susfs` (userspace do SUSFS) |

Duas linhas do M05 acima deixaram de ser texto e viraram gate: o `droidspaces_preflight.py` prova
(a) a **ordem do próprio app** — F0/W1, posição 2, depois do M01 — e (b) que o motor escolhido está
na lista suportada pelo DroidSpaces (`apatch`, `kernelsu`, `sukisu`; **Magisk não**). Com isso,
`root_engine_gate.py --engine magisk` sai **INCOMPATÍVEL (1)**, e não mais "compatível".

Consequência de arquitetura: trocar o motor **não é** “instalar um módulo a mais” — muda o **M01**,
adiciona um artefato de kernel ao **M15** e cria uma condição no **M05**. Por isso a onda 1 do
ledger é a mesma nos dois casos: *um artefato por vez, com PASS antes do próximo*.

## 6. O que foi implementado para isso deixar de ser opinião

| Arquivo | O que faz |
|---|---|
| `references/root-engines.json` | fatos por motor (mecanismo, dependência de kernel, SUSFS, rollback) |
| `references/kernel-candidates.json` | candidatos com data, hash, suporte declarado e status (`baseline`, `candidate_unverified`, `rejected_eol`) |
| `references/module-requirements.json` | contrato dos 15 módulos (root, motor exigido, SUSFS, Zygisk, mount-hide, kernel-level) |
| `scripts/root_engine_gate.py` | cruza motor × kernel × módulos → **COMPATÍVEL / PENDENTE / INCOMPATÍVEL** com motivos |
| `tests/test_root_engine_gate.sh` | 23 casos (inclui fixtures que provam que o gate sabe dizer **não**, e o M05 recusando Magisk) |
| `scripts/droidspaces_preflight.py` | Gate do **M05**: contrato estático, evidência de kernel e checagem no device — detalhado em [DROIDSPACES-VALIDATION.md](DROIDSPACES-VALIDATION.md) |
| `references/mutation-catalog.json` | 13 mutantes do motor (M103–M106, M114–M129) e do M05 (M107–M113), todos mortos por asserção |

Comandos:

```bash
python3 skills/evox-rom-ci-optimizer/scripts/root_engine_gate.py --engine apatch            # exit 0
python3 skills/evox-rom-ci-optimizer/scripts/root_engine_gate.py --engine kernelsu          # exit 3 (pendente)
python3 skills/evox-rom-ci-optimizer/scripts/root_engine_gate.py --engine kernelsu \
        --candidate meteoric-v6-pong --json                                                 # exit 1 (EOL)
```

## 7. Conformidade com a instrução inicial (otimização limpa)

| Requisito original | Continua respeitado? | Como |
|---|---|---|
| Kernel só com suporte declarado à build exata + modelo Pong | **sim** | `kernel_compat_check.sh` (KMI, base, build, sha256) + `kernel-candidates.json` |
| Um módulo por vez, com PASS antes do próximo | **sim** | `rollout_gate.sh` (ledger) — inalterado |
| Backup `boot.img` sempre + rollback verificado | **sim** | `forge_patcher.sh`/`patch_boot_offline.sh` geram `boot_stock_rollback.img` + sha256 |
| Nada no USB antes de Release Artifact testado | **sim** | `sandbox_rollout.sh` recusa gate reprovado; M15 é o último |
| Cache de partes verdes | **sim** | `cache_manager.sh` (hash por fase) |
| Nada de mount-hide global com DroidSpaces | **sim** (agora testado) | o gate emite condição **R03** quando SUSFS e M05 coexistem |
| Decisão de produto é da usuária | **sim** | o gate não escolhe; ele classifica e mostra o motivo |

> Ponto de honestidade: se a escolha for **KernelSU + SUSFS**, a “otimização limpa” passa a incluir
> **um kernel de terceiro** no caminho crítico. Isso é defensável — mas é um aumento deliberado de
> superfície, com perda de OTA e um artefato a mais para auditar. Não é “mais limpo” que APatch;
> é mais **ocultável**.

## 8. Decisão A ratificada — motor único (2026-11-01)

**A usuária confirmou:** *"Confirmo APatch no kernel stock"*. As opções B e C ficam **arquivadas**,
não pendentes.

| Opção | Estado | Prova |
|---|---|---|
| **A — APatch no kernel stock** | **RATIFICADA** (2026-11-01) | `references/root-decision.json` · `root_engine_gate.py --engine apatch` → **0** |
| B — KernelSU/SukiSU + SUSFS | **PROIBIDA** por decisão (não é "pendente") | `--engine kernelsu\|sukisu` → **1** |
| C — Magisk | **PROIBIDA** por decisão | `--engine magisk` → **1** · DroidSpaces nem suporta Magisk |

O que a decisão fixa, em termos executáveis:

1. **Um motor só.** `root-engines.json` marca `apatch` como o único `allowed: true`; os demais
   carregam `blocked_by`. Dois motores permitidos = `motor_unico` INCOMPATÍVEL.
2. **Kernel só o da ROM.** `kernel-candidates.json` passou a declarar `origin` (`stock-rom` ×
   `third-party`); qualquer candidato de terceiro é INCOMPATÍVEL mesmo que fosse certificado.
   `--candidate stock-evolutionx` continua **PENDENTE (3)** — o kernel certo ainda exige a L4.
3. **SUSFS sai do escopo** (`decisao_susfs`): nenhum módulo do escopo depende dele; R03 deixa de ser
   condição ativa (continua documentada e testada, para o caso de a decisão ser revista).
4. **M01 = patch `kptools`/`kpimg` no `boot.img` oficial**; rollback é a imagem stock verificada.
5. **M05/DroidSpaces** só aceita motor ratificado (`motor_ratificado` no preflight).
6. **Isonomia de metodologia de kernel:** todo módulo `kernel_level: true` (M01, M05, M10) declara
   `kernel_evidence: rom_package` + `kernel_gate: kernel_compat_check.sh` — uma prova só, do mesmo
   pacote. Nada de "caminho paralelo" com kernel compilado.

**Sequência executável:** `docs/skills/APPROVED-INSTALL-SEQUENCE.md` (fila aprovada, camada de
conformidade e o que está fora da decisão).

**Provas:** `tests/test_root_decision.sh` (38 casos) + `tests/test_root_engine_gate.sh` (35) +
`tests/test_droidspaces_preflight.sh` (32). Revisão só com nova decisão explícita e kernel
**declarado e certificado** à build 2026-09-15 (`revisit_if` no JSON).

Enquanto a L4 não fechar, o estado correto continua **nada de `fastboot flash`**.
