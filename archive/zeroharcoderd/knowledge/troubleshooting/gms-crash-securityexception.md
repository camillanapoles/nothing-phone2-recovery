# Troubleshooting: GMS Crash — SecurityException getRoleHoldersAsUser

> From STATE.md D-1/D-2. Critical for APatch root on Nothing Phone 2.

---

## Error

```log
java.lang.SecurityException: getRoleHoldersAsUser
```

- **Process:** `com.google.android.gms.ui`
- **Cause:** Missing `MANAGE_ROLE_HOLDERS` or `GET_ROLE_HOLDERS` permission
- **Trigger:** SELinux `Permissive` mode alters process security context

---

## Root Cause Analysis

| Suspect | Verdict | Fix |
|---------|---------|-----|
| **APatch/Zygisk modules removing system permissions** | ⚠️ Possible | Review module configs |
| **GMS version incompatible with Android 16** | ⚠️ Possible | Update GMS to latest |
| **SELinux Permissive (currently active)** | ✅ **Confirmed** | Set back to `Enforcing` |

---

## Step-by-Step Fix

### Step 1: Check SELinux Mode

```bash
adb shell getenforce
# Current: Permissive (TEMPORARY — from audit)
# Required: Enforcing
```

### Step 2: Return to Enforcing

```bash
# Temporary (reverts on reboot):
adb shell su -c 'setenforce 1'

# Permanent (via APatch module):
# Create a custom SELinux rule module:
# /data/adb/modules/selinux_enforce/service.d/05-selinux.sh
echo '#!/system/bin/sh
setenforce 1' > /data/adb/modules/custom_selinux/post-fs-data.sh
chmod 755 /data/adb/modules/custom_selinux/post-fs-data.sh
```

### Step 3: Re-enable GMS Feedback

```bash
# From STATE.md D-6:
adb shell pm enable com.google.android.feedback
```

### Step 4: Clear GMS Data

```bash
adb shell pm clear com.google.android.gms
adb shell pm clear com.android.vending
adb shell pm clear com.google.android.gms.ui
```

### Step 5: Reboot & Verify

```bash
adb reboot
# After boot:
adb shell getenforce   # → Enforcing
adb logcat -b crash | grep "SecurityException"  # → No new crashes
```

---

## Verification

| Check | Command | Pass condition |
|-------|---------|----------------|
| SELinux mode | `adb shell getenforce` | `Enforcing` |
| GMS feedback | `adb shell pm list packages -d \| grep feedback` | Package enabled |
| Crash logs | `adb logcat -b crash -t 200 \| grep gms` | No `FATAL` or `SecurityException` |
| RoleManager test | `adb shell su -c 'pm dump com.google.android.gms \| grep role'` | No permission errors |
| Storage check | `adb shell df -h /vendor` | >= 20 MB free |

---

## Emergency Rollback

If GMS still crashes after switching to Enforcing:

```bash
# 1. Temporarily go Permissive again (only for diagnosis):
adb shell su -c 'setenforce 0'

# 2. Disable suspicious modules:
touch /data/adb/modules/mountify/disable
touch /data/adb/modules/zygisk_shamiko/disable

# 3. Reboot into recovery → flash stock boot.img:
fastboot flash boot_b /home/cnmfs/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img
fastboot --set-active=b
fastboot reboot

# 4. Re-apply APatch patch:
#    Open APatch app → Install → Select stock boot.img → Patch → Flash
```

---

## Tag
`#[gms]` #[securityexception] #[selinux] #[nothing-phone-2] #[apatch] #[debug]`