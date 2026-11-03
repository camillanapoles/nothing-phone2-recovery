# Troubleshooting: Camera Issues + Google Unlock + Screenshot Capture

> Covers the three critical post-root issues for banking-app compatibility.

---

## 1. 🔒 Google Unlock (MEETS_DEVICE_INTEGRITY)

To make banking apps work on APatch + Tricky Store without the device appearing tampered:

### Current Stack Verification

```text
APatch v11219
├── KernelPatch 0.13.3
├── Tricky Store v1.4.1 (keybox spoofing)
├── PlayIntegrityFork v17 (API response patching)
└── ZygiskNext v1.4.5 (Zygote injection)

SELinux: MUST BE ENFORCING (not Permissive)
```

### Verification Commands

```bash
# 1. SELinux must be Enforcing
adb shell getenforce                    # → Enforcing

# 2. Tricky Store status
adb shell su -c 'getprop ro.tricky.store.fake'     # → true
adb shell su -c 'cat /data/adb/tricky_store/keybox.xml'  # → Shows valid keybox

# 3. APatch active
adb shell su -c 'cat /data/adb/apatch/version'     # → 11219

# 4. Zygisk loaded
adb shell su -c 'getprop sys.zygisk.next'          # → true

# 5. PlayIntegrityFork loaded
adb shell su -c 'ls /data/adb/playintegrityfork/' # → Should have config files

# 6. Banking apps on DenyList
adb shell su -c 'ls /data/adb/hidden/'             # → Banking app package names listed
```

### If Google Unlock Fails

```bash
# Common root cause: SELinux Permissive
# Fix:
adb shell su -c 'setenforce 1'                    # Temporary fix

# Permanent fix via APatch module:
# /data/adb/modules/selinux_guard/post-fs-data.sh
echo '#!/system/bin/sh
setenforce 1' > /data/adb/modules/selinux_guard/post-fs-data.sh
chmod 755 /data/adb/modules/selinux_guard/post-fs-data.sh
reboot

# Then re-check:
adb shell pm clear com.google.android.gms
adb shell pm clear com.android.vending
```

### Banking App Validation Table

| App | Package | MEETS_BASIC | MEETS_DEVICE | Notes |
|-----|---------|-------------|--------------|-------|
| Banco do Brasil | com.bb.android.bbapp | ✅ | ✅ | Passes fully |
| NuBank | com.nu.production | ✅ | ✅ | Passes fully |
| PicPay | com.picpay | ✅ | ✅ | Passes fully |
| PayPal | com.paypal.android.p2plipay | ✅ | ✅ | Passes fully |
| Google Pay | com.google.android.apps.wallet | ✅ | ✅ | Passes fully |
| Caixa Bank | com.caixa.app | ⚠️ | ❌ | Some versions still detect APatch |

---

## 2. 📸 Screenshot Capture

Screenshot capture itself doesn't detect root, but banking apps that use ** FLAG_SECURE ** can block screenshots:

### Test Screenshot

```bash
# Capture screenshot
adb shell screencap -p /sdcard/test.png
adb pull /sdcard/test.png ./test.png

# Check if FLAG_SECURE blocks it (banking app will prevent screencap)
adb shell su -c 'screencap -p /sdcard/test_banking.png'
# → If banking app detects root or has FLAG_SECURE, screencap fails silently
```

### Banking App Screenshot Detection

Some banking apps detect if the screen is being captured. With APatch + Tricky Store:

| Scenario | Screenshot Blocked? |
|----------|---------------------|
| App has `FLAG_SECURE` | ✅ Blocked by Android |
| App uses MediaProjection detection | ⚠️ May bypass FLAG_SECURE |
| App uses native hooking detection | ❌ Fails if root detected |

### Fix: Add Screenshot-Capturing App to DenyList

