const fs = require("node:fs");
const path = require("node:path");
const Ajv = require("ajv");
const addFormats = require("ajv-formats");

const ajv = new Ajv();
addFormats(ajv);

// Load schemas
const unifiedSchema = require("../../schemas/unified_health.schema.json");
const featuresSchema = require("../../schemas/night_features.schema.json");
const validateUnified = ajv.compile(unifiedSchema);
const validateFeatures = ajv.compile(featuresSchema);

function parseLines(file) {
  const text = fs.readFileSync(file, "utf8");
  return text.trim().length ? text.trim().split(/\n/).map(l => JSON.parse(l)) : [];
}

async function normalizeUnifiedToNightFeatures(rawDir, featDir, opts = {}) {
  const files = fs.readdirSync(rawDir).filter(f => f.endsWith(".json") || f.endsWith(".jsonl"));
  const perNight = {};
  const seen = new Set(); // dedupe by sha1
  const errors = [];
  
  // Load all health records
  for (const f of files) {
    if (f.startsWith("dosetrack_export")) continue; // skip, handle separately
    
    const full = path.join(rawDir, f);
    const lines = f.endsWith(".jsonl") ? parseLines(full) : fs.readFileSync(full, "utf8").trim().split(/\n/).map(l => JSON.parse(l));
    
    for (const r of lines) {
      // Validate schema
      if (!validateUnified(r)) {
        errors.push({ file: f, record: r, errors: validateUnified.errors });
        continue;
      }
      
      // Dedupe by sha1
      if (seen.has(r.sha1)) continue;
      seen.add(r.sha1);
      
      // Use service_day_key from exporter (NOT midnight bucketing)
      const k = r.service_day_key;
      perNight[k] ||= initNight(k);
      accumulate(perNight[k], r);
    }
  }
  
  // Load DoseLog exports
  const dosetrackFiles = fs.readdirSync(rawDir).filter(f => f.startsWith("dosetrack_export") && (f.endsWith(".json") || f.endsWith(".jsonl")));
  for (const f of dosetrackFiles) {
    const full = path.join(rawDir, f);
    const lines = parseLines(full);
    for (const n of lines) {
      const k = n.night_key;
      perNight[k] ||= initNight(k);
      enrichWithDoseLog(perNight[k], n);
    }
  }
  
  // Compute rolling windows (adherence7d, overrideCount7d, bedtimeStdDev14d, dose12Interval7d)
  const sorted = Object.values(perNight).sort((a, b) => a.night_key.localeCompare(b.night_key));
  for (let i = 0; i < sorted.length; i++) {
    computeRollingFeatures(sorted, i);
  }
  
  // Validate features
  const validated = sorted.filter(n => {
    if (!validateFeatures(n)) {
      errors.push({ night_key: n.night_key, errors: validateFeatures.errors });
      return false;
    }
    return true;
  });
  
  // Write output
  const out = path.join(featDir, `night_features_${Date.now()}.jsonl`);
  fs.mkdirSync(featDir, { recursive: true });
  fs.writeFileSync(out, validated.map(o => JSON.stringify(o)).join("\n"));
  
  // Write error log
  if (errors.length > 0) {
    const errOut = path.join(featDir, `errors_${Date.now()}.json`);
    fs.writeFileSync(errOut, JSON.stringify(errors, null, 2));
    console.warn(`⚠️  ${errors.length} validation errors → ${errOut}`);
  }
  
  return out;
}

function initNight(nightKey) {
  const dow = new Date(nightKey + "T00:00:00Z").getUTCDay();
  return {
    night_key: nightKey,
    dow,
    adherence7d: 0,
    overrideCount7d: 0,
    bedtimeStdDevMin14d: 0,
    isWorkday: false, // TODO: integrate with WeeklySchedule
    sleepDurationMin: null,
    wakeCount: null,
    dose12IntervalMin7dAvg: null,
    dose12IntervalMin7dStd: null,
    whoopRecoveryPct: null,
    hrvScore: null,
    _raw: { sleep: [], hr: [], hrv: [], spo2: [], steps: [], naps: [], wakes: [], doses: [] }
  };
}

