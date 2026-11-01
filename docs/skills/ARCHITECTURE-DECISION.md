# ADR-001 — Arquitetura de teste e promoção do Nothing Phone 2 (Pong)

**Status:** aceito em 2026-11-01 · **Decisor:** usuária · **Executor:** agente de sessão
**Fonte de verdade de conteúdo:** `skills/evox-rom-ci-optimizer/references/module-matrix-5w1h.md`
**Trava executável:** `skills/evox-rom-ci-optimizer/scripts/architecture_guard.py` (AG1–AG21)

> Este documento existe para a **próxima sessão que executa**. Se você é essa sessão: leia
> este arquivo, rode `make -s arch` e `python3 skills/evox-rom-ci-optimizer/scripts/session_open.py check`.
> Se `arch` falhar, **pare** — alguém reintroduziu a arquitetura antiga.

---

## 0. Vocabulário canônico (evita colisão entre skills)

| Termo | Significa | **Não** confundir com |
|---|---|---|
| `AG1–AG21` | travas de arquitetura executáveis (`architecture_guard.py`) | `G1–G10` (objetivos globais, §9 do `AGENTS.md`) |
| `Guard-4` | 4 condições antes de qualquer mutação: build/kernel pinados · backup stock byte-idêntico (boot **e** `init_boot` quando existir) · rollback exato · confirmação humana | `G4` de outras skills (`github`, `cogni-synapse`, `sci-…`), que significam outra coisa <!-- scan:exempt --> |
| **GO-USB 10/10** | checklist de 10 itens antes do cabo (antes chamado de "gate 10") <!-- scan:exempt --> | `G10` (objetivo "HIL A/B isolado") |
| `R01–R09` | regras do scanner de conflito | `C1–C13` (regras da varredura de contradições) |
| `P1–P14` | decisões da usuária | `E1–E6` (erros do draft do HIL) |
| `F0–F5` | fases de rollout dos módulos | `W1–W5` (ondas antigas, históricas) |

Motivo: "Gate 4"/"G4" existia com **5 significados diferentes** no repositório e "gate 10" colidia <!-- scan:exempt -->
com o objetivo `G10`. A varredura (`contradiction_scan.py`, regras C8–C10) reprova o vocabulário solto.

## 1. Princípios invioláveis

| # | Princípio | Como é verificado |
|---|---|---|
| 1 | Nada vai ao USB sem passar por imagem (AVD) **e** HIL local A/B | `workflows-local/pong-ab-hil.yml` (gate de slot) |
| 2 | Um módulo por vez, com teste antes do próximo | `rollout_gate.sh` + ledger |
| 3 | Falha tem que ser classificada, não adivinhada | `abl_fallback_probe.sh` |
| 4 | Quarentena acontece **no host, antes** da troca de slot | `00_slot_router.sh quarantine` |
| 5 | Todo artefato é identificado por sha256; ausência de binário é erro explícito | `extract_rom_assets.sh` sai 3 |
| 6 | Kernel só com suporte declarado à build exata (2026-09-15) e ao Pong | `kernel_compat_check.sh` |
| 7 | `boot.img` stock sempre disponível para desbootloop | `cache_manager.sh` + backup dd |
| 8 | Nenhum workflow do GitHub executa `fastboot` | AG13 |
| 9 | Emulador prova a **camada de módulos**, nunca o boot do pong | AG8 |
| 10 | Decisão registrada antes de executar (`decision.json`) | `session_open.py check` |
| 11 | Teste só vale se puder reprovar (mutação) | `make mutation` 129/129 · AG19/AG21 |
| 12 | Asserção não pode ser impossível nem engolir falha | `make vacuity` · AG20 |
| 13 | **Um único motor de root (APatch) e um único kernel (o da ROM)** | `root_engine_gate.py` + `tests/test_root_decision.sh` |


## 2.1 Decisão A ratificada — motor único e kernel da ROM (2026-11-01)

**Confirmado pela usuária:** *"Confirmo APatch no kernel stock"*. Registro executável:
`skills/evox-rom-ci-optimizer/references/root-decision.json` (`decision: A`, `ratified: true`,
`decided_by: user`, `decided_at: 2026-11-01`, `engine: apatch`, `kernel_source: stock-rom`,
`custom_kernel_allowed: false`, `susfs_allowed: false`, `exclusive_single_engine: true`).

