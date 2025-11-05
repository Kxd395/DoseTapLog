#!/usr/bin/env python3
"""
Add missing Swift files to DoseTrackNew Xcode project
"""
import re
import sys
import uuid

PROJECT_FILE = "/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackNew/DoseTrackNew.xcodeproj/project.pbxproj"

FILES_TO_ADD = [
    "GuardNoWakeSheet.swift",
    "../../ios/HealthExportBridge+Compression.swift",
    "../../ios/EncryptionSettingsView.swift"
]

def generate_uuid():
    """Generate Xcode-style 24-character hex ID"""
    return uuid.uuid4().hex[:24].upper()

def add_file_to_project(project_content, filename):
    """Add a Swift file to Xcode project"""
    
    # Generate UUIDs for file reference and build file
    file_ref_id = generate_uuid()
    build_file_id = generate_uuid()
    
    print(f"Adding {filename}...")
    print(f"  FileRef ID: {file_ref_id}")
    print(f"  BuildFile ID: {build_file_id}")
    
    # Extract just the filename (no path)
    basename = filename.split('/')[-1]
    
    # 1. Add PBXFileReference
    file_ref = f"""\t\t{file_ref_id} /* {basename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {basename}; sourceTree = "<group>"; }};"""
    
    # Find the PBXFileReference section and add our entry
    file_ref_section = re.search(r'(\/\* Begin PBXFileReference section \*\/.*?)(\/\* End PBXFileReference section \*\/)', project_content, re.DOTALL)
    if file_ref_section:
        insertion_point = file_ref_section.end(1)
        project_content = project_content[:insertion_point] + "\n" + file_ref + "\n" + project_content[insertion_point:]
    
    # 2. Add PBXBuildFile
    build_file = f"""\t\t{build_file_id} /* {basename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {basename} */; }};"""
    
    build_file_section = re.search(r'(\/\* Begin PBXBuildFile section \*\/.*?)(\/\* End PBXBuildFile section \*\/)', project_content, re.DOTALL)
    if build_file_section:
        insertion_point = build_file_section.end(1)
        project_content = project_content[:insertion_point] + "\n" + build_file + "\n" + project_content[insertion_point:]
    
    # 3. Add to PBXGroup (DoseTrackNew group)
    # Find the DoseTrackNew group and add file reference
    group_pattern = r'(\/\* DoseTrackNew \*\/ = \{[^}]+children = \([^)]+)(\/\* Models.swift \*/,)'
    match = re.search(group_pattern, project_content, re.DOTALL)
    if match:
        insertion = f"\n\t\t\t\t{file_ref_id} /* {basename} */,"
        project_content = project_content[:match.end(1)] + insertion + "\n\t\t\t\t" + project_content[match.end(1):]
    
    # 4. Add to PBXSourcesBuildPhase
    sources_pattern = r'(\/\* Sources \*\/ = \{[^}]+files = \([^)]+)'
    match = re.search(sources_pattern, project_content, re.DOTALL)
    if match:
        insertion = f"\n\t\t\t\t{build_file_id} /* {basename} in Sources */,"
        project_content = project_content[:match.end(1)] + insertion + "\n\t\t\t\t" + project_content[match.end(1):]
    
    return project_content

def main():
    print("Reading Xcode project file...")
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    original_content = content
    
    for filename in FILES_TO_ADD:
        content = add_file_to_project(content, filename)
    
    # Backup original
    backup_file = PROJECT_FILE + ".backup"
    print(f"\nBacking up original to {backup_file}")
    with open(backup_file, 'w') as f:
        f.write(original_content)
    
    # Write modified
    print(f"Writing modified project to {PROJECT_FILE}")
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)
    
    print("\n✅ Successfully added files to Xcode project!")
    print("Files added:")
    for f in FILES_TO_ADD:
        print(f"  - {f}")

if __name__ == "__main__":
    main()
