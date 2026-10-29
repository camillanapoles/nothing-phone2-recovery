#!/bin/bash
# CI Setup Script: Android SDK for Nothing Phone 2 Boot Testing
# Configures Android SDK + platform tools for boot image validation

set -e

echo "🔄 Installing Android SDK components..."

# Install platform-tools
yes | sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" 2>&1 | tail -5

# Install payload-dumper-go for extracting boot.img from OTA
echo "📥 Installing payload-dumper-go..."
curl -sL "https://github.com/ssut/payload-dumper-go/releases/latest/download/payload-dumper-go-linux-amd64.zip" -o /tmp/payload-dumper-go.zip
unzip -o /tmp/payload-dumper-go.zip -d /tmp/
chmod +x /tmp/payload-dumper-go
cp /tmp/payload-dumper-go /opt/hostedtoolcache/

# Verify fastlot/fastboot available (for simulation)
echo "🔧 Verifying tools..."
adb version
fastboot version

echo "✅ Android SDK setup complete"