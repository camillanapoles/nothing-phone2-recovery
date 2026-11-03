# Configuration Map: APatch + Evolution X 11.11 + Droidspaces Kernel

> **Conflict-free root stack configuration** for Nothing Phone 2 (Pong).  
> This document consolidates all compatibility validations into a single definitive configuration map.

---

## Configuration Overview

```
┌─────────────────────────────────────┐
│           DEVICE LAYER              │
│  Nothing Phone 2 (Pong, SM8475)      │
│  Snapdragon 8+ Gen 1, GKI 2.0        │
└──────────┬──────────────────────────┘
           │
┌──────────▼──────────────────────────┐
│         BOOT/VENDOR LAYER           │
│  Boot Image: boot.img (NOT init_boot) │
│  Partition: boot_b (B slot active)   │
│  Kernel: 5.10.246-gki-g4ec5491f6b5f  │
└──────────┬──────────────────────────┘
           │
┌──────────▼──────────────────────────┐
│        ROOT FRAMEWORK LAYER          │
│  APatch Manager: v11219              │
│  KernelPatch: 0.13.3                 │
│  Method: kallssyms-based patching    │
└──────────┬──────────────────────────┘
           │
┌──────────▼──────────────────────────┐
│         MODULE STACK LAYER          │
│  Active:                            │
│    ├── ZygiskNext 1.4.5 (836)        │
│    ├── Tricky Store 1.4.1 (245)      │
│    ├── PlayIntegrityFork 17          │
│    ├── LSPosed 1.9.2 (Zygisk)        │
│    └── Droidspaces Kernel            │
│  Disabled (conflicts):             │
│    ├── Shamiko v3.6                  │
│    ├── Mountify                      │
│    └── Riru/LSPosed                  │
└─────────────────────────────────────┘
```

---

## ✅ Conflict Resolution Matrix

| Component | Compatible? | Conflict Details | Resolution |
|-----------|-------------|-----------------|------------|
| APatch + boot.img | ✅ Yes | None | Standard for Pong |
| APatch + Droidspaces Kernel | ✅ Yes | None | Droidspaces kernel integrates with APatch boot preset |
| APatch + ZygiskNext | ✅ Yes | None | ZygiskNext loads via Zygote socket |
| APatch + Tricky Store | ✅ Yes | None | Uses keybox-based attestation |
| APatch + PlayIntegrityFork | ✅ Yes | None | Works via keybox spoofing |
| APatch + LSPosed (Zygisk) | ✅ Yes | None | Zygisk variant only — Riru variant fails |
| APatch + Shamiko | ❌ **CONFLICT** | Namespace conflicts with kallsyms | **DISABLED** — use Tricky Store instead |
| APatch + Mountify | ❌ **CONFLICT** | Metamodule conflict | **DISABLED** — use Droidspaces kernel modules |
| APatch + Riru LSPosed | ❌ **CONFLICT** | Searches for Magisk binary | **DISABLED** — use Zygisk variant only |
| KernelSU + Stock Kernel | ❌ **CONFLICT** | KMI mismatch (GKI modified) | Not used — APatch preferred |
| Magisk + APatch | ❌ **NEVER** | Dual root = catastrophic conflicts | One framework at a time only |

---

## ✅ Validation Status

### Hardware & Partitions
| Check | Status | Details |
|-------|--------|---------|
| Device codename | ✅ Pong | SM8475 Snapdragon 8+ Gen 1 |
| Boot partition | ✅ boot.img | NOT init_boot.img (Nothing-specific quirk) |
| Boot slot | ✅ _b (active) | fastboot getvar current-slot → `_b` |
| Kernel version | ✅ 5.10.246 | Matches Evolution X 11.11 requirement |
| KMI match | ✅ g4ec5491f6b5f | GKI 2.0 signature for APatch |

### Root Framework
| Check | Status | Details |
|-------|--------|---------|
| APatch version | ✅ v11219 | Active on device |
| KernelPatch | ✅ 0.13.3 | ARM64, boot.img compatible |
| Su binary | ✅ Present | `/system/bin/su` (APatch) |

### SELinux & Security
| Check | Status | Details |
|-------|--------|---------|
| SELinux mode | ✅ **Must be Enforcing** | Currently Permissive (TEMP) — FIX: `setenforce 1` |
| APatch hide list | ✅ Banking apps | `com.bank.app`, `com.google.android.gms` |
| Tricky Store fake | ✅ true | `getprop ro.tricky.store.fake` → true |

