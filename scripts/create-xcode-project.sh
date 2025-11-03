#!/bin/bash
# DoseTrack - Automated Xcode Project Creation
# Run this AFTER installing Xcode from the Mac App Store

set -e  # Exit on error

echo "🚀 DoseTrack Xcode Project Setup"
echo "=================================="
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ ERROR: Xcode is not installed"
    echo ""
    echo "Please install Xcode first:"
    echo "  1. Open Mac App Store"
    echo "  2. Search for 'Xcode'"
    echo "  3. Click 'Get' or 'Install'"
    echo "  4. Wait for installation (12-15 GB)"
    echo "  5. Run this script again"
    echo ""
    echo "Or download from: https://developer.apple.com/download/"
    exit 1
fi

echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"
echo ""

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📂 Project root: $PROJECT_ROOT"
echo ""

# Check if project already exists
if [ -d "DoseTrack.xcodeproj" ] || [ -d "DoseTrack.xcworkspace" ]; then
    echo "⚠️  Xcode project already exists!"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Opening existing project..."
        open DoseTrack.xcodeproj 2>/dev/null || open DoseTrack.xcworkspace 2>/dev/null || true
        exit 0
    fi
    echo "🗑️  Removing old project..."
    rm -rf DoseTrack.xcodeproj DoseTrack.xcworkspace
fi

echo "🔧 Creating iOS app project structure..."
echo ""

# Create temporary directory for Xcode project generation
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "📝 Generating project via xcodegen or manual structure..."

# Since xcodegen might not be installed, we'll guide user to create manually
echo ""
echo "⚠️  Automated project creation requires manual steps in Xcode."
echo ""
echo "Please follow these steps:"
echo ""
echo "1️⃣  Open Xcode"
echo "2️⃣  File → New → Project"
echo "3️⃣  Choose: iOS → App"
echo "4️⃣  Configure:"
echo "    • Product Name: DoseTrack"
echo "    • Organization Identifier: com.jefferson"
echo "    • Bundle ID: com.jefferson.dosetrack"
echo "    • Interface: SwiftUI"
echo "    • Storage: SwiftData"
echo "    • Location: $PROJECT_ROOT"
echo ""
echo "5️⃣  Delete default files (ContentView.swift, etc.)"
echo ""
echo "6️⃣  Add existing files:"
echo "    • Right-click project → Add Files"
echo "    • Select all files from: $PROJECT_ROOT/ios/"
echo "    • ⚠️  UNCHECK 'Copy items if needed'"
echo "    • ✅ CHECK 'Add to targets: DoseTrack'"
echo ""
echo "7️⃣  Add Widget Extension:"
echo "    • File → New → Target → Widget Extension"
echo "    • Name: DoseTrackWidget"
echo "    • Bundle ID: com.jefferson.dosetrack.widget"
echo "    • Add files from: $PROJECT_ROOT/ios/Widget/"
echo ""
echo "8️⃣  Configure Capabilities (Signing & Capabilities tab):"
echo "    App Target:"
echo "      • ✅ HealthKit"
echo "      • ✅ App Groups (group.com.jefferson.dosetrack)"
echo "      • ✅ Push Notifications"
echo "    Widget Target:"
echo "      • ✅ App Groups (group.com.jefferson.dosetrack)"
echo ""
echo "9️⃣  Add Info.plist entries:"
echo "    • NSHealthShareUsageDescription"
echo "    • NSHealthUpdateUsageDescription"
echo ""
echo "🔟 Build & Run:"
echo "    • Select iPhone 15 simulator"
echo "    • Press ⌘R to run"
echo ""
echo "📖 Full guide: $PROJECT_ROOT/docs/ops/XCODE_SETUP_GUIDE.md"
echo ""

# Clean up
cd "$PROJECT_ROOT"
rm -rf "$TEMP_DIR"

# Offer to open Xcode
read -p "Open Xcode now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "🚀 Opening Xcode..."
    open -a Xcode . 2>/dev/null || open -a "Xcode.app" . 2>/dev/null || echo "⚠️  Could not open Xcode automatically"
fi

echo ""
echo "✅ Setup instructions displayed above"
echo "📚 Detailed guide: docs/ops/XCODE_SETUP_GUIDE.md"
echo ""
