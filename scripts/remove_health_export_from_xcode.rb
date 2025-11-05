#!/usr/bin/env ruby
# Remove Health Export v2 files from DoseTrackNew Xcode project
# These files are meant to be standalone, not part of the iOS app

require 'xcodeproj'

# Files to remove (they're in ios/ but shouldn't be in the Xcode project)
FILES_TO_REMOVE = [
  'HealthExportBridge.swift',
  'HealthExportBridge+Anchors.swift',
  'HealthExportBridge+Compression.swift',
  'HealthExportBridge+Steps.swift',
  'HealthExportBridge+TwoPhaseCommit.swift',
  'DoseLogExporter.swift',
  'EncryptionSettingsView.swift',
  'ServiceDayMaxOverlap.swift',
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

removed_count = 0

FILES_TO_REMOVE.each do |filename|
  # Find file reference
  file_ref = group.files.find { |f| f.path&.end_with?(filename) }
  
  if file_ref
    # Remove from build phase
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        target.source_build_phase.files.delete(build_file)
      end
    end
    
    # Remove from group
    file_ref.remove_from_project
    puts "✅ Removed #{filename}"
    removed_count += 1
  else
    puts "⏭️  Skipping #{filename} (not found in project)"
  end
end

# Save project
if removed_count > 0
  puts "\n💾 Saving project..."
  project.save
  puts "✅ Successfully removed #{removed_count} file(s) from Xcode project"
  puts "\n📝 Note: These files remain in ios/ directory for standalone use"
else
  puts "\n✅ No files needed removal"
end
