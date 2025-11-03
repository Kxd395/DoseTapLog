#!/bin/bash
# Quick script to open the new DoseTrack project in Xcode

echo "🚀 Opening DoseTrackNew in Xcode..."
echo ""
echo "✅ This project has ALL the new features:"
echo "   - Reset Night button"
echo "   - Late Dose Override"
echo "   - Safety Banners"
echo "   - All 28 Swift files from ios/"
echo ""
echo "📖 Setup guide: docs/ops/DOSETRACK_NEW_SETUP.md"
echo ""

open /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackNew/DoseTrackNew.xcodeproj

echo "✅ Xcode should open in a few seconds!"
echo ""
echo "🔧 Remember to:"
echo "   1. Set your Apple ID as Team (Signing & Capabilities)"
echo "   2. Change Bundle ID to com.YOURNAME.DoseTrackNew"
echo "   3. Add HealthKit capability (+ Capability button)"
echo "   4. Press ⌘+R to build and run!"
