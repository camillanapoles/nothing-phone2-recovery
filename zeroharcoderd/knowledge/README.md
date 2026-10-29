# Knowledge Base — Android Root on Nothing Phone 2 (Pong)

> Zero-hardcoded-variable agentic reference for rooting Nothing Phone 2 with Evolution X. All values (paths, SHAs, versions) are stored in-file — `cat` or `source` what you need. Built incrementally.

---

## 🗺️ Navigation Index

### Quick Start
- [`quick-reference.md`](./quick-reference.md) — print-and-go checklist (Guard-4, root stack, emergency)
- [`README.md`](./README.md) — this file

### Device Envs
- [`environments/nothing-phone-2.md`](./environments/nothing-phone-2.md) — hardware, partitions, GPIO, USB PIDs
- [`environments/evolutionx-11.11.md`](./environments/evolutionx-11.11.md) — ROM specifics, sideload, GApps, post-install

### Root Frameworks
- [`frameworks/magisk-v30.7.md`](./frameworks/magisk-v30.7.md) — boot patching, Zygisk, DenyList, OTA
- [`frameworks/apatch-v11219.md`](./frameworks/apatch-v11219.md) — **Preferred for Pong** (kallsyms, no KMI dependency)
- [`frameworks/kernelsu-next-v3.4.2.md`](./frameworks/kernelsu-next-v3.4.2.md) — LKM, SUSFS, App Profiles

### Modules
- [`modules/zygisknext.md`](./modules/zygisknext.md) — Zygisk base (v1.4.5 build 836)
- [`modules/playintegrityfork.md`](./modules/playintegrityfork.md) — Play Integrity bypass (v17)
- [`modules/trickystore.md`](./modules/trickystore.md) — Keybox attestation spoofing (v1.4.1)
- [`modules/lsposed.md`](./modules/lsposed.md) — Xposed framework **Zygisk variant only**
- [`modules/shamiko.md`](./modules/shamiko.md) — Root hiding (DISABLED on APatch — conflicts)
- [`modules/mountify.md`](./modules/mountify.md) — APatch mount manager (DISABLED — metamodule conflict)
- [`modules/droidspaces.md`](./modules/droidspaces.md) — Custom kernel modules (SYSVIPC, POSIX_MQ, Glyph driver)
- [`modules/free-form-windows.md`](./modules/free-form-windows.md) — Mini-janelas on Nothing OS 3.0
- [`modules/morph-apps.md`](./modules/morph-apps.md) — Sandboxed morph app environment, bank liberado

### Tools
- [`tools/droidspaces-kernel-build.md`](./tools/droidspaces-kernel-build.md) — Kernel build framework, KMI check

### CI/CD
- [`.github/workflows/boot-test.yml`](./.github/workflows/boot-test.yml) — GitHub Actions: boot simulation + knowledge validation
- [`ci/setup_android_sdk.sh`](./ci/setup_android_sdk.sh) — Android SDK setup for CI boot testing

### Configuration Maps
- [`config-map/apatch-evolutionx-droidspaces.md`](./config-map/apatch-evolutionx-droidspaces.md) — Conflict-free root stack config + CI validation

### Troubleshooting
- [`troubleshooting/gms-crash-securityexception.md`](./troubleshooting/gms-crash-securityexception.md) — D-1: GMS SecurityException fix (SELinux Permissive)
- [`troubleshooting/play-integrity-banking.md`](./troubleshooting/play-integrity-banking.md) — Play Integrity + banking app validation
- [`troubleshooting/camera-not-working.md`](./troubleshooting/camera-not-working.md) — Camera HAL, LSPosed conflicts
- [`troubleshooting/google-unlock-camera-screenshot.md`](./troubleshooting/google-unlock-camera-screenshot.md) — Google Unlock, camera, screenshot validation

---

## 🎯 Recommended Root Stack (Sept 2026)

