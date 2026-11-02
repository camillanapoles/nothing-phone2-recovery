# Relatório final de orquestração — retificado, validado e pronto para ratificação

> **HISTÓRICO — NÃO EXECUTAR.** Escrito sob a Decisão A (APatch + kernel stock),
> superseded pela **Decisão C** em 2026-11-01 (`references/root-decision.json`). Vale como registro;
> os comandos de root/kernel aqui não são a ordem vigente.

**Documentos irmãos:** [`PROJECT-OVERVIEW.md`](PROJECT-OVERVIEW.md) (o projeto explicado) ·
[`PR-AUTHORIZATION-5W1H.md`](PR-AUTHORIZATION-5W1H.md) (pedido de autorização do PR)

**Data:** 2026-11-01 · **Branch:** `arena/863582fd-nothing-phone2-recovery` · **PR:** não aberto (aguarda seu "ratifico")
**Escopo:** como o agente atuará na próxima sessão — emulação no GitHub Actions, 15 módulos, kernel, custos, rollback e release pré-USB.

---

## 1. O que mudou nesta retificação (premissa corrigida)

| Afirmação original | Correção técnica | Efeito no plano |
|---|---|---|
| "carregar a ROM do Evolution X no QEMU e bootar" | a imagem do `pong` é **arm64** com `vendor` do SM8475 (GPU/modem/NPU/câmera reais); runner hospedado é **x86_64** e o arm64 hospedado **não tem KVM** | a ROM **não** boota no CI; o CI valida a **camada de módulos** numa AVD API 36 x86_64 |
| "validar conflitos no emulador e liberar" | emulador não prova kernel-space, NPU, câmera HAL nem `sysfs` do device | 6 módulos validam de fato, 5 parcialmente, **4 só no aparelho**; GO-USB 10/10 + Stage D cobrem o resto |
| "cache no Actions resolve continuidade" | cache do Actions é efêmero (7 dias, por chave) | dois níveis: `actions/cache` (insumo grande) **e** `cache/` versionado no repo (manifesto + sha256) |
| "um workflow de 25 min" | emulador + boot + 15 módulos não cabem em um job | 3 jobs encadeados com timeouts próprios (25 / 15 / 10) e `needs:` |

Nada disso foi "suavizado": cada correção virou documento, script e teste (§7).

---

## 2. Arquitetura ratificada: 3 estágios de CI + 1 estágio humano

```text
┌───────────────────────────── GitHub Actions (ubuntu-24.04, x86_64) ─────────────────────────────┐
│ A · FORGE (timeout 25)                                                                          │
│   preflight → baixa .zip + confere sha256 → L4 (kernel/KMI/hashes do PACOTE)                    │
│   → gate kernel (modelo/API/KMI/build) → scanner R00–R09 → patch offline                        │
│   → guard4_verify (backup byte-idêntico) → cache put/verify → artefatos                         │
│                                                                                                 │
│ B · SANDBOX (timeout 15, KVM)                                                                   │
│   AVD API 36 x86_64 → boot_completed → 1 módulo por vez via adb → soft-reboot                  │
│   → crash/AVC/uptime → evidence.json → rollout_gate (PASS antes do próximo)                     │
│                                                                                                 │
│ C · RELEASE (timeout 10)                                                                        │
│   imagens + conflict_report + boot_stock_rollback + SHA256SUMS + flash_and_rollback.sh          │
│   → artefato pré-USB (retention 5 dias)                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
   D · DEVICE (você, com o cabo): flash assistido após 10/10 gates → collect_evidence.sh
```

Arquivos: `skills/evox-rom-ci-optimizer/references/evox-ci-validator.yml` (workflow),
`references/emulation-sandbox.md` (racional e limites), `scripts/sandbox_rollout.sh` (Stage B).

---

## 3. Orquestração agêntica (quem faz o quê, com qual prova)

