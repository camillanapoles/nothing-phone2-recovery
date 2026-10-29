# Troubleshooting: Free-Form Windows (Mini Janelas) on Nothing Phone 2

> Nothing Phone OS 3.0 feature: free-form window mode (mini windows / floating windows).

---

## Overview

Nothing Phone 2 (Nothing OS 3.0, Android 16) supports **free-form windows** — also called "mini janelas" or floating windows. This allows apps to run in resizable windows overlaid on top of other apps.

---

## Enabling Free-Form Mode

### Method 1: Developer Settings (Recommended)

```bash
# 1. Enable Developer Options
adb shell settings put global development_settings 1

# 2. Enable free-form windowing
adb shell settings put global enable_freeform_support 1

# 3. Reboot (required for changes to take effect)
adb reboot
```

> **Alternative:** On-device: Settings → Developer Options → "Enable freeform support" (toggle ON)

### Method 2: ADB Commands (Per-App)

```bash
# Launch app in free-form mode
adb shell am start \
  -n com.example.app/.MainActivity \
  --activity-native-new-api \
  --activity-exclude-from-recents

# Set initial window bounds (left, top, right, bottom in DP)
adb shell wm size 1080x2400  # Reset resolution first
adb shell wm density 420      # Adjust DPI if needed
```

### Method 3: Magisk Module (Root Required)

```bash
# Use "Lilaya" module or similar LSPosed module for per-app free-form
# Install via LSPosed Manager → Modules → Add "FreeForm"
#
# LSPosed module: "FloatIt" or "Freedom Utilities"
# Enables free-form for specific apps without global change
```

---

## Nothing OS Specific Gestures

| Gesture | Action |
|---------|--------|
| Swipe from corner (bottom-right) | Opens mini-window |
| Swipe from corner (bottom-left) | Opens full-screen |
| Mini-window drag | Position anywhere on screen |
| Mini-window pinch | Resize window |
| Mini-window → top | Expand to full screen |
| Mini-window → bottom | Close/minimize |

---

## Validation Steps

```bash
# 1. Check free-form support
adb shell dumpsys window | grep -i freeform
# → Should show: "mFreeFormWindowMode: true" or similar

# 2. Test app launch
adb shell am start \
  -n com.android.chrome/com.google.android.apps.chrome.Main \
  --activity-native-new-api

# 3. Verify window state
adb shell dumpsys window | grep -A5 "mCurrentFocus"
# → Should show free-form bounds

# 4. Check system support
adb shell getprop | grep -i freeform
# → Should return properties
```

---

## Known Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| **Free-form toggle missing** | Nothing OS version < 3.0 | Update to Nothing OS 3.0+ |
| **Window resizes to full screen** | App doesn't declare resizeableActivity | Enable "Force RESIZE" via DevTools |
| **Keyboard conflicts** | IME covers window | Disable "Show keyboard on tap" |
| **App crashes in window** | App not designed for free-form | Enable dev force-resize |
| **Gesture conflict** | Back gesture intercepts drag | Adjust sensitivity in Settings |

---

## Developer Settings for Free-Form Debugging

```text
Settings → Developer Options → Drawing →
  Window animation scale: 1x (for testing)
  Disable HW overlays: try if glitchy
  Force GPU rendering: ON (fixes rendering glitches)
  Show layout bounds: ON (see window edges)

Settings → Developer Options → →
  Freeform support: ON
  Freeform toolbar: optional (shows window controls)
  Freeform status bar: optional
```

---

## Root-Specific Considerations (APatch)

| Aspect | Details |
|--------|---------|
| **Free-form + root** | Works — window manager hooks don't conflict with APatch kallsyms |
| **LSPosed modules** | Use "FloatIt" or "MiniWindow" for enhanced per-app control |
| **SELinux** | Enforcing mode required — permissive breaks window manager policies |
| **DenyList** | Add window manager to DenyList if apps detect hooks |

---

## Tag
`#[free-form]` #[mini-windows] #[nothing-os-3] #[android-16] #[pong] #[nothing-phone-2] #[window-manager] #[float]`