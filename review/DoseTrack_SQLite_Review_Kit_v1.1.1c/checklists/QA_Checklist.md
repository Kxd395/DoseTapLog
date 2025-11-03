# QA Checklist

- [ ] sqlite3 version recorded
- [ ] Fresh DB created without errors
- [ ] PRAGMA foreign_keys=ON is effective
- [ ] All tables created as expected
- [ ] Triggers exist and are active
- [ ] Invalid per dose inserts are rejected
- [ ] Invalid nightly total inserts are rejected
- [ ] Invalid dose2 window is rejected
- [ ] Valid path passes end to end
- [ ] v_clinician_csv returns expected columns and rows
- [ ] v_sleep_data_quality view returns expected flags
- [ ] Indices exist for common queries
- [ ] Example export to CSV created and opened
