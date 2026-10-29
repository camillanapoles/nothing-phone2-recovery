# Environment: Nothing Phone 2 (Pong, SM8475)

> Device-specific configuration, partitions, quirks, and compatibility matrix.

---

## Hardware Specification

| Property | Value |
|----------|-------|
| **Codename** | `Pong` |
| **Model Numbers** | `A065` (Global), `AIN065` (India) |
| **SoC** | Qualcomm SM8475 — Snapdragon 8+ Gen 1 |
| **Architecture** | ARM64 (aarch64) |
| **RAM** | 8 GB / 12 GB LPDDR5 |
| **Storage** | 128 GB / 256 GB / 512 GB UFS 3.1 |
| **Display** | 6.7" LTPO OLED, 1080×2412, 120 Hz, 394 PPI |
| **Battery** | 4700 mAh Li-Ion (non-removable) |
| **Bootloader** | Unlockable globally (no carrier restrictions) |
| **Security** | Knox: N/A (Nothing does not trip Knox) |

---

## Partition Layout (A/B)

```
boot_a / boot_b           ← Kernel + ramdisk (patched for root)
dtbo_a / dtbo_b           ← Device tree overlay
vbmeta_a / vbmeta_b       ← AVB metadata
vendor_boot_a / vendor_boot_b ← Vendor ramdisk (Android 13+)
super                      ← Dynamic partitions (system, vendor, product, etc.)
```

**Key difference from standard Android 13+:**  
Nothing Phone 2 uses **traditional `boot.img` architecture** — NOT `init_boot.img`.  
The `vendor_boot` partition exists but `boot` is still the primary root patch target.

---

## Bootloader & Unlock

| Property | Value |
|----------|-------|
| **Unlock Method** | `fastboot flashing unlock` |
| **Carrier Lock** | None — all regions unlockable |
| **Wait Period** | None |
| **OEM Unlock Toggle** | Settings → Developer Options → OEM unlocking |
| **USB Debugging** | Required for `adb` and `fastboot` |

---

## Stock Firmware Sources

| Source | URL |
|--------|-----|
| **Nothing Archive (GitHub)** | https://github.com/spike0en/nothing_archive |
| **XDA OTA Thread** | https://xdaforums.com/t/nothing-phone-2-official-ota-zip-full-incremental.4604803/ |
| **Nothing Support** | https://nothing.tech/support |

---

## Custom ROM Compatibility

| ROM | Base | Status | Root Support | Glyph Support | Notes |
|-----|------|--------|--------------|---------------|-------|
| **LineageOS** | AOSP | Official (23.2) | ✅ Magisk/APatch | Partial | `Pong` builds available |
| **Evolution X** | AOSP | Official (11.11) | ✅ Magisk/APatch | ✅ Full | Latest: Android 16 QPR2 |
| **crDroid** | LineageOS | Unofficial | ✅ | Partial | Check XDA |
| **/e/OS** | LineageOS | Official | ✅ | Partial | Privacy-focused |
| **PixelOS** | AOSP | Unofficial | ✅ | Limited | Pixel-like UX |
| **GrapheneOS** | AOSP | ❌ Pixel-only | N/A | N/A | Not for Nothing |

---

## Kernel Information

| Property | Value |
|----------|-------|
| **Stock Kernel** | 5.10.246-gki-g4ec5491f6b5f |
| **Kernel Branch** | `android14-5.10` (GKI 2.0) |
| **KMI Version** | gki-g4ec5491f6b5f (Qualcomm-modified) |
| **KernelSU LKM** | ❌ Fails (KMI mismatch with GKI modules) |
| **APatch** | ✅ Works (kallsyms-based, no KMI dependency) |
| **Magisk** | ✅ Works (patches boot.img) |

### Kernel Source for Custom Builds

```bash
# LineageOS kernel (matches device exactly)
git clone --branch lineage-23.2 --depth 1 \
  https://github.com/LineageOS/android_kernel_nothing_sm8475 \
  ~/nothing-phone2/kernel-build/kernel
```

**SUBLEVEL 246** matches the stock kernel exactly.

---

## Root Framework Compatibility

| Framework | Supported | Notes |
|-----------|-----------|-------|
| **Magisk** | ✅ Full | v30.7+ for Android 16 QPR2 |
| **KernelSU** | ❌ LKM fails | KMI mismatch; GKI modules reject custom KSU |
| **KernelSU Next** | ⚠️ Needs custom kernel | Requires building with KSU integration |
| **APatch** | ✅ Full | v11219 — kallsyms patching works |
| **LSPosed (Zygisk)** | ✅ With ZygiskNext | Use Zygisk variant only |
| **LSPosed (Riru)** | ❌ | Looks for `magisk` binary |

---

## Known Device Quirks

| Quirk | Impact | Workaround |
|-------|--------|------------|
| No `init_boot` partition | Guides mentioning `init_boot` are wrong | Patch `boot.img` only |
| KMI modified by Qualcomm | KernelSU LKM incompatible | Use APatch or Magisk |
| Glyph interface | Breaks on some custom ROMs | Test before full switch |
| Recovery in CDC NCM mode (0xa4a1) | No ADB/fastboot | Force reboot: Power + Vol Down 20s |
| Recovery auto-switches slots | Sideload may land on wrong slot | Always `getprop ro.boot.slot_suffix` after recovery reboot |
| MindTheGapps via recovery fails | Dynamic partition mount issues | Use systemless GApps module or KernelSU module |

---

## USB PID Reference

| PID | Mode | ADB | Fastboot | Notes |
|-----|------|-----|----------|-------|
| `05c6:a4a1` | CDC NCM | ❌ | ❌ | Kernel booted, Android not complete — force reboot |
| `05c6:9008` | EDL | ❌ | ❌ | Emergency Download — needs firehose |
| `05c6:908c` | Fastboot | ❌ | ✅ | Standard fastboot mode |
| `18d1:4ee7` | ADB | ✅ | ❌ | Normal Android (may vary) |

---

## Glyph Interface

- **Supported:** Nothing OS, Evolution X (official builds)
- **Partial:** LineageOS, crDroid, /e/OS
- **Broken:** Most other AOSP ROMs

---

## Tags
`#[nothing-phone-2]` `#[pong]` `#[sm8475]` `#[gki-2.0]` `#[android-16]` `#[boot-img]` `#[kernel-quirk]` `#[glyph]`