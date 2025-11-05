#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
require("dotenv").config();
const appleXml = require("./sources/apple_health_xml.js");
const hk = require("./sources/healthkit_json.js");
const hc = require("./sources/healthconnect_json.js");
const { normalizeUnifiedToNightFeatures } = require("./util/normalize.js");

const args = process.argv.slice(2);
const cmd = args[0];
const params = Object.fromEntries(args.slice(1).map(a => {
  const [k, v = "true"] = a.replace(/^--/, "").split("=");
  return [k, v];
}));

const REPO_ROOT = path.resolve(__dirname, "../../../..");
const RAW = path.join(REPO_ROOT, "ml", "datasets", "raw", "health");
const FEAT = path.join(REPO_ROOT, "ml", "datasets", "features");
fs.mkdirSync(RAW, { recursive: true });
fs.mkdirSync(FEAT, { recursive: true });

async function pull(source) {
  switch (source) {
    case "healthkit_json":
      return hk.pull(process.env.HEALTH_SYNC_DIR, RAW, params);
    case "healthconnect_json":
      return hc.pull(process.env.ANDROID_SYNC_DIR || process.env.HEALTH_SYNC_DIR, RAW, params);
    case "apple_health_xml":
      if (!params.file) throw new Error("--file=/path/to/export.xml required");
      return appleXml.ingest(params.file, RAW, params);
    default:
      throw new Error(`Unknown source: ${source}`);
  }
}

(async () => {
  try {
    if (cmd === "status") {
      console.log("HEALTH_SYNC_DIR:", process.env.HEALTH_SYNC_DIR || "(unset)");
      console.log("ANDROID_SYNC_DIR:", process.env.ANDROID_SYNC_DIR || "(unset)");
      process.exit(0);
    }
    if (cmd === "pull") {
      if (!params.source) throw new Error("--source=healthkit_json|healthconnect_json|apple_health_xml required");
      await pull(params.source);
      console.log("✓ Pull complete");
      process.exit(0);
    }
    if (cmd === "normalize") {
      await normalizeUnifiedToNightFeatures(RAW, FEAT, params);
      console.log("✓ Normalize complete");
      process.exit(0);
    }
    console.log("Commands: status | pull --source=… | normalize");
  } catch (e) {
    console.error("✗ Error:", e.message);
    process.exit(1);
  }
})();
