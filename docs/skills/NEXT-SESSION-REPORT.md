# Relatório de preparação — sessão de execução da ROM (para validação antes do PR)

**Data:** 2026-11-01 · **Branch:** `arena/863582fd-nothing-phone2-recovery` · **PR:** não aberto (aguardando sua validação)
**Pergunta que originou este documento:** a lacuna L4 deve ser fechada com a **imagem da ROM** e não com o aparelho?

> **Atualização 2026-11-01 (retificação de arquitetura):** este relatório descreve a preparação da L4
> e dos gates. A orquestração final — emulação no GitHub Actions, 3 estágios, ordem F0–F5 dos
> módulos e checklist de ratificação — está em **[`FINAL-ORCHESTRATION-REPORT.md`](FINAL-ORCHESTRATION-REPORT.md)**.

---

## 1. Resposta direta à sua dúvida: **sim, a L4 vem do pacote da ROM**

Você está certa. Os três dados da L4 são **propriedades do pacote que será gravado**, não do estado
atual do telefone:

| Dado da L4 | Fonte correta | Por que não o aparelho |
|---|---|---|
| versão de kernel / KMI | `boot.img` **dentro** do `.zip` oficial | o kernel instalado hoje pode ser outro (APatch/custom) — não é a base da build |
| hash de `boot_b` | `boot.img` extraído do `payload.bin` | `fastboot getvar` não devolve hash de partição, e o slot pode ter sido alterado |
| hash de `vendor_boot_b` / `vbmeta_b` | `vendor_boot.img` / `vbmeta.img` do mesmo `payload.bin` | idem; e o que vale para rollback é o byte do pacote oficial |

O aparelho entra **só como confirmação, em modo leitura**: `ro.build.display.id`, `ro.boot.slot_suffix`,
`fastboot getvar current-slot/slot-successful:*`. Nada de hash inventado, nada de "deve ser igual".

Isso está implementado e testado: `skills/evox-rom-ci-optimizer/scripts/extract_rom_assets.sh`
(**15 PASS / 0 FAIL**) — extrai `payload.bin` → imagens → `rom_assets.json` com sha256, kernel, KMI e
`l4_closed`. Sem `payload-dumper-go`, ele **falha com exit 3** em vez de chutar.

---

## 2. O que eu entendi que você quer (valide esta lista)

1. Android 16 (Evolution X **11.11**, build `20260915` para `Pong`) rodando com **root** (APatch/KPM),
   **DroidSpaces** (containers), **Duck-ToolBox** (Play Integrity/banking), **MaxManager** (performance),
   **GenieX** (IA local no NPU), câmera, SAF, multi-janela, rede por app/port-forward.
2. **Sem conflito** com o que já existe no aparelho: cada escrita disputada tem um único dono (R01–R09).
3. **Reversível**: sempre existe `boot_stock_rollback.img` com SHA-256 antes de qualquer flash.
4. **Nada no escuro**: o agente explica o que vai fazer, com qual gate, e prova com saída de comando.
5. **Decisão sua, não dele**: qual build usar (Vanilla ou GAPPS) e quando o cabo USB entra.
6. **Este workspace é a preparação**: a próxima sessão precisa encontrar conhecimento, instrução e
   governança já testados — não precisa redescobrir nada.

Se algum item estiver errado, é aqui que se corrige — antes de qualquer download.

---

## 3. A pergunta que o agente FARÁ (e não pode responder por você)

### Vanilla × GAPPS — trade-off honesto

| Critério | **Vanilla** (`…-11.11-Vanilla-Official.zip`) | **GAPPS** (`…-11.11-Official.zip`) |
|---|---|---|
| Conteúdo | AOSP + Evolve, sem Google | AOSP + Evolve + Google Apps/serviços |
| Play Services / banking | **não funciona** até instalar GApps/microG manualmente | funciona de origem |
| M03 (Google core + fingerprint) | vira tarefa manual sua (Wave 2) | já satisfeita pelo build |
| Superfície de conflito | menor: menos `priv-app`, menos `.so`, menos sysconfig | maior: GMS, permissões, sysconfig, atualizações do Play |
| Tamanho / boot / RAM | menor, boot mais rápido, menos background | maior, mais serviços residentes |
| Controle de identidade | total (você escolhe pacote e fingerprint) | fingerprint do Evolve; ajuste fino via Duck-ToolBox |
| Play Integrity | caminho longo: props manuais + TrickyStore | caminho curto: build certificada + TrickyStore |
| Risco de bootloop por módulo | menor (menos coisa para colidir) | maior (mais superfície para o scanner pegar) |
| Recomendado quando | mínimo, privacidade, laboratório, GApps própria | uso diário completo, IA/Google prontos, menos passos |

