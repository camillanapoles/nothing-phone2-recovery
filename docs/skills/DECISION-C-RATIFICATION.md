# Decisão C — root + kernel amarrados ao sucesso de todas as features

**Data:** 2026-11-01 · **Quem decidiu:** a usuária · **Estado:** ratificada; o **par** agora é
derivado (não mais escrito) · **Fonte canônica:** `references/pack-objective.json` +
`references/pack-conditions.json` + `scripts/root_pair_solver.py`;
`references/root-decision.json` passou a ser **arquivo gerado**.

> **Atualização da mesma data (segunda rodada):** a usuária pediu que o pack inteiro fosse validado de
> forma **determinística**, sem método root/kernel hardcoded e sem lista de proibidos — "o que existe é
> a condição encontrada do par que torna verdadeiras as 10 condições". Isso virou código:
> `root_pair_solver.py` enumera todos os pares e avalia C01…C10. Ver `docs/skills/PACK-DETERMINISM.md`.
> Consequência prática: **nenhum motor é "o escolhido" por decreto** — hoje três motores empatam em
> C06 (configs provadas) e o solver nomeia o empate em vez de escolher.

## 1. O que você pediu (literal)

> "DECISÃO DO ROOT + KERNEL SÃO DEPENDENTES DE ADQUIRIR SUCESSO pra todas features. VALIDADAMENTE.
> Se garantir, 2 ponto, melhor performance, estabilidade etc … Você pode e deve mudar ao obter o
> root + kernel que garantem."

Traduzido em regra executável: **o par motor×kernel só é aceito se todas as features forem
garantidas com prova**; ocultação e integridade continuam obrigatórias; performance/estabilidade
vêm depois de "funciona". Foi isso que autorizou trocar APatch pelo par da Decisão C.

## 2. O que mudou (A → C)

| Item | Decisão A (revogada) | Estado derivado hoje |
|---|---|---|
| Motor | APatch | **derivado do pack** — 3 pares empatados (apatch/kernelsu/sukisu) até C06 fechar |
| Kernel | stock da ROM | **compilado por nós**: fonte do device + KSU + SUSFS + patches DroidSpaces |
| Kernel de terceiro | proibido | **continua proibido** (`third_party_kernel_allowed: false`) |
| SUSFS | proibido | **permitido e primário** na ocultação |
| M01 | patch `kptools`/`kpimg` no `boot.img` | flash do kernel compilado + KSU-Next Manager |
| Prova de kernel | `kernel_evidence: rom_package` | `kernel_evidence: built_kernel` |
| M05 DroidSpaces | **IMPOSSÍVEL** | **PENDENTE** (caminho existe) |

## 3. Por que a A não podia entregar tudo

A documentação oficial do DroidSpaces (`Documentation/Kernel-Configuration.md`) diz que
`CONFIG_SYSVIPC`, `CONFIG_IPC_NS` e `CONFIG_POSIX_MQUEUE` "não são opcionais" e que ativá-los em GKI
≥ 5.4 **sem o patch de kABI da versão dá bootloop**. O kernel stock `pong` 5.10 não tem esses
símbolos → sob a A o M05 era impossível, não "pendente". Com kernel próprio, os três `CONFIG_*`
entram **junto** com `001…below-kernel-6.12` e `002…posix_mqueue` na mesma build.

## 4. O que a C exige da build (e ainda não está feito)

`CONFIG_KSU`, `CONFIG_KPM`, `CONFIG_SUSFS`, `CONFIG_SYSVIPC`, `CONFIG_POSIX_MQUEUE`, `CONFIG_IPC_NS`,
`CONFIG_DEVTMPFS`, `CONFIG_NET_NS`, `CONFIG_NAMESPACES`, `CONFIG_USER_NS`, `CONFIG_PID_NS` +
patches `001…below-kernel-6.12` e `002…posix_mqueue`, com **build reprodutível + sha256**.

Cadeia de prova (nesta ordem, nada pula etapa):

1. `kernel_compat_check.sh` sobre o kernel compilado → exit 0
2. `droidspaces_preflight.py --kernel-evidence <kernel-config.json>` → PRONTO
3. boot em AVD/staging com `boot.ok`, `crashes=0`, 10 min de uptime
4. `root_engine_gate.py --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces` → 0
   (hoje devolve **3**)
5. `make garantia` → 0 só com evidência medida no aparelho

## 5. Custo, risco e plano B (declarados agora, não depois)

- **Custo:** nós compilamos e mantemos o kernel; OTA da ROM passa a exigir **rebuild + refazer o M01**.
- **Risco 1:** SUSFS pode colidir com os patches de kABI. Fallback já declarado: build **sem SUSFS**
  + Zygisk Next + Zygisk Assistant (é o par **B** em ocultação) — nunca "SUSFS quebrado instalado".
- **Risco 2:** build não bootar. `revisit_if`: se falhar `kernel_compat_check`/boot, cair para **B**
  (APatch + kernel próprio sem SUSFS) e depois **A2** (sem M05) — a decisão diz isso explicitamente.
- **Backup:** `boot.img` stock byte-idêntico + `.sha256` **antes** de qualquer flash (P0.3).

## 6. Estado do pack hoje

```
$ make pack
[pack] FALTA_PROVA · 16 pares (4 motores × 4 kernels) · garantidos=0 pendentes=6
  PEND apatch   × custom-build-pong-ksu-susfs-droidspaces   falta: C06
  PEND kernelsu × custom-build-pong-ksu-susfs-droidspaces   falta: C06
  PEND sukisu   × custom-build-pong-ksu-susfs-droidspaces   falta: C06
  PEND apatch   × np2-kernel-lineageos-v3.0.5               falta: C03,C06,C07
  NAO  kernelsu × stock-evolutionx                          falta: C02,C06,C07
  NAO  magisk   × (qualquer)                                falta: C05
  NAO  (qualquer) × meteoric-v6-pong                        falta: C03,C04,...
[pack] EMPATE determinístico em 3 pares com as mesmas pendências ['C06']
```

Uma única condição separa o pack de `PAR_GARANTIDO`: **C06 — as 13 `CONFIG_*` provadas** (evidência,
não intenção). O gate por par mostra o mesmo, condição por condição:

```
$ root_engine_gate.py --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces
[gate] → PENDENTE (9/10 condições)
  PEND C06 ... ainda não prova 13/13: [CONFIG_* ...]
```

Isso é o comportamento correto: **"garantido" não é declarado sem prova**, e nenhum motor é
favorecido por estar escrito no código.
