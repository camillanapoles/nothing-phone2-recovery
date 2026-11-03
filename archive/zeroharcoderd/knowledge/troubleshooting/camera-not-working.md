# Troubleshooting: Camera Not Working After Root

> Covers hardware camera failures post-root on Nothing Phone 2 (Pong).

---

## Overview

After rooting (especially APatch + custom modules), the **camera app may fail** — typically a black screen, crash on launch, or "Camera service not available."

---

## Common Causes

| Cause | Description | Diagnostic |
|-------|-------------|------------|
| **Camera HAL blocked** | SELinux/App profile denies camera to untrusted apps | Check logcat for `Permission Denial` |
| **Vendor overlay broken** | APatch module replaced/modified `/vendor` files | Compare `/vendor/lib64/hw/camera.vendor.so` |
| **LSPosed hook conflict** | Camera app crashes after LSPosed module install | Disable LSPosed modules → test camera |
| **Kernel driver issue** | Droidspaces kernel lacks camera hooks | `dmesg \| grep camera` shows init errors |
| **GMS CameraX conflict** | Google Services conflict with camera HAL | Clear GMS data → test |

---

## Step-by-Step Diagnosis

### Step 1: Check Camera Service

```bash
# Is the camera service running?
adb shell ps -ef | grep camera
# → Should show: cameraproxy, cameraserver

# Check camera HAL status
adb shell lshal | grep camera
# → camera.provider@n.n-vn::ICameraProvider

# Test direct camera access
adb shell "am start -a android.media.action.IMAGE_CAPTURE"
# → Launches default camera app
```

### Step 2: Inspect SELinux Enforcement

```bash
# Must be Enforcing — Permissive breaks HAL policies
adb shell getenforce
# → Enforcing

# If Permissive (common during APatch debugging):
adb shell su -c 'setenforce 1'

# Check for AVC denials:
adb logcat -b events | grep avc
# → Look for "avc: denied" related to camera
```

### Step 3: Inspect Root Module Interference

```bash
# List active APatch modules:
adb shell su -c 'ls /data/adb/modules/'
# → Disable in order:
# 1. mountify (DISABLED already)
# 2. lsposed (temporarily disable)
# 3. shamiko (should be disabled on APatch)
# 4. tricky_store, playintegrityfork (safe, keep)

# Test camera after each disable:
touch /data/adb/modules/lsposed/disable
reboot
```

### Step 4: Check Camera HAL Libraries

```bash
# List camera HAL files:
adb shell ls -la /vendor/lib64/hw/camera*
# → camera.vendor.so, camera.qcom.so

# Check file integrity (hash compare):
adb shell "md5sum /vendor/lib64/hw/camera.vendor.so"
# → Compare with STOCK Nothing Phone 2 (should match)
```

### Step 5: Droidspaces Kernel Camera Hooks

```bash
# If using custom Droidspaces kernel:
# Check camera driver init messages:
adb shell dmesg | grep -i "qc_ci\|camera_module"
# → Should show successful camera driver probe

# Check camera device node:
adb shell ls -la /dev/media*
# → /dev/media0, /dev/video0 should exist

# Check vendor camera service:
adb shell getprop ro.hardware.chip
# → Should return sm8475 or similar
```

---

## Fix Strategies

### Fix 1: Restore Stock Vendor Files

```bash
# If vendor overlay was modified by a module:
# 1. Disable all APatch modules (except core root):
rm -rf /data/adb/modules/[module_name]/

# 2. Flash stock boot (which includes stock vendor):
fastboot flash boot_b /path/to/stock_boot.img
fastboot flash dtbo /path/to/stock_dtbo.img
fastboot --set-active=b
fastboot reboot

# 3. Re-apply APatch only:
#    Open APatch → Install → Select stock boot → Patch
```

### Fix 2: LSPosed Module Conflict

