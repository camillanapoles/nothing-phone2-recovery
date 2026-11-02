# Patches do kernel do pack (kABI do DroidSpaces)

**Fonte:** `ravindu644/Droidspaces-OSS` → `Documentation/resources/kernel-patches/GKI/below-kernel-6.12`
**Pin da fonte:** commit `58e3f4e2c909adc3d8bb2a5c9ac914591bb16725` (2026-11-01)
**Integridade:** `SHA256SUMS` nesta pasta; `kernel_build_gate.py --prebuild` (`B08`) reprova se algum arquivo divergir.

| arquivo | papel | quando |
|---|---|---|
| `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch` | primeiro a tentar: padding de ABI para `CONFIG_SYSVIPC` | sempre (5.4–6.6; nosso alvo é 5.10.246) |
| `001.GKI-below-6.12-fix_sysvipc_kabi_3_4_5.patch` | alternativa (outro slot de padding) | **só** se a `6_7_8` der bootloop |
| `001.GKI-below-6.12-fix_sysvipc_kabi_1_2_3.patch` | alternativa (outro slot de padding) | **só** se as anteriores derem bootloop |
| `002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch` | ABI padding para `CONFIG_POSIX_MQUEUE` | sempre em 5.10 e anterior |

Regras: um `001` por build (nunca dois), `git apply --check` antes de aplicar, rejeição = falha
(nada de `--force`/fuzz). Cada troca de variante é registrada com o motivo (bootloop) e refaz o build
inteiro — não se remenda binário.

O fragmento `kernel/fragments/evox_pong_pack.config` é **gerado** por `scripts/kernel-fragment.py` a
partir do contrato do DroidSpaces (`droidspaces-requirements.json`) e copiado no build para
`arch/arm64/configs/evox_pong_pack.config`.