**Minha recomendação, dado o que você descreveu (IA local, banking, câmera, uso diário): GAPPS.**
Justificativa positiva: M03 já vem resolvida, Play Services presente (banking/IA dependem dele),
menos passos manuais, caminho mais curto para Play Integrity. Justificativa negativa (o que você paga):
mais bloat, mais superfície de conflito (o scanner vai trabalhar mais nas Waves 2–3), imagem maior,
mais serviços em background, e a fingerprint é a do Evolve (não a sua escolha).

**Alternativa defensável:** Vanilla se você quer soberania total da camada Google (microG/GApps
própria) e aceita fazer M03 à mão — é o caminho mais limpo tecnicamente e o mais trabalhoso.

> O agente **pergunta**, registra a escolha em `workspace/decision.json` (versão, URL, sha256) e só
> então baixa/extrai. Sem decisão registrada, o pipeline para com exit 2.

---

## 4. O que o agente fará — passo a passo, com gate e prova

| Fase | Ação | Comando | Prova / gate |
|---|---|---|---|
| **0. Briefing** | explica plano, pergunta Vanilla × GAPPS, registra decisão | `cat workspace/decision.json` | decisão sua registrada |
| **1. Preflight** | checa binários, sem instalar nada silenciosamente | `preflight_deps.sh --hints` | exit 0 ou lista do que falta |
| **2. L4** | fecha hash/kernel/KMI **do zip** | `extract_rom_assets.sh --zip … --expect-sha256 …` | `l4_closed: true` (exit 0) |
| **3. Base** | extrai partições de trabalho (Wave 1) | `extract_evox_base.sh --rom …` | `evox_base_manifest.json` com sha256 |
| **4. Auditoria** | conflito estático entre módulos/plataformas | `make scan` / `make audit` | `CLEAN` (WARN justificado; CONFLICT = veto) |
| **5. Estágio A** | patch offline do boot (APatch/KPM) + rollback | `make patch-boot` / `forge_patcher.sh` | `boot_patched.img` + `boot_stock_rollback.img` + `.sha256` |
| **6. Estágio B** | boot do patched no QEMU/KVM | `make runtime-test` | `sys.boot_completed=1`, sem RescueParty |
| **7. Ondas 2–4** | identidade, performance/NPU/câmera, janelas/SAF/rede | módulos + `make scan` a cada onda | 10 testes binários por onda |
| **8. Estado** | snapshot por camada | `snapshot_branch_manager.sh` | `snapshot/<layer>/<tag>` + manifesto |
| **9. Release** | pacote pré-USB | `make bundle` | `SHA256SUMS` + `flash_and_rollback.sh` |
| **10. Pós-flash** | coleta de evidência (só depois do seu OK) | `collect_evidence.sh` | `evidence.json` + `MANIFEST.sha256` |

Nada disso toca o aparelho. A fase 10 é a única que depende de você conectar o cabo — e ela vem
**depois** de 10/10 gates.

---

## 5. Quais módulos, em que onda, entregues como

| Onda | Módulos | O que é entregue | Teste que valida |
|---|---|---|---|
| **W1** | M01 Kernel/Root (APatch+KPM) · M05 DroidSpaces | `boot_patched.img`, `boot_stock_rollback.img`, daemon LXC | Guard-4/KMI; namespaces |
| **W2** | M03 GApps A16 · M07 Fingerprint · M08 Duck-ToolBox | overlays sysconfig, `system.prop`, `duck-toolbox` | colisão de chave; crashes GMS |
| **W3** | MaxManager (externo) · GenieX (externo) · M02 Câmera | `MaxManager-V2.zip` auditado, QAIRT, GCam/HAL | exclusividade de escrita; rede do NPU; `.so`/XML |
| **W4** | M04 Screen Capture · M06 Free-Form · M09 SAF · M10/M11 Rede | flags WindowManager, overlay SAF, `iptables`/`adb reverse` | SurfaceFlinger/SystemUI; R/W SAF; ConnectivityService |
| **W5** | M13 Ambient CI · M14 Snapshots · M15 Release | workflow com travas, branches `snapshot/*`, pacote pré-USB | trava de custo; manifesto; gate 10 |

Regras duras por módulo: `persist` intocável (R06), SELinux `Enforcing` (R08), MaxManager com
exclusividade de escrita (R01/R02), Duck-ToolBox consolida M07/M08 (R04), DroidSpaces sem mount-hide
global (R03).

---

## 6. Binários: o que instalar (e o que já existe)

