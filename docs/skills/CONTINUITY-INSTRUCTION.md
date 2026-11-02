# Instrução de continuidade — kernel do pack `pong` (v1.1)

**Branch de origem:** `arena/863582fd-nothing-phone2-recovery` · **Skill:** `evox-rom-ci-optimizer` v3.1
**Base:** PR #7 mergeado em `cdd5885` · **Alvo:** root e kernel perfeitos para DroidSpaces, integridade,
root oculto, performance e estabilidade no Nothing Phone (2) `pong` / SM8475 / EvolutionX 11.11 (A16).
**Provas da base:** `make -s prove` **754 casos / 35 suítes** · mutação **169/169 mortos por asserção** ·
`audit-loop` limpo · `escopo` limpo.

Este documento é a primeira leitura de qualquer sessão nova. Ele carrega **continuidade, método,
mandato, aprendizados, anti-padrões, o que garantir e como resolver dúvida**. Ele **não** autoriza
decisão de produto em nome da usuária e **não** substitui prova: o verde do harness é a evidência;
este texto é o mapa.

---

## 1. A verdade absoluta inequívoca (cláusula pétrea)

> **Um motor fictício `engine-x` + kernel fictício `kernel-x` são selecionados pelo solver apenas por
> satisfazerem o dado — nenhuma linha de código mudou para isso.**

Consequências que **nunca** podem ser violadas num refactor:

1. O solver (`scripts/root_pair_solver.py`) enumera **pares** (motor × kernel) e avalia as **10
   condições** (`references/pack-conditions.json`) sobre o par. Nenhuma condição nomeia motor ou kernel.
2. Não existe `if engine == …` nem `if kernel == …` em solver, gate ou teste. Literal de motor no
   código é **defeito**, não otimização.
3. Não existe lista de "motores proibidos" ou "kernels proibidos". Proibição é **consequência provada**
   de condição falsa — nunca preferência declarada.
4. Se um par fictício satisfizer o dado, ele é escolhido. Se o dado mudar, a escolha muda — **sem tocar
   no código**. O `continuity_gate.py` (cláusula `Q12`) reprova se um id de motor aparecer literal no
   solver, e o selftest (`make -s pack-selftest`) quebra uma condição por vez para provar que cada uma
   é load-bearing.

---

## 2. Regra de autoridade (antes de qualquer ação)

1. **"O passado era erro."** Plano, instrução ou conclusão de sessão anterior **não é autoridade**. Toda
   herança é confrontada com as regras vigentes e classificada: **vigente / arquivado / proibido**.
2. **Fonte de verdade é o workspace + teste executável**, não a lembrança de quem escreveu. Documento
   que contradiz o gate é corrigido no mesmo turno; divergência vai para `docs/skills/AUDIT-CONTRADICTIONS.md`.
3. **Ordem de leitura:** `AGENTS.md` → este documento → `HANDOFF-NEXT-AGENT.md` (P1/P2/P3 e operação) →
   `PACK-DETERMINISM.md` → `KERNEL-REQUIREMENTS.md` → `KERNEL-BUILD-TEST-PLAN.md` → `make -s prove`.

---

## 3. Continuidade: o que está provado × o que está pendente

**Provado e reexecutável**

| Prova | Número | Comando |
|---|---|---|
| Suítes | 754 casos / 35 suítes | `make -s prove` |
| Mutações mortas por asserção | 169/169 | `make -s mutation` |
| Condições do pack com contra-exemplo | 10/10 | `make -s pack-selftest` |
| Plano do kernel | 20/20 (`P01`–`P20`) | `make -s kernel` |
| Pré-build do kernel | 22/26 (4 PEND nomeados) | `make -s kernel` |
| Escopo e arquitetura | limpos (AG1–AG21) | `make -s escopo` · `make -s arch` |

**Fechado nesta rodada (com prova)**

- **`B01`** pin do source: `4ec5491f6b5fd8776207a2a453d6b98b1928de7a` em `lineage-23.2` (2026-01-24),
  conferido na API (branch head), com `gki_defconfig`/`vendor/*` presentes, `Makefile` = **5.10.246** e o
  SHA coincidindo com o tag de KMI `gki-g4ec5491f6b5f`.
