# Module: Morph Apps — Sandboxed Patched App Environment

> Secure sub-environment for running "morph" (patched) apps like modified banking APK, Netflix L3 bypass, and other altered apps that check for root/tamper.

---

## Overview

**Morph Apps** is a sub-environment that isolates patched (modified) applications from the regular system. It provides:

- A fake/tampered device identity for apps that check device integrity
- Isolated storage and runtime environment
- Selective root hiding per-app
- Rollback capability if an app misbehaves
- Bank liberado — banking apps see a "clean" device while root is active in the main environment

---

## Architecture

```text
┌─────────────────────────────────────────┐
│ Main System (APatch + Tricky Store)      │
│   ├── Real device identity (tampered)   │
│   └── Full root access                  │
└────────────┬───────────────────────────┘
             │
┌────────────▼───────────────────────────┐
│ Morph Environment (Isolated)            │
│   ├── Fake device identity              │
│   ├── No root access (hidden)           │
│   ├── Isolated app storage              │
│   ├── Network isolation (optional)      │
│   └── App-specific SELinux policies     │
│                                         │
│ Apps in this env:                       │
│   - com.bank.app.morph                  │
│   - com.netflix.morph                    │
│   - com.other.patched                   │
└─────────────────────────────────────────┘
```

---

## How It Works

### Device Identity Spoofing

Each Morph environment presents a **fake device identity** to apps:

| Property | Real Value | Morph (Fake) Value |
|----------|------------|-------------------|
| `ro.build.fingerprint` | evolutionx/pong/... | motorola/*****/... |
| `ro.product.brand` | Nothing | Google |
| `ro.product.model` | Nothing Phone 2 | Pixel 8 |
| `ro.build.flavor` | pong-userdebug | **Redbone** |
| `ro.boot.flash.locked` | 0 (unlocked) | 1 (locked) |
| `ro.boot.verifiedbootstate` | orange | green |
| `ro.boot.veritymode` | 1 (disabled) | 0 (enabled) |
| `ro.boot.flash.locked` | 0 | 1 |
| SELinux | Enforcing | Permissive (isolated) |
| `/system/bin/su` | present | hidden |

---

## Implementation Methods

### Method 1: LSPosed Module (Recommended — Non-root user-space)

```bash
# Use "MagiskTrustUserCertificates" + "App Spoof" via LSPosed:
# Module: "FakeDev" (LSPosed)
# Module: "MagiskTrustUserCertificates" (for network pinning)

# Setup:
# 1. Install FakeDev via LSPosed Manager
# 2. Enable for your morph banking app
# 3. Set fake fingerprint → "Pixel 8"
# 4. Set fake brand → "Google"
# 5. Hide su → Enable in FakeDev settings
```

### Method 2: APatch App Profiles (KernelSU-style isolation)

```bash
# APatch + KernelSU Next:
# 1. Create App Profile:
adb shell su -c 'apd profile create com.bank.app.morph'

# 2. Set profile rules:
adb shell su -c 'apd profile set com.bank.app.morph su=deny'
adb shell su -c 'apd profile set com.bank.app.morph selinux=permissive'

# 3. Spoof device props in profile:
# Edit /data/adb/ksu/app_profiles/com.bank.app.morph.xml
# Set:
#   <item name="ro.build.fingerprint" value="google/sailfish/sailfish:14/..."/>
#   <item name="ro.product.model" value="Pixel 8"/>
```

### Method 3: Magisk + ZygiskNext + Custom Config (Advanced)

```bash
# Use ZygiskNext + custom Zygisk modules:
# 1. Install Zygote Detection Blocker:
#    https://github.com/5im0n/Zygisk-Examples/tree/main/zygisk-detection-blocker

# 2. Set per-app config:
su -c "zn_config.py set --app com.bank.app.morph --deny"
su -c "zn_config.py set --app com.bank.app.morph --spoof-fingerprint 'Pixel 8'"
su -c "zn_config.py set --app com.bank.app.morph --spoof-brand 'Google'"
```

---

## Banking App Morph Setup (Example)

### 1. Download Morph APK

```bash
# Banking app patched APK (example):
# - com.nubank.android.morph-v1.0-arm64-v8a-release.apk
# - Contains patched safety-net and root checks removed
# - Signed with test key (or resigned with your key)

adb install com.nubank.android.morph-v1.0.apk
```

