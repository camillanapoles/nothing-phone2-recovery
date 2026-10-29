# Framework: APatch v11219 — KernelPatch Root Manager

> Kallsyms-based kernel patching root manager. **Preferred for Nothing Phone 2 (Pong)** because KernelSU LKM fails due to modified GKI KMI.

---

## Version Information

| Property | Value |
|----------|-------|
| **APatch Version** | 11219 |
| **KernelPatch** | 0.13.3 |
| **Android Support** | ARM64 kernels 3.18–6.12 |
| **Source** | https://github.com/bmax121/APatch |
| **SuperKey** | Required for sensitive operations |

---

## Why APatch on Nothing Phone 2?

| Framework | Works on Pong? | Reason |
|-----------|---------------|--------|
| **KernelSU LKM** | ❌ | KMI mismatch — GKI modules reject custom KSU |
| **KernelSU Next** | ⚠️ | Needs custom kernel build with KSU integration |
| **Magisk** | ✅ | Patches boot.img — works but no LKM support |
| **APatch** | ✅ | Kallsyms-based — no KMI dependency |

---

## Architecture

```
boot.img (stock)
    ↓
KernelPatch (0.13.3) — patches kallsyms directly into kernel binary
    ↓
boot.img (patched) — APatch root active
    ↓
APatch Manager (v11219) — manages modules, SuperKey, app profiles
```

### Key Components

| Component | Path | Purpose |
|-----------|------|---------|
| APatch Manager | `/system/bin/apd` | Module management, SuperKey |
| Su binary | `/system/bin/su` | Root access |
| KernelPatch | Built into boot.img | Kernel-level patching |
| SuperKey | APK | Sensitive root operations |

---

## Installation (Nothing Phone 2)

```bash
# 1. Get stock boot.img for Evolution X 11.11
#    Extract from OTA payload.bin using payload-dumper-go

# 2. Patch with APatch
#    Method A: APatch app → Install → Select boot.img
#    Method B: apd CLI (requires root)
#    adb shell su -c "apd patch /sdcard/Download/boot.img"

# 3. Flash patched boot
adb reboot bootloader
fastboot flash boot_b apatch_patched_boot.img
fastboot --set-active=b
fastboot reboot

# 4. Verify
adb shell su -c 'cat /data/adb/apatch/version'
# → 11219
```

---

## Module Management

### CLI Commands (requires root)

```bash
# List modules
su -c "apd module list"

# Install module
su -c "apd module install /data/local/tmp/module.zip"

# Disable module
touch /data/adb/modules/MODULE_NAME/disable

# Enable module
rm /data/adb/modules/MODULE_NAME/disable

# Module directory structure
/data/adb/modules/MODULE_NAME/
├── module.prop          # id, name, version, author
├── system/              # Files to overlay
├── post-fs-data.sh      # Boot script
├── service.sh           # Service script
└── uninstall.sh         # Cleanup script
```

### Essential Modules for Nothing Phone 2

| Module | Purpose | Status |
|--------|---------|--------|
| zygisknext | Zygisk base layer | ✅ Required |
| tricky_store | Play Integrity keybox spoofing | ✅ Required |
| playintegrityfork | Attestation bypass (v17) | ✅ Required |
| LSPosed (Zygisk) | Xposed framework | ✅ Required |
| mountify | Mount management | ❌ Disabled (conflicts) |
| zygisk_shamiko | Root hiding | ❌ Disabled (APatch conflict) |

---

## SuperKey Operations

| Operation | Command | Notes |
|-----------|---------|-------|
| Hide from apps | `su -c "apd hide <package>"` | Per-app root hiding |
| Show to apps | `su -c "apd unhide <package>"` | Reverse |
| Manage modules | `apd module <install|list|remove>` | Via CLI |
| SELinux rules | `apd selinux <enforce|permissive>` | Temporary only |

---

## App Profiles (APatch)

Per-app root access control:

```bash
# Grant root to specific app
su -c "apd profile set <package> root=allow"

# Deny root to specific app
su -c "apd profile set <package> root=deny"

# List profiles
su -c "apd profile list"
```

---

## Nothing Phone 2 Specific Notes

| Aspect | Details |
|--------|---------|
| **Boot partition** | `boot` (NOT `init_boot`) |
| **Slot** | A/B — flash to active slot |
| **Kernel** | GKI 2.0 (5.10.246) — APatch compatible |
| **Glyph** | Works with APatch |
| **Play Integrity** | BASIC achievable; needs tricky_store + playintegrityfork |
| **SELinux** | Enforcing maintained |
| **KMI** | Not required — kallsyms-based |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Bootloop after patch | Flash stock boot.img: `fastboot flash boot stock_boot.img` |
| Module not loading | Check `/data/adb/modules/` for `disable` file |
| SuperKey fails | Reboot, try again |
| SELinux permissive | `apd selinux enforce` (after testing) |
| APatch version mismatch | Flash stock boot, re-patch with correct version |

---

## Verification Commands

```bash
# APatch version
adb shell su -c 'cat /data/adb/apatch/version'

# KernelPatch status
adb shell su -c 'cat /data/adb/apatch/kp_version'

# Root access
adb shell su -c 'id'
# → uid=0(root)

# SELinux status
adb shell getenforce
# → Enforcing

# Module list
adb shell su -c 'ls /data/adb/modules/'
```

---

## Tags
`#[apatch-11219]` `#[kernelpatch-0.13.3]` `#[nothing-phone-2]` `#[pong]` `#[gki-2.0]` `#[kallsyms]` `#[superkey]` `#[android-16]` `#[evolutionx-11.11]` `#[root]`