- **`B08`** material da árvore: `kernel/patches/` (kABI `001` ×3 + `002`, `SHA256SUMS`, fonte
  `Droidspaces-OSS@58e3f4e`) e `kernel/fragments/evox_pong_pack.config` **gerado** do contrato por
  `scripts/kernel-fragment.py` (`make -s fragmento`).

**Pendente (exit 3 — nunca "pronto")**

- **`C06`**: as **12 CONFIG_\*** exigidas pelo DroidSpaces seguem **sem prova**. Trava `M05` e mantém
  empate determinístico em 3 pares (`apatch`, `kernelsu`, `sukisu` × `custom-build-pong-ksu-susfs-droidspaces`).
- **`B01`** source sem pin (`a-fixar-no-primeiro-build`) · **`B03`** árvore ausente · **`B05`** evidência
  de configs ausente · **`B06`** artefatos de build inexistentes.
- Nenhum módulo `M01`–`M15` tem PASS: nada foi buildado, nada foi flasheado.

Estado do pack hoje: `FALTA_PROVA · 16 pares (4 motores × 4 kernels) · garantidos=0 pendentes=6`.

---

## 4. Método de ação (não improvise outro)

```
condição falseável → solver por dado → gate executável → prova (suíte + mutante) → PASS do módulo
```

1. **Condição antes de código.** Escreva a afirmação **e** o contra-exemplo. Sem contra-exemplo é
   decoração: **reprova**.
2. **Dado antes de regra.** Insumo vira JSON; a regra lê o JSON. Constante com nome de motor/kernel no
   código é defeito.
3. **Gate executável, não conselho.** Estado `ok`/`falha`/`pendente` + exit code:
   **0** pronto · **3** pendente · **1** falha · **4** entrada inválida.
4. **Prova em dois níveis.** (a) suíte que falha se a regra sumir; (b) **mutante** no catálogo que morre
   por asserção. Mutante que sobrevive = teste mascarado: corrige-se o teste, não o mutante.
5. **Um módulo por vez.** `M01` → PASS → `M02` → … Rollout nunca em lote; `guard4_verify.sh` antes do
   primeiro flash.
6. **Fechar o turno com prova.** `make -s prove && make -s mutation && make -s audit-loop` verdes →
   commit → push → PR → merge.

---

## 5. Mandato: o que a sessão decide × o que é da usuária

**Decide sozinha:** estrutura de dados, regras e gates, testes, refactor, documentação, redação de
requisito falseável, ordem técnica **dentro** do já autorizado.

| Item | Estado | Regra |
|---|---|---|
| **P1** Vanilla × GApps | **aberta** | apresentar a tabela pinada e **parar**. Nunca escolher. |
| **P2** builds | fixado | exatamente as builds de **2026-09-15** (11.11); outra build = fora de escopo. |
| **P3** | **"Sim"** | autorização registrada; não re-perguntar. |
| **L4** | não pedir | nada de dado de L4 por parte do agente; `adb` só **read-only**. |
| **USB/físico** | gated | nada no USB antes de `M15` (Release Artifact validado) e staging AVD com PASS. |
| **"GARANTA"** | condicional | garantir = executar **condicionado à compatibilidade provada pelo gate** + decisão dela. |

---

## 6. Plano do `custom-build-pong-ksu-susfs-droidspaces` (como será)

