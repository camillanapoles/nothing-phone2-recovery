# Revisão técnica: `act` + A/B como HIL (o que está certo, o que quebra)

> Avaliação da proposta "trocar emulação em nuvem por `nektos/act` + slots A/B do `pong`".
> Veredito: **direção correta, implementação do draft tem 6 erros** — 3 deles causam bootloop no
> slot estável, exatamente o que a proposta queria evitar.

---

## 1. O que está certo (confirmado)

| Afirmação do draft | Veredito | Observação |
|---|---|---|
| ROM arm64 do `pong` não boota em runner x86_64 | **correto** | falta ISA, DTB do SM8475 e HALs de `vendor` |
| Nem em `ubuntu-24.04-arm` hospedado | **correto na conclusão** | ARM64 hospedado não expõe KVM; e mesmo com KVM faltaria DTB/vendor |
| QEMU TCG seria 15–20× mais lento | **plausível** | o que mata não é a lentidão em si, é o watchdog do `system_server` estourando |
| `/data` é compartilhado entre slots | **correto e crítico** | é a raiz do risco que o draft tenta resolver |
| Bootloader Qualcomm faz fallback A/B | **correto, com ressalva** | fallback depende do contador de tentativas e de o slot não ter sido marcado `successful`; travamento *depois* do kernel pode não derrubar o slot sozinho |
| `act` local com USB passthrough | **correto, só Linux** | Docker Desktop em macOS/Windows não faz passthrough de `/dev/bus/usb` |
| Custo zero e ROM em cache local | **correto** | mas `act` recria o container a cada job: estado de filesystem não persiste |

---

## 2. Os 6 erros do draft (e a correção)

### E1 · `mount --bind /data/adb/staging_b /data/adb/modules` — chega tarde e quebra o gerenciador

`post-fs-data.d/` roda **depois** da fase `post-fs-data` dos módulos: o gerenciador de root já leu
`/data/adb/modules`, já montou os overlays e já executou os scripts. Bind nesse instante não desfaz
nada do que já rodou, e ainda atropela o namespace de montagem do APatch/KernelSU/Magisk.

**Correção:** quarentena por **marcador `disable`** (mecanismo oficial dos três gerenciadores),
aplicada **no host, antes de trocar de slot** (`00_slot_router.sh quarantine`), e uma **guarda de
tentativas** no device que desabilita os experimentais quando o número de boots estoura.

### E2 · Contar com rollback automático para travamento de `system_server`

O fallback do ABL é confiável para falha de **bootloader/kernel cedo**. Para "bootou e pendurou",
quem tem de agir é o host (watchdog + `set-active` de volta) — não a sorte.

**Correção:** watchdog no job (`timeout 180` + verificação de `ro.boot.slot_suffix` após o boot);
se o slot bootado ≠ slot de staging → rollback imediato e `quarantine` de novo.

### E3 · `su -c` no primeiro root (problema do ovo e da galinha)

O fluxo inteiro assume `su` disponível. Na **primeira** instalação (M01) ainda não há root: nenhum
`su -c`, nenhum `dd` de partição, nenhum slot router instalado.

**Correção:** F0 tem caminho **fastboot-only**:
1. `fastboot flash boot_<slot>` + `init_boot_<slot>` (Android 13+ separa ramdisk);
2. primeiro boot → root ativo;
3. **só então** instalar `00_slot_router.sh` e passar a usar `su -c`.

### E4 · `copy staging → modules_stable` — diretório que não existe

Nenhum gerenciador lê `/data/adb/modules_stable`. Copiar para lá "promove" nada.

**Correção:** promoção = `activate` (remove `disable` dos módulos em `approved.list`), mantendo o
mesmo `/data/adb/modules`. Estado fica em `/data/adb/slot_router/`, não em pasta inventada.

### E5 · Flash de `boot` sem tratar AVB/vbmeta e sem `init_boot`

`pong` é A/B com AVB: boot patchado sem vbmeta coerente pode não bootar (verificação falha antes do
Android). E no Android 16 o `init_boot` carrega o ramdisk genérico — patchear só `boot` deixa o
conjunto inconsistente.