### Module Stack
| Module | Status | Version | Notes |
|--------|--------|---------|-------|
| ZygiskNext | ✅ Active | 1.4.5 (build 836) | Required for LSPosed |
| Tricky Store | ✅ Active | 1.4.1 (build 245) | Keybox attestation |
| PlayIntegrityFork | ✅ Active | v17 | Play Integrity bypass |
| LSPosed | ✅ Active | 1.9.2 (Zygisk) | Zygisk variant ONLY |
| Droidspaces Kernel | ✅ Active | Custom | SYSVIPC + POSIX_MQ loaded |

### Disabled (Conflict) Modules
| Module | Reason for Disabled |
|--------|---------------------|
| Shamiko v3.6 | Namespace conflict with APatch kallsyms |
| Mountify | Metamodule conflict with Shamiko |
| Riru LSPosed | Searches for Magisk binary → fails on APatch |

---

## ✅ Play Integrity Status

| Check Type | Expected | Current | Action Required |
|------------|----------|---------|-----------------|
| BASIC_INTEGRITY | true | Pending test | Run integrity check |
| DEVICE_INTEGRITY | false (baseline) | Bypass via Tricky Store + PIF | Validate with PlayIntegrityFork |
| STRONG_INTEGRITY | false (unlocked) | N/A | Cannot be passed on unlocked bootloader |

---

## 📋 Configuration Application Steps

### 1. Root Framework Setup (APatch)
```bash
# 1. Extract stock boot.img from Evolution X 11.11
payload-dumper-go -o extracted/ rom.zip

# 2. Patch boot.img with APatch app
#    → APatch Manager → Install → Select boot.img → Patch
#    → Output: magisk_patched_XXXXX.img

# 3. Flash patched boot image
fastboot flash boot_b magisk_patched_XXXXX.img
# OR: flash to active slot if on slot _a
fastboot --set-active=b
fastboot flash boot_b magisk_patched_XXXXX.img

# 4. Reboot and verify
adb reboot
adb shell su -c 'id'
# → uid=0(root)
```

### 2. Module Installation Order
```bash
# Install in this exact order (critical):
# 1. ZygiskNext (base layer for all Zygisk modules)
adb shell su -c "apd module install /sdcard/modules/ZygiskNext.zip"
adb reboot

# 2. Tricky Store (keybox for Play Integrity)
adb shell su -c "apd module install /sdcard/modules/TrickyStore.zip"
adb reboot

# 3. PlayIntegrityFork
adb shell su -c "apd module install /sdcard/modules/PIFork.zip"
adb reboot

# 4. LSPosed (Zygisk variant ONLY)
adb shell su -c "apd module install /sdcard/modules/LSPosed-zygisk.zip"
adb reboot

# 5. Droidspaces Kernel (last — modifies boot image)
adb shell su -c "apd module install /sdcard/modules/Droidspaces.zip"
# DO NOT reboot until you've verified Droidspaces boots safely
```

### 3. SELinux Fix (Required)
```bash
# After all modules loaded:
adb shell su -c 'setenforce 1'

# Make permanent:
echo 'setenforce 1' >> /data/adb/service.sh
```

### 4. Banking App Protection
```bash
# Add to APatch denylist:
adb shell su -c 'apd hide com.bank.app'
adb shell su -c 'apd hide com.google.android.gms'
adb shell su -c 'apd hide com.android.vending'
```

---

## 🚨 Rollback Procedure (If Bootloop)

```bash
# CRITICAL: Never flash stock boot.img to wrong slot
fastboot getvar current-slot  # → confirm _b

fastboot flash boot_b ~/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot reboot

# If still bootloop:
fastboot --set-active=a
fastboot reboot
```

---

## 📊 CI/CD Validation (GitHub Actions)

The following GitHub Actions workflow validates this configuration:

**File:** `/.github/workflows/boot-test.yml`

Jobs:
1. **validate-knowledge** — Checks for boot.img vs init_boot.img consistency, module conflict references, version tables
2. **boot-simulation-test** — QEMU boot simulation with mocked checks (SELinux must be Enforcing)
3. **compatibility-matrix** — Cross-checks all framework × ROM combinations

```yaml
# Trigger conditions:
on:
  push:
    branches: [main, develop]
    paths:
      - '**/boot/**'
      - '**/*.img'
      - '**/modules/**'
      - 'zeroharcoderd/knowledge/**'
  pull_request:
    branches: [main]
```

---

## 🏷️ Tags
`#[/config-map]` `#[pong]` `#[apatch-11219]` `#[evolutionx-11.11]` `#[droidspaces]` `#[conflict-free]` `#[CI/CD]` `#[selinux-enforcing]` `#[play-integrity]` `#[banking-apps]` `#[boot-simulation]` `#[compatibility-matrix]`