| Sub-agente | Dono de | Entrada | Saída (artefato) | Gate de saída |
|---|---|---|---|---|
| **GOV** (governança) | DAG, ownership ledger, ordem das fases | pedido + decisão da usuária | `workspace/decision.json` + plano | decisão registrada |
| **EVOX-FORGE** | payload, patch, rollback | `.zip` + `candidate.json` | `rom_assets.json`, `boot_patched.img`, `boot_stock_rollback.img(.sha256)` | `guard4_verify` → VERIFIED |
| **CONFLICT-INQUISITOR** | colisão estática | `modules/` + imagens | `conflict_report.json` (CLEAN/WARN/CONFLICT) | `scan --strict` exit 0 |
| **CI-SANDBOX-PROBE** | Stage B (AVD) | módulos + AVD | `evidence/<módulo>.json` | `rollout_gate` PASS por módulo |
| **SNAPSHOT-KEEPER** | estado por camada | fases verdes | branch/tag `snapshot/<layer>` + manifesto | manifesto íntegro |
| **GATEKEEPER (humano)** | flash | 10/10 PASS | `evidence.json` pós-flash | sua autorização |

Handoff é sempre **artefato + hash**, nunca "passou". Contrato completo em `AGENTS.md` §3 e §7.

---

## 4. Ordem incremental dos módulos (ratificada)

| Fase | Módulos | Por que nesta posição | Critério de saída |
|---|---|---|---|
| **F0** | M01 APatch/kernel · M05 DroidSpaces | tudo depende de root; container precisa do kernel | boot + root ativo + rollback verificado |
| **F1** | M03 GApps · M07 Fingerprint · M08 Duck-ToolBox | identidade vem antes de performance; Duck-ToolBox consolida 7+8 | GMS sem crash · fingerprint lida · atestação responde |
| **F2** | M12A MaxManager · M12B GenieX | disputam `sysfs`/NPU; precisam de root e baseline limpo | escrita única · NPU responde |
| **F3** | M02 Câmera | maior risco de `cameraserver`; falha precisa de baseline conhecido | cameraserver estável · sem colisão de XML/.so |
| **F4** | M04 Captura · M06 Free-Form · M09 SAF · M10 rede/socket · M11 port-forward | `stop; start` e netfilter só depois do core estável | SurfaceFlinger/SystemUI ok · SAF R/W · regra por UID |
| **F5** | M13 CI · M14 Snapshots · M15 Release | continuidade e entrega | 10/10 gates · manifesto · pacote pré-USB |

Relação com a sua lista: sua ordem foi preservada como **intenção**; câmera desceu de #2 para F3 e
captura de #4 para F4 (justificativa em `references/module-rollout-order.md` §2). Nada foi removido:
Duck-ToolBox cobre #7+#8, MaxManager/GenieX entram em F2.

---

## 5. Emulação: o que ela prova e o que só o aparelho prova

| Valida de fato (6) | Valida parcialmente (5) | Só no aparelho (4) |
|---|---|---|
| M04 captura · M06 free-form · M07 fingerprint · M09 SAF · M10/M11 rede · M13/M14/M15 processo | M02 câmera · M03 GApps · M05 DroidSpaces · M08 Duck-ToolBox · M12B GenieX | M01 kernel/KPM · M12A MaxManager (`sysfs`) · HAL de câmera · RKP/attestation real |

Consequência prática: **o CI nunca autoriza flash sozinho**. Ele reduz risco e prova o processo; o
GO-USB 10/10 e o Stage D continuam humanos.

---

## 6. Custos: como o pipeline não vira conta

| Trava | Valor | Quem verifica |
|---|---|---|
| `concurrency.cancel-in-progress` | true | lint R1 |
| timeout do job | 25 / 15 / 10 min | lint R2 |
| timeout do step do emulador | 12 min | lint R3 |
| watchdog de boot | 300 s + `dmesg` | lint R8 |
| cache da ROM | por `sha256` | lint R4 |
| retention dos artefatos | 5 dias | lint R5 |
| permissões | `contents: read` | lint R6 |
| KVM | passo udev explícito | lint R7 |
| emulador sem snapshot | `-no-snapshot` | lint R9 |
| sem `fastboot flash` no CI | proibido | lint R10 |
| sem segredo literal | proibido | lint R11 |

