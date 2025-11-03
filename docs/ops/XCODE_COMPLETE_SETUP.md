# Create DoseTrack iOS App - Complete Guide

## Step 1: Create New Xcode Project

1. Open Xcode (`/Applications/_Development/Xcode.app`)
2. **File → New → Project**
3. **Select iOS** (NOT macOS!) at the top
4. **Choose "App"** template
5. Click **Next**

## Step 2: Configure Project

- **Product Name:** `DoseTrack`
- **Team:** (Select your team - should be "Jefferson DiBartolomeo")
- **Organization Identifier:** `AxxessPhilly`
- **Bundle Identifier:** Should auto-fill as `AxxessPhilly.DoseTrack`
- **Interface:** **SwiftUI**
- **Storage:** **SwiftData**
- **Language:** Swift
- **Include Tests:** ✓ (checked)

Click **Next**

## Step 3: Save Location

- Navigate to: `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/`
- **IMPORTANT:** Uncheck "Create Git repository" (we already have one)
- Click **Create**

## Step 4: Delete Default Files

In Xcode's left sidebar, **DELETE** these auto-generated files (Move to Trash):
- `ContentView.swift`
- `Item.swift`  
- The default `DoseTrackApp.swift` (we'll replace it)

## Step 5: Add Real Swift Files

1. **Right-click on "DoseTrack" folder** (yellow folder icon) → **Add Files to "DoseTrack"...**
2. Navigate to: `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/ios/`
3. **Select ALL `.swift` files** (⌘A to select all)
4. **IMPORTANT Settings:**
   - ✗ **UNCHECK** "Copy items if needed" (they're already in the right place)
   - ✓ **CHECK** "Add to targets: DoseTrack"
5. Click **Add**

## Step 6: Add HealthKit Privacy Descriptions

1. Click the **blue "DoseTrack" project icon** at the top of the left sidebar
2. Select the **"DoseTrack" target** (under TARGETS, not PROJECT)
3. Go to the **"Info" tab**
4. Under "Custom iOS Target Properties", click the **"+"** button
5. Add these two entries:

**First Entry:**
- Key: `Privacy - Health Share Usage Description`
  (or type: `NSHealthShareUsageDescription`)
- Value: `DoseTrack needs access to your sleep data to automatically detect when you wake up.`

**Second Entry:**  
- Key: `Privacy - Health Update Usage Description`
  (or type: `NSHealthUpdateUsageDescription`)
- Value: `DoseTrack may write sleep-related data for dose tracking.`

## Step 7: Add HealthKit Capability

1. Still in the DoseTrack target settings
2. Go to the **"Signing & Capabilities" tab**
3. Click the **"+ Capability"** button
4. Search for and add: **HealthKit**

## Step 8: Select iPhone Simulator

At the top of Xcode (toolbar):
- Click where it says **"My Mac"** or the current destination
- Select: **iPhone 15 Pro** (or any iPhone running iOS 17+)

## Step 9: Build and Run!

Press **⌘R** (Command+R) to build and run

The app should launch in the simulator showing:
- Tonight plan (Dose 1 and Dose 2)
- "Dose 1 now" and "Dose 2 now" buttons
- "Autofill wake from Health" button
- "Export CSV" button

## Troubleshooting

**If you see build errors:**
- Make sure you selected **iOS** (not macOS) in Step 1
- Make sure all Swift files are checked under "Target Membership"
- Make sure HealthKit privacy descriptions are added

**If the app crashes on launch:**
- Check that both HealthKit privacy keys are in the Info tab
- Check that HealthKit capability is added

---

**You're creating an iOS app, so iOS must be