function accumulate(night, rec) {
  switch (rec.record_type) {
    case "sleep":
      night._raw.sleep.push(rec);
      break;
    case "nap":
      night._raw.naps.push(rec);
      break;
    case "hr":
      night._raw.hr.push(rec);
      break;
    case "hrv":
      night._raw.hrv.push(rec);
      if (typeof rec.value === "number") {
        night.hrvScore = night.hrvScore ? Math.max(night.hrvScore, rec.value) : rec.value; // max HRV for night
      }
      break;
    case "spo2":
      night._raw.spo2.push(rec);
      break;
    case "step":
      night._raw.steps.push(rec);
      break;
  }
}

function enrichWithDoseLog(night, doseLog) {
  night._raw.doses.push(doseLog);
  
  // Wake count
  if (doseLog.wake_events && Array.isArray(doseLog.wake_events)) {
    night.wakeCount = doseLog.wake_events.length;
    night._raw.wakes = doseLog.wake_events;
  }
}

function computeRollingFeatures(sorted, idx) {
  const night = sorted[idx];
  const nightKey = night.night_key;
  
  // Get last 7 days (including today)
  const last7 = sorted.slice(Math.max(0, idx - 6), idx + 1);
  const last14 = sorted.slice(Math.max(0, idx - 13), idx + 1);
  
  // Adherence7d: fraction with both doses
  const withBothDoses = last7.filter(n => n._raw.doses.some(d => d.dose1_utc && d.dose2_utc)).length;
  night.adherence7d = last7.length > 0 ? withBothDoses / last7.length : 0;
  
  // OverrideCount7d
  night.overrideCount7d = last7.reduce((sum, n) => {
    return sum + n._raw.doses.filter(d => d.dose2_is_override).length;
  }, 0);
  
  // BedtimeStdDevMin14d
  const bedtimes = last14.flatMap(n => n._raw.doses.filter(d => d.bedtime_utc).map(d => new Date(d.bedtime_utc)));
  if (bedtimes.length >= 2) {
    const minutesOfDay = bedtimes.map(d => d.getUTCHours() * 60 + d.getUTCMinutes());
    const mean = minutesOfDay.reduce((a, b) => a + b, 0) / minutesOfDay.length;
    const variance = minutesOfDay.reduce((sum, m) => sum + Math.pow(m - mean, 2), 0) / minutesOfDay.length;
    night.bedtimeStdDevMin14d = Math.sqrt(variance);
  }
  
  // Dose 1→2 interval stats (7d)
  const intervals = last7.flatMap(n => {
    return n._raw.doses
      .filter(d => d.dose1_utc && d.dose2_utc)
      .map(d => {
        const d1 = new Date(d.dose1_utc);
        const d2 = new Date(d.dose2_utc);
        return (d2 - d1) / 60000; // minutes
      });
  });
  if (intervals.length > 0) {
    night.dose12IntervalMin7dAvg = intervals.reduce((a, b) => a + b, 0) / intervals.length;
    if (intervals.length >= 2) {
      const mean = night.dose12IntervalMin7dAvg;
      const variance = intervals.reduce((sum, i) => sum + Math.pow(i - mean, 2), 0) / intervals.length;
      night.dose12IntervalMin7dStd = Math.sqrt(variance);
    }
  }
  
  // Sleep duration (sum of all sleep records for this night)
  const sleepDurations = night._raw.sleep.map(s => {
    const start = new Date(s.start_utc);
    const end = new Date(s.end_utc);
    return (end - start) / 60000; // minutes
  });
  if (sleepDurations.length > 0) {
    night.sleepDurationMin = sleepDurations.reduce((a, b) => a + b, 0);
  }
  
  // Clean up _raw before export (optional, can keep for debugging)
  // delete night._raw;
}

module.exports = { normalizeUnifiedToNightFeatures };
