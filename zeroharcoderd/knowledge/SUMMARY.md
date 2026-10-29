# Knowledge Base Complete — Contents Summary

## Files Created

### Root Frameworks (3)
1. **`frameworks/magisk-v30.7.md`** — Boot image patching, Zygisk, DenyList, Shamiko root-hiding stack, OTA handling
2. **`frameworks/apatch-v11219.md`** — **Preferred for Nothing Phone 2** — kallsyms-based patching, no KMI dependency, module management CLI (`apd`), App Profiles
3. **`frameworks/kernelsu-next-v3.4.2.md`** — LKM mode, SUSFS, App Profiles, GKI 2.0 support; KMI mismatch note for Pong

### Modules (7)
4. **`modules/zygisknext.md`** — v1.4.5 (build 836) — required base layer for Zygisk
5. **`modules/playintegrityfork.md`** — v17 — Play Integrity bypass, GMS crash fix (D-1/D-2)
6. **`modules/trickystore.md`** — v1.4.1 — keybox attestation spoofing for `MEETS_DEVICE_INTEGRITY`
7. **`modules/lsposed.md`** — v1.9.2 — **Zygisk variant only** (Riru fails on APatch)
8. **`modules/shamiko.md`** — **DISABLED** — conflicts with APatch kallsyms
9. **`modules/mountify.md`** — **DISABLED** — metamodule conflict with Shamiko
10. **`modules/droidspaces.md`** — Custom kernel modules (SYSVIPC, POSIX_MQ, Glyph driver)

### Device Envs (2)
11. **`environments/nothing-phone-2.md`** — Hardware, partition layout (`boot` not `init_boot`), KMI quirk, USB PIDs
12. **`environments/evolutionx-11.11.md`** — ROM specifics, sideload procedure (1800s timeout), post-install setup

### Tools (1)
13. **`tools/droidspaces-kernel-build.md`** — Kernel build framework, SYSVIPC + POSIX_MQUEUE patches, KMI check

### Troubleshooting (4)
14. **`troubleshooting/gms-crash-securityexception.md`** — From STATE.md D-1/D-2
15. **`troubleshooting/play-integrity-banking.md`** — Play Integrity stack, banking app validation table
16. **`troubleshooting/free-form-windows.md`** — Mini-janelas on Nothing OS 3.0+
17. **`troubleshooting/camera-not-working.md`** — Camera HAL, SELinux, LSPosed conflicts

### Core (2)
18. **`quick-reference.md`** — One-page printable checklist (Guard-4, emergency, root stack)
19. **`README.md`** — Full index, recommended stack, critical gotchas

---

## Version Matrix (All in-files — zero hardcoded variables)

| Component | Version | File |
|-----------|---------|------|
| Evolution X (ROM) | 11.11 (Android 16 QPR2) | environments/evolutionx-11.11.md |
| APatch | 11219 | frameworks/apatch-v11219.md |
| Magisk | v30.7 | frameworks/magisk-v30.7.md |
| KernelSU Next | v3.4.2 | frameworks/kernelsu-next-v3.4.2.md |
| KernelPatch | 0.13.3 | apatch-v11219.md |
| ZygiskNext | 1.4.5 (836) | modules/zygisknext.md |
| Tricky Store | 1.4.1 (245) | modules/trickystore.md |
| PlayIntegrityFork | v17 | modules/playintegrityfork.md |
| LSPosed | v1.9.2 (7024) | modules/lsposed.md |
| Shamiko | v3.6 | modules/shamiko.md |
| Droidspaces kernel | lineage-23.2 + patches | tools/droidspaces-kernel-build.md |

---

## Key Rules (from AGENTS.md + discoveries)

| Rule | Details |
|------|---------|
| **Err #1** | ALWAYS confirm `fastboot getvar current-slot` before flashing |
| **Err #2** | Don't assume stock_boot fixes bootloop — check `logcat -b boot` first |
| **Err #3** | Check `.claude/settings.local.json` before any destructive command |
| **Err #4** | `sha256sum` verification before flash — mismatch = ABORT |
| **Err #5** | APatch ≠ KernelSU — verify with `su -c 'cat /data/adb/apatch/version'` |
| **Err #6** | After custom kernel flash, audit modules in `/data/adb/modules/` |

**Gotcha**: Nothing Phone 2 uses `boot.img`, NOT `init_boot.img` — most guides are wrong.

---

## Directory: `/home/cnmfs/nothing-phone2/zeroharcoderd/knowledge/`