`scripts/ci_workflow_lint.py` roda no `make -C skills check-all`; workflow que perder uma trava reprova.

---

## 7. Evidência desta retificação (rodada agora)

```text
R00–R09 (scanner) ................ 13 PASS
preflight de dependências ........  8 PASS
L4 pelo pacote (ROM) ............. 15 PASS
kernel × ROM × device ............ 10 PASS
rollout canário (ledger) ......... 13 PASS
cache + guard4 ................... 13 PASS
Stage B (adb stub) ...............  9 PASS
lint de custo do workflow ........ 12 PASS
coletor pós-flash ................  8 PASS
validate ......................... 0 falhas · 8 skills
eval ............................. APROVADO
higiene de estado ................ 13 PASS · clean · 0 linhas no DB do FSM
```

---

## 8. Alternativas que avaliei (e por que a escolhida venceu)

| Opção | Custo/complexidade | Cobertura | Veredito |
|---|---|---|---|
| AVD x86_64 API 36 (escolhida) | baixo, KVM no runner | camada de módulos | **padrão** |
| Cuttlefish arm64 | exige runner arm64 com KVM (self-hosted) | GSI arm64 real | opcional, se você pagar runner |
| QEMU TCG arm64 | sem KVM, 10–50× lento | teórica | descartado (estoura timeout) |
| Device farm | custo por minuto | hardware real | descartado no pré-flash |
| Codespace interativo | cobra VM ligada | depuração manual | só com `poweroff 1800 s` |

---

## 9. Riscos residuais (declarados, não escondidos)

1. **ABI de módulo é declarativa**: se o `.zip` não declarar `android_api`/`kmi`, o gate rejeita — mas
   quem preenche é o fornecedor do módulo. Risco de "declarou errado".
2. **Duck-ToolBox/`duckd` é arm64**: no Stage B o binário não roda; valida-se contrato/WebUI.
3. **AVD API 36 x86_64 ≠ vendor do Pong**: câmera, NPU e `sysfs` ficam sem teste até o Stage D.
4. **Emulador pode passar e o aparelho falhar** em virtude de SELinux do vendor: mitigado por
   `collect_evidence.sh` (AVC denials) e rollback verificado.
5. **ROM/GApps de terceiros** mudam sem aviso: `--expect-sha256` + cache por hash tornam a troca visível.

---

## 10. Pendências — estado após as suas respostas de 2026-11-01

| # | Pendência | Sua resposta | Como virou contrato |
|---|---|---|---|
| P1 | Vanilla × GAPPS | "explicar e sugerir na abertura, com justificativa" | `references/session-opening.md` §P1 + `session_open.py questions` |
| P2 | Caminho do `.zip` | "solicitar após a decisão" | §P2: pedido em ordem, só depois da build |
| P3 | Autorizar binários | "pedir item a item, com justificativa" | §P3: 4 itens com "sem ele não há…" |
| P4 | Kernel | "sugerir o mais estável/compatível" | §P4: stock + APatch; externo só com gate 1 verde |
| P5 | Módulos | "pedir aprovação com descrição" | §P5 + `decision.json` com `approved` por módulo |
| P6 | Canário/AVC | "melhor performance" | §P6: **AVD 60 s · device 10 min · 0 AVC novo** (proposta) |
| P7 | Cache | "melhor performance" | §P7: **inline ≤ 25 MB · retention 5 d · prune 90 d** |
| P8 | USB | "produção, só após 10/10 no emulador" | §P8 + `usb.acknowledged` obrigatório na decisão |

**Bloqueantes (humanas):** P1 (Vanilla × GApps), P2 (caminho do `.zip` + sha256), P3 (autorização
de binários) e P9 (autorizar o PR).
**Delegadas e aceitas:** P10 Duck-ToolBox consolidado · P11 kernel stock + APatch · P12 HIL fora do
GitHub Actions · P13 HIL A/B como pré-gate · P14 quarentena no host. Detalhe e critérios de revisão
em [`PENDING-DECISIONS.md`](PENDING-DECISIONS.md).

## 11. Checklist de ratificação (marque para liberar a próxima sessão)