```bash
# Disable LSPosed temporarily:
touch /data/adb/modules/lsposed/disable

# Test camera — if it works:
# The fix is to review LSPosed modules for camera hooks
# Common culprits: "App Settings," "GravityBox," "EdgeX"

# Better fix — use LSPosed scope:
# Launch LSPosed Manager → Modules →
# Set camera app to NOT load problematic modules
```

### Fix 3: Droidspaces Kernel Camera Patches

```bash
# If using custom Droidspaces kernel:
# 1. Check kernel config:
zcat /proc/config.gz | grep -i "CONFIG_VIDEO"
# → Should include CONFIG_VIDEO_V4L2, CONFIG_VIDEO_QCOM

# 2. Verify camera driver loaded:
dmesg | grep -i "camera\|qc_ci"
# → Should show: "qc_ci: probe ok" or similar success message

# 3. If driver missing — rebuild Droidspaces kernel with:
#    CONFIG_VIDEO_CAM_SENSOR=y
#    CONFIG_QCOM_CAM_PRESERVE_VFE=y
#    CONFIG_MSM_CAMERA=y
```

### Fix 4: SELinux Policy for Camera on APatch

```bash
# Create custom APatch module to grant camera permissions:

# /data/adb/modules/camera_fix/service.d/01-camera.sh
#!/system/bin/sh

# Ensure SELinux allows camera HAL
# This is a workaround — proper fix is in the kernel/device tree

# Re-enable camera service if killed
svc system_server restart  # ⚠️ DANGEROUS — use carefully
# Better: targeted restart only
pkill -f cameraserver

# Verify:
getprop sys.boot_completed  # → 1
```

---

## Nothing Phone 2 Camera Specifics

| Component | Path | Notes |
|-----------|------|-------|
| **Camera HAL** | `/vendor/lib64/hw/camera.qcom.so` | Qualcomm QC-CI HAL |
| **Camera service** | `cameraproxy` | Runs in isolated process |
| **Permissions** | `/system/etc/permissions/` | Camera requires HAL permission |
| **Nothing Glyph** | Camera affects LED patterns | Verify Glyph works too |

### Camera Test Sequence

```bash
# 1. After any root change, validate camera:
adb shell "am start -a android.media.action.IMAGE_CAPTURE"
# → Should launch camera app successfully

# 2. Capture an image:
# → Camera should take photo, show preview, save thumbnail

# 3. Test video recording:
# → 1080p30 video should record without crash

# 4. Check Glyph:
# → Camera app should trigger Glyph interface patterns
```

---

## Verification Checklist

| Check | Command | Pass |
|-------|---------|------|
| Camera app launches | `am start -a android.media.action.IMAGE_CAPTURE` | ✅ No crash |
| Camera service running | `ps -ef \| grep camera` | ✅ cameraproxy running |
| HAL loaded | `lshal \| grep camera` | ✅ Hidl service present |
| SELinux | `getenforce` | ✅ Enforcing |
| No LSPosed hooks | `ls /data/adb/modules/lsposed/disable` | ✅ Exists (disabled) |
| No Shamiko | `ls /data/adb/modules/zygisk_shamiko` | ✅ Absent or disabled |
| dmesg clean | `dmesg \| grep -i error` | ✅ No camera errors |
| /vendor intact | `ls /vendor/lib64/hw/camera*` | ✅ Files present |

---

## Emergency: Restore Stock Camera

If camera is completely broken after root attempts:

```bash
# Nuclear option — restore entire stock boot partition:
fastboot flash boot_b ~/nothing-phone2/backups/snapshot-4-root-active/stock_boot.img

# Flash stock dtbo:
fastboot flash dtbo ~/nothing-phone2/ extracted/dtbo.img

# Relock vbmeta (if needed):
fastboot flash vbmeta ~/nothing-phone2/extracted/vbmeta.img

# Reboot to recovery:
fastboot reboot
# Then: recovery → "Reboot system now"
# Root will be lost — re-apply APatch after camera works
```

---

## Tag
#[camera] #[hal] #[selinux] #[lsposed] #[apatch] #[droidspaces] #[nothing-phone-2] #[pong] #[vendor]`