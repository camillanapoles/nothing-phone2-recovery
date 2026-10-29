# Framework: KernelSU Next v3.4.2 (Android 16 / GKI 2.0)

> Kernel-based root with App Profiles, SUSFS, and built-in LKM support for GKI 2.0 devices.

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | v3.4.2 (latest) |
| **Also tested** | v3.4.0 |
| **Android Support** | Kernels 4.4–6.18 |
| **GKI Support** | GKI 2.0 (5.10–6.18) with built-in SUSFS |
| **Source** | https://github.com/KernelSU-Next/KernelSU-Next |
| **Manager App** | KernelSU Next Manager |

---

## Architecture

```
Custom kernel (with KSU integrated)
    ↓
KSU LKM (ksud)
    ↓
KernelSU Next Manager — manages modules, App Profiles, SUSFS
```

### Key Components

| Component | Path | Purpose |
|-----------|------|---------|
| ksud | `/data/adb/ksu/ksud` | Kernel module daemon |
| KSU LKM | Built into kernel | Kernel-level root |
| SUSFS | Built-in (v3.4+) | Kernel-level root hiding |
| Manager | APK | UI for modules, App Profiles |
| App Profiles | `/data/adb/ksu/app_profiles/` | Per-app root/SELinux control |

---

## Installation

### Method 1: Custom Kernel (Recommended)

```bash
# 1. Flash a KernelSU Next-compatible kernel
#    For Nothing Phone 2: NP² Kernel or custom build with KSU integration
#    Source: https://github.com/miguvt/NP2_Kernel

# 2. Install KernelSU Next Manager
#    Download APK from releases
adb install KernelSU.apk

# 3. Reboot and verify
adb shell su -c 'id'
# → uid=0(root)
```

### Method 2: Boot Image Patching (GKI)

```bash
# 1. Get stock boot.img
# 2. Use KernelSU app to patch:
#    Open KernelSU → Install → Select boot.img → Patch
# 3. Flash patched image
fastboot flash boot patched_boot.img
```

### Method 3: Kernel Patch (LKM)

```bash
# 1. Build custom kernel with KSU integration
# 2. Flash kernel via fastboot
fastboot flash boot custom_kernel_with_ksu.img
# 3. Install Manager APK
```

---

## Module Management

### CLI Commands (requires root)

```bash
# List modules
su -c "ksu --list-modules"

# Install module
su -c "ksud install /data/local/tmp/module.zip"

# Enable/disable module
su -c "ksu --enable-module <name>"
su -c "ksu --disable-module <name>"

# Module directory
/data/adb/ksu/modules/<name>/
├── module.prop
├── system/
├── post-fs-data.sh
└── service.sh
```

---

## App Profiles

Per-app root access control:

```bash
# Grant root to specific app
su -c "ksu --grant <package>"

# Deny root to specific app
su -c "ksu --deny <package>"

# List profiles
su -c "ksu --list-profiles"

# Profile directory
/data/adb/ksu/app_profiles/<uid>.xml
```

---

## SUSFS (Built-in v3.4+)

Kernel-level root hiding:

| Feature | Description |
|---------|-------------|
| **Faking** | Fakes root detection results |
| **Unlink** | Hides /system/bin/su, /data/adb from apps |
| **SetUID** | Blocks setuid binaries |
| **Procfs** | Hides su/ksu from /proc |
| **Mount** | Hides module mounts from apps |

---

## Nothing Phone 2 Compatibility

### Status: ⚠️ Needs custom kernel

| Aspect | Details |
|--------|---------|
| **Stock kernel** | 5.10.246 — no KSU integration |
| **GKI support** | GKI 2.0 (5.10 LTS) |
| **KernelSU LKM** | Fails on stock KMI (modified by Qualcomm) |
| **Custom kernel required** | NP² Kernel (https://github.com/miguvt/NP2_Kernel) |
| **KernelSU Next variant** | Recommended for Pong |

### Options for Nothing Phone 2

1. **APatch** (✅ recommended) — kallsyms-based, no kernel build needed
2. **KernelSU Next** — needs custom kernel (NP² Kernel or build from source)
3. **Magisk** — works but no LKM/module support

If you want KernelSU on Nothing Phone 2:

```bash
# 1. Flash NP² Kernel with KSU Next integration
#    https://github.com/miguvt/NP2_Kernel

# 2. Install KernelSU Next Manager
adb install KernelSU.apk

# 3. Verify SUSFS
su -c "ksu --check-susfs"
```

---

## SELinux Modes

KernelSU Next supports both modes:

```bash
# Check mode
getenforce  # Enforcing / Permissive

# Toggle (temporary)
su -c "setenforce 0"  # Permissive
su -c "setenforce 1"  # Enforcing

# KernelSU Manager → Settings → SELinux
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Module not loading | Check `/data/adb/ksu/modules/` for `disable` files |
| App Profile not working | Verify package name exact match |
| SUSFS not active | Ensure custom kernel has SUSFS built-in |
| Bootloop after kernel flash | Flash stock boot.img to recover |
| SELinux enforcing blocks root | Temporarily set permissive, then refine rules |

---

## Verification Commands

```bash
# KSU version
adb shell su -c 'ksu --version'

# Kernel check
adb shell su -c 'uname -r'
# → 5.10.246-gki-...

# SUSFS status
adb shell su -c 'ksu --check-susfs'

# Root access
adb shell su -c 'id'
# → uid=0(root) group=0(root)

# SELinux
adb shell getenforce
# → Enforcing
```

---

## Comparison: KernelSU vs KernelSU Next

| Feature | KernelSU | KernelSU Next |
|---------|----------|---------------|
| Developer | tiann | Community fork (pershoot et al) |
| Latest | ~v3.2.5 | v3.4.2 |
| GKI SUSFS | Optional plugin | Built-in (v3.4+) |
| App Profiles | ✅ | ✅ |
| KMI requirement | Strict | More flexible |
| Maintenance | Slower | Active |
| Recommended for | Standard | Nothing Phone 2 (custom kernel) |

---

## Tags
`#[kernelsu-next-v3.4.2]` `#[android-16]` `#[gki-2.0]` `#[susfs]` `#[app-profiles]` `#[nothing-phone-2]` `#[pong]` `#[custom-kernel]` `#[root]`