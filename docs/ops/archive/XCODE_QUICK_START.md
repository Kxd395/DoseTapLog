# 🚀 Create DoseTrack Project in Xcode - Step by Step

**Your Swift files are here:** `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/ios/`  
**Xcode is installed at:** `/Applications/_Development/Xcode.app`  
**Xcode version:** 26.0.1

---

## ✅ Your Files Are Safe!

All 14 Swift files are in the `ios/` folder:
- ✅ DoseTrackApp.swift
- ✅ Models.swift
- ✅ TodayLogView.swift
- ✅ DoseLogController.swift
- ✅ HealthKitManager.swift
- ✅ CSVExporter.swift
- ✅ NightPlanRecommender.swift
- ✅ Config.swift
- ✅ AppGroupStore.swift
- ✅ AppIntents+DoseLog.swift
- ✅ Date+UTC.swift
- ✅ Rounding+Display.swift
- Plus: Tests/ and Widget/ folders

---

## 📝 Follow These Steps in Xcode

### Step 1: Create New Project (2 minutes)

Xcode should now be open. If you see a welcome screen:

1. Click **"Create New Project"**
2. Or: **File → New → Project...**

### Step 2: Choose Template

1. Select **iOS** at the top
2. Select **App** template
3. Click **Next**

### Step 3: Configure Project

Fill in these details:

| Field | Value |
|-------|-------|
| **Product Name** | DoseTrack |
| **Team** | (Select your Apple ID or leave as None) |
| **Organization Identifier** | com.jefferson |
| **Bundle Identifier** | com.jefferson.dosetrack (auto-fills) |
| **Interface** | SwiftUI |
| **Storage** | SwiftData |
| **Language** | Swift |
| **Include Tests** | ✅ Checked |

Click **Next**

### Step 4: Choose Location

**IMPORTANT:** Save the project to:
```
/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c
```

- ✅ **UNCHECK** "Create Git repository" (you already have one)
- Click **Create**

### Step 5: Delete Default Files

Xcode creates some default files. Delete these:

1. In the left sidebar (Navigator), find and **DELETE**:
   - `ContentView.swift` (right-click → Delete → Move to Trash)
   - `Item.swift` (right-click → Delete → Move to Trash)

Keep:
- `DoseTrackApp.swift` (Xcode's generated one - we'll replace)
- `Assets.xcassets`
- `Preview Content`

### Step 6: Add Your Swift Files

Now add your actual Swift files:

1. **Right-click** on "DoseTrack" folder in navigator
2. Select **"Add Files to DoseTrack..."**
3. Navigate to: `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/ios/`
4. **Select ALL Swift files** (not folders yet):
   - AppGroupStore.swift
   - AppIntents+DoseLog.swift
   - Config.swift
   - CSVExporter.swift
   - Date+UTC.swift
   - DoseLogController.swift
   - DoseTrackApp.swift (this will REPLACE Xcode's default)
   - HealthKitManager.swift
   - Models.swift
   - NightPlanRecommender.swift
   - Rounding+Display.swift
   - TodayLogView.swift

5. **IMPORTANT Settings:**
   - ❌ **UNCHECK** "Copy items if needed"
   - ✅ **CHECK** "Add to targets: DoseTrack"
   - **Create groups** (not folder references)

6. Click **Add**

### Step 7: Add Test Files

1. **Right-click** on "DoseTrackTests" folder
2. **"Add Files to DoseTrack..."**
3. Navigate to: `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/ios/Tests/`
4. Select **DoseLogTests.swift**
5. ❌ **UNCHECK** "Copy items if needed"
6. ✅ **CHECK** "Add to targets: DoseTrackTests"
7. Click **Add**

### Step 8: Configure Capabilities

1. Click on **DoseTrack** (blue icon) in navigator
2. Select **DoseTrack** target (under TARGETS)
3. Go to **"Signing & Capabilities"** tab

#### Add HealthKit:
1. Click **"+ Capability"** button
2. Search for **"HealthKit"**
3. Double-click to add
4. ✅ Check **"Background Delivery"**

#### Add App Groups:
1. Click **"+ Capability"** button again
2. Search for **"App Groups"**
3. Double-click to add
4. Click **"+"** under App Groups
5. Enter: `group.com.jefferson.dosetrack`
6. Click **OK**

#### Add Push Notifications:
1. Click **"+ Capability"** button again
2. Search for **"Push Notifications"**
3. Double-click to add

### Step 9: Update Info.plist

1. In navigator, find **Info.plist** (or Info tab)
2. Add these keys (if not already there):

Right-click in the Info area → **Add Row**:
- **Key:** `NSHealthShareUsageDescription`
- **Value:** `DoseTrack needs access to your sleep data to automatically fill your final wake time.`

Add another row:
- **Key:** `NSHealthUpdateUsageDescription`
- **Value:** `DoseTrack does not write health data.`

### Step 10: Build Settings

1. Still in project settings
2. **Build Settings** tab
3. Search for **"iOS Deployment Target"**
4. Set to **iOS 17.0** (or later)

### Step 11: First Build! 🎉

1. Select a simulator at the top: **iPhone 15** (or any iOS 17+ device)
2. Press **⌘R** or click the **▶️ Play button**
3. Wait for build...
4. App should launch in simulator!

---

## 🐛 If You See Build Errors

### "Cannot find DoseTrackApp in scope"
- Make sure you added DoseTrackApp.swift from ios/ folder
- Make sure you deleted Xcode's default DoseTrackApp.swift

### "Cannot find type 'DoseLog' in scope"
- Make sure Models.swift is added to target
- Check that all Swift files have a checkmark under "Target Membership"

### "No such module 'SwiftData'"
- Go to Build Settings → iOS Deployment Target → Set to 17.0+
- Clean build folder (⌘⇧K) and rebuild

---

## 📂 Your Project Structure Should Look Like:

```
DoseTrack (Xcode Project)
├── DoseTrack/
│   ├── AppGroupStore.swift
│   ├── AppIntents+DoseLog.swift
│   ├── Config.swift
│   ├── CSVExporter.swift
│   ├── Date+UTC.swift
│   ├── DoseLogController.swift
│   ├── DoseTrackApp.swift
│   ├── HealthKitManager.swift
│   ├── Models.swift
│   ├── NightPlanRecommender.swift
│   ├── Rounding+Display.swift
│   ├── TodayLogView.swift
│   ├── Assets.xcassets
│   └── Preview Content/
├── DoseTrackTests/
│   └── DoseLogTests.swift
└── Products/
    └── DoseTrack.app
```

---

## ✅ Success Checklist

After following all steps:

- [ ] Project created in correct location
- [ ] All 12 Swift files added
- [ ] Test file added
- [ ] HealthKit capability enabled
- [ ] App Groups configured
- [ ] Push Notifications enabled
- [ ] Info.plist updated with privacy descriptions
- [ ] iOS Deployment Target set to 17.0+
- [ ] App builds without errors (⌘B)
- [ ] App runs in simulator (⌘R)

---

## 🎯 Quick Commands

Once setup is complete:

| Action | Shortcut |
|--------|----------|
| Build | ⌘B |
| Run | ⌘R |
| Stop | ⌘. |
| Clean | ⌘⇧K |
| Test | ⌘U |

---

## 🆘 Need Help?

If you get stuck:
1. Check this guide again
2. See: `docs/ops/XCODE_SETUP_GUIDE.md` (detailed version)
3. Try: Clean Build Folder (⌘⇧K) then rebuild

---

**Estimated time:** 10-15 minutes for first-time setup

**You're now ready to build and run DoseTrack! 🚀**
