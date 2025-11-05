const fs = require("node:fs");
const path = require("node:path");

async function pull(syncDir, outDir, opts = {}) {
  if (!syncDir) throw new Error("HEALTH_SYNC_DIR or ANDROID_SYNC_DIR is not set");
  const files = fs.readdirSync(syncDir).filter(f => f.startsWith("healthconnect_export") && f.endsWith(".json"));
  for (const f of files) {
    const src = path.join(syncDir, f);
    const dst = path.join(outDir, f);
    fs.copyFileSync(src, dst);
  }
  return files.length;
}

module.exports = { pull };
