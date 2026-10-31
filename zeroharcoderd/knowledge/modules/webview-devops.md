# Module: WebView DevOps Tools

Ferramentas leves para desenvolvimento e conexão entre apps via WebView.

---

## Overview

WebView DevTools para Nothing Phone 2 (Pong) com APatch. Inclui:
- WebView debugging
- DevTools integration  
- App-to-app connection facilitada
- Browser-based DevOps

---

## WebView Debugging

```bash
# Habilitar debug do WebView
adb shell settings put global WebViewBrowser devtools_enabled 1

# Ver WebView version
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN | grep -i webview

# Limpar dados WebView
adb shell pm clear com.android.webview
```

---

## DevTools Integration

| Feature | Status | Notes |
|---------|--------|-------|
| Remote Debugging | ✅ Disponível | `chrome://inspect` |
| WebView DevTools | ✅ APatch compatível | Não conflita com kallsyms |
| Debug via ADB | ✅ Ativado | porta 9222 |

---

## App-to-App Connection

### Intent-based Connection
```bash
# Compartilhar entre apps via intent
adb shell am start -a android.intent.action.SEND \
  -type "text/plain" \
  -e "android.intent.extra.TEXT" "Dados para compartilhamento" \
  com.example.app1/.ShareActivity
```

### Content Provider Bridge
```bash
# Apps podem compartilhar dados via ContentProvider
# Configure permissões no AndroidManifest.xml:
# <provider
#     android:name=".SharedDataProvider"
#     android:authorities="com.example.app1.provider"
#     android:exported="true"
#     android:grantUriPermissions="true" />
```

---

## Browser DevOps

### Chrome DevTools Protocol (CDP)
```bash
# Acesar CDP via WebView
# URL: chrome-devtools://devtools/bundled/inspector.html?ws=localhost:9222/devtools/page/XXX

# Listar páginas WebView ativas
adb shell curl -s http://localhost:9222/json/list | jq '.'
```

### Minimal WebView Setup
Para Nothing Phone 2 com APatch:
- Use Android System WebView (com Google)
- Ou Cloudflare WARP WebView (leve alternativa)

---

## Tags
`#[webview]` #[devops] #[debug] #[intent] #[content-provider] #[browser]