```text
Nothing Phone 2 (Pong, SM8475)
├── ROM: Evolution X 11.11 (Android 16 QPR2) — Vanilla (2.54 GB)
├── Root: APatch v11219 (KernelPatch 0.13.3) — Preferred (no KMI dependency)
├── Alt Root: Magisk v30.7 (if avoiding APatch modules)
├── Kernel: Stock GKI 2.0 (5.10.246-gki-g4ec5491f6b5f)
└── Active Modules:
    ├── ZygiskNext v1.4.5 (836)       ← Required for LSPosed
    ├── Tricky Store v1.4.1 (245)     ← Keybox for DEVICE_INTEGRITY
    ├── PlayIntegrityFork v17         ← Play Integrity bypass
    ├── LSPosed v1.9.2 (Zygisk)       ← Zygisk variant ONLY
    └── Droidspaces Kernel           ← Custom kernel with SYSVIPC

DISABLED MODULES (critical conflicts):
    ├── mountify (metamodule conflict with Shamiko)
    ├── Shamiko v3.6 (conflicts with APatch kallsyms)
    └── Riru/LSPosed (search for magisk binary → fails on APatch)
```

---

## ⚠️ Critical Gotchas (Pong-Specific)

| Fact | Impact | Solution |
|------|--------|----------|
| **`boot.img` not `init_boot.img`** | Most guides wrong for Pong → bootloop | Patch `boot.img` |
| **Modified GKI KMI** | KernelSU LKM fails on stock | Use APatch (kallsyms) or custom kernel |
| **LSPosed Riru variant** | Fails silently on APatch | **Only Zygisk variant** |
| **Shamiko + APatch** | Namespace conflicts | Keep Shamiko DISABLED |
| **3.6 GB ZIP sideload** | Timeout at ~47% | `timeout 1800 adb sideload` |
| **CDC NCM mode** | No ADB on boot | Hold Vol Down + Power 20s |
| **Full ROM + MindTheGapps** | Installation Error 1 | Use Vanilla + systemless GApps |

---

## 📂 Directory Structure Reference

```text
/home/cnmfs/nothing-phone2/
├── backups/snapshot-4-root-active/     ← stock_boot.img + apatch_patched_boot.img + checksums
├── downloads/
│   ├── EvolutionX-11.11-Vanilla.zip    ← 2.54 GB
│   ├── recovery.img                    ← Evolution X Recovery (100 MB)
│   └── modules/                        ← All module zips
├── extracted/                          ← OTA payload extraction
├── evolotionx-16.00-nothing_phone2/   ← ROM contents
└── logs/                               ← Audit logs
```

> **Key files in snapshots:**
> - `stock_boot.img` — SHA256: `6f2c638f...`
> - `apatch_patched_boot.img` — SHA256: `f57c7db7...`
> - `checksums.txt` — always verify: `sha256sum -c checksums.txt`

---

## 🚨 Emergency Commands

```bash
# Bootloop → restore stock
fastboot flash boot_b ~/n2/backups/snapshot-4-root-active/stock_boot.img

# CDC NCM mode (0xa4a1) → force reboot
# Hold POWER + VOL_DOWN for 20 seconds

# Verify slot status
fastboot getvar current-slot     → _b
fastboot getvar slot-successful:b → yes
fastboot getvar unlocked         → yes
```

---

## 🛡️ Guard-4 Pre-Flash Checklist

```bash
# Run before EVERY flash:
 fastboot devices                    → shows serial
 fastboot getvar current-slot      → _b
 fastboot getvar slot-successful:b → yes
 fastboot getvar unlocked         → yes
 sha256sum <image>                 → matches checksums.txt
 ls .claude/settings.local.json    → command allowed
```

---

## 🔍 Related Project Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Nothing-phone2 recovery playbook (6 error rules) |
| `STATE.md` | Current device state — APatch 11219, slot _b, SELunix Permissive (TEMP) |
| `WIKI.md` | Root stack summary, discoveries |
| `odd/tasks/fsm-recovery-audit.md` | FSM audit system spec (Pydantic AI V2) |
| `magisk_vs_kernelsu.md` | Framework comparison |

---

## Tags
`#[/knowledge-base]` `#[nothing-phone-2]` `#[pong]` `#[sm8475]` `#[evolutionx-11.11]` `#[/apatch-11219]` `#[/magisk-v30.7]` `#[/kernelsu-next-v3.4.2]` `#[android-16]` `#[/droidspaces]` `#[/play-integrity]` `#[/gms]` #[/free-form]` #[camera-fix]`