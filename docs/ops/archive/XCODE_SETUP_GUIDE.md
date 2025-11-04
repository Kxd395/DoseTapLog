# DoseTrack iOS App - Xcode Setup Guide

**Status:** ⚠️ Xcode not currently installed on this system  
**Created:** November 1, 2025

---

## Current Situation

✅ **All Swift source code is ready** (14 files in `ios/` directory)  
✅ **Backend server is configured** and ready to run  
✅ **Documentation is complete** (100%)  
❌ **Xcode is not installed** - needed to build the iOS app

---

## Step 1: Install Xcode

### Option A: Mac App Store (Recommended)
1. Open the **Mac App Store**
2. Search for **"Xcode"**
3. Click **"Get"** or **"Install"**
4. Wait for download (~12-15 GB, takes 30-60 minutes)
5. After installation, open Xcode once to accept license agreement

### Option B: Apple Developer Portal
1. Go to https://developer.apple.com/download/
2. Sign in with your Apple ID
3. Download latest Xcode (Xcode 15.4+)
4. Install the `.xip` file

### Verify Installation
```bash
xcode-select --install  # Install command line tools
xcodebuild -version      # Should show Xcode version
```

---

## Step 2: Create iOS App Project

Once Xcode is installed, run this script:

```bash
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
./scripts/create-xcode-project.sh
```

Or manually create the project:

### Manual Creation Steps

1. **Open Xcode**
2. **File → New → Project**
3. Choose **iOS → App**
4. Configure:
   - **Product Name:** DoseTrack
   - **Team:** (Your Apple Developer account)
   - **Organization Identifier:** com.jefferson
   - **Bundle Identifier:** com.jefferson.dosetrack
   - **Interface:** SwiftUI
   - **Storage:** SwiftData
   - **Language:** Swift
   - **Location:** `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c`

5. **Delete the default files** Xcode creates (ContentView.swift, etc.)

6. **Add your existing Swift files:**
   - Right-click on the project in navigator
   - **Add Files to "DoseTrack"...**
   - Select all files from `ios/` folder:
     - AppGroupStore.swift
     - AppIntents+DoseLog.swift
     - Config.swift
     - CSVExporter.swift
     - Date+UTC.swift
     - DoseLogController.swift
     - DoseTrackApp.swift
     - HealthKitManager.swift
     - Models.swift
     - NightPlanRecommender.swift
     - Rounding+Display.swift
     - TodayLogView.swift
   - ✅ Check **"Copy items if needed"** = NO (files already in place)
   - ✅ Check **"Add to targets"** = DoseTrack

7. **Add Widget Extension:**
   - **File → New → Target**
   - Choose **Widget Extension**
   - Name: **DoseTrackWidget**
   - Bundle ID: **com.jefferson.dosetrack.widget**
   - Add files from `ios/Widget/` folder

8. **Add Test Target:**
   - Should be auto-created, or **File → New → Target → Unit Testing Bundle**
   - Add files from `ios/Tests/` folder

---

## Step 3: Configure Capabilities

### App Target (DoseTrack)

1. **Select project** in navigator
2. **Select "DoseTrack" target**
3. **"Signing & Capabilities" tab**

#### Required Capabilities:

**1. HealthKit**
   - Click **+ Capability**
   - Add **HealthKit**
   - ✅ Background Delivery
   - ✅ Clinical Health Records (optional)

**2. App Groups**
   - Click **+ Capability**
   - Add **App Groups**
   - ✅ Enable: `group.com.jefferson.dosetrack`

**3. Push Notifications** (for alerts)
   - Click **+ Capability**
   - Add **Push Notifications**

### Widget Target (DoseTrackWidget)

1. **Select "DoseTrackWidget" target**
2. **"Signing & Capabilities" tab**

**Required:**
   - **App Groups** with `group.com.jefferson.dosetrack`

---

## Step 4: Configure Info.plist

Add these privacy usage descriptions:

**App's Info.plist:**

```xml
<key>NSHealthShareUsageDescription</key>
<string>DoseTrack needs access to your sleep data to automatically fill your final wake time.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>DoseTrack does not write health data.</string>
```

**Widget's Info.plist:**

Add App Group identifier if not auto-configured.

---

## Step 5: Build Settings

### Deployment Target
- **iOS Deployment Target:** 17.0 or later
- **Swift Language Version:** Swift 6

### Minimum Configuration
- **Product Bundle Identifier:** 
  - App: `com.jefferson.dosetrack`
  - Widget: `com.jefferson.dosetrack.widget`

---

## Step 6: Build & Run

### First Build
```bash
# From terminal
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Or in Xcode
1. Select **DoseTrack scheme**
2. Select **iPhone 15 simulator** (or any iOS 17+ simulator)
3. Click **▶️ Run** or press **⌘R**

### Run Tests
```bash
xcodebuild test -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Step 7: Connect to Backend

Once the app builds:

1. **Start the backend server:**
   ```bash
   cd server
   npm start
   ```

2. **Update app configuration** if needed (in `Config.swift`):
   - WHOOP proxy URL: `http://localhost:3000`

3. **Test the full stack:**
   - App can fetch sleep data via WHOOP proxy
   - HealthKit integration (requires real device)
   - CSV export functionality

---

## Quick Start Script

Once Xcode is installed, use this automated script:

```bash
#!/bin/bash
# scripts/create-xcode-project.sh

echo "🚀 Creating DoseTrack Xcode Project..."

cd "$(dirname "$0")/.."

# This will be created after you have Xcode installed
# For now, this is a placeholder

echo "⚠️  Please install Xcode first, then run this script"
echo "📦 Xcode download: https://apps.apple.com/app/xcode/id497799835"
```

---

## What's Ready NOW

✅ All Swift source files (14 files)  
✅ Backend server configured  
✅ Documentation complete  
✅ Project structure defined  
✅ This setup guide created  

## What You Need to Do

1. ⬇️ **Install Xcode** (~12 GB, 30-60 min download)
2. 🔧 **Create project** (follow Step 2 above)
3. ⚙️ **Configure capabilities** (follow Step 3)
4. ▶️ **Build & run** (follow Step 6)

---

## Troubleshooting

### "Command line tools not found"
```bash
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### "No developer account"
- You can still build and run on simulator without an Apple Developer account
- Real device testing requires free Apple ID or paid Developer Program ($99/year)

### "SwiftData not found"
- Ensure deployment target is iOS 17.0+
- Ensure Xcode 15.4+ is installed

### "HealthKit not available in simulator"
- HealthKit features only work on **real devices**
- You can test other features in simulator

---

## Next Steps After Xcode Installation

1. Install Xcode from App Store
2. Open this guide again
3. Follow Step 2 to create the project
4. You'll be building and running within 15-30 minutes

**Need help?** Check `docs/ops/START_HERE.md` for additional guidance.
