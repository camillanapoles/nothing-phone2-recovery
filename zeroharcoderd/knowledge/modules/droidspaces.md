# Module: Droidspaces — Custom Kernel Build Framework

> Custom kernel build for Nothing Phone 2 with SYSVIPC + POSIX_MQUEUE patches.

---

## Overview

Droidspaces is a kernel build framework for Nothing Phone 2 (Pong/SM8475) that adds custom modules on top of LineageOS lineage-23.2 kernel (5.10.246-gki).

---

## Kernel Source

```bash
# Clone the LineageOS kernel (recommended base)
git clone -b lineage-23.2 --depth 1 \
  https://github.com/LineageOS/android_kernel_nothing_sm8475 \
  kernel/

# Or fork of arter97 pong kernel (community maintained):
git clone https://github.com/arter97/android_kernel_nothing_sm8475
```

### Kernel Source for Droidspaces

**Primary**: `nothing_phone2_kernel_droidspaces` on GitHub
- Repository: private (request access from maintainer)
- Mirror: `https://git.coderexclusive.com/droidspaces/kernel_nothing_sm8475` (if available)
- Branch: `droidspaces-android14-5.10`

```bash
# Clone (requires access):
git clone -b droidspaces-android14-5.10 \
  https://github.com/droidspaces/kernel_nothing_sm8475 \
  kernel/
```

### Building from LineageOS base + Droidspaces patches:

```bash
# 1. Clone LineageOS kernel base:
git clone -b lineage-23.2 --depth 1 \
  https://github.com/LineageOS/android_kernel_nothing_sm8475 \
  kernel/

cd kernel/

# 2. Download Droidspaces patches:
#    - sysvipc_patch.diff
#    - posix_mqueue_patch.diff
#    - glyph_interface_patch.diff

# 3. Apply patches:
patch -p1 < /path/to/patches/sysvipc_patch.diff
patch -p1 < /path/to/patches/posix_mqueue_patch.diff

# 4. Build:
make sm8475_user_defconfig
make -j$(nproc) CC=clang LD=ld.lld Image.gz

# 5. Package:
make dtbo.img
```

---

## Droidspaces Kernel Modules

| Module | Path | Purpose |
|--------|------|---------|
| SYSVIPC | `ipc/sysvipc.c` | System V IPC (shared memory, semaphores, message queues) |
| POSIX_MQ | `ipc/mqueue.c` | POSIX message queues — used by Droidspaces runtime |
| Glyph Driver | `drivers/leds/glyph/` | Nothing Phone Glyph interface driver |
| CAM Sensor | `drivers/media/platform/camera/` | Qualcomm camera sensor hooks |
| GKI Compatibility Layer | `drivers/gki/` | Ensures compatibility with GKI 2.0 KMI |

---

## Droidspaces Runtime Modules

### SYSVIPC Module

```bash
# Path: /proc/sysvipc/
# Used for inter-process communication in Droidspaces apps

# Check if module loaded:
adb shell "ls /proc/sysvipc/"
# → Should show: msg, sem, shm, msg, sem, shm

# Inspect shared memory:
adb shell "cat /proc/sysvipc/shm"
# → List of shared memory segments

# Inspect semaphores:
adb shell "cat /proc/sysvipc/sem"
# → List of semaphore arrays

# Inspect message queues:
adb shell "cat /proc/sysvipc/msg"
# → List of message queues
```

### POSIX_MQ Module

```bash
# Path: /proc/sys/kernel/posix-mqueue/
# Used for message queue support in Droidspaces services

# Check POSIX MQ limits:
adb shell "cat /proc/sys/kernel/posix-mqueue/qsize"
# → Maximum number of messages

adb shell "cat /proc/sys/kernel/posix-mqueue/msgsize"
# → Maximum message size

# Enable if not set:
adb shell "sysctl -w kernel.posix-mqueue.qsize=16"
```

### Glyph Interface Module

```bash
# Path: /sys/class/leds/glyph/
# Controls Nothing Phone Glyph (LED) interface

# Check Glyph status:
adb shell "cat /sys/class/leds/glyph/brightness"
# → Should return 0 (off) or a value (on)

# Test Glyph:
adb shell "echo 255 > /sys/class/leds/glyph/brightness"
# → Glyph should illuminate

# Check Glyph patterns:
adb shell "ls /sys/class/leds/glyph/patterns/"
# → Available animation patterns
```

---

## Kernel Validation