| # | Etapa | Comando/insumo | Fecha |
|---|---|---|---|
| 1 | Pinar o source | `LineageOS/android_kernel_nothing_sm8475` @ `lineage-23.2`, commit de 40 hex, GPL-2.0 | `B01` |
| 2 | Materializar a árvore | `gki_defconfig` + `vendor/waipio_GKI.config` + `vendor/nothing/waipio_GKI.config` + `vendor/debugfs.config` + `arch/arm64/configs/evox_pong_pack.config` | `B03`, `B04` |
| 3 | Patch set (sem `--force`) | `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`, `002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch`, KernelSU-Next v3.4.2 embutido, SUSFS (único `drop_patch` declarado) | `C07` |
| 4 | Buildar no GitHub Actions | imagem DDK `ghcr.io/ylarod/ddk-min:android13-5.10-*`, `LLVM=1 LLVM_IAS=1` | `B06` |
| 5 | Provar as configs | `.config` → `kernel-config.json` (`CONFIG_X=y\|m`) | `B05` → **`C06`** |
| 6 | Re-rodar o solver | `make -s pack` | empate resolvido **por dado** |
| 7 | Staging → físico | `M01` → … → `M15`, um PASS por vez | `M*` |

Comando único do gate, quando os insumos existirem:

```bash
python3 skills/evox-rom-ci-optimizer/scripts/kernel_build_gate.py --root . --prebuild \
  --kernel-tree <árvore> --config-json <evidência> --build-dir <artefatos>
```

---

## 7. Requisitos da kernel — funcionais (11)

| ID | Requisito | Prova (`verified_by`) | Falsificação (`falsified_by`) |
|---|---|---|---|
| FR-01 | sobe no `pong` com a build pinada (boot completo, sem panic) | `boot.ok` + `dmesg` sem `Kernel panic` + 10 min de uptime | flash do `boot.img` + reboot: qualquer panic/loop |
| FR-02 | KernelSU-Next v3.4.2 concede root | Manager abre + `su -c 'id -u'` = 0 | sem root ou Manager recusando o kernel |
| FR-03 | SUSFS ativo e listando (ou fallback declarado) | `ksud susfs`/proc + `/sys/fs/susfs` | patch aplicado e interface ausente |
| FR-04 | DroidSpaces sobe container PID/IPC/UTS/NET/USER | *Check Requirements* + container real | requisito faltando no app |
| FR-05 | SYSVIPC/POSIX_MQUEUE utilizáveis no container | `/proc/sysvipc/{shm,sem,msg}` + `/dev/mqueue` | `ENOSYS`/`EINVAL` |
| FR-06 | rede por app: netfilter `owner` + eBPF | `iptables -m owner` + carga de programa BPF | regra não aplica ou BPF rejeitado |
| FR-07 | CPU/GPU/thermal controláveis (M12A) | `cpufreq`/`devfreq` + zonas térmicas | nó ausente ou escrita negada |
| FR-08 | NPU/QAIRT abre (M12B) | init `libcdsprpc` + inferência de fumaça | timeout/crash no primeiro uso |
| FR-09 | `MEETS_DEVICE_INTEGRITY` (M07) | Play Integrity + PIFork/TrickyStore | `MEETS_DEVICE_INTEGRITY` falso |
| FR-10 | rollback byte-idêntico ao kernel stock | `guard4_verify.sh` (backup + sha256) | hash divergente ou backup ausente |
| FR-11 | OTA tem plano (rebuild + refazer M01) | script de rebuild reprodutível + documento do par | build nova sem pin de source/patch |

## 8. Requisitos da kernel — não funcionais (10)

| ID | Requisito | Falsificação |
|---|---|---|
| NFR-01 | reprodutível: mesmo (pin, configs, patches) ⇒ mesmo sha256 de `Image`/`.config` | sha diferente em execuções idênticas |
| NFR-02 | build ≤ 90 min em `ubuntu-latest` 4 vCPU com ccache frio | job > 90 min ou timeout |
| NFR-03 | nenhum patch com `--force`/fuzz > 0 | `.rej` ou fuzz aceito |
| NFR-04 | todo artefato com sha256 + proveniência | artefato sem hash/attestation |
| NFR-05 | ações pinadas por SHA de 40 hex | `@vN` sem SHA |
| NFR-06 | 0 panic/crash em 72 h de uso | qualquer panic/oom-kill anômalo |
| NFR-07 | performance ≤ 3% de perda vs stock | queda > 3% |
| NFR-08 | `boot.img` ≤ stock + 5% | exceder o limite do slot |
| NFR-09 | GPL-2.0 cumprida (fonte publicada) | binário sem fonte correspondente |
| NFR-10 | build sem segredo (fork público, sem PAT) | falha por secret ausente |

