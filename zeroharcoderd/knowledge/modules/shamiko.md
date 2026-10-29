# Module: Shamiko (v3.6)

> Root-hiding module that conceals Magisk from apps on the DenyList. **CAUTION: conflicts with APatch-based root stacks.**

---

## Version Information

| Property | Value |
|----------|-------|
| **Version** | v3.6 |
| **Android Support** | Android 8.0–16 |
| **Compat** | Magisk + Zygisk (with DenyList) |
| **APatch** | ❌ **Do NOT use** — causes conflicts |
| **Source** | https://github.com/LSPosed/ZygiskNext |

---

## ⚠️ Critical Compatibility Warning

| Root Setup | Use Shamiko? | Notes |
|------------|-------------|-------|
| **Magisk v30.7** | ✅ Recommended | Works with DenyList |
| **APatch v11219** | ❌ **NO** | Conflicts with kallsyms — Shamiko can break APatch root |
| **KernelSU Next** | ⚠️ Maybe | KernelSU has own hiding; dual-layer may break |
| **Magisk + APatch dual** | ❌ **NEVER** | Catastrophic conflicts |

---

## Why Shamiko is DISABLED on Nothing Phone 2 (APatch stack)

From `STATE.md`:

> - `mountify` has `metamodule=true` in its `module.prop`
> - `mountify` is the metamodule that manages mount namespaces for APatch/KernelSU
> - Adding Shamiko's mount manipulation can corrupt APatch's namespace remapping

### Current module state:
```bash
# Disabled modules (from audit logs)
/data/adb/modules/mountify/disable   ← created (conflict with Shamiko suspected)
/data/adb/modules/zygisk_shamiko/disable ← created (conflict with APatch)
```

---

## If You MUST Use Shamiko (Magisk-only setup)

```bash
# 1. Install Magisk v30.7 only (no APatch)
# 2. Enable Zygisk
# 3. Install Shamiko via Magisk app (not CLI)
# 4. Add banking apps to Magisk DenyList
# 5. DO NOT install APatch modules or KernelSU

# Reboot and test:
adb shell su -c 'id'
# → Should still return uid=0 for apps NOT on DenyList
# → Apps on DenyList see uid=0(hidden) — Shamiko hides su
```

---

## Alternative Root Hiding for APatch

| Tool | Purpose | Compat |
|------|---------|--------|
| **Tricky Store** | Keybox attestation spoofing | ✅ Works with APatch |
| **PlayIntegrityFork** | Play Integrity bypass | ✅ Works with APatch |
| **Zygote Detection Block** | Prevents app from seeing su | ✅ ZygiskNext |
| **App Profiles** | Per-app root deny | ✅ KernelSU Next |

---

## Shamiko Configuration

```bash
# Shamiko has no config file — relies entirely on Magisk DenyList
# Add apps to DenyList via Magisk app or CLI:

adb shell su -c 'magisk --denylist add com.bank.app'
# Only effective on Magisk, not APatch
```

---

## Troubleshooting

| Issue | With Shamiko | With APatch |
|-------|-------------|-------------|
| Root detected | Check DenyList | Switch to Tricky Store + PlayIntegrityFork |
| System crash | Remove Shamiko + Magisk, flash stock boot | N/A |
| Banking app fails | Use PlayIntegrityFork + Tricky Store instead |  |

---

## Tag
`#[shamiko]` `#[root-hiding]` `#[denylist]` `#[magisk]` `#[/apatch]` `#[/kernelsu]` `#[nothing-phone-2]` `#[pong]`