# Alarm Wakeup Logic
Fields: alarmScheduledTimeUTC, alarmFiredAtUTC, alarmAcknowledgedAtUTC, alarmSnoozeCount, alarmStatus, alarmOrigin

Rules:
- One pending alarm per night; set replaces prior
- Snooze default 7 minutes, cap 3
- Final Wake cancels pending alarm
- If Dose 2 near alarm, shift once by preference
- CSV includes alarm columns
