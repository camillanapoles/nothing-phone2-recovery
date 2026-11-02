# Emulação no GitHub Actions — o que é real, o que não é, e como fica o pipeline

> Correção de premissa, com número: **a ROM do `pong` (arm64, `vendor` do SM8475) não inicia
> em runner x86_64**. O que inicia é uma **AVD x86_64 da mesma API (36)** — e ela valida a
> **camada de módulos**, não o vendor do aparelho. O resto se prova no offline (Stage A) ou no
> aparelho (Stage D, humano).

## 1. As três restrições que decidem a arquitetura

| Restrição | Fato | Consequência |
|---|---|---|
| Arquitetura | imagem de `pong` é **arm64-v8a** | runner hospedado é x86_64; QEMU TCG arm64 é lento demais para CI de 25 min |
| KVM | runners Linux **x86_64** expõem `/dev/kvm` (com passo de udev); **ARM64 hospedado não** | AVD x86_64 acelera; AVD/GSI arm64 não roda em runner hospedado |
| Vendor proprietário | `vendor.img`/`odm` do SM8475 dependem de hardware real (GPU, modem, NPU, câmera) | mesmo com CPU certa, não há boot funcional do vendor fora do aparelho |

Fontes: documentação do `android-emulator-runner` (Linux/KVM) e relatos de que virtualização aninhada
só existe em runners Linux x86_64 — ARM64 hospedado não tem.

## 2. Arquitetura ratificada: 3 estágios + 1 humano

```text
Stage A  FORGE (ubuntu-24.04, x86_64, sem KVM)
  payload.bin → boot/init_boot/vendor_boot/vbmeta → hashes (L4)
  → gate de kernel (modelo/API/KMI/build) → scanner R00–R09
  → patch offline (APatch/KPM, Magisk, KSU) → guard4_verify → cache/artefatos

Stage B  SANDBOX (ubuntu-24.04 + KVM, AVD API 36 x86_64)
  boot_completed → injeta 1 módulo por vez via adb → soft-reboot
  → logcat crash + AVC + uptime → evidence.json → rollout_gate (PASS antes do próximo)

Stage C  RELEASE (ubuntu-24.04)
  empacota imagens + conflict_report + SHA256SUMS + flash_and_rollback.sh
  → artefato pré-USB (retenção curta)

Stage D  DEVICE (humano, com o cabo)
  flash assistido após 10/10 gates → collect_evidence.sh → evidence.json
```

## 3. O que a AVD realmente valida — por módulo

| Módulo | Validação em Stage B | O que só o aparelho prova |
|---|---|---|
| **M01** APatch/kernel | **não** (KPM arm64, kernel do device) | patch do `boot.img`, KMI, root real |
| **M02** Câmera (GCam/HAL) | parcial: instala apk, permissões, XML não colide | HAL, `/dev/video*`, lentes, `cameraserver` |
| **M03** GApps A16 | parcial: overlay `sysconfig`/priv-app, props, crash de GMS | certificação, Play Store, serviços dependentes de vendor |
| **M04** Screen Capture | **sim**: flags + SurfaceFlinger/SystemUI após `stop; start` | captura protegida real |
| **M05** DroidSpaces | parcial: binário x86_64, checklist de namespaces | kernel config, `seccomp`, mount namespace do device |
| **M06** Free-Form | **sim**: `enable_freeform_support`, resize de atividades | comportamento com GPU real |
| **M07** Fingerprint | **sim**: props aplicadas e lidas de volta | RKP/attestation do aparelho |
| **M08** Duck-ToolBox | parcial: contratos/WebUI; `duckd` arm64 não executa | Play Integrity/banking de verdade |
| **M09** SAF | **sim**: R/W em `/Android/data` e `obb` com provider | apps de terceiros com escopo real |
| **M10/M11** Rede/port-forward | **sim**: `adb reverse`, regras por UID (se `owner` disponível) | stack de rede do vendor/modem |
| **M12A** MaxManager | **não** (`/sys/devices/system/cpu` do device) | controle térmico/energia real |
| **M12B** GenieX | **não** (Hexagon NPU/`adsprpc`) | inferência no NPU |
| **M13/M14/M15** CI, snapshots, release | **sim**: o processo inteiro é testável | nada — são artefatos de engenharia |

Resumo honesto: **6 validam de fato, 5 parcialmente, 4 não**. Prometer 15/15 em emulador seria mentira;
o GO-USB 10/10 (pré-USB) cobre o que a AVD não cobre, e o Stage D confirma no hardware.

## 4. Travas de custo (o que impede a conta de subir)

| Trava | Onde | Efeito |
|---|---|---|
| `concurrency.cancel-in-progress: true` | workflow | commit novo derruba a execução anterior |
| `timeout-minutes: 25` no job | forge/release | job travado morre em 25 min |
| `timeout-minutes: 12` no step do emulador | sandbox | bootloop não passa de 12 min |
| `timeout 300` + `sys.boot_completed` | script do sandbox | watchdog mata a AVD e coleta `dmesg` |
| `-no-snapshot` | emulador | sem estado corrompido reaproveitado |
| `actions/cache` por `sha256` da ROM | forge | não rebaixa ~6 GB por run |
| `retention-days: 5` | artefatos | storage não acumula |
| `permissions: contents: read` | workflow | token sem poder de escrita |

Verificação automática: `python3 scripts/ci_workflow_lint.py references/evox-ci-validator.yml`
(11 regras, **12 PASS** no teste). Workflow que perder uma trava **não passa no CI do repo**.

## 5. Codespaces (quando você quiser depurar à mão)

`references/devcontainer.json` já traz `postStartCommand` com `sleep 1800 && sudo poweroff`.
Além dele, configure *Default idle timeout* em 5–15 min nas configurações de Codespaces.
Codespaces cobra VM ligada — o poweroff por inatividade é a única trava que não depende de disciplina.

## 6. Alternativas avaliadas (e por que não são o padrão)

| Alternativa | Prós | Contras | Veredito |
|---|---|---|---|
| **AVD x86_64 API 36** (escolhida) | KVM no runner hospedado, rápido, `android-emulator-runner` maduro | não é arm64, não tem vendor | **padrão do Stage B** |
| Cuttlefish arm64 | boot de GSI arm64 real | exige host arm64 com KVM → self-hosted (custo/ops) | opcional, se você mantiver runner |
| QEMU TCG arm64 | sem KVM | 10–50× mais lento; estoura timeout | descartado |
| Device farm (Firebase/BrowserStack) | hardware real | custo por minuto, sem patch de boot | descartado para pré-flash |
| Emular no Codespace | interativo | cobra VM ligada | só depuração, com poweroff 1800 s |

## 7. Como o Stage B conversa com os gates já testados

```text
sandbox_rollout.sh  →  adb install 1 módulo → soft-reboot → evidence.json
                    →  rollout_gate record  (boot.ok, crashes=0, uptime)
                    →  falhou: exit 3, próximo módulo NÃO abre
cache_manager.sh    →  cada fase verde vira entrada com sha256 (manifesto no repo)
guard4_verify.sh    →  só depois: VERIFIED contra o boot.img oficial
```
