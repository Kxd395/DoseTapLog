# P0 No-Ship-Unless Gates

- [ ] Two-phase anchor commit with crash recovery (Swift) — implemented & tested
- [ ] Deletion tombstones cascade — normalizer removes contributions + recomputes rolling windows
- [ ] Service-day max-overlap rule — Swift & JS parity (100 random cases) pass 100%
- [ ] Compression format consistent end-to-end (gzip) — extension matches; CI verified
- [ ] Steps totals via HKStatisticsCollection — overlap-free aggregates
- [ ] Encryption UX shippable — PBKDF2, rotation, RAM wipe, strength meter, keychain storage
- [ ] Export manifest contains per-type counts, anchor tokens (base64), blob SHA-256
- [ ] Join invariant enforced — night_key (DoseLog) == service_day_key (Health); rebucket tool documented

## Attachments Required
- Link to parity report and cases
- Screenshot(s) of Encryption Settings UI
- xcodebuild test logs (anchors/DST/service-day)
- Agent normalize logs (tombstone cascade)
- Sample export (.jsonl.gz) and final manifest