| Consequência | Antes | Agora |
|---|---|---|
| `--engine kernelsu` / `--engine sukisu` / `--engine magisk` | 3 (pendente) | **1 (INCOMPATÍVEL)** — decidido, não pendente |
| kernel de terceiro (`--candidate np2-…`, `meteoric-…`) | 1 por EOL/não certificado | **1 por política**, independente de certificação |
| `--candidate stock-evolutionx` | 3 (falta L4) | 3 (falta L4) — o kernel certo continua exigindo prova |
| SUSFS | condição possível | **proibido** (`decisao_susfs`) — nada no escopo depende dele |
| M01 | "patch ou kernel de terceiro" | **patch `kptools`/`kpimg` no `boot.img` da ROM** |
| DroidSpaces (M05) | qualquer motor da lista do app | só `apatch` (`motor_ratificado`) |

**Isonomia de metodologia de kernel:** todo módulo `kernel_level: true` (M01, M05, M10) declara
`kernel_evidence: rom_package` + `kernel_gate: kernel_compat_check.sh` — a mesma prova, extraída do
mesmo pacote. Não existe "caminho B" com kernel compilado; a suíte `test_root_decision.sh` falha se
alguém reintroduzir um segundo motor, um segundo método de kernel ou um candidato sem origem.

Revisão só com nova decisão explícita (`revisit_if` no JSON): kernel com suporte **declarado e
certificado** (`kernel_compat_check.sh` exit 0) à build 2026-09-15.

## 2. Arquitetura em vigor

```
A FORGE (offline, host)                       exige zip + sha256; nada de download no CI
      │
B SANDBOX — AVD API 36 x86_64 no GitHub Actions   pré-gate barato (módulos, conflito, boot da UI)
      │  cache por sha256 · timeout · -no-snapshot · encerra sozinho (sem custo parado)
C RELEASE — artifact imutável + manifesto        nada sai daqui sem teste verde
      │
E HIL LOCAL — act + slot A/B (quarentena)        GATE AUTORITATIVO
      │  abl_fallback_probe.sh: OK / ABL_FALLBACK / HANG / HANG_EARLY / BOOTLOADER
D DEVICE/USB — humano                           10/10 + autorização item a item
```

**Limite do A/B:** isola `boot`/`init_boot` (por isso serve para root, kernel, AVB).
**Não** isola `system`/`vendor` (partições dinâmicas compartilhadas) — para módulos que mexem
em `/system` a prova é o AVD + o ledger de rollout, não o slot.

## 3. O que NÃO refazer (arquitetura anterior desprezada)

| Abandonado | Por quê | No lugar | Trava |
|---|---|---|---|
| `mount --bind /data/adb/staging_b /data/adb/modules` em `post-fs-data.d` | roda **depois** da varredura de módulos do APatch/KernelSU; o bind não desfaz de forma confiável e o boot já foi decidido | quarentena por marcador `disable` no host, antes da troca de slot | AG10 |
| `bootctl mark-boot-successful` | HAL `boot_control` não é garantida no Pong | `fastboot --set-active` + verificação de `ro.boot.slot_suffix` **e** `sys.boot_completed` | AG2 |
| `cp -rn` para promover módulos | não idempotente, não auditável | manifesto + sha256 + `guard4_verify.sh` | AG9/AG5 |
| Bootar a ROM arm64 do Pong em runner/AVD | runner hospedado é x86_64; ARM64 hospedado não tem KVM aninhado; TCG estoura timeout | AVD só valida a camada de módulos | AG8 |
| `fastboot flash` disparado por CI | CI não tem o aparelho; comando remoto é irreversível | HIL local com slot B e rollback | AG13, AG1 |
| `modules_stable` | diretório inexistente no APatch; instrução fantasma | caminho real + verificação em runtime | AG9 |
| `staging_b` como caminho fixo | conflita com o nome do slot e induz erro de alvo | slot resolvido por `ro.boot.slot_suffix` | AG3 |
| `bootctl mark-boot-successful` no workflow local | HAL não garantida; mascarava falha de boot | checagem de `sys.boot_completed` **e** slot esperado | AG14 |
| Baixar “a build mais nova” a cada sessão | resultado diferente a cada run; quebra comparação e cache | manifesto pinado (nome/URL/build) + lock de sha256; divergência = exit 4 | AG16 |
| Dois pipelines cloud (`evox-ci-pipeline.yml` e `evox-ci-validator.yml`) | ambiguidade de fonte de verdade | antigo movido para `references/archive/` com aviso | AG15 |

Mensões históricas que **não** têm efeito sobre a arquitetura nova: narrativa de incidentes,
comparativos de alternativas (Cuttlefish, QEMU TCG, macOS runner) e o guia legado gerado por
`.github/workflows/boot-test.yml` (marcado como LEGADO no próprio artefato). Elas ficam como
registro; não são instruções.

## 3-B. Por que o HIL A/B **não** é o gate final (P13)