**Correção:** flashar `boot_<slot>` **e** `init_boot_<slot>` do mesmo build, e declarar a decisão de
AVB (`vbmeta` patchado ou verity/verification desabilitadas) no `decision.json`.

### E6 · "12 componentes" e ausência de gate de slot no próprio módulo

O escopo tem **15 módulos/16 itens** (F0–F5), e o roteador precisa de lista explícita
(`staged.list` / `approved.list`) — não de "todos os `.zip` da pasta".

**Correção:** listas versionadas + `normalize_module()` recusando `../`; `guard` só age sobre nomes
listados.

---

## 3. Arquitetura corrigida (híbrida, não "substituição")

```text
PRÉ-GATE (barato, sem risco)            GATE AUTORITATIVO (hardware real)
┌──────────────────────────────┐        ┌──────────────────────────────────────────┐
│ Stage A · forge offline      │        │ HIL local via act + slots A/B            │
│  payload → L4 → kernel gate  │  ───►  │  1. quarantine (host, su)                │
│  → scanner → patch → guard4  │        │  2. flash boot_<b> + init_boot_<b>       │
│ Stage B · AVD API 36 (smoke) │        │  3. watchdog + gate de slot              │
│  scripts/props/Zygote        │        │  4. evidência (SELinux, crash, HALs)     │
└──────────────────────────────┘        │  5. activate (só aprovados)              │
                                        └──────────────────────────────────────────┘
```

- A AVD **não** foi descartada: ela é o filtro barato que evita gastar ciclos de reboot do aparelho
  em erro trivial de script/propriedade.
- O HIL A/B é o **gate final antes do USB de produção**, porque só ele exercita kernel, HAL e `/data`
  reais.
- Nenhum dos dois substitui o gate 10: 10/10 verdes + sua autorização.

## 4. Contrato do `00_slot_router.sh` (implementado e testado)

| Comando | Quando | Efeito |
|---|---|---|
| `guard` (default, no boot) | `post-fs-data.d` | conta tentativa; em produção desabilita experimentais; acima do limite marca `staging-failed` |
| `quarantine` | **host, antes de flashar/trocar slot** | cria `disable` em `staged.list` (idempotente) |
| `activate` | depois de PASS | remove `disable` **só** de `approved.list` |
| `status` | CI | `KEY=VALUE` (`state`, `current_slot`, `attempts`, `disabled`…) |
| `reset` | manual | zera contador, preserva log |

Recusas embutidas: nunca `rm -rf`, nunca `mount`, nunca escreve em `/persist`/`/metadata`, recusa
`MODULES_ROOT` perigoso (`/`, `/data`, `/system`…), valida nome de módulo, lock contra corrida.

Teste: `tests/test_slot_router.sh` → **13 PASS** (staging, produção, fallback, limite excedido,
quarentena idempotente, ativação só do aprovado, troca de slot zera contador, recusa de raiz, arquivos
preservados).

## 5. `act`: o que ele resolve e o que ele não resolve

**Resolve:** execução do mesmo YAML localmente, sem minutos de nuvem, com USB no container, cache da
ROM no disco e ciclo rápido.

**Não resolve:** (a) isolamento de `/data` — isso é o router; (b) persistência entre jobs — cada job
é um container novo, então artefatos precisam de `actions/upload-artifact`/volume; (c) passthrough em
macOS/Windows; (d) substituir o gate 10.

## 6. Como isto se liga ao resto do contrato

| Peça | Arquivo |
|---|---|
| Router no device | `assets/00_slot_router.sh` |
| Workflow local (fora do GitHub) | `workflows-local/pong-ab-hil.yml` |
| Config do `act` | `.actrc` + `.actrc.md` |
| Lint (perfil cloud × local) | `scripts/ci_workflow_lint.py` — local exige R12 (rollback) e R13 (gate de slot) |
| Ordem e canário | `references/module-rollout-order.md` · `scripts/rollout_gate.sh` |