NFR **não** mapeiam para `C01`–`C10`: o pack decide *o que* instalar; os NFR decidem *se o construído é
confiável*. Dizer o contrário infla cobertura.

---

## 9. Critério de 100% por módulo (16 provas, PASS bloqueante)

PASS = **(a)** o critério é observado com o esperado; **(b)** o contra-exemplo foi testado e não ocorre;
**(c)** as condições `C` de que o módulo depende estão provadas. `M(n+1)` só depois de `M(n)`.

| Módulo | Critério de PASS | Esperado | Depende de |
|---|---|---|---|
| **M01** | `su -c 'id -u'` = 0 + Manager reconhece o kernel | root ativo, SELinux `Enforcing` | C01, C02, C03, C07 |
| **M02** | câmera abre e grava (GCam + flags HAL) | sem erro de HAL | C09 |
| **M03** | Play Store e serviços Google sobem | login e sync ok | C03 |
| **M04** | captura de tela irrestrita funciona | sem bloqueio | C09 |
| **M05** | *Check Requirements* + container real (PID/IPC/UTS/NET/USER) + shm/mq | todos OK | **C05, C06, C07** |
| **M06** | janelas free-form abrem e redimensionam | multi-janela ok | C09 |
| **M07** | Play Integrity (PIFork + TrickyStore) | `MEETS_DEVICE_INTEGRITY` | C08 |
| **M08** | ocultação por app (lista R08) + SUSFS ativo | app alvo não detecta root | C08 |
| **M09** | SAF monta diretório externo | leitura/escrita ok | C09 |
| **M10** | netfilter `owner` + BPF por app | regra só no app | C06, C09 |
| **M11** | port-forward intranet responde | porta acessível na LAN | C09 |
| **M12A** | `cpufreq`/GPU/thermal legíveis e controláveis | controle efetivo | C09 |
| **M12B** | NPU/QAIRT inicializa + inferência de fumaça | sem erro | C09 |
| **M13** | pipeline do CI de ambiente ponta a ponta | job verde | — |
| **M14** | snapshot por camada restaura estado | rollback fiel | C10 |
| **M15** | Release Artifact validado antes de qualquer USB | artefato + hash conferidos | NFR-04 |

`M12A` e `M12B` são provas distintas — nunca um PASS só. **`M05` é o gargalo:** depende de `C06`/`C07`;
enquanto `C06` estiver pendente, `M05` **não** pode ter PASS (nem por leitura de código).

---

## 10. Build e deploy da kernel por GitHub Actions

**Ações pinadas por SHA de 40 hex** (tag → commit conferido na API em 2026-11-01):