- [ ] **R1** concordo que a ROM arm64 do Pong **não** boota no CI e que o Stage B valida a camada de módulos
- [ ] **R2** concordo com os 3 estágios (forge → sandbox → release) + Stage D humano
- [ ] **R3** concordo com a ordem F0→F5 dos 15 módulos
- [ ] **R4** concordo com as travas de custo (25/15/10 min, cache por hash, retention 5)
- [ ] **R5** concordo que o CI nunca autoriza flash sozinho (GO-USB 10/10 + sua confirmação)
- [ ] **R6** respondi P1–P3 (bloqueantes) e, se quiser, P4–P10

Com **R1–R5 + P1–P3**, a próxima sessão executa o Stage A real (L4 + kernel gate + patch + rollback)
e devolve o pacote com hashes; o Stage B roda na sequência, módulo por módulo.

---

## 12. Ratificação de execução (2026-11-01) — contrato para a próxima sessão

Esta seção fecha o pedido de **garantia**: a próxima sessão que executar não pode trocar os
princípios nem “reinterpretar” a arquitetura. Tudo abaixo é **executável**, não narrativa.

| Peça | Arquivo | O que garante |
|---|---|---|
| Contrato | [`ARCHITECTURE-DECISION.md`](ARCHITECTURE-DECISION.md) | 10 princípios, arquitetura A→B→C→E→D, lista do que **não** refazer, limites do A/B |
| Trava | `skills/evox-rom-ci-optimizer/scripts/architecture_guard.py` | **AG1–AG21** falham o build se a arquitetura antiga voltar (`make -s arch`, dentro de `make -s prove`) |
| Classificador de falha | `scripts/abl_fallback_probe.sh` | distingue `OK` / `ABL_FALLBACK` / `HANG` / `HANG_EARLY` / `BOOTLOADER` / `NO_DEVICE` |
| Marcas de boot | `assets/00_slot_router.sh guard` | separa falha antes do userspace de travamento pós-kernel |
| Abertura | `scripts/session_open.py` (`auto` + `check`) | preenche P10–P14, mantém P1–P3 bloqueantes |
| Validação | [`VALIDATION-REPORT.md`](VALIDATION-REPORT.md) | prova arquivo por arquivo, inclusive o que **não** foi possível validar offline |

**Números deste worktree:** `make -s prove` exit **0** · **18 regras** de arquitetura OK ·
29 suítes verdes · **582 casos** (527 na skill da ROM + 8 no guardian + 13 de estado + 34 nos wrappers) · `bash -n` em 40 scripts · `py_compile` em 9 módulos · `audit_loop.sh` converge limpo em 2 iterações · **139/139 mutantes mortos por asserção** (`make mutation`, ver `FALSIFIABILITY-REPORT.md`).

**Auditoria de contradições:** 57 erros → **0** (`docs/skills/AUDIT-CONTRADICTIONS.md`), incluindo a colisão
`Gate 4`/`G4`/`gate 10` e a questão do `init_boot` (agora condicional e provada por par de rollback). <!-- scan:exempt -->

**Coleta determinística (P1):** manifesto `references/rom-artifacts.json` pina as duas variantes da
build 2026-09-15; `scripts/rom_artifact_fetch.sh --variant both` baixa/confere com pin de sha256 e
drift = exit 4. Discussão em [`VANILLA-VS-GAPPS.md`](VANILLA-VS-GAPPS.md).

**Correções aplicadas neste turno:** `bootctl` removido do HIL (AG14) · pipeline antigo
movido para `references/archive/` com aviso SUPERSEDIDO (AG15) · `QEMU/KVM` → AVD em
`runtime_module_tester.sh`, `pong-hardware-matrix.md`, `AGENTS.md`, `agente.md`, `skills/README.md` ·
guia legado do `.github/workflows/boot-test.yml` marcado como tal.

**Ainda fora do alcance do sandbox:** download do `.zip` (sem egress), L4 real e patch de boot
(sem `payload-dumper-go`/`magiskboot`/`kptools`), e comportamento real do ABL (sem USB).
O relatório de validação declara isso explicitamente — nada foi simulado como se fosse real.
