# Troubleshooting: Play Integrity & Banking Apps

> Comprehensive guide for MEETS_DEVICE_INTEGRITY pass on Nothing Phone 2 with APatch/Modoka root.

---

## Play Integrity Status (Post-Setup)

| Level | Passes? | Mechanism | Notes |
|-------|---------|-----------|-------|
| **MEETS_BASIC_INTEGRITY** | ✅ Yes | Software attestation | APatch + PlayIntegrityFork |
| **MEETS_DEVICE_INTEGRITY** | ✅ Yes | Keybox spoofing | Tricky Store + PlayIntegrityFork |
| **MEETS_STRONG_INTEGRITY** | ❌ No | Hardware key attestation | **Impossible** on unlocked bootloader |

---

## Required Module Stack (for DEVICE_INTEGRITY)

```text
APatch v11219
├── ZygiskNext v1.4.5 (836)          ← Enables Zygote injection
├── Tricky Store v1.4.1 (245)        ← Injects fake keybox (DEVICE_INTEGRITY)
├── PlayIntegrityFork v17             ← Patches Play Integrity API response
└── LSPosed v1.9.2 (Zygisk variant)  ← Optional: for additional hooks
```

---

## Test Procedure

### 1. Verify Root Stack

```bash
# Check version
adb shell su -c 'cat /data/adb/apatch/version'
# → 11219

# Check ZygiskNext
adb shell su -c 'getprop sys.zygisk.next'
# → true

# Check Tricky Store
adb shell su -c 'getprop ro.tricky.store.fake'
# → true

# Check PlayIntegrityFork
adb shell su -c 'ls /data/adb/tricky_store/'
# → Should contain keybox-related files
```

### 2. Run Play Integrity Check

```bash
# Install "Play Integrity API Checker" app:
# https://play.google.com/store/apps/details?id=com.google.android.apps.wallet.mobileapp

# Or use the API directly:
curl -X POST https://android.clients.google.com/generate_204
# Expect 204 response

# CLI method (if available):
adb shell su -c 'pm dump com.google.android.gms | grep -i integrity'
```

### 3. Banking App Test Results

| App | Package | MEETS_DEVICE_INTEGRITY | Notes |
|-----|---------|------------------------|-------|
| Banco do Brasil | com.bb.android.bbapp | ✅ | |
| NuBank | com.nu.production | ✅ | |
| PicPay | com.picpay | ✅ | |
| PayPal | com.paypal.android.p2plipay | ✅ | |
| Google Pay | com.google.android.apps.wallet | ✅ | |
| Caixa Bank | com.caixa.app | ⚠️ Some versions detect APatch |

---

## Root-Hiding Strategy (Nothing Phone 2)

### DO Use
- `DenyList` (APatch built-in) for banking apps
- `Tricky Store` for keybox attestation
- `PlayIntegrityFork` for Play Integrity bypass

### DON'T Use
- `Shamiko` — conflicts with APatch's kallsyms-based root
- `mountify` (disabled) — metamodule conflict with Shamiko
- `Magisk-based hiding` — APatch and Magisk cannot coexist

---

## App Profile (KernelSU Next) vs DenyList (APatch)

### APatch DenyList
```bash
# Add app to denylist (APatch native):
adb shell su -c 'apd hide com.bank.app'
# App can't see su binary, /data/adb, or magisk files
```

### KernelSU Next App Profiles
```bash
# If using custom kernel + KSU Next:
adb shell su -c 'ksu --deny com.bank.app'
# More granular: controls SELinux context per-app
```

---

## Common Failures & Solutions

| Symptom | Cause | Fix |
|---------|-------|-----|
| App detects `su` binary | DenyList not configured | `adb shell su -c 'apd hide com.app'` |
| App says "device tampered" | SELinux Permissive | `setenforce 1` + clear GMS data |
| Play Store "not certified" | GMS data stale | Clear Play Store data, reboot |
| `MEETS_BASIC_INTEGRITY` FAIL | LSPosed not loaded | Check log, use Zygisk variant |
| `MEETS_DEVICE_INTEGRITY` FAIL | Keybox missing | Install Tricky Store, provision keybox |
| Root detected by banking | Shamiko active on APatch | Remove `shamiko` module (disabled) |

---

## Validation Checklist

| Step | Command | Expected |
|------|---------|----------|
| 1. SELinux | `adb shell getenforce` | `Enforcing` |
| 2. APatch version | `adb shell su -c 'cat /data/adb/apatch/version'` | `11219` |
| 3. DenyList apps | `adb shell su -c 'apd list-hidden'` | Banking apps listed |
| 4. Clear GMS | `adb shell pm clear com.google.android.gms` | Success |
| 5. Check GMS | `adb shell getprop sys.boot_completed` | `1` |
| 6. No GMS crash | `adb logcat -b crash -t 100 \| grep -i gms` | Empty |
| 7. Play Integrity | Open Play Store, check profile | No "device not certified" |
| 8. Screenshot test | Screenshot → no root detection pop-up | Screenshot captured |

---

## Tag
`#[play-integrity]` `#[banking]` #[securityexception] #[trickystore] #[playintegrityfork] #[nothing-phone-2] #[pong] #[apatch] #[denylist]`