# Module: Tricky Store (v1.4.1)

> Keybox-based Play Integrity spoofing. Injects fake hardware key attestation to pass `MEETS_DEVICE_INTEGRITY`.

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | 1.4.1 (build 245) |
| **Android Support** | Android 12–16 |
| **Compat** | APatch, KernelSU, Magisk (with ZygiskNext) |
| **Source** | https://github.com/5im0n/TrickyStore |

---

## Installation

```bash
# 1. Download TrickyStore module zip
# 2. Install:
adb shell su -c "apd module install /data/local/tmp/TrickyStore.zip"

# 3. Reboot
adb reboot
```

---

## Keybox Management

### Provision a Keybox

```bash
# TrickyStore includes a test keybox by default
# For production apps, use a real Google-issued keybox

# Check status:
adb shell su -c 'getprop ro.tricky.store.status'

# Keybox location:
ls /data/vendor_de/0/misc/keystore/
# → primary_cryptoverse.xml (or similar)

# Replace keybox (requires valid XML):
adb push keybox.xml /data/vendor_de/0/misc/keystore/primary_cryptoverse.xml
adb shell chown 10000:10000 /data/vendor_de/0/misc/keystore/primary_cryptoverse.xml
```

---

## Verification

```bash
# Open Play Store → Account → Play Integrity
# Or use an app like "Device Validation" or "Play Integrity Checker"

# MEETS_DEVICE_INTEGRITY should show ✅ PASS

# CLI checks:
adb shell su -c 'getprop ro.tricky.store.fake'
# → true

adb shell su -c 'dmesg | grep tricky'
# → Kernel log entries
```

---

## Nothing Phone 2 Notes

| Aspect | Details |
|--------|---------|
| **Keybox type** | Test keybox works for most apps |
| **Strong Integrity** | Still fails (unlocked bootloader) |
| **GMS crashes** | If GMS crashes after install, clear GMS data + reboot |
| **Banking apps** | Most pass with DEVICE_INTEGRITY (BBC, Nu, PicPay tested) |

---

## Known Issues & Solutions

| Issue | Solution |
|-------|----------|
| **GMS SecurityException** | Switch SELinux to Enforcing, clear GMS data |
| **Play Store says "Device not certified"** | Clear Play Store data, reboot, retry |
| **Banking app still detects root** | Add to DenyList, disable Shamiko (use TrickStore only) |

---

## Tags
`#[trickystore]` `#[keybox]` `#[/play-integrity]` `#[device-integrity]` `#[nothing-phone-2]` `#[pong]` `#[gms]` `#[banking]`