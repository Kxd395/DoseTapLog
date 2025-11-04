# iOS Build Checklist

- macOS: run
  - xcodebuild -list
  - xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15' build
- Optional lint
  - if command -v swiftformat; then swiftformat --lint ios/; fi
- Capture outputs to review/RepoReview/output/logs/