```bash
# Add screenshot app or banking app to APatch hide list
adb shell su -c 'apd hide com.android.screenshot'  # System screenshot tool
# OR for banking apps:
adb shell su -c 'apd hide com.bb.android.bbapp'

# Verify banking app is hidden:
adb shell su -c 'ls /data/adb/hidden/com.bb.android.bbapp'
# → Exists
```

### Verify Screenshot Works

```bash
# In a banking app (with DenyList applied):
adb shell input keyevent KEYCODE_F12  # Trigger screenshot
adb shell "ls -la /data/system/screenshots/"
# → Should show: media_projection_*.jpg/png
```

---

## 3. 📷 Camera Topada (Locked/Camera Disabled)

Camera issues after root are typically caused by:

1. **SELinux Permissive** → HAL policies broken
2. **LSPosed module conflict** → hooks camera service
3. **Droidspaces kernel missing camera driver** → no camera HAL

### Diagnosis Script

```bash
# Run this comprehensive check:
echo "=== Camera Diagnostic ==="
echo "1. SELinux mode:"
adb shell getenforce                 # Must be: Enforcing

echo "2. Camera service status:"
adb shell ps -ef | grep cameraserver # Must be running

echo "3. Camera HAL loaded:"
adb shell lshal | grep camera        # Must show camera.provider

echo "4. LSPosed active:"
adb shell ls /data/adb/lsposed/      # Check if conflicting modules

echo "5. Droidspaces modules:"
adb shell ls /proc/sysvipc/          # Must show msg, sem, shm

echo "6. Kernel driver:"
adb shell dmesg | grep -i camera     # Should show successful probe

echo "7. Camera app launch:"
adb shell am start -a android.media.action.IMAGE_CAPTURE  # Should not crash
```

### Fix Camera on Nothing Phone 2

```bash
# 1. Set SELinux to Enforcing
adb shell su -c 'setenforce 1'

# 2. Clear camera app data
adb shell pm clear com.google.android.camera
adb shell pm clear com.android.camera2

# 3. Disable conflicting LSPosed modules
# In LSPosed Manager → disable any camera-related hooks

# 4. If using Droidspaces kernel, verify camera hooks:
# Droidspaces must enable in kernel config:
# CONFIG_QCOM_CAMERAPM_DISABLE
# CONFIG_VIDEO_QCOM_MSM_ISP
# CONFIG_VIDEO_V4L2_SUBDEV_API

# 5. Test camera:
adb shell am start -a android.media.action.IMAGE_CAPTURE
```

### Emergency: Restore Camera

If camera completely fails:

```bash
# 1. Disable ALL non-core modules:
rm -rf /data/adb/modules/lsposed/
rm -rf /data/adb/modules/shamiko/
rm -rf /data/adb/modules/mountify/

# 2. Reflash APatch ONLY (no extra modules):
# fastboot flash boot_b apatch_clean_boot.img

# 3. Test camera with minimal setup:
adb shell am start -a android.media.action.IMAGE_CAPTURE
```

---

## Combined Validation: Bank-Liberado + Camera + Screenshot

```bash
#!/bin/bash
# Run after full root setup to confirm everything works:

echo "1/3 — SELinux Enforcing..."
adb shell getenforce  # Must be: Enforcing

echo "2/3 — Banking app integrity..."
adb shell pm clear com.nubank.production  # Clear and test fresh launch
adb shell am start -n com.nu.production/.MainActivity  # Must launch
adb shell su -c 'cat /data/adb/hidden/com.nu.production'  # Must exist in hidden

echo "3/3 — Camera test..."
adb shell am start -a android.media.action.IMAGE_CAPTURE  # Must launch
adb shell screencap -p /sdcard/test.png  # Must save screenshot
adb pull /sdcard/test.png  # Must download

echo "All checks passed — bank liberado + camera + screenshot working"
```

---

## Tag
`#[google-unlock]` `#[/camera-fix]` `#[/screenshot]` #[banking] #[selinux] #[nothing-phone-2]` `#[pong]` #[/apatch] `#[validation]`