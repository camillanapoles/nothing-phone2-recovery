# Module: PlayIntegrityFork (v17)

> Play Integrity API bypass. Works with APatch, KernelSU, and Magisk with ZygiskNext.

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | v17 (latest) |
| **Android Support** | Android 9–16 |
| **Compat** | Magisk, KernelSU, APatch (with ZygiskNext) |
| **Source** | https://github.com/playintfork/playintegrityfork |

---

## Installation

```bash
# 1. Download via MMRL or GitHub releases
# 2. Install:
adb shell su -c "apd module install /data/local/tmp/PlayIntegrityFork.zip"

# 3. Reboot
adb reboot
```

---

## Verification

```bash
# Open the app → Check SafetyNet/Play Integrity
# Should pass:
# - MEETS_BASIC_INTEGRITY: ✅
# - MEETS_DEVICE_INTEGRITY: ✅ (with keybox)
# - MEETS_STRONG_INTEGRITY: ❌ (unlocked bootloader)

# CLI check
adb shell su -c 'getprop ro.boot.flash.locked'
# → 0 (unlocked — strong integrity will fail)
```

---

## Keybox Integration

For `MEETS_DEVICE_INTEGRITY`, pair with **Tricky Store** (v1.4.1):

```bash
# 1. Install Tricky Store module
adb shell su -c "apd module install /data/local/tmp/TrickyStore.zip"

# 2. Configure keybox:
#    - Use a valid keybox from Google (test or production)
#    - Place in /data/vendor_de/0/misc/keystore/

# 3. Clear Play Store data
adb shell pm clear com.android.vending
adb shell pm clear com.google.android.gms
```

---

## Nothing Phone 2 Notes

| Check | Status | Notes |
|-------|--------|-------|
| **BASIC_INTEGRITY** | ✅ Passable | APatch + PlayIntegrityFork |
| **DEVICE_INTEGRITY** | ✅ Passable | Needs Tricky Store + valid keybox |
| **STRONG_INTEGRITY** | ❌ Impossible | Unlocked bootloader permanently |
| **GMS Crash** | ⚠️ Known issue | May need SELinux fix or GMS reinstall |

---

## GMS Crash Fix (D-1/D-2 from STATE.md)

```bash
# If GMS crashes with SecurityException getRoleHoldersAsUser:
# 1. Check SELinux mode
adb shell getenforce  # Must be Enforcing

# 2. If Permissive, switch to Enforcing:
adb shell su -c 'setenforce 1'

# 3. Clear GMS data
adb shell pm clear com.google.android.gms

# 4. Reboot
```

---

## Tags
`#[playintegrityfork]` `#[play-integrity]` `#[gms]` `#[securityexception]` `#[tricky-store]` `#[nothing-phone-2]` `#[pong]`