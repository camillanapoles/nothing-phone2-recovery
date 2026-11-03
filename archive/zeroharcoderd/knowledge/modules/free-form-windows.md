# Feature: Free-Form Windows (Mini Janelas) on Nothing Phone 2

> Nothing OS 3.0 supports floating mini-janelas — free-form windows that overlay other apps.

---

## Overview

**Mini Janelas** (mini windows) is a feature introduced in Nothing OS 3.0. It allows apps to run in resizable floating windows over other apps — similar to free-form window mode but with a distinctive visual style and gesture controls.

This feature is **hardware-accelerated** and works best with the Glyph interface integration.

---

## Enabling via Developer Options

```bash
# On device:
# 1. Settings → System → Developer Options
# 2. Scroll to "Drawing" section
# 3. Enable "Freeform support"
# 4. Optional: Enable "Show freeform toolbar" for window controls

# Via ADB (faster):
adb shell settings put global develop_settings_development_settings 1
adb shell settings put global enable_freeform_support 1
adb reboot
```

---

## Gesture Controls (Nothing OS 3.0)

| Gesture | Action |
|--------|--------|
| Swipe from bottom-right corner | Opens app in mini-janela |
| Drag mini-janela | Move floating window |
| Pinch on mini-janela | Resize window |
| Drag to top | Expand to full screen |
| Drag to bottom + hold | Close mini-janela |

---

## Per-App Configuration

```bash
# Enable free-form for specific apps via ADB:
# Note: This uses Android's native free-form, not Nothing's mini-janelas
# For Nothing's mini-janelas, only system-wide toggle exists (as of Nothing OS 3.0)

adb shell settings put global freeform_policy_whitelist "com.example.app1,com.example.app2"
```

---

## Root Considerations

| Aspect | With APatch | Notes |
|--------|-------------|-------|
| **Free-form mode** | ✅ Works | Window manager hooks don't conflict with APatch kallsyms |
| **SELinux** | Must be Enforcing | Permissive breaks window manager policies |
| **LSPosed** | Safe | Use "FloatIt" or "MiniWindow" LSPosed modules for enhanced control |
| **DenyList** | Add window manager | `apd hide com.android.systemui` if apps detect hooks |
| **Droidspaces** | Compatible | SYSVIPC supports inter-process window communication |

---

## Troubleshooting Free-Form Mode

| Issue | Cause | Fix |
|-------|-------|-----|
| Mini-janela not appearing | Feature disabled in Nothing OS version < 3.0 | Update to Nothing OS 3.0+ |
| Window resizes to fullscreen | App doesn't declare `resizeableActivity=true` | Enable "Force RESIZE" in Developer Options |
| Gesture conflict | Back gesture interferes with drag | Adjust gesture sensitivity in Settings |
| Camera conflicts | Camera app blocks free-form | Use camera in main screen, not mini-janela |

---

## Validation

```bash
# 1. Check free-form support:
adb shell dumpsys window | grep -i freeform
# → Should show: "mFreeFormWindowMode: true"

# 2. Test launch:
# Swipe from bottom-right corner (Nothing gesture)
# → Should open app in mini-janela

# 3. Verify window bounds:
adb shell dumpsys window | grep -A5 "mCurrentFocus"
# → Should show free-form bounds

# 4. Check system support:
adb shell getprop | grep -i freeform
# → Should return properties
```

---

## Tag
`#[free-form]` `#[/mini-janelas]` `#[nothing-os-3]` `#[android-16]` `#[pong]` `#[nothing-phone-2]` `#[window-manager]` `#[floating-window]` `#[droidspaces]` `#[apatch]`