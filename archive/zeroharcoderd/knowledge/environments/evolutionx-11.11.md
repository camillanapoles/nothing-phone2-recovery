# Environment: Evolution X 11.11 (Android 16 QPR2) on Nothing Phone 2

> Version-specific configuration for Evolution X 11.11 (build `BP4A.251205.006`).

---

## Release Information

| Property | Value |
|----------|-------|
| **Version** | 11.11 |
| **Android Version** | 16 (API 36) |
| **Security Patch** | September 2026 |
| **Build Fingerprint** | `google/mustang_beta/mustang:CANARY/ZP11.260618.005/15760424:user/release-keys` |
| **Build ID** | `BP4A.251205.006` |
| **ROM Type** | Vanilla (no GApps) / Official (with GApps) |
| **Maintainer** | hiroshi. (Superuser) |
| **Source** | https://evolution-x.org/device/Pong |

---

## Available Downloads

| Variant | Size | SHA256 | Notes |
|---------|------|--------|-------|
| **Vanilla** | 2.54 GB | Check release page | No GApps — use for root + custom GApps |
| **Official (GApps)** | 3.65 GB | `79236f9b4259cf5df124dcd7176f8b4c30de0d755e189e8a4224a03e365422fb` | Includes GApps |

---

## Recovery

| Property | Value |
|----------|-------|
| **Recovery Base** | Evolution X Recovery (based on 11.9 binary) |
| **Recovery Image** | `/home/cnmfs/nothing-phone2/downloads/recovery.img` (100 MB) |
| **Sideload** | Supported — Apply Update → Apply from ADB |
| **Format Data** | Required when switching ROM families |

---

## Boot Image & Root

| Property | Value |
|----------|-------|
| **Boot Partition** | `boot` (NOT `init_boot`) |
| **Slot Architecture** | A/B |
| **Stock Boot SHA** | `6f2c638f...` (in `snapshot-4-root-active/`) |
| **APatch Boot SHA** | `f57c7db7...` (in `snapshot-4-root-active/`) |
| **Magisk Compatibility** | v30.7+ (Android 16 QPR2 support) |
| **APatch Compatibility** | v11219+ |

---

## Post-Install Setup Checklist

### 1. First Boot Validation
```bash
adb shell getprop ro.build.display.id
# → BP4A.251205.006

adb shell getprop ro.boot.slot_suffix
# → _b

adb shell getprop sys.boot_completed
# → 1
```

### 2. GApps Installation (Vanilla builds only)
```bash
# Use systemless GApps module via KernelSU/APatch, OR
# Sideload MindTheGapps via recovery (may have mount issues)
# Recommended: OpenGApps pico/nano for Android 16
```

### 3. Root Setup
```bash
# APatch (preferred for Pong)
# 1. Patch stock boot.img with APatch
# 2. Flash to boot_b
# 3. Verify su -c id → uid=0

# Magisk (alternative)
# 1. Magisk app → Install → Select and Patch boot.img
# 2. Flash patched image
# 3. Enable Zygisk + DenyList
```

### 4. Essential Modules
| Module | Source | Notes |
|--------|--------|-------|
| ZygiskNext | GitHub releases | Base Zygisk layer |
| Tricky Store | GitHub releases | Keybox-based PI spoofing |
| PlayIntegrityFork v17 | osm0sis | Works with APatch/KSU |
| LSPosed (Zygisk) | v1.9.2 (7024) | Requires ZygiskNext |

### 5. Known Working / Broken

| Feature | Status | Notes |
|---------|--------|-------|
| Fingerprint | ⚠️ Test after root | APatch + ZygiskNext may interfere |
| Glyph | ✅ Full | Works on official Evolution X builds |
| Camera | ✅ | Vendor blobs included |
| GMS (Vanilla) | ❌ Needs module | Use systemless GApps |
| Play Integrity | ⚠️ BASIC only | DEVICE_INTEGRITY needs keybox spoofing |
| SELinux | ✅ Enforcing | Root maintains Enforcing |

---

## Build Changelog (relevant to Pong)

| Version | Date | Key Changes |
|---------|------|-------------|
| 11.11 | Sep 15, 2026 | Android 16 QPR2, Glyph fixes |
| 11.9 | Aug 2, 2026 | Firmware NOS 4.1, Dolby |
| 11.8 | Jun 18, 2026 | Initial Android 16 |
| 11.7 | May 26, 2026 | Firmware NOS 4.0 |
| 11.6.4 | Apr 26, 2026 | Security patches |

---

## Sideload Procedure (Verified)

```bash
# 1. Device in recovery (Evolution X)
adb devices
# → 9f51ecb9  recovery

# 2. Confirm slot
adb shell getprop ro.boot.slot_suffix
# → _b

# 3. Sideload with LONG timeout
timeout 1800 adb sideload ~/Downloads/EvolutionX-16.0-20260915-Pong-11.11-Official.zip

# 4. Wait for 100% → DO NOT CANCEL at ~47%
# 5. Recovery prompts "reboot recovery to install additional packages"
# 6. Click YES on device
# 7. Select "Reboot system now"
```

---

## Post-OTA Root Re-Patch

```bash
# After any OTA update, root is lost. Re-patch:
# 1. Extract new boot.img from OTA (payload-dumper-go)
# 2. Patch with Magisk/APatch
# 3. Flash to inactive slot (Magisk: "Install to Inactive Slot")
# 4. Reboot
```

---

## Tags
`#[evolutionx-11.11]` `#[android-16]` `#[android-16-qpr2]` `#[pong]` `#[nothing-phone-2]` `#[sideload]` `#[recovery]` `#[root]` `#[apatch]` `#[magisk-v30.7]` `#[gapps-vanilla]`