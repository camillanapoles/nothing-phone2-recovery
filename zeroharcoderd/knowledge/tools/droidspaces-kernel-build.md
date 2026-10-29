# Feature: Droidspaces — Kernel Build Framework

> Custom kernel with SYSVIPC + POSIX_MQUEUE for Nothing Phone 2 inter-process communication.

---

## Overview

**Droidspaces** is a kernel build framework for Nothing Phone 2 that adds Linux kernel IPC features (System V IPC and POSIX Message Queues) needed by distributed/multi-process Android applications.

---

## Build Script Template (`build_pong.sh`)

```bash
#!/bin/bash
# Droidspaces kernel build for Nothing Phone 2 (Pong)

export ARCH=arm64
export SUBARCH=arm64
export PATH=$PATH:/opt/aosp/prebuilts/clang/host/linux-x86/llvm/bin
export LLVM=1

# 1. Configure kernel
make sm8475_defconfig

# 2. Apply Droidspaces patches
patch -p1 < ../patches/sysvipc_patch.diff
patch -p1 < ../patches/posix_mqueue_patch.diff
patch -p1 < ../patches/glyph_interface_patch.diff

# 3. Build kernel image
make -j$(nproc) \
  CC=clang \
  LD=ld.lld \
  Image.gz \
  modules

# 4. Package DTBO
make dtbo.img

# 5. Package with AnyKernel3 for APatch
# Output: Droidspaces-Pong-v1.0.zip (flashable via APatch/Recovery)
```

---

## Kernel Requirements (GKI 2.0)

| Setting | Value |
|---------|-------|
| Base | LineageOS `lineage-23.2` branch |
| Kernel Version | `5.10.246` |
| KMI Tag | `gki-g4ec5491f6b5f` (matches stock) |
| Architecture | `arm64-v8a` |

```bash
# Verify kernel version:
make KERNELVERSION
# → 5.10.246-gki-g4ec5491f6b5f

# Check KMI compatibility:
adb shell "uname -r"
# → 5.10.246-gki-g4ec5491f6b5f
```

---

## Droidspaces Kernel Modules

| Module | Config Flag | Location | Purpose |
|--------|-------------|----------|---------|
| `SYSVIPC` | `CONFIG_SYSVIPC=y` | `ipc/sysvipc.c` | System V IPC (shm, sem, msg) |
| `POSIX_MQ` | `CONFIG_POSIX_MQUEUE=y` | `ipc/mqueue.c` | POSIX message queues |
| **Glyph Driver** | `CONFIG_LEDS_GLYPH=y` | `drivers/leds/glyph/` | Nothing Glyph interface |
| **Camera HAL** | `CONFIG_QCOM_CAM_*` | `drivers/media/platform/camera/` | Qualcomm camera hooks |
| **GKI Compatibility** | Various | `drivers/gki/` | Ensures GKI 2.0 kABI compatibility |

---

## Building with Droidspaces + APatch

### Method 1: APatch Boot Patching (Recommended)

```bash
# 1. Build Droidspaces kernel:
#    → produces Image.gz + dtbo.img

# 2. Package with kernel preset:
#    Place Droidspaces Image.gz into APatch boot preset:
#    /data/adb/apatch/boot_preset/
#    ├── boot.img (from Droidspaces build)
#    └── dtbo.img

# 3. Let APatch handle signing/hashing:
#    APatch app → Install → Select boot.img → Patch
#    This patches the Droidspaces kernel with kallsyms hook
```

### Method 2: Custom APatch Module

```bash
# Create Droidspaces APatch module:
# /data/adb/modules/droidspaces/
├── module.prop      # id=droidspaces_kernel, name=Droidspaces Kernel
├── post-fs-data.sh  # Loads Droidspaces kernel features
├── service.d/       # Starts Droidspaces services
└── sbin/.magisk/img/
    ├── sysvipc.ko   # SYSVIPC kernel object
    └── posix_mq.ko  # POSIX MQ kernel object

# Install:
adb push droidspaces.zip /sdcard/
adb shell su -c "apd module install /sdcard/droidspaces.zip"
```

---

## Validation After Flash

```bash
# 1. Check Droidspaces modules loaded:
adb shell ls /proc/sysvipc/
# → Should show: msg, sem, shm, msg, sem, shm

# 2. Check POSIX MQ active:
adb shell cat /proc/sys/kernel/posix-mqueue/qsize
# → Should return number (e.g., 16)

# 3. Check Glyph driver:
adb shell dmesg | grep -i "glyph\|Nothing Glyph"
# → Should show: "[    0.000000] Nothing Glyph driver loaded"

# 4. Check camera (if Droidspaces camera hooks enabled):
adb shell dmesg | grep -i "camera\|qc_ci"
# → Should show successful camera driver probe

# 5. Verify kernel version:
adb shell "uname -r"
# → Should match Droidspaces build version
```

---

## Known Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| SYSVIPC not loading | Kernel config missing | Rebuild with `CONFIG_SYSVIPC=y` |
| POSIX MQ not loading | Kernel config missing | Rebuild with `CONFIG_POSIX_MQUEUE=y` |
| Glyph not working | Wrong KMI match | Use stock-matching Droidspaces KMI |
| Camera crashes | Missing camera hooks | Enable `CONFIG_QCOM_CAM_*` in kernel |
| Bootloop | Incompatible kernel | Flash stock boot.img via fastboot |

---

## Tag
`#[droidspaces]` `#[custom-kernel]` `#[sysvipc]` #[posix-mqueue]` `#[glyph-driver]` #[/camera-hal] #[kernel-build]` #[pong] #[nothing-phone-2] #[apatch]`