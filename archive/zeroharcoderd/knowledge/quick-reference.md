# 📱 Quick Reference — Nothing Phone 2 Root (Pong, SM8475)

> One-page checklist. Print this. Tape it next to your desk.

---

## 🔴 STOP — Pre-Flash Checklist (AGENTS.md GUARD-4)

| Check | Command / Action | Must Pass |
|-------|-----------------|-----------|
| Device serial | `fastboot devices` → `9f51ecb9` | ✅ |
| Current slot | `fastboot getvar current-slot` → `_b` | ✅ |
| Slot b successful | `fastboot getvar slot-successful:b` → `yes` | ✅ |
| Bootloader state | `fastboot getvar unlocked` → `yes` | ✅ |
| SHA256 of image | `sha256sum <img>` matches known | ✅ |
| Settings permission | `.claude/settings.local.json` lists the command | ✅ |
| User confirmation | Ask explicitly before destructive flash | ✅ |

---

## ⚡ Root Stack (as of Sept 2026)

| Layer | Component | Version | Notes |
|-------|-----------|---------|-------|
| Device | Nothing Phone 2 | Pong / SM8475 | Android 16 |
| ROM Base | Evolution X | 11.11 (Vanilla) | Build ID: `BP4A.251205.006` |
| Kernel | GKI 2.0 | 5.10.246-gki-g4ec5491f6b5f | Match vermagic |
| Root Manager | APatch | 11219 | kallsyms-based patching |
| Kernel Patch | KernelPatch | 0.13.3 | ARM64, boot.img only |
| Zygisk | ZygiskNext | 1.4.5 (836) | Required for LSPosed |
| Root Hide | Shamiko | v3.6 | Magisk-style (use carefully w/ APatch) |
| PI Bypass | Tricky Store | 1.4.1 (245) | Keybox-based attestation |
| PI Fork | PlayIntegrityFork | v17 | Works with KernelSU/APatch |
| LSPosed | Zygisk variant | v1.9.2 (7024) | Requires ZygiskNext |

---

## 📂 Critical File Locations

```bash
# Boot images (NEVER overwrite without new timestamp)
~/nothing-phone2/backups/snapshot-4-root-active/
├── stock_boot.img                 # SHA: 6f2c638f...
├── apatch_patched_boot.img        # SHA: f57c7db7...
└── checksums.txt                  # SHA256 list

# Downloads
~/nothing-phone2/downloads/
├── recovery.img                   # Evolution X 11.9 (100MB)
├── Magisk-v30.7.apk
├── modules/                       # All module zips
│   ├── ZygiskNext.zip
│   ├── TrickyStore.zip
│   ├── PlayIntegrityFork.zip
│   ├── LSPosed-zygisk.zip
│   └── Shamiko.zip
├── EvolutionX-16.0-20260618-Pong-11.8-Vanilla-Official.zip
└── EvolutionX-16.0-20260915-Pong-11.11-Official.zip

# Kernel source (custom for DroidSpaces)
~/nothing-phone2/kernel-build/
├── kernel/                        # LineageOS lineage-23.2 (kernel 5.10.246)
├── patches/                       # SYSVIPC + POSIX_MQUEUE kABI patches
├── build_pong.sh                  # Build script
└── build-artifacts/               # Compiled Image.gz, Module.symvers
```

---

## ⚙️ Boot Image Strategy (Nothing Phone 2)

| Android Version | Boot Partition | Notes |
|-----------------|---------------|-------|
| Android ≤12 | `boot.img` | Not used for Nothing Phone 2 currently |
| Android 13+ | `init_boot.img` | **Wrong** — Pong uses `boot.img` architecture |

> **⚠️ NOTHING PHONE 2 SPECIFIC:** There is NO `init_boot` partition. It uses the traditional `boot.img` architecture. APatch/KSU guides that mention `init_boot.img` **DO NOT APPLY** to Pong.

---

## 🔧 Sideload Process (3.6 GB ROM)

```bash
# Recovery: Apply Update → Apply from ADB
timeout 1800 adb sideload ~/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip
# ⚠️ DO NOT CANEL at ~47% — it’s normal for transfers to appear stuck
# After completion, when recovery asks "reboot recovery", click YES
```