```bash
# 1. Verify KMI match:
adb shell "uname -r"
# → Should match your Droidspaces build KMI
#  Example: 5.10.246-gki-droidspaces-f6b5f

# 2. Check SYSVIPC active:
adb shell "ls /proc/sysvipc/"
# → Empty? Module NOT loaded → kernel config issue

# 3. Check POSIX_MQ active:
adb shell "cat /proc/sys/kernel/posix-mqueue/qsize"
# → Should return a number

# 4. Check Glyph driver:
adb shell "dmesg | grep glyph"
# → Should show: "[    0.000000] Nothing Glyph driver loaded"

# 5. Run Droidspaces validator:
# If Droidspaces app is installed:
adb shell "am start -n com.droidspaces.app/.ValidatorActivity"
# → Should report: all modules OK
```

---

## Droidspaces Kernel Modules (APatch-style)

```bash
# Droidspaces provides an APatch module for loading custom kernel drivers:
# /data/adb/modules/droidspaces_kernel/
├── post-fs-data.sh          # Load kernel modules at boot
├── service.d/               # Start Droidspaces services
├── sbin/.magisk/img/        # Magic mount points
│   └── sysvipc              # SYSVIPC kernel object
│   └── posix_mqueue         # POSIX MQ kernel object
├── x86_64/                  # (ignored — ARM64 only)
└── arm64-v8a/
    └── libdroidspaces.so    # Droidspaces runtime library

# Install Droidspaces kernel module:
adb push droidspaces_kernel.zip /sdcard/
adb shell su -c "apd install /sdcard/droidspaces_kernel.zip"
```

---

## Known Issues

| Issue | Cause | Workaround |
|-------|-------|------------|
| SYSVIPC not loading | Kernel config missing SYSV IPC | Rebuild kernel with `CONFIG_SYSVIPC=y` |
| POSIX_MQ not loading | Kernel config missing POSIX_MQ | Rebuild with `CONFIG_POSIX_MQUEUE=y` |
| Glyph driver broken | Wrong kernel KMI match | Use exact KMI or APatch kallsyms |
| Camera HAL crashes | Kernel missing camera hooks | Enable `CONFIG_QCOM_CAM_*` drivers |
| Droidspaces app crashes | Runtime library mismatch | Use matching Droidspaces app version |

---

## Tag
#[droidspaces] #[custom-kernel] #[sysvipc] #[posix-mqueue] #[glyph] #[/camera-hal] #[kernel] #[pong] #[nothing-phone-2] #[kernel-modules] #[validation] #[apatch]`
---

## Nothing Phone 2 Integration

### Kernel Patching with Droidspaces

```bash
# Droidspaces kernel integrates SYSVIPC + POSIX_MQUEUE patches
# into LineageOS lineage-23.2 kernel base

# Build steps:
# 1. Clone: https://github.com/droidspaces/kernel_nothing_sm8475 (private)
# 2. Apply Droidspaces patches (SYSVIPC, POSIX_MQ, Glyph driver)
# 3. Build:
make sm8475_user_defconfig
make -j$(nproc) CC=clang LD=ld.lld Image.gz
make dtbo.img

# 4. Package with AnyKernel3 for APatch:
#    Creates boot.img with Droidspaces features enabled
```

### APatch Module Integration

```bash
# Droidspaces provides an APatch module:
# /data/adb/modules/droidspaces_kernel/
├── post-fs-data.sh          # Load kernel modules at boot
├── sbin/.magisk/img/        # Magic mount points
│   ├── sysvipc             # SYSVIPC kernel object
│   └── posix_mqueue        # POSIX MQ kernel object
└── arm64-v8a/
    └── libdroidspaces.so    # Runtime library

# Install Droidspaces kernel module:
adb push droidspaces_kernel.zip /sdcard/
adb shell su -c "apd module install /sdcard/droidspaces_kernel.zip"
```

### Validation After Droidspaces Flash

```bash
# 1. Check Droidspaces modules active:
adb shell ls /proc/sysvipc/
# → Should show: msg, sem, shm, msg, sem, shm

# 2. Check POSIX MQ:
adb shell cat /proc/sys/kernel/posix-mqueue/qsize
# → Should return a number (e.g., 16)

# 3. Check Glyph driver:
adb shell dmesg | grep -i glyph
# → Should show: "[    0.000000] Nothing Glyph driver loaded"

# 4. Check camera (if using Droidspaces camera hooks):
adb shell am start -a android.media.action.IMAGE_CAPTURE
# → Should launch camera without crash
```
