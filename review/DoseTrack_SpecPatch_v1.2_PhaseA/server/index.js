import express from "express"
import rateLimit from "express-rate-limit"
import fetch from "node-fetch"
import dotenv from "dotenv"
dotenv.config()

const app = express()

// API key middleware
function requireApiKey(req, res, next) {
  const key = req.headers["x-api-key"]
  if (!process.env.API_KEY) {
    return res.status(500).json({ error: "server_misconfigured", detail: "API_KEY not set" })
  }
  if (key !== process.env.API_KEY) {
    return res.status(401).json({ error: "unauthorized" })
  }
  next()
}

// Rate limiter - conservative to respect vendor APIs
const limiter = rateLimit({ windowMs: 60 * 1000, limit: 30 })
app.use(limiter)

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "DoseTrack WHOOP Proxy", time: new Date().toISOString() })
})

// Generic WHOOP fetch with pagination for v2 style endpoints
async function whoopPaged(path, params = {}) {
  const base = process.env.WHOOP_BASE || "https://api.prod.whoop.com"
  const token = process.env.WHOOP_TOKEN
  if (!token) throw new Error("WHOOP_TOKEN not set")

  const search = new URLSearchParams(params)
  let url = `${base}${path}?${search.toString()}`
  let out = []
  let guard = 0

  while (url && guard < 50) {
    const r = await fetch(url, {
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" }
    })
    if (!r.ok) {
      const txt = await r.text()
      throw new Error(`WHOOP error ${r.status}: ${txt}`)
    }
    const data = await r.json()
    // v2 style often uses "records" and "next_token" - this is illustrative
    if (Array.isArray(data.records)) out.push(...data.records)
    else if (Array.isArray(data)) out.push(...data)
    const next = data.next_token || data.nextToken || null
    url = next ? `${base}${path}?next_token=${encodeURIComponent(next)}` : null
    guard += 1
  }
  return out
}

// Standardized range endpoints - the app will compute rolling averages
app.get("/api/whoop/v2/sleep/range", requireApiKey, async (req, res) => {
  try {
    const { start, end } = req.query
    if (!start || !end) return res.status(400).json({ error: "bad_request", detail: "start and end required" })
    const records = await whoopPaged("/v2/sleep", { start, end })
    // project only fields we care about
    const nights = records.map(r => ({
      id: r.id,
      cycle_id: r.cycle_id,
      start: r.start,
      end: r.end,
      stage_summary: r.stage_summary,
      disturbances: r.disturbances
    }))
    res.json({ nights })
  } catch (e) {
    res.status(500).json({ error: "whoop_sleep_failed", detail: String(e) })
  }
})

app.get("/api/whoop/v2/physiology/range", requireApiKey, async (req, res) => {
  try {
    const { start, end } = req.query
    if (!start || !end) return res.status(400).json({ error: "bad_request", detail: "start and end required" })
    const cycles = await whoopPaged("/v2/cycle", { start, end })
    // WHOOP physiology is often attached to cycle or recovery endpoints
    // This endpoint returns basic nightly physiology; the client can join by date
    const out = cycles.map(c => ({
      id: c.id,
      start: c.start,
      end: c.end,
      average_heart_rate: c.average_heart_rate,
      resting_heart_rate: c.resting_heart_rate,
      respiratory_rate: c.respiratory_rate, // may be null or missing per API version
      hrv_rmssd_millis: c.heart_rate_variability_rmssd_milli, // naming illustrative
      recovery_score: c.recovery_score
    }))
    res.json({ records: out })
  } catch (e) {
    res.status(500).json({ error: "whoop_physiology_failed", detail: String(e) })
  }
})

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`DoseTrack WHOOP Proxy running on http://localhost:${port}`)
})
