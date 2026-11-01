# Decisão C — root + kernel amarrados ao sucesso de todas as features

**Data:** 2026-11-01 · **Quem decidiu:** a usuária · **Estado:** ratificada, par **PENDENTE** até o
build ser certificado · **Fonte canônica:** `skills/evox-rom-ci-optimizer/references/root-decision.json`

## 1. O que você pediu (literal)

> "DECISÃO DO ROOT + KERNEL SÃO DEPENDENTES DE ADQUIRIR SUCESSO pra todas features. VALIDADAMENTE.
> Se garantir, 2 ponto, melhor performance, estabilidade etc … Você pode e deve mudar ao obter o
> root + kernel que garantem."

Traduzido em regra executável: **o par motor×kernel só é aceito se todas as features forem
garantidas com prova**; ocultação e integridade continuam obrigatórias; performance/estabilidade
vêm depois de "funciona". Foi isso que autorizou trocar APatch pelo par da Decisão C.

## 2. O que mudou (A → C)

| Item | Decisão A (revogada) | Decisão C (vigente) |
|---|---|---|
| Motor | APatch | **KernelSU-Next v3.4.2** (release 2026-10-13) |
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

## 6. Estado do gate hoje

```
$ python3 skills/evox-rom-ci-optimizer/scripts/root_engine_gate.py \
    --engine kernelsu --candidate custom-build-pong-ksu-susfs-droidspaces
decisao_ratificada .... ok
decisao_motor ......... ok
motor_unico ........... ok
decisao_kernel ........ ok
m05_motor ............. ok
m05_ordem ............. ok
kernel_certificado .... PENDENTE   ← falta o build + sha256
r03_mount_hide ........ CONDICAO   ← mount-hide global tem de ficar off
m05_kernel_configs .... CONDICAO   ← as 12 CONFIG_* provadas na evidência
→ PENDENTE (exit 3)
```

Isso é o comportamento correto: **"garantido" não é declarado sem prova**. O gate não afrouxa; ele
só passou a reconhecer o caminho que você autorizou.
