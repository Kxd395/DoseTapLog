# Health Data Drop-in (Agent)

Ingest **Apple Health / HealthKit**, **Android Health Connect / Google Fit**, and **Apple Health XML** into a **unified JSONL** format and emit **night-level features** for your ML pipeline.

## What you get
- CLI to pull & normalize health exports (offline/local).
- Cross-platform bridges (iOS/Android) to dump JSON exports into a sync folder.
- JSON Schemas for unified records and night features.

## Quick start
1) `cd agent/dropins/health-data`
2) `npm i`
3) Copy `example.env` to `.env` and set `HEALTH_SYNC_DIR` (e.g., iCloud Drive path where your app exports to).
4) Run:
```
npm run status
npm run pull:ios
npm run pull:android
npm run ingest:apple-xml -- --file=/path/to/export.xml
npm run normalize
```

Raw outputs land in: `ml/datasets/raw/health/`
Features land in: `ml/datasets/features/`

## Privacy
- Local-only processing. No network calls.
- Optional timestamp fuzzing (`--fuzz-min=10`) possible to de-identify.

See `agent.dropin.yaml` for agent integration and `package.json` for npm scripts.