O HIL A/B é o pré-gate técnico mais forte que existe sem o cabo na mão dela — e continua **não**
sendo o gate final. As razões são estruturais, não de maturidade:

| O que o A/B prova | O que ele **não** prova |
|---|---|
| o slot novo completa `boot_completed=1` | se o app de banco abre sem detectar root |
| falha cedo (ABL troca de slot) é reversível | travamento pós-kernel sem marca (só o probe detecta, com limite) |
| kernel/`boot`/`init_boot`/AVB do slot funcionam | `system`/`vendor`/`product` — partições **dinâmicas compartilhadas** entre slots |
| módulos que quebram o boot são isoláveis | câmera HAL, NPU, rádio/VoLTE, térmica e consumo |
| rollback por `fastboot --set-active` | comportamento de UI e de serviços de terceiros |

Além disso, `quarantine`/`activate` usam `su` — logo **o ciclo 0 (M01) não pode usar o roteador**:
o primeiro root é fastboot puro, e é exatamente onde `guard4_verify` (par `boot`/`init_boot`) e o
layout do pacote importam mais. Por isso o gate final é o **GO-USB 10/10 + autorização humana**, e a
prova derradeira é o aparelho.

## 4. Captura do risco "ABL só cobre falha cedo"

Fallback do bootloader só é confiável para falha **antes do userspace**. Um travamento em
`system_server` pode deixar o slot ruim sem que o ABL troque de slot — o aparelho fica em loop
"tela acesa, sem boot". Como isso é detectado:

1. **Marca de boot** — `00_slot_router.sh guard` grava `/data/adb/slot_router/marks/<slot>_<n>.mark`
   (`uptime`, `at`) no `post-fs-data.d`. Marca presente = o kernel **chegou** ao userspace.
2. **Probe host** — `abl_fallback_probe.sh --staging b --prod a --timeout 180 --rollback`
   classifica: `OK` (0) · `ABL_FALLBACK` (3, slot bootado ≠ staging) · `HANG` (4, marca presente
   e `boot_completed=0` → travamento pós-kernel) · `HANG_EARLY` (4, sem marca → antes do userspace)
   · `BOOTLOADER`/`NO_DEVICE` (5).
3. **Evidência** — `pstore/console-ramoops-0`, `logcat -b crash`, `dmesg`, `dumpsys activity`
   em `workspace/evidence/` + `boot_probe.json`.
4. **Ação** — `--rollback` executa `fastboot --set-active=<prod>`; `quarantine` antes do próximo ciclo;
   exit ≠ 0 impede o ledger de marcar `passed`.
5. **Três camadas** — watchdog por `boot_completed` **e** slot pós-boot (dois sinais), canário
   `rollout_gate.sh` e `max-attempts` no router.

Limite declarado: se o aparelho travar **antes** de qualquer `adb` e o ABL não trocar de slot,
o probe retorna `NO_DEVICE`/`BOOTLOADER` → recuperação manual por botão físico + `fastboot
--set-active`. Não há automação honesta para esse caso.

## 5. Verificação em 60 segundos

```bash
make -s arch                                  # AG1–AG21
skills/evox-rom-ci-optimizer/scripts/audit_loop.sh   # AG + scan + cobertura + vacuidade + suítes
make -s mutation                              # falseabilidade: 129 mutantes, 0 sobreviventes
make -s prove                                 # estado + guard + 15 suítes + eval
python3 skills/evox-rom-ci-optimizer/scripts/architecture_guard.py --self-test
python3 skills/evox-rom-ci-optimizer/scripts/session_open.py check --file workspace/decision.json --json
```

## 6. O que continua dependendo da usuária

| ID | Pergunta | Por que não foi delegada |
|---|---|---|
| P1 | Vanilla × GApps | muda o conteúdo do sistema e o conjunto de módulos |
| P2 | Caminho do `.zip` + sha256 | sandbox sem egress ao CDN da Evolution X |
| P3 | Autorização de binários | instalação de ferramentas no host dela |

P10–P14 (Duck-ToolBox consolidado, kernel stock+APatch, HIL fora do GitHub Actions, HIL como
pré-gate, quarentena no host) foram **delegadas** e estão registradas em `decision.json`
(`defaults.decided_by = "agent-context"`) por `session_open.py auto`.

## 7. Histórico

| Data | Mudança |
|---|---|
| 2026-11-01 | ADR criado; arquitetura híbrida AVD→HIL→USB ratificada; 13 regras de trava |
| 2026-11-01 | §0 vocabulário canônico (fim da colisão Gate 4/G4/gate 10); <!-- scan:exempt --> §3-B limites do A/B; AG17/AG18 (contradições e cobertura); `guard4_verify` cobre `init_boot` quando o pacote tiver |
