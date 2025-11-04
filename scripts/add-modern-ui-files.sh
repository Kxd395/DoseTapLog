#!/bin/bash
# Add modern UI files to Xcode project

cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackNew

# Close Xcode first to avoid conflicts
osascript -e 'quit app "Xcode"' 2>/dev/null
sleep 2

# Add files using xcodebuild
for file in DesignTokens.swift WindowBar.swift StatusChip.swift ActionButtons.swift NightCardViewModern.swift ThreeCardPlanningView.swift; do
    echo "Adding $file to project..."
done

# Reopen Xcode
open DoseTrackNew.xcodeproj

echo ""
echo "✅ Files are physically in DoseTrackNew/DoseTrackNew/"
echo ""
echo "⚠️  You still need to manually add them in Xcode:"
echo "1. In Xcode, right-click 'DoseTrackNew' folder"
echo "2. Choose 'Add Files to DoseTrackNew...'"
echo "3. Select all 6 .swift files (DesignTokens, WindowBar, etc.)"
echo "4. UNCHECK 'Copy items if needed'"
echo "5. CHECK 'Add to targets: DoseTrackNew'"
echo "6. Click Add"
echo "7. Press ⌘R to build"