| Binário | Para quê | Como instalar | Estado aqui |
|---|---|---|---|
| `payload-dumper-go` | **L4** + Wave 1: abrir `payload.bin` | `go install github.com/ssut/payload-dumper-go@latest` ou release oficial | **ausente** |
| `kptools` | patch APatch/KPM (M01) | release `github.com/bmax121/KernelPatch/releases` | ausente |
| `magiskboot` | unpack/repack `boot.img` | Magisk (MagiskBoot) | ausente |
| `abootimg` | fallback de unpack | `apt install -y abootimg` | ausente |
| `adb` | estágio B no device / pós-flash | `apt install -y android-tools-adb` | ausente |
| `qemu-system-x86_64` | estágio B emulador | `apt install -y qemu-system-x86` | ausente |
| `strings` (binutils) | ler kernel/KMI do `boot.img` | `apt install -y binutils` | presente |
| `unzip`, `python3`, `sha256sum` | manifesto, hashes, scanner | base do sistema | presentes |

Para a **L4 isolada**, o mínimo é: `payload-dumper-go` + `unzip` + `python3` + `sha256sum`.
O `preflight_deps.sh` não instala nada: diz o que falta e o comando (exit 1 se exigido).

---

## 7. O que continua bloqueado (e por quê)

| Bloqueio | Consequência | Como destravar |
|---|---|---|
| **Sem rede para `cdn.evolution-x.org` neste ambiente** | o `.zip` não pode ser baixado pelo agente | você baixa e coloca o arquivo no workspace (ou indica o caminho) |
| **L4 sem o zip** | `rom_assets.json` não existe → Wave 1 para | rodar `extract_rom_assets.sh` com o zip local |
| **Sem `payload-dumper-go`** | extração impossível (exit 3 explícito) | instalar via Go ou release |
| **Flash físico** | não autorizado | 10/10 gates + sua confirmação explícita |
| **GitHub / PR** | não usado | liberação explícita sua |

---

## 8. Critérios de aceite desta preparação (o que eu afirmo que está pronto)

| # | Critério | Prova rodada |
|---|---|---|
| A1 | L4 fecha pelo pacote, com prova | `test_extract_rom_assets.sh` → **15 PASS / 0 FAIL** |
| A2 | Binários ausentes geram erro explícito | exit 3/4/5/6 testados; nada de imagem fantasma |
| A3 | Skills íntegras | `validate` 0 falhas · `eval` APROVADO · 8 skills |
| A4 | Regras de conflito testadas | R00–R09 → **13 PASS** |
| A5 | Preflight testado | **8 PASS** |
| A6 | Pós-flash com evidência | `test_collect_evidence.sh` → **8 PASS** |
| A7 | Estado do workspace limpo | `state_reset.sh` → `clean` · 0 linhas no DB do FSM |
| A8 | Instrução de abertura e pergunta obrigatória | `SKILL.md` §VI-A + `AGENTS.md` §2 |
| A9 | Kernel só com tríade fechada | `test_kernel_compat_check.sh` → **10 PASS** |
| A10 | Um módulo por vez, com evidência | `test_rollout_gate.sh` → **13 PASS** |
| A11 | Cache das fases verdes + rollback provado | `test_cache_and_guard4.sh` → **13 PASS** |

---

## 9. O que eu preciso de você para liberar a execução

1. **Confirmar os objetivos da §2** (ou corrigir o que estiver errado).
2. **Responder Vanilla ou GAPPS** — ou autorizar o agente a perguntar formalmente na abertura
   (é o que a §3 descreve; ele não escolhe sozinho).
3. **Deixar o `.zip` acessível** (caminho local) — o sandbox não alcança `cdn.evolution-x.org`.
4. **Autorizar (ou não) a instalação** de `payload-dumper-go`, `kptools`, `magiskboot`, `adb`.

Respondidos 1–4, a próxima sessão executa as fases 0→9 sem tocar no aparelho e devolve o pacote
pré-USB com gate 10. O flash continua sendo decisão sua, com o cabo na sua mão.

---

## 11. Cobertura dos 6 requisitos que você pediu (validado item por item)

