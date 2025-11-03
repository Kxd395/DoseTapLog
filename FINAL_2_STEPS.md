# ✅ Almost Done! Just 2 Quick Steps in Xcode

I've already:
- ✅ Deleted the default template files
- ✅ Copied all 12 DoseTrack Swift files to your project folder

## You need to do these 2 things:

### Step 1: Add Files to Xcode Target (30 seconds)

In Xcode's left sidebar:
1. **Right-click on the "DoseTrackIOS" folder** (yellow folder icon)
2. Select **"Add Files to 'DoseTrackIOS'..."**
3. Navigate to: `/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackIOS/DoseTrackIOS/`
4. Press **⌘A** to select all 12 `.swift` files
5. **IMPORTANT Settings:**
   - ✗ **UNCHECK** "Copy items if needed" (they're already there!)
   - ✓ **CHECK** "Add to targets: DoseTrackIOS"
6. Click **Add**

### Step 2: Add HealthKit Privacy Descriptions (1 minute)

1. Click the **blue "DoseTrackIOS" project icon** at the very top of the left sidebar
2. Select **"DoseTrackIOS" target** (under TARGETS in the middle panel)
3. Click the **"Info" tab** at the top
4. Find "Custom iOS Target Properties" section
5. Click the **"+"** button and add:

**First entry:**
- Key: `Privacy - Health Share Usage Description`
- Value: `DoseTrack needs access to your sleep data to automatically detect when you wake up.`

6. Click **"+"** again and add:

**Second entry:**
- Key: `Privacy - Health Update Usage Description`  
- Value: `DoseTrack may write sleep-related data for dose tracking.`

## Then Build!

Press **⌘R** (Command+R) to build and run.

You should see:
- Tonight plan with Dose 1 and Dose 2
- "Dose 1 now" and "Dose 2 now" buttons
- "Autofill wake from Health" button
- "Export CSV" button

That's it! 🎉
