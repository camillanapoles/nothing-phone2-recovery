# Module: Mountify — APatch Systemless Mount Manager

> **STATUS: DISABLED** — Metamodule that manages `/system` mounts for APatch/KernelSU. Conflicts with Shamiko and some root-hiding modules.

---

## Background (D-3 from STATE.md)

> `mountify` has `metamodule=true` in its `module.prop`  
> The mountify module is the metamodule itself that manages mount namespaces for APatch/KernelSU.  
> BOOTCOUNT=0 in `count.sh` indicates the module just restarted.  
> Suspected conflict with "Magic Meta Module" or Shamiko's mount manipulation.

---

## Why It’s Disabled

| Reason | Explanation |
|--------|-------------|
| **Metamodule conflict** | mountify manages mount namespaces via `metamodule=true`; Shamiko also manipulates mounts → collision |
| **Namespace corruption** | Mixing APatch mount management with Magisk-style root hiding breaks `/system` overlays |
| **BOOTCOUNT=0** | Indicates fresh module state — was recently (re)installed or reset |

### Current status:
```bash
cat /data/adb/modules/mountify/module.prop
# metamodule=true
# name=Mountify

ls /data/adb/modules/mountify/disable
# File exists → module is DISABLED
```

---

## To Re-enable Mountify (IF safe)

```bash
# 1. Confirm NO conflicting modules:
ls /data/adb/modules/ | grep -E "shamiko|magic|meta"  # Should be empty

# 2. Remove disable file:
adb shell su -c 'rm /data/adb/modules/mountify/disable'

# 3. Reboot and verify mounts:
adb shell su -c 'mount | grep system'
# → Should show mountify-managed entries

# 4. If bootloop:
#    fastboot flash boot stock_boot.img
#    Re-apply APatch patch
```

---

## Alternatives (If mountify is needed)

| Need | Alternative |
|------|-------------|
| Systemless mounts | APatch handles natively — no module needed |
| Mount namespace isolation | Use App Profiles (KernelSU) or DenyList (Magisk) |
| Overlay management | KernelSU metamodules (if using custom kernel) |

---

## Tag
`#[mountify]` `#[/apatch]` `#[metamodule]` `#[disabled]` `#[mount-namespace]` `