# 🚀 HOW TO RUN THE APP

**Status:** ✅ Build succeeded, app installed  
**Issue:** App not launching from command line  
**Solution:** Use Xcode to run it

---

## ✅ WHAT WE VERIFIED

1. ✅ Build succeeded
2. ✅ App bundle created at:
   ```
   ~/Library/Developer/Xcode/DerivedData/DoseTrackIOS-.../
   Build/Products/Debug-iphonesimulator/DoseTrackIOS.app
   ```
3. ✅ App installed to simulator
4. ✅ Bundle ID: `AxxessPhilly.DoseTrackIOS`
5. ✅ iPhone 17 Pro simulator is running

---

## 🎯 EASIEST WAY TO RUN: USE XCODE

### Method 1: Run from Xcode (RECOMMENDED)

**In Xcode (which you have open):**

1. **Select the scheme:**
   - Top bar should show "DoseTrackIOS" 
   - Next to it, select "iPhone 17 Pro" (or any simulator)

2. **Click the Play button or press ⌘R**
   - This will build AND launch the app
   - The simulator will open/focus
   - The app will launch automatically

3. **Wait a few seconds**
   - App should appear on the simulator home screen
   - Should launch automatically

---

## 🔧 METHOD 2: Manual Launch from Command Line

If Xcode doesn't work, try this in terminal:

```bash
# Open the simulator (if not already open)
open -a Simulator

# Launch the app
xcrun simctl launch booted AxxessPhilly.DoseTrackIOS
```

---

## 🔍 WHY THE APP DIDN'T SHOW AUTOMATICALLY

**What you did:**
```bash
xcodebuild ... build
```

**What this does:**
- ✅ Compiles the code
- ✅ Creates the .app bundle
- ❌ Does NOT install to simulator
- ❌ Does NOT launch the app

**What you need:**
```bash
# In Xcode: Press ⌘R (Run)
# OR from terminal:
xcodebuild ... build install
# THEN manually launch
```

**But the easiest way is just pressing ⌘R in Xcode!**

---

## 📱 EXPECTED RESULT

When you run the app (via Xcode ⌘R), you should see:

1. **Build progress** - "Building DoseTrackIOS..."
2. **Simulator launches** - iPhone 17 Pro opens
3. **App installs** - DoseTrackIOS icon appears
4. **App launches** - App opens automatically
5. **UI displays** - You should see the Today view with:
   - Night key/date info
   - Dose 1 and Dose 2 buttons
   - Safety banner
   - Settings gear icon

---

## ⚠️ IF APP CRASHES IMMEDIATELY

If the app launches but crashes, check:

1. **Console output in Xcode**
   - View → Debug Area → Show Debug Area
   - Look for error messages

2. **Common issues:**
   - SwiftData model issues
   - Missing entitlements
   - Permission issues (HealthKit)

3. **Quick fixes:**
   - Product → Clean Build Folder (⇧⌘K)
   - Rebuild (⌘B)
   - Try again (⌘R)

---

## 🎯 STEP-BY-STEP: RUN FROM XCODE

**Looking at your Xcode window:**

1. **Top toolbar** (where it says "DoseTrackIOS" and "iPhone 17 Pro"):
   - Verify "DoseTrackIOS" is selected as the scheme
   - Verify "iPhone 17 Pro" is selected as destination

2. **Click the triangular PLAY button** (▶️) 
   - Or press ⌘R on keyboard
   - Located in top-left area of Xcode

3. **Watch the build progress:**
   - Top center will show "Building DoseTrackIOS"
   - Wait for it to finish (~10-30 seconds)

4. **App should launch automatically:**
   - Simulator will come to foreground
   - App icon appears
   - App opens

---

## 🐛 TROUBLESHOOTING

### "No such module 'SwiftData'"
**Fix:** 
- File → Project Settings → Package Dependencies
- Build Settings → Deployment Target → iOS 17.0+

### "Could not launch DoseTrackIOS"
**Fix:**
- Simulator → Device → Erase All Content and Settings
- Try running again

### "App installs but doesn't launch"
**Fix:**
- On simulator, manually tap the DoseTrackIOS icon
- Or: xcrun simctl launch booted AxxessPhilly.DoseTrackIOS

### "Build succeeds but nothing happens"
**Fix:**
- Make sure you're clicking RUN (▶️) not just Build (🔨)
- Run = Build + Install + Launch
- Build = Just compile

---

## ✅ QUICK CHECK

Before running, verify in Xcode:

- [ ] Scheme: DoseTrackIOS (top bar)
- [ ] Destination: iPhone 17 Pro (or any simulator)
- [ ] No build errors shown
- [ ] Simulator app is open
- [ ] Click Play button (▶️) or press ⌘R

---

## 🎉 WHAT YOU SHOULD SEE

**On successful launch:**

```
iPhone 17 Pro Simulator
┌─────────────────────────┐
│  ☰  DoseTrack        ⚙️ │  ← Navigation bar with settings
├─────────────────────────┤
│                         │
│  Night: 2025-11-02      │  ← Current night session
│                         │
│  ┌───────────────────┐  │
│  │  Dose 1: X.XXg    │  │  ← Dose amounts
│  │  Dose 2: X.XXg    │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │ [In bed now]      │  │  ← Action buttons
│  │ [Dose 1 now]      │  │
│  │ [Dose 2 now]      │  │
│  └───────────────────┘  │
│                         │
│  Safety Status: ✓       │  ← Safety banner
│                         │
└─────────────────────────┘
```

---

## 🚀 NEXT STEPS AFTER LAUNCH

Once the app is running:

1. **Test basic navigation:**
   - Tap settings gear (⚙️)
   - Settings panel should open

2. **Test dose tracking:**
   - Tap "In bed now"
   - Tap "Dose 1 now"
   - Verify events are logged

3. **Check for crashes:**
   - Navigate around
   - Watch Xcode console for errors

4. **Report any issues:**
   - Note exact error messages
   - Check crash logs
   - Review console output

---

## 📞 QUICK REFERENCE

**Bundle ID:** `AxxessPhilly.DoseTrackIOS`  
**Simulator:** iPhone 17 Pro (D5F74E3B-82C5-4175-9BCF-84EB2CB884DD)  
**Build Location:** `~/Library/Developer/Xcode/DerivedData/DoseTrackIOS-*/Build/Products/Debug-iphonesimulator/`

**Xcode Commands:**
- Build: ⌘B
- Run: ⌘R
- Stop: ⌘.
- Clean: ⇧⌘K

**Terminal Commands:**
```bash
# Launch app on booted simulator
xcrun simctl launch booted AxxessPhilly.DoseTrackIOS

# Open simulator
open -a Simulator

# Install app to simulator
xcrun simctl install booted /path/to/DoseTrackIOS.app
```

---

**TL;DR: Just press ⌘R in Xcode and the app should launch! 🚀**