| Timeout | File Size | Safe? |
|---------|-----------|-------|
| 60s | 3.6 GB | ❌ Will timeout |
| 600s | 3.6 GB | ❌ May timeout |
| 1800s | 3.6 GB | ✅ Guaranteed |

---

## 🔐 Unlock / Root Commands

### Bootloader Unlock (Nothing Phone 2)
```bash
fastboot flashing unlock
# On device: Volume → "UNLOCK THE BOOTLOADER" → Power
```

### APatch Root
```bash
# 1. Ensure system is stable
adb shell getprop sys.boot_completed  # → 1

# 2. Reboot to fastboot
adb reboot bootloader
fastboot getvar current-slot  # → _b

# 3. Flash APatch boot (verify SHA first)
sha256sum ~/nothing-phone2/backups/snapshot-4-root-active/apatch_patched_boot.img
# Expected: f57c7db7d948a906ebe63370e6cb481e72a5bebd1b7e0b027bab883bf70df7b4

fastboot flash boot_b ~/.../apatch_patched_boot.img
fastboot --set-active=b
fastboot reboot
```

---

## 🛡️ Post-Root Module Management

```bash
# List all modules
adb shell su -c 'ls /data/adb/modules/'

# Disable a module (create disable file)
adb shell su -c 'touch /data/adb/modules/MODULE_NAME/disable'

# Check which modules are active
adb shell su -c 'ls /data/adb/modules/ | while read m; do [ ! -f /data/adb/modules/$m/disable ] && echo "ATIVO: $m"; done'

# Reboot to apply changes
adb reboot
```

### Essential Active Modules (Pong)
| Module | Purpose | Status |
|--------|---------|--------|
| zygisknext | Zygisk base layer | ✅ Active |
| tricky_store | Play Integrity keybox spoofing | ✅ Active |
| playintegrityfork | Attestation bypass (v17) | ✅ Active |
| mountify | Mount management | ❌ Disabled (known conflicts) |
| zygisk_shamiko | Root hiding | ❌ Disabled (APatch conflict) |
| LSPosed | Xposed framework | ✅ Active (Zygisk variant only) |

---

## 🆘 Emergency Commands

```bash
# Force reboot to fastboot (when ADB/fastboot dead, PID = 0xa4a1)
# Physical: Hold Power + Vol Down for 20 seconds

# Rollback to slot A
fastboot --set-active=a
fastboot reboot

# Flash stock boot back
fastboot flash boot_b ~/.../stock_boot.img

# Enter EDL (last resort — requires firehose)
# Physical: Hold Vol Up + Vol Down + plug USB
# OR: fastboot oem edl
```

---

## 📊 Verification Commands

```bash
# Root access
adb shell su -c 'id'
# Expected: uid=0(root)

# SELinux status
adb shell getenforce
# Expected: Enforcing

# APatch version
adb shell su -c 'cat /data/adb/apatch/version'

# Build ID + slot
adb shell getprop ro.build.display.id  # → BP4A.251205.006
adb shell getprop ro.boot.slot_suffix  # → _b

# Boot completion
adb shell getprop sys.boot_completed  # → 1

# Kernel version
adb shell uname -r  # → 5.10.246-gki-g4ec5491f6b5f

# No critical errors in boot log
adb shell logcat -b boot -t 200 | grep -iE 'error|fail|panic|watchdog'
```

---

## 🧠 AGENTS.md Error Reference

| Error # | Symptom | Fix |
|---------|---------|-----|
| #1 | Assumed slot _b in bootloop, but device was on _a | Always `getprop ro.boot.slot_suffix ` first |
| #2 | Assumed stock_boot.img would fix bootloop | Check `logcat -b boot` for root cause |
| #3 | fastboot flash ran without settings.local.json permission | Check AGENTS.md checklist before flashing |
| #4 | Flash without SHA256 validation | Always `sha256sum -c checksums.txt` |
| #5 | Confused APatch with KernelSU (user said "kernel su") | Check with `su -c 'cat /data/adb/apatch/version'` |
| #6 | Incompatible kernel × modules | Audit `/data/adb/modules/` after flash |

## Tags
`#[nothing-phone-2]` `#[pong]` `#[evolutionx-11.11]` `#[apatch-11219]` `#[magisk-v30.7]` `#[kernelsu-next-v3.4.2]` `#[zygisknext]` `#[tricky-store]` `#[emergency]` `#[guard-4]`
