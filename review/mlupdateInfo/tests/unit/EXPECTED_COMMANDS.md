# Unit/Integration Test Commands (Expected)

## Swift (Xcode)
xcodebuild test \
  -scheme DoseTrackNew \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:HealthExportBridgeTests \
  -only-testing:ServiceDayMaxOverlapTests

## Node (Agent)
cd review/health-data-dropin/agent/dropins/health-data
npm install

# Validate schemas
npm run validate

# Run normalize with logs
NODE_ENV=test node src/ingest.js normalize \  --input ../../../../ml/datasets/raw/health \  --output ../../../../ml/datasets/features \  --log-file {base}/runtime_artifacts/logs/normalize.log
