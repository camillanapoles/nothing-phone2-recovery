# Framework: Magisk v30.7 (Android 16 QPR2)

> Systemless root with Zygisk injection, DenyList, and module management.

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | v30.7 |
| **Release Date** | 2026-02-23 |
| **Android Support** | 6.0+ (explicit Android 16 QPR2 sepolicy + Zygisk support) |
| **Source** | https://github.com/topjohnwu/Magisk/releases/tag/v30.7 |
| **Changelog** | https://topjohnwu.github.io/Magisk/changes.html |

---

## Key Features (v30.7)

| Feature | Description |
|---------|-------------|
| **Android 16 QPR2 sepolicy** | MagiskInit supports new sepolicy format |
| **Zygisk for Android 16+** | Zygisk injection works on API 36 |
| **klogdump partition support** | Alternative pre-init storage |
| **MagiskSU capabilities** | Does not drop caps by default (use `--drop-cap`) |
| **lzma detection** | Better boot image format detection |
| **Command-line parsing** | Fixed argument parsing bugs in MagiskBoot |

---

## Installation Methods

### Method 1: Boot Image Patching (Standard)

```bash
# 1. Get stock boot.img for your ROM
#    - Extract from OTA payload.bin using payload-dumper-go
#    - Nothing Phone 2: target is boot.img (NOT init_boot.img)

# 2. Transfer to device
adb push boot.img /sdcard/Download/

# 3. Install Magisk APK
adb install Magisk-v30.7.apk

# 4. On device: Magisk → Install → "Select and Patch a File" → boot.img
#    Output: /sdcard/Download/magisk_patched_XXXXXX.img

# 5. Pull patched image
adb pull /sdcard/Download/magisk_patched_*.img ./magisk_patched_boot.img

# 6. Flash via fastboot
adb reboot bootloader
fastboot flash boot magisk_patched_boot.img
fastboot reboot
```

### Method 2: Fastbootd (A/B devices)

```bash
# For A/B devices, Magisk app can do "Install to Inactive Slot (After OTA)"
# This preserves root across seamless updates
```

---

## Post-Install Configuration

### Essential Settings

```text
Magisk App → Settings:
├── Enable Zygisk: ✅ ON
├── Enforce DenyList: ✅ ON
├── Hide Magisk App: ✅ ON (for banking apps)
└── Recovery Mode: ✅ OFF (unless needed)
```

### DenyList Configuration

Add these packages to DenyList:
- `com.google.android.gms` (Google Play Services)
- `com.android.vending` (Google Play Store)
- `com.google.android.gsf` (Google Services Framework)
- Your banking/payment apps
- Any app that detects root

---

## Root Hiding Strategy (Magisk + Community)

> **⚠️ IMPORTANT:** Magisk upstream **explicitly does not handle root hiding**.  
> You MUST use community modules:

| Module | Purpose | Compatibility |
|--------|---------|---------------|
| **Shamiko** (v3.6+) | Hides Magisk from apps | Works with Zygisk |
| **Zygisk Assistant** | DenyList UI + hiding | Works with Zygisk |
| **Play Integrity Fix** | SafetyNet/PI bypass | Works with DenyList |
| **Tricky Store** | Keybox attestation | Works with ZygiskNext |

### Hide Stack (Recommended)

```
Magisk v30.7
    ├── Zygisk: ENABLED
    ├── DenyList: ENABLED (banking apps)
    ├── Shamiko (v3.6): LOADED via Zygisk
    ├── Play Integrity Fix (v0.6+): LOADED via Zygisk
    └── Tricky Store (v1.4.1): KEYBOX attestation
```

---

## OTA Handling (A/B Devices)

### Magisk's "Install to Inactive Slot"

1. OTA downloads → **don't reboot yet**
2. Open Magisk → Install → "Install to Inactive Slot (After OTA)"
3. Wait for completion
4. Reboot when prompted
5. Root preserved!

### Manual OTA Re-Patch

```bash
# If automatic fails:
# 1. Extract new boot.img from OTA
# 2. Patch with Magisk app
# 3. Flash to inactive slot
fastboot flash boot magisk_patched_new.img  # from inactive slot
```

---

## Module Management

```bash
# List installed modules
ls /data/adb/modules/

# Disable a module
touch /data/adb/modules/MODULE_NAME/disable

# Enable a module
rm /data/adb/modules/MODULE_NAME/disable

# Module directory structure
/data/adb/modules/MODULE_NAME/
├── module.prop          # Metadata (id, name, version, author)
├── system/              # Files to overlay (optional)
├── post-fs-data.sh      # Runs late in boot (optional)
├── service.sh           # Runs after post-fs-data (optional)
└── uninstall.sh         # Runs on module removal (optional)
```

---

## Magisk on Nothing Phone 2 (Pong)

| Aspect | Details |
|--------|---------|
| **Boot partition** | `boot` (not `init_boot`) |
| **Slot** | A/B — flash to active slot or use "Inactive Slot" |
| **Kernel** | GKI 2.0 (5.10.246) — Magisk v30.7+ compatible |
| **Recovery** | Evolution X Recovery — Magisk module sideload supported |
| **Glyph** | Works with Magisk (no module conflict) |
| **Play Integrity** | BASIC achievable; DEVICE_INTEGRITY needs modules |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Magisk shows "N/A" | Wrong image patched — re-patch correct boot.img |
| Bootloop after flash | Flash stock boot.img back: `fastboot flash boot stock_boot.img` |
| Root not detected | Reboot; check "Additional Setup" in Magisk app |
| Banking app detects root | Add to DenyList + Shamiko + Play Integrity Fix |
| OTA removes root | Use "Install to Inactive Slot" before reboot |
| Zygisk module not loading | Ensure Zygisk enabled + reboot after install |

---

## Verification Commands

```bash
# Root check
adb shell su -c 'id'
# → uid=0(root) gid=0(root)

# Magisk version
adb shell su -c 'magisk -v'
# → Magisk v30.7

# Zygisk status
adb shell su -c 'magisk --zygisk'
# → Zygisk enabled

# DenyList status
adb shell su -c 'magisk --denylist'
# → List of packages

# Boot image verify
adb shell su -c 'cat /proc/cmdline'
# → Check for magisk parameters
```

---

## Compatibility Matrix

| Component | Version | Works? |
|-----------|---------|--------|
| Android 16 QPR2 | API 36 | ✅ |
| Nothing Phone 2 (Pong) | SM8475 | ✅ |
| Evolution X 11.11 | BP4A.251205.006 | ✅ |
| LineageOS 23.2 | Android 16 | ✅ |
| KernelSU (LKM) | N/A | ❌ (KMI mismatch) |
| APatch | v11219+ | ✅ (alternative) |
| ZygiskNext | 1.4.5+ | ✅ |
| LSPosed (Zygisk) | 1.9.2+ | ✅ |
| Shamiko | v3.6+ | ✅ |

---

## Tags
`#[magisk-v30.7]` `#[android-16-qpr2]` `#[zygisk]` `#[denylist]` `#[shamiko]` `#[play-integrity]` `#[tricky-store]` `#[nothing-phone-2]` `#[evolutionx-11.11]` `#[oot-handling]`