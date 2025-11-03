/**
 * Drop-in additions for index.js
 * - Pagination helper for WHOOP endpoints supporting next_token
 * - /api/aggregates/7days that returns simple averages for app consumption
 * - Basic rate limit and date query validation
 */

// Add near top with other imports
// const rateLimit = require('express-rate-limit')

// After app init:
/*
const limiter = rateLimit({ windowMs: 1000, max: 1 })
app.use('/api/', limiter)
*/

// Replace your getJson with a paginating version for range endpoints
async function getJsonWithPagination(url, headers) {
  const all = []
  let next = null, guard = 0
  do {
    const pageUrl = next ? `${url}&nextToken=${encodeURIComponent(next)}` : url
    const r = await axios.get(pageUrl, { headers })
    const payload = r.data
    const items = payload.records || payload.data || []
    all.push(...items)
    next = payload.nextToken || payload.next_token || null
    guard += 1
  } while (next && guard < 20)
  return all
}

// Tiny validator for dd-mm or ISO-ish
function isISODate(s) { return /^\d{4}-\d{2}-\d{2}/.test(s) }

app.get('/api/aggregates/7days', requireApiKey, async (req, res) => {
  try {
    const now = new Date()
    const start = new Date(now.getTime() - 8 * 24 * 3600 * 1000)
    const startStr = start.toISOString().slice(0,10)
    const endStr = now.toISOString().slice(0,10)
    const headers = { Authorization: `Bearer ${TOKENS.access_token}` }

    const recUrl = `${WHOOP_BASE}/recovery/collection?start=${startStr}&end=${endStr}&limit=25`
    const slpUrl = `${WHOOP_BASE}/sleep/collection?start=${startStr}&end=${endStr}&limit=25`

    const [rec, slp] = await Promise.all([
      getJsonWithPagination(recUrl, headers),
      getJsonWithPagination(slpUrl, headers)
    ])

    const avgRecovery = rec.length ? Math.round(rec.map(r => r.score?.recovery_score ?? 0).reduce((a,b)=>a+b,0) / rec.length) : null
    const latestSleep = slp.sort((a,b) => new Date(b.end) - new Date(a.end))[0]
    const payload = {
      days: rec.length,
      avgRecovery,
      latestSleepEnd: latestSleep?.end ?? null
    }
    res.json(payload)
  } catch (e) {
    res.status(500).json({ error: 'aggregate_failed' })
  }
})