### 2. Enable Morph Environment

```bash
# Using LSPosed "FakeDev" module (if available) or ZygiskNext:
# 1. LSPosed → FakeDev → Enable for com.nubank.android.morph
# 2. Set:
#    - Fake Model: "Pixel 8"
#    - Fake Brand: "Google"  
#    - Fake Fingerprint: "google/shoreline/shoreline:14/UP1A.231005.007/..."
#    - Magisk Hide: ON
#    - SELinux: Permissive (in isolated mode)
#    - su: HIDE (do not expose)

# If FakeDev not available:
# Use "App Spoof" + "Device Info" LSPosed modules
```

### 3. Configure APatch DenyList

```bash
# Add morph app to APatch denylist:
adb shell su -c 'apd hide com.nubank.android.morph'
# Now APatch won't interfere with this app

# Verify:
adb shell su -c 'ls /data/adb/hidden/com.nubank.android.morph'
# → Exists
```

### 4. Configure Tricky Store (if needed)

```bash
# Some banking apps check Play Integrity in the morph env too
# Ensure Tricky Store is active:
adb shell su -c 'getprop ro.tricky.store.fake'
# → true

# But the morph app needs the REAL trickystore hidden:
# FakeDev should report a real keybox to the app
# This is the trickiest part — see below
```

---

## Morph Environment Rollback (Emergency)

If a morph app causes issues:

```bash
# 1. Uninstall the morph app:
adb uninstall com.nubank.android.morph

# 2. If it's a system app (cannot uninstall):
# Disable it instead:
adb shell pm disable-user com.nubank.android.morph

# 3. Clean data:
adb shell pm clear com.nubank.android.morph

# 4. Clear any LSPosed hooks for the app:
# LSPosed → FakeDev → Remove app from scope

# 5. Re-enable for real app (non-morph):
# Reinstall clean banking app
# Do NOT add to any morph/spoof profiles
```

---

## Bank App Detection Bypass (Morph Mode)

### Common Detection Vectors

| Detection Method | What the app checks | Morph Counter |
|------------------|---------------------|---------------|
| `which su` | Looks for su binary | Hide via FakeDev/LSPosed |
| `/system/app/*` | Checks for Magisk APK | Use Magisk Hide or `su` → hide package |
| SELinux status | `getenforce` → "Permissive" | Spoof to "Enforcing" |
| `build.prop` props | `ro.debuggable`, `ro.secure` | Override via LSPosed/FakeDev |
| SafetyNet | JCA + CTS profile | Use PlayIntegrityFork + Tricky Store |
| Hardware key attestation | `KeyGenParameter` + StrongBox | Requires real keybox (Tricky Store) |
| `getprop ro.boot.flash.locked` | Returns 0 (unlocked) | Spoof to 1 (locked) |

### Morph Props Override

For each morph app, set these props (via LSPosed module or APatch App Profile):

```properties
ro.debuggable=0
ro.secure=1
ro.build.type=user
ro.build.flavor=*****-user
ro.build.fingerprint=google/shoreline/shoreline:14/UP1A.231005.007/11111111:user/release-keys
ro.boot.flash.locked=1
ro.boot.verifiedbootstate=green
ro.boot.veritymode=enforcing
ro.boot.flash.lock_unlock_verity=1
ro.boot.warranty_bit=0  # Some apps check this; can also set to 1 (clean)
```

> 🔍 **Note:** Some banking apps check `ro.boot.flash.locked=1` AND that it matches `ro.boot.flash.locked` in `/proc/cmdline` or `bootconfig` — a simple prop override may not be enough. Advanced LSPosed modules hook `getprop` at the syscall level.

---

## Network Isolation (Optional)

For maximum security during morph app usage:

```bash
# Use NetGuard or AfWall+ (Android Firewall) to limit network access
# For banking morph apps:
# Allow: Bank domain + CDN domains
# Deny: All other connectivity (analytics, ads, tracking)

# Via ADB:
adb shell su -c 'iptables -A OUTPUT -p tcp -d "*.bank.com" -j ACCEPT'
adb shell su -c 'iptables -A OUTPUT -j DROP'
```

---

## Tag
`#[morph-apps]` #[banking] #[bank-liberado] #[root-hiding] #[lsposed] #[/apatch] #[app-isolation]` `#[/play-integrity]` `#[safety-net]` #[device-spoof]`