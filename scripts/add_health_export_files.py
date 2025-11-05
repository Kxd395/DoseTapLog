#!/usr/bin/env python3
"""
Add Health Export v2 files to DoseTrackNew Xcode project.
This script adds all missing Swift files from the ios/ directory.
"""

import sys
import os

# Add parent directory to path for xcodeproj module
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(script_dir)

try:
    from pbxproj import XcodeProject
except ImportError:
    print("❌ Error: pbxproj module not found")
    print("   Install with: pip3 install pbxproj")
    sys.exit(1)

# Files to add from ios/ directory
NEW_FILES = [
    'AlarmOrchestrator.swift',
    'DoseLogExporter.swift',
    'EncryptionSettingsView.swift',
    'GuardNoWakeSheet.swift',
    'HealthExportBridge.swift',
    'HealthExportBridge+Anchors.swift',
    'HealthExportBridge+Compression.swift',
    'HealthExportBridge+Steps.swift',
    'HealthExportBridge+TwoPhaseCommit.swift',
    'ModernStatusChipRow.swift',
    'ServiceDayMaxOverlap.swift',
    'WakeSheetView.swift',
    'WindowState.swift',
]

def main():
    # Path to Xcode project
    project_path = os.path.join(project_root, 'DoseTrackNew/DoseTrackNew.xcodeproj/project.pbxproj')
    
    if not os.path.exists(project_path):
        print(f"❌ Error: Project file not found at {project_path}")
        sys.exit(1)
    
    print(f"📦 Opening Xcode project: {project_path}")
    project = XcodeProject.load(project_path)
    
    # Get the main target
    if not project.objects.get_targets():
        print("❌ Error: No targets found in project")
        sys.exit(1)
    
    target = project.objects.get_targets()[0]
    print(f"🎯 Target: {target.name}")
    
    # Add each file
    added_count = 0
    skipped_count = 0
    
    for filename in NEW_FILES:
        # Check if file exists in ios/ directory
        source_path = os.path.join(project_root, 'ios', filename)
        if not os.path.exists(source_path):
            print(f"⚠️  Skipping {filename} (not found in ios/)")
            continue
        
        # Check if already in project
        existing_files = project.objects.get_files_by_name(filename)
        if existing_files:
            print(f"⏭️  Skipping {filename} (already in project)")
            skipped_count += 1
            continue
        
        # Add file to project
        try:
            # Use relative path from DoseTrackNew/DoseTrackNew/ to ios/
            relative_path = f"../../ios/{filename}"
            project.add_file(relative_path, parent=project.get_or_create_group('DoseTrackNew'))
            print(f"✅ Added {filename}")
            added_count += 1
        except Exception as e:
            print(f"❌ Error adding {filename}: {e}")
    
    # Save project
    if added_count > 0:
        print(f"\n💾 Saving project...")
        project.save()
        print(f"✅ Successfully added {added_count} file(s) to Xcode project")
        print(f"⏭️  Skipped {skipped_count} file(s) (already in project)")
    else:
        print(f"\n✅ No new files to add ({skipped_count} already in project)")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