| # | Requisito seu | Estava? | O que foi acrescentado | Prova |
|---|---|---|---|---|
| **1** | Kernel compatível com a **versão exata da ROM** e com o **modelo** (Pong); conferir versão do Android e se o desenvolvedor suporta a base | **parcial** (só citava GKI/kallsyms) | `references/kernel-selection-gate.md` + `scripts/kernel_compat_check.sh`: compara `model=pong`, SoC, API 36, KMI, base `major.minor` e `supported_rom_builds`; exige `developer_support.declared` | **10 PASS** |
| **3** | No CI/CD, instalar **um módulo por vez** e testar antes do próximo | **não explícito** (só "5 ondas") | `references/rollout-and-cache.md` + `scripts/rollout_gate.sh`: ledger canário, recusa 2 módulos abertos, exige `boot.ok=true`, `crashes=0`, `uptime ≥ 10 min`; `FAILED` trava o próximo | **13 PASS** |
| **4** | Manter **cache das partes bem-sucedidas** no repositório, para continuidade | **parcial** (`workspace/` é gitignored) | `scripts/cache_manager.sh`: `put/get/list/verify`, manifesto com SHA-256; ≤ 25 MB versionado, acima vira referência externa com hash | **13 PASS** (junto ao item 5) |
| **5** | Sempre ter **backup do `boot.img`** para bootloop | **sim** (Guard-4 já copiava) | `scripts/guard4_verify.sh`: exige backup existente, `.sha256` conferindo **e** byte-idêntico ao `boot.img` do pacote oficial | **13 PASS** (mesmo teste) |
| **6** | Instalar a **versão estável atualizada**; checar **compatibilidade módulo × Android × kernel**; decidir com base no `pong`, estabilidade e eficiência | **parcial** (matriz 5W1H, sem critério de versão) | §2 do `kernel-selection-gate.md` (5 critérios em ordem, pinned `20260915`, "estabilidade > novidade") + tabela de campos obrigatórios por módulo (`android_api`, `kmi`, `arch`, `root_engine`, `susqs/zygisk`, `url+sha256`) | documentado + gate 1 executável |

Resumo: **1 e 6** ganharam gate executável e referência; **3 e 4** não existiam e agora existem com
teste; **5** existia, mas passou a ter prova de integridade contra o pacote oficial.

### Onde cada regra vive (para não virar texto solto)

```text
AGENTS.md §3 (invariantes 9–15)           regra de bolso, sempre lida
skills/BOOT.md §5 (fluxo 4b/4c/6/7b/7c)   ordem obrigatória na execução
SKILL.md §VI-D                            contrato + exit codes
references/kernel-selection-gate.md       req 1 e 6
references/rollout-and-cache.md           req 3 e 4
scripts/{kernel_compat_check,rollout_gate,cache_manager,guard4_verify}.sh
tests/test_{kernel_compat_check,rollout_gate,cache_and_guard4}.sh
```

---

## 12. Pendências completas da sessão (o que só você pode responder)

| # | Pendência | Tipo | O que destrava | Se não responder |
|---|---|---|---|---|
| **P1** | **Vanilla ou GAPPS** | decisão | escolha da build + `workspace/decision.json` | nada é baixado/extraído |
| **P2** | **`.zip` da ROM acessível** (o sandbox não alcança `cdn.evolution-x.org`) | insumo | caminho local do arquivo | L4 não fecha; Wave 1 não começa |
| **P3** | **Autorizar instalação** de `payload-dumper-go`, `kptools`, `magiskboot`, `adb` | permissão | `go install`/release/apt | só a L4 roda; patch e estágio B ficam bloqueados |
| **P4** | **Kernel: stock + patch APatch ou kernel de terceiro?** | decisão | define se o gate 1 roda contra candidato externo | padrão = stock + APatch (menor risco) |
| **P5** | **Lista final de módulos** que entram em W2–W4 (MaxManager, GenieX, GCam, Duck-ToolBox, DroidSpaces, SAF, free-form, rede) | escopo | ledger de rollout | fica a matriz 5W1H completa como proposta |
| **P6** | **Janela de canário** (10 min por módulo) e critério de AVC denial aceitável | decisão | `--min-uptime` e baseline | padrão 10 min, baseline 0 novos AVC |
| **P7** | **Retenção de cache** (o que fica versionado; quanto tempo) | política | `cache_manager put` por fase | padrão: manifestos sempre, binários > 25 MB externos |
| **P8** | **Quando o cabo USB entra** (gate 10 = 10/10 PASS) | autorização | flash assistido | nada é gravado no aparelho |
| **P9** | **Abrir PR** com esta preparação? | autorização | PR da branch atual | fica só no commit local/remoto da branch |
| **P10** | **L4 na prática**: rodar `extract_rom_assets.sh` com o zip e confirmar kernel/KMI | execução | arquivo + permissão P3 | L4 permanece "procedimento pronto, dado ausente" |

> P1–P3 são bloqueantes para começar. P4–P7 refinam a execução. P8–P9 são autorizações.
> P10 é o primeiro comando real da próxima sessão.

---

## 10. Nota sobre o PR

Nada foi aberto: este relatório é o artefato de validação. Commit já feito na branch
`arena/863582fd-nothing-phone2-recovery`; o PR só sai depois do seu "ok" — e mesmo assim ele contém
apenas skills/docs/testes, nenhum binário de ROM.
