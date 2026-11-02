# O projeto explicado — do zip da ROM ao aparelho, sem susto

**Versão:** 2026-11-01 · **Branch:** `arena/863582fd-nothing-phone2-recovery`
**Leitura em 3 minutos.** Se quiser o detalhe técnico, os links estão em cada seção.

---

## 1. O objetivo, em uma frase

Levar o **Nothing Phone 2 (`pong`, SM8475)** para a **Evolution X 11.11 (Android 16)** com root,
containers, IA local, bancos funcionando e ajustes de performance — **provando cada etapa antes de
tocar no aparelho**.

## 2. Como o trabalho está dividido

```text
┌ você decide ────────────────┐   ┌ os agentes executam e provam ──────────────────────┐
│ build (Vanilla/GAPPS)        │   │ EVOX-FORGE        payload, patch, rollback         │
│ kernel (stock/terceiro)      │→  │ CONFLICT-INQUISITOR  colisão estática R00–R09      │
│ módulos aprovados            │   │ CI-SANDBOX-PROBE  boot na AVD, 1 módulo por vez    │
│ autorização de binário       │   │ SNAPSHOT-KEEPER   branch/tag por camada            │
│ quando o cabo entra          │   │ GATEKEEPER (você) flash + evidência pós-flash      │
└──────────────────────────────┘   └────────────────────────────────────────────────────┘
```

Nada é feito "de cabeça": cada sub-agente entrega **arquivo + hash**, e o gate seguinte só abre com
o hash batendo. Contrato: `AGENTS.md` §3 e §7.

## 3. Os 4 estágios

| Estágio | Onde roda | O que faz | O que prova |
|---|---|---|---|
| **A · forge** | CI x86_64 (sem KVM) | abre o `.zip`, extrai `payload.bin`, fecha a L4, confere kernel, roda o scanner, patcheia o `boot.img`, cria o rollback | hashes, kernel/KMI, ausência de conflito, backup íntegro |
| **B · sandbox** | CI x86_64 com KVM | sobe uma AVD API 36, injeta **um módulo por vez** via `adb`, reinicia, coleta crash/AVC/uptime | a camada de módulos não quebra o boot |
| **C · release** | CI x86_64 | empacota imagens + relatório + `SHA256SUMS` + `flash_and_rollback.sh` | pacote pré-USB coerente e verificável |
| **D · device** | **você, com o cabo** | flash assistido e coleta de evidência | o hardware real está saudável |

**Importante e honesto:** a ROM do `pong` é **arm64 com vendor físico**; ela **não inicia** no CI
x86_64. O Stage B valida a *camada de módulos*, não o vendor (câmera, NPU, `sysfs`, kernel). Esses
quatro só se provam no Stage D. Detalhe: `skills/evox-rom-ci-optimizer/references/emulation-sandbox.md`.

## 4. O caminho do dado (o que é gerado em cada passo)

```text
zip oficial
  └─ sha256 ───────────────────────────────────────────► trava anti-ROM-trocada
      └─ payload.bin
          └─ boot / init_boot / vendor_boot / vbmeta
              ├─ rom_assets.json  (kernel, KMI, hashes) ──► L4 fechada
              ├─ kernel_compat_check ─────────────────────► COMPATIBLE / INCOMPATIBLE
              ├─ static_conflict_scanner ─────────────────► CLEAN / WARN / CONFLICT
              └─ boot_patched.img + boot_stock_rollback.img(.sha256)
                     └─ guard4_verify ────────────────────► VERIFIED
                          └─ AVD: 1 módulo por vez
                              └─ evidence.json → rollout_gate ──► PASS por módulo
                                  └─ cache/manifest.json ────────► fase verde endereçável
                                      └─ release pré-USB ────────► GO-USB 10/10
                                          └─ Stage D: flash + collect_evidence
```

## 5. As 6 fases de módulos (16 itens)

| Fase | Módulos | O que muda no aparelho |
|---|---|---|
| **F0** | APatch/kernel · DroidSpaces | root em espaço de kernel e containers Linux |
| **F1** | GApps · Fingerprint · Duck-ToolBox | identidade Google e atestação (banking) |
| **F2** | MaxManager · GenieX | controle de performance e IA no NPU |
| **F3** | Câmera (GCam + HAL) | qualidade fotográfica e lentes auxiliares |
| **F4** | Captura · Free-Form · SAF · Rede/socket · Port-forward | janelas, storage e rede por app |
| **F5** | CI · Snapshots · Release | continuidade e entrega pré-USB |

Cada fase tem critério de saída binário e **um módulo por vez**
(`references/module-rollout-order.md`).

## 6. O que impede erro caro

| Risco | Trava |
|---|---|
| ROM errada baixada | `--expect-sha256` → exit 5 |
| kernel incompatível | gate 1 (modelo, API, KMI, base, build, suporte) |
| módulos que se sobrescrevem | scanner R00–R09 (13 cenários) |
| bootloop por módulo novo | canário: 1 por vez + evidência + `rollout_gate` |
| rollback inválido | `guard4_verify` (backup byte-idêntico + `.sha256`) |
| CI caro/ travado | lint de 11 travas de custo (timeouts, cache, retention, watchdog) |
| cache corrompido | `cache_manager verify` recomputa todo hash |
| "achei que passou" | todo PASS tem arquivo, comando e saída |

## 7. O que já está pronto e testado (hoje)

```text
skills 8 · validate 0 falhas · eval APROVADO
scanner 13 · preflight 8 · L4 15 · kernel 10 · rollout 13 · cache/guard4 15
Stage B 9 · lint de custo 12 · pós-flash 8 · abertura de sessão 10 · higiene 13
```

## 8. O que falta (e por que ainda não foi feito)

| Item | Depende de | Por que não dá para adiantar |
|---|---|---|
| L4 real (kernel/KMI/hashes) | o `.zip` + autorização de binário | o sandbox não alcança o CDN |
| Stage A completo | L4 + `kptools`/`magiskboot` | patch exige as ferramentas |
| Stage B | Stage A + `adb` | sem imagens patcheadas não há o que injetar |
| Stage C/D | Stage B verde + sua autorização | flash é produção |

## 9. Como você valida o projeto (sem ler código)

1. Rode `make prove` — tudo verde ou não está pronto.
2. Leia `docs/skills/FINAL-ORCHESTRATION-REPORT.md` §10–§11 — pendências e checklist.
3. Peça ao agente: "mostre a saída de `session_open.py check`" — deve dizer `decisão completa`
   antes de qualquer download.
4. Se algo divergir do combinado, `AGENTS.md` §0 define a precedência em uma linha.

## 10. Glossário curto

- **L4**: lacuna dos dados da build (kernel, KMI, hashes) — fechada pelo pacote, não pelo aparelho.
- **Guard-4**: backup byte-idêntico do `boot.img` antes de qualquer mutação.
- **AVD**: emulador Android (x86_64) — não é o `pong`, é o laboratório da camada de módulos.
- **KMI**: identificador de compatibilidade de módulos de kernel (`android14-11`, etc.).
- **Canário**: instalar um módulo, provar, e só então o próximo.
- **GO-USB 10/10**: 10/10 testes verdes antes de qualquer contato com o cabo USB.
