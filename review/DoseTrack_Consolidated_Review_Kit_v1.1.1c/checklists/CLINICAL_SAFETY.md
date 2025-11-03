# CLINICAL SAFETY CHECKLIST - DoseTrack v1.1.1c

- [ ] Per dose min and max: 1.5 g to 4.5 g
- [ ] Total nightly min and max: 3.0 g to 9.0 g
- [ ] Dose 2 window start: 150 minutes after Dose 1
- [ ] Dose 2 window end: 240 minutes after Dose 1
- [ ] Rounding policy: 0.25 g only at display and save
- [ ] Internal calculations remain full precision Double
- [ ] Recommender never suggests values outside guardrails
- [ ] Validation blocks saving if Dose 2 precedes Dose 1
- [ ] CSV uses HH:mm in local offset and one row per night
- [ ] Final wake provenance recorded when autofilled
