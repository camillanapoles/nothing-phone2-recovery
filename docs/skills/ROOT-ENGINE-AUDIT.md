# Auditoria — qual motor de root, qual kernel, e como ficam os módulos

**Data:** 2026-11-01 · **Device:** Nothing Phone (2) `pong` / SM8475 · **ROM alvo:** Evolution X
`16.0-20260915-Pong-11.11` (Android 16 / API 36, pinada) · **Pergunta:** Magisk, APatch ou
KernelSU(+SUSFS com kernel customizado)? E isso é compatível com a otimização limpa que foi pedida?

**Regra que vale aqui:** o agente verifica e recomenda com dado; **a escolha é sua**. Nada foi
flasheado, nada foi substituído — só auditado com fonte, data e hash.

---

## 1. Veredito em uma linha

> **Hoje só existe um conjunto COMPATÍVEL: APatch no `boot.img` da própria ROM.**
> KernelSU/SUSFS exige kernel de terceiro e **nenhum candidato declara suporte à sua build** →
> estado `PENDENTE`. O Meteoric, citado como “opção de out/nov 2026”, está **EOL desde jun/2025**.

Isso não é opinião: é a saída do gate novo `root_engine_gate.py` (§6).

| Combinação | Veredito do gate |
|---|---|
| APatch + kernel stock (sem candidato de kernel) | **COMPATÍVEL** (exit 0) |
| APatch + kernel stock com manifesto (`stock-evolutionx`) | **PENDENTE** — falta a L4 (KMI/base reais) |
| KernelSU / SukiSU sem candidato | **PENDENTE** — motor exige kernel próprio |
| KernelSU + NP² Kernel v3.0.5 | **PENDENTE** — kernel ativo, mas não certificado para a build |
| KernelSU + Meteoric V6 | **INCOMPATÍVEL** — `rejected_eol` |

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
| Status no repo | `baseline_recommended` | `fallback` | `second_wave` | `second_wave` |

Fontes: `references/root-engines.json`; `config/managers.json`; aviso já existente nos workflows —
“KernelSU LKM has KMI mismatch on stock kernel”.

## 4. Candidatos de kernel (com data e hash)

| Candidato | Versão / data | KMI declarada | Suporte à sua build? | Status |
|---|---|---|---|---|
| **Kernel stock da ROM** | `boot.img` do `payload.bin` (build 2026-09-15) | sai da L4 | é a própria build | `baseline` |
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
| `tests/test_root_engine_gate.sh` | 18 casos (inclui fixtures que provam que o gate sabe dizer **não**) |
| `references/mutation-catalog.json` | 4 mutantes novos (M103–M106), todos mortos por asserção |

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

## 8. Recomendação (com dado) e o que falta para você decidir

**Recomendação:** duas ondas.

1. **Onda 1 (agora):** kernel stock + **APatch**. É o único conjunto que o gate declara
   `COMPATÍVEL` sem dados novos; entrega root, Guard-4, rollback por imagem stock e todos os 15
   módulos sem depender de kernel de terceiro.
2. **Onda 2 (se e quando a ocultação em nível de kernel for requisito):** **KernelSU/SukiSU com
   SUSFS** sobre um kernel **mantido** — candidato atual: NP² Kernel v3.0.5 (`candidate_unverified`),
   não o Meteoric (EOL).

Para transformar a onda 2 em decisão executável, faltam **três dados** (nenhum deles é opinião):

1. **L4 da build pinada** — `extract_evox_base.sh` sobre o ZIP oficial (já pinado em
   `references/rom-artifacts.json`) → KMI e base reais do kernel da ROM.
2. **Declaração do mantenedor do kernel** de suporte à build `EvolutionX-16.0-20260915-Pong-11.11`
   (API 36) — suporte “a LineageOS/A16 em geral” não fecha o gate.
3. **Hash do artefato** (o NP² já publica; o Meteoric não) e teste em AVD antes do físico.

**Decisão sua (assinale):**

- [ ] **A — APatch no kernel stock** (recomendado): começo hoje, sem kernel de terceiro.
- [ ] **B — KernelSU/SukiSU + SUSFS**: aceito trocar o kernel oficial por um de terceiro, com perda
      de OTA, e vou fornecer/aguardar os 3 dados acima antes de qualquer flash.
- [ ] **C — Magisk**: fallback (só se algum módulo exigir Magisk especificamente; hoje nenhum exige).

Enquanto não houver resposta, o estado correto é **nada de `fastboot flash`** — o gate continua
`PENDENTE` e o ledger continua fechado.
