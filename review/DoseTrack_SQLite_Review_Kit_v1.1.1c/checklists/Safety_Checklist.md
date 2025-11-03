# Safety Checklist

- [ ] Per dose bounds enforced by trg_med_event_bounds for Xywav
- [ ] Per night total enforced by trg_med_event_total_max for Xywav
- [ ] Dose 2 window 150 to 240 minutes enforced by trg_event_log_dose2_window
- [ ] No raw audio stored, only numeric features in environmental_survey_data
- [ ] Medication privacy via hashed name stored in events
- [ ] Soft deletes supported via deleted_at columns
- [ ] Views do not expose sensitive free text such as medication names in events
