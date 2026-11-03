# Module: ZygiskNext (Zygisk Implementation)

> Standalone Zygisk implementation for Magisk, KernelSU, and APatch. Required for LSPosed and many root-hiding modules.

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | 1.4.5 (build 836) |
| **Android Support** | Android 8.0–16 |
| **Compat** | Magisk v24+, KernelSU Next, APatch |
| **Source** | https://github.com/LSPosed/ZygiskNext |

---

## Installation

```bash
# 1. Download ZygiskNext module zip
# 2. Install via APatch CLI:
adb shell su -c "apd module install /data/local/tmp/ZygiskNext.zip"

# OR via KernelSU:
adb shell su -c "ksud install /data/local/tmp/ZygiskNext.zip"

# 3. Reboot
adb reboot
```

---

## Verification

```bash
# Check Zygisk status
adb shell su -c 'getprop sys.zygisk.next'
# → true

# Check module loaded
adb shell su -c 'ls /data/adb/zygisk_next/'
# → config, denylist, etc.

# Check log
adb shell su -c 'tail /data/adb/zygisk_next/log'
```

---

## Configuration

### App Config (per-app)
```bash
# Deny Zygisk for specific app
su -c "zn_config.py set --app com.bank.app --deny"

# Allow for specific app
su -c "zn_config.py set --app com.game.app --allow"

# List configs
su -c "zn_config.py list"
```

### Global Config
```bash
# /data/adb/zygisk_next/config
FORCE_STDOUT=1
UNRESTRICTED=0
OPTIMIZE=1
UNAME_HACK=0
REPLACE_SHELL=0
```

---

## Nothing Phone 2 Notes

| Aspect | Details |
|--------|---------|
| **Requires** | Working root (APatch/Magisk/KSU) |
| **With LSPosed** | Essential — LSPosed Zygisk variant depends on ZygiskNext |
| **With APatch** | Compatible — ZygiskNext works independently of Magisk |
| **SELinux** | Functions in Enforcing mode |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Zygisk not loading | Reboot, check module installed correctly |
| LSPosed fails to start | Ensure ZygiskNext loaded before LSPosed |
| App detects Zygisk | Add to ZygiskNext denylist |
| Random crashes | Disable UNAME_HACK, check OPTIMIZE flag |

---

## Tags
`#[zygisknext]` `#[zygisk]` `#[modules]` `#[apatch]` `#[magisk]` `#[kernelsu]` `#[lsposed]`