#!/usr/bin/env ruby
# Add Health Export v2 files to DoseTrackNew Xcode project

require 'xcodeproj'

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

project_path = 'DoseTrackNew/DoseTrackNew.xcodeproj'
puts "📦 Opening Xcode project: #{project_path}"

project = Xcodeproj::Project.open(project_path)
target = project.targets.first
puts "🎯 Target: #{target.name}"

# Get the DoseTrackNew group
group = project.main_group['DoseTrackNew']
unless group
  puts "❌ Error: Could not find DoseTrackNew group"
  exit 1
end

added_count = 0
skipped_count = 0

NEW_FILES.each do |filename|
  # Check if file exists
  source_path = "../../ios/#{filename}"
  full_path = File.join(File.dirname(project_path), 'DoseTrackNew', source_path)
  
  unless File.exist?(full_path)
    puts "⚠️  Skipping #{filename} (not found at #{full_path})"
    next
  end
  
  # Check if already in project
  existing = group.files.find { |f| f.path == filename }
  if existing
    puts "⏭️  Skipping #{filename} (already in project)"
    skipped_count += 1
    next
  end
  
  # Add file to project
  begin
    file_ref = group.new_file(source_path)
    target.add_file_references([file_ref])
    puts "✅ Added #{filename}"
    added_count += 1
  rescue => e
    puts "❌ Error adding #{filename}: #{e.message}"
  end
end

# Save project
if added_count > 0
  puts "\n💾 Saving project..."
  project.save
  puts "✅ Successfully added #{added_count} file(s) to Xcode project"
  puts "⏭️  Skipped #{skipped_count} file(s) (already in project)"
else
  puts "\n✅ No new files to add (#{skipped_count} already in project)"
end

puts "\n🏗️  Next steps:"
puts "   1. Open DoseTrackNew.xcodeproj in Xcode"
puts "   2. Build the project (⌘B)"
puts "   3. Fix any remaining compilation errors"
