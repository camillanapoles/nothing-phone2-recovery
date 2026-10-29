# Module: LSPosed (Zygisk variant v1.9.2)

> Xposed framework for runtime modifications via Zygote injection. **Zygisk variant required** for APatch/KernelSU/Modern Magisk setups.

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | v1.9.2 (build 7024) |
| **Variant** | Zygisk (not Riru) |
| **Android Support** | Android 8.0–16 |
| **Prerequisite** | ZygiskNext must be loaded |
| **Source** | https://github.com/LSPosed/LSPosed |

---

## ⚠️ Critical: Choose the RIGHT Variant

| Variant | Looks for | APatch / KernelSU? | Nothing Phone 2? |
|---------|-----------|---------------------|------------------|
| **Riru** | `magisk` binary | ❌ Fails | ❌ No |
| **Zygisk** | Zygote socket | ✅ Works | ✅ **USE THIS** |

**Download URL (Zygisk):**
```
LSPosed-v1.9.2-7024-zygisk-release.zip
```

---

## Installation

```bash
# 1. Ensure ZygiskNext is installed AND loaded (reboot first)
adb shell su -c 'getprop sys.zygisk.next'
# → true

# 2. Install LSPosed Zygisk variant
adb shell su -c "apd module install /data/local/tmp/LSPosed-v1.9.2-7024-zygisk-release.zip"

# 3. Reboot
adb reboot

# 4. Verify
adb shell su -c 'ls /data/adb/lsposed/'
# → Should contain conf.d, modules, etc.
```

---

## Verification

```bash
# Check if LSPatched process is running
adb shell ps -ef | grep lsposed

# Check Zygisk log
adb shell su -c 'tail /data/adb/zygiskzygote.log'

# App should open — no "Zygote not found" errors

# List installed modules
adb shell su -c 'ls /data/adb/lsposed/modules/'
```

---

## Nothing Phone 2 Notes

| Aspect | Details |
|--------|---------|
| **Riru variant** | Searches for Magisk → FAILS silently on APatch |
| **Zygisk variant** | Requires ZygiskNext to be pre-loaded |
| **App Profiles** | Works in Enforcing SELinux |
| **Glyph service** | LSPosed hooks can interfere — test before deploying hooks |

---

## Popular LSPosed Modules

| Module | Purpose | Download |
|--------|---------|----------|
| **GravityBox** | System UI customization, gestures | GitHub |
| **EdgeX** | Gesture injection (Nothing Phone specific?) | XDA |
| **App Settings** | Per-app configs | GitHub |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Zygote not found" | Using Riru variant — switch to Zygisk |
| LSPosed app crashes on open | Reboot, ensure ZygiskNext is loaded |
| Module not applying | Check module scope, restart target app |
| System instability | Disable modules one by one to find culprit |

---

## Tags
`#[lsposed]` `#[xposed]` `#[zygisk]` `#[/riru]` `#[nothing-phone-2]` `#[pong]` `#[evolutionx]` `