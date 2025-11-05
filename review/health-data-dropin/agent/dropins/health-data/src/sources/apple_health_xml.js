const fs = require("node:fs");
const path = require("node:path");
const { parseStringPromise } = require("xml2js");

async function ingest(xmlPath, outDir, opts = {}) {
  const xml = fs.readFileSync(xmlPath, "utf8");
  const data = await parseStringPromise(xml, { explicitArray: false });
  const recs = [];
  const rows = data?.HealthData?.Record ?? [];
  const arr = Array.isArray(rows) ? rows : [rows];

  for (const r of arr) {
    if (!r || !r.$) continue;
    const type = r.$.type || "";
    const start = r.$.startDate;
    const end = r.$.endDate;
    if (!start || !end) continue;

    const pushRec = (record_type, value) => {
      recs.push({
        source: "apple_xml",
        record_type,
        start_utc: start,
        end_utc: end,
        value,
        metadata: {}
      });
    };

    if (type.includes("SleepAnalysis")) {
      pushRec("sleep", null);
    } else if (type.includes("HeartRate")) {
      pushRec("hr", Number(r.$.value));
    } else if (type.includes("HeartRateVariabilitySDNN")) {
      pushRec("hrv", Number(r.$.value));
    } else if (type.includes("RespiratoryRate")) {
      pushRec("respiratory_rate", Number(r.$.value));
    }
  }
  const out = path.join(outDir, `apple_xml_${Date.now()}.jsonl`);
  fs.writeFileSync(out, recs.map(r => JSON.stringify(r)).join("\n"));
  return out;
}

module.exports = { ingest };