| Uso | Tag | SHA |
|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/cache` | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| `actions/download-artifact` | v8.0.2 | `9000827ccba6bdab643e8b6fd33ac0654aef8333` |
| `actions/attest-build-provenance` | v4.2.2 | `4d101475d8b20a2381f78447822ac1eab6504dd8` |
| `softprops/action-gh-release` | v3.0.3 | `efb35369e0ad2afab669f228072c1b0d510eae64` |
| `sigstore/cosign-installer` | v4.1.2 | `6f9f17788090df1f26f669e9d70d6ae9567deba6` |

**Recusadas com motivo:** `lemniskett/*` (85★), `feicong/*` (56★), `zclkkk/*` (108★),
`UnicomAndroid/kerneler` (176★) — sem pin auditável, foco LKM ou genéricas demais para GKI com config
de vendor. Build sai por `run:` explícito sobre a imagem DDK, não por wrapper de terceiro.

**Pipeline:** `build` (checkout → cache ccache por `pin|defconfig|patch set` → `make -C $KDIR O=$OUT
ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 Image dtbo.img` → dump `.config`→`kernel-config.json` → upload +
`attest-build-provenance`, timeout 90 min) → `package` (AnyKernel3, `cosign sign SHA256SUMS`, **draft**
release com `Image`, `boot.img`, `dtbo.img`, config, `kernel-config.json`, zip AK3, `SHA256SUMS`).

**Deploy:** draft → baixar e conferir sha256 contra `SHA256SUMS` → `gh attestation verify` → staging/AVD
→ físico. **Proibido** `fastboot flash` no CI, flash sem backup verificado e release sem hash conferido.

---

## 11. Box de kernel recebido via GitHub (`kernel-source/`, `zeroharcoderd/knowledge/`)

Box é **fonte de hipótese**, não autoridade. Três portas, com critério objetivo e rollback:

| Opção | Quando | Como fica | Rollback |
|---|---|---|---|
| **(a) validar como referência** *(padrão)* | claims úteis, nenhum build ainda | `source.alternatives` com `status: a_validar`; nada do box entra no build | remover a entrada do JSON |
| **(b) fork alterado como candidato do pack** | item por item conferido **e** build verde **e** `C06` provado | candidato próprio com `pin`, `configs_proven`, `patches_present`, `supported_rom_builds` | apagar o candidato (pack volta a `FALTA_PROVA`, sem brick) |
| **(c) outro módulo / descartar** | contradição insolúvel ou EOL | documentação histórica; **não** entra no pack | nenhum (nada foi usado) |

**Conferências que o box ainda deve** (cada uma é `PENDENTE`, nunca "sim"):

1. `make sm8475_defconfig` vs plano (`gki_defconfig` + `vendor/waipio_GKI.config` +
   `vendor/nothing/waipio_GKI.config` + `vendor/debugfs.config` + nosso fragmento) — `B03` decide.
2. `patch -p1 < ../patches/*.diff` sem `--check`/`--dry-run` **viola NFR-03**; só entra com
   `git apply --check` e rejeição = falha no build.
3. Nomes de patch do box (`sysvipc_patch.diff`, `posix_mqueue_patch.diff`, `glyph_interface_patch.diff`)
   **não** são os oficiais do DroidSpaces: usar `001…`/`002…` com sha256.
4. `5.10.246-gki-g4ec5491f6b5f` é **claim**: versão real sai de leitura read-only do device (`uname -r`).
5. `boot.img (NOT init_boot)` / slot `boot_b`: plausível, **não confirmado** (`R3` cobre `init_boot`).

Enquanto as 5 não fecharem, o box **não** é kernel do pack — e isso **não** é proibição por origem: é
ausência de prova.

---

## 12. Pré-build: garantir item por item

`python3 skills/evox-rom-ci-optimizer/scripts/kernel_build_gate.py --root . --prebuild`

- **`P01`–`P20` (plano):** 20/20 OK — alvo, fonte com licença, toolchain, defconfig + 4 fragmentos,
  4 patches com `on_reject`, 13 configs de contrato + 19 de módulo, 11 FR + 10 NFR falseáveis, ids
  únicos, sem placeholder, 7 ações com SHA e versão, 4 alternativas recusadas, 7 artefatos com hash +
  proveniência, deploy em 6 passos, 16 módulos com critério falseável, 4 riscos com mitigação.
- **`B01`–`B07` (pré-build):** `B02`/`B07` OK; `B01` pin · `B03` árvore · `B05` 12 CONFIG_* · `B06`
  artefatos = **PENDENTE (exit 3)**, com o nome do que falta. **PENDENTE não é falha e não é OK.**

Regra de parada: nenhum build é disparado com `P*` em falha; nenhum flash acontece sem `B*` fechado,
`M15` validado e `guard4_verify.sh` verde.

---

## 13. Como testar o par `root × kernel`

1. **Estático (sem device):** `make -s pack` (quais pares fecham as 10 condições), `make -s m05`
   (contrato do DroidSpaces), `make -s kernel` (plano + pré-build), `make -s garantia` (5 requisitos,
   prova ou PENDENTE). Serve para **não** levar ao device o que já reprova aqui.
2. **Staging AVD:** artefato do draft → sha256 contra `SHA256SUMS` → `gh attestation verify` → flash em
   staging → reboot ×3 → `dmesg` sem panic, `uname -r` = buildado, `su -c 'id -u'` = 0. **Só com PASS**
   de staging o físico entra.
3. **Físico, um módulo por vez:** `guard4_verify.sh` → flash → `uname -r` → **M01** → **M05** →
   **M07/M08** → **M02/M03/M04/M06/M09/M11** → **M10/M12A/M12B** → **M13/M14/M15**.
4. **Proibido:** HIL A/B como gate final (só diagnóstico após staging com PASS). `P6`/`P7` medem
   performance (NFR-07); `P8` é produção.

**Par validado** = (1) 10 condições verdadeiras **por dado**; (2) build com hash + proveniência;
(3) 12 CONFIG_* provadas no `.config`; (4) `M01` e `M05` com PASS em staging **e** físico com backup
verificado; (5) decisão de variante registrada pela usuária. Até lá, a resposta honesta é
`FALTA_PROVA` + lista de pendências.

---

## 14. Aprendizados (o que já custou tempo)

1. `cmd | tail` mascara exit code — redirecione e leia `$?`.
2. Texto explicativo derruba o próprio gate — política de patch é **enum** (`on_reject`), não prosa.
3. Patch só com `git apply --check`/`--dry-run`; rejeição = falha. Exceção declarada e única: `004-susfs`
   com `drop_patch` (build segue sem SUSFS, fallback anunciado).
4. Cobertura é por item, não por grupo (`M02/M04/...` num só item não cobre).
5. Cobertura não pode vir de graça: no `P19`, config específica de módulo **não** vale como critério.
6. Paridade com `droidspaces-requirements.json` é o antídoto do plano fossilizado (`P06`/`B07`).
7. GKI ≥5.4 sem os patches kABI (`001`, `002`) dá bootloop ao ligar SYSVIPC/IPC/POSIX_MQUEUE.
8. Ação com tag flutuante é bomba-relógio: SHA de 40 hex ou nada (`B02`).
9. Wrapper genérico de "kernel build action" não serve (`actions_avoided`).
10. Ausência de dado nunca vira "incompatível": kernel de terceiro sem prova é **PENDENTE**.

---

## 15. Anti-padrões — o que **não** fazer (lista fechada)

- ❌ `if engine == …` / `if kernel == …` em solver, gate ou teste.
- ❌ Lista de motores/kernels "proibidos" (proibição só como consequência provada).
- ❌ Dado ausente como `OK` **ou** como `FALHA` — é **`PENDENTE` (exit 3)**.
- ❌ Dizer "garantido" sem par que feche as 10 condições **e** decisão registrada.
- ❌ Patch com `--force`/fuzz; `releases/latest` como pin.
- ❌ Proibido tratar físico, USB ou HIL A/B como gate final (HIL só diagnóstico pós-staging).
- ❌ Herdar variante de ROM (`session_open.py auto` limpa, não herda).
- ❌ "Consertar" teste verde que passou com a lógica removida.
- ❌ Citar número que não confira com a execução da própria sessão.
- ❌ Fundir `M12A`/`M12B` num único PASS; apresentar plano sem `falsified_by`.
- ❌ Editar fixture por `assert old in s` sem `grep -n`; heredoc bash com heredoc Python aninhado;
  variável de shell com acento.

---

## 16. O que garantir antes de dizer "pronto"

1. `make -s prove` verde (suítes + contrato + arquitetura + skills).
2. `make -s mutation` — todos mortos por asserção (0 vivo, 0 inválido, 0 só-timeout).
3. `make -s audit-loop` limpo; `make -s escopo` limpo.
4. `make -s kernel` com pendências **nomeadas** (nunca "quase pronto").
5. `make -s pack` com estado honesto (`FALTA_PROVA` é resposta legítima).
6. `make -s continuidade` — esta instrução contém as cláusulas obrigatórias e a verdade absoluta.
6b. `make -s debitos` — todo débito aberto tem passo de fechamento (exit 3 é honesto; exit 1 não é);
   `make -s closure` — o plano de fechamento é executável.
7. Commit → push na branch da sessão → PR → **merge** → nova sessão.

---

## 17. Como resolver dúvida (escala de decisão)

1. **Dado ausente?** → `PENDENTE` (exit 3), dizendo **qual** dado falta e **onde** ele entra. Nunca estimar.
2. **Está no workspace?** → cite caminho (e linha). Não "lembre".
3. **Contradição entre artefatos?** → vence o **provado por teste**; o outro é corrigido no mesmo turno e
   registrado em `AUDIT-CONTRADICTIONS.md`.
4. **Decisão de produto** (variante, aceitar perda, subir físico)? → **perguntar** com dados pinados e parar.
5. **Dúvida de escopo/legado?** → `make -s escopo`; legado listado é proibido até prova nova.
6. **Ambiguidade restante?** → registrar em `PENDING-DECISIONS.md` com opções, custo e pergunta objetiva;
   seguir com o que **não** depende da resposta.

**Regra de ouro:** na dúvida entre afirmar e marcar pendente, **marcar pendente** — o custo de um
pendente honesto é um turno; o custo de uma afirmação falsa é um device brickado.

---

## 18. Próximos passos ordenados (retomada imediata)

O débito não é lista escrita à mão: `make -s debitos` **deriva** o estado dos gates e diz, para cada
débito, o passo que o fecha, o comando e o critério. O plano executável está em
`docs/skills/EXECUTION-PLAN.md` e é validado por `make -s closure` (DAG acíclico, gate com exit e
critério, staging antes do físico). Hoje: **7 abertos de 7**.

1. ~~Pinar o commit (40 hex) do source → `B01`~~ **feito**: `4ec5491f6b5f…` (5.10.246, KMI `gki-g4ec5491f6b5f`).
2. Decidir o box (§11): **validar × fork × descartar**, com justificativa e rollback.
3. Buildar `custom-build-pong-ksu-susfs-droidspaces` no Actions (draft + `SHA256SUMS` + attestation) → `B06`.
4. Provar as 12 CONFIG_* a partir do `.config` → `B05` → **`C06`**.
5. `make -s pack` → empate resolvido **por dado**.
6. Validar `M01` → `M15` (com `M12A`/`M12B`), estático → AVD → físico, um PASS por vez.
7. **P1** antes de qualquer download/flash de ROM: perguntar Vanilla × GApps e parar.
8. Encerrar: `make -s prove && make -s mutation && make -s audit-loop` → commit → push → PR → merge.

---

## 19. Comandos de retomada

```bash
make -s prove                 # 754 casos / 35 suítes
make -s mutation              # 165 mutantes, todos mortos por asserção
make -s continuidade          # esta instrução: cláusulas obrigatórias + verdade absoluta
make -s debitos               # débitos derivados dos gates + passo que fecha cada um (exit 3)
make -s closure               # o plano de fechamento é executável (K01–K16)
make -s fragmento             # o fragmento do pack bate com o contrato do DroidSpaces
make -s pack                  # solver: estado do par (motor × kernel) por dado
make -s pack-selftest         # as 10 condições caem uma por vez
make -s kernel                # plano P01–P20 + pré-build B01–B07 (exit 0/3)
make -s m05                   # contrato estático do DroidSpaces
make -s escopo                # legado que manda NÃO usar
make -s audit-loop            # AG + contradições + cobertura + suítes até convergir
```

---

## 20. Prompt de abertura para a sessão nova

> Leia `AGENTS.md` e `docs/skills/CONTINUITY-INSTRUCTION.md` (v1.1) antes de qualquer ação. Preserve a
> cláusula pétrea: `engine-x` + `kernel-x` fictícios são escolhidos pelo solver **apenas por satisfazerem
> o dado**, sem alterar código. Trabalhe pelo método `condição → solver → gate → prova`, com `PENDENTE`
> (exit 3) para dado ausente, um módulo por vez, e sem decisão de produto em nome da usuária (P1 aberta,
> P2 = 2026-09-15/11.11, P3 = Sim, L4 não se pede, USB só após M15). Comece pelo §18.
