import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import rateLimit from "express-rate-limit";
import fetch from "node-fetch";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({ origin: "http://localhost:*" }));
app.use(express.json());

// Rate limiter: 60 requests per minute
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "rate_limit_exceeded" }
});

// API key authentication middleware
function requireApiKey(req, res, next) {
  const expected = process.env.API_KEY;
  if (!expected) {
    return res.status(500).json({ error: "server_config_error", detail: "API_KEY not configured" });
  }
  const provided = req.get("x-api-key");
  if (provided !== expected) {
    return res.status(401).json({ error: "unauthorized", detail: "Invalid or missing x-api-key header" });
  }
  return next();
}

// Pagination helper for WHOOP API
async function getJsonWithPagination(path, initialLimit = 20, params = {}) {
  const base = process.env.WHOOP_BASE || "https://api.prod.whoop.com";
  const url = new URL(path, base);
  
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
  url.searchParams.set("limit", String(initialLimit));
  
  const token = process.env.WHOOP_TOKEN;
  if (!token) {
    throw new Error("WHOOP_TOKEN not configured");
  }
  
  const records = [];
  let currentUrl = url.toString();
  
  while (true) {
    const res = await fetch(currentUrl, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    if (!res.ok) {
      throw new Error(`WHOOP API error: ${res.status} ${res.statusText}`);
    }
    
    const json = await res.json();
    
    if (Array.isArray(json.records)) {
      records.push(...json.records);
    }
    
    const nextToken = json.next_token || json.nextToken || null;
    if (!nextToken) break;
    
    // Update URL with next token
    const nextUrl = new URL(currentUrl);
    nextUrl.searchParams.set("nextToken", nextToken);
    currentUrl = nextUrl.toString();
  }
  
  return records;
}

// Health check endpoint (no auth required)
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    service: "dosetrack-whoop-proxy",
    version: "1.0.0"
  });
});

// Apply rate limiting and auth to all /api/* routes
app.use("/api", limiter);
app.use("/api", requireApiKey);

// Get latest sleep record
app.get("/api/sleep/latest", async (req, res) => {
  try {
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 3600 * 1000);
    
    const sleep = await getJsonWithPagination("/developer/v1/activity/sleep", 25, {
      start: oneDayAgo.toISOString(),
      end: now.toISOString()
    });
    
    if (sleep.length === 0) {
      return res.json({ record: null, message: "No sleep data in last 24 hours" });
    }
    
    // Return most recent sleep record
    const latest = sleep.sort((a, b) => new Date(b.end) - new Date(a.end))[0];
    
    res.json({
      record: {
        start: latest.start,
        end: latest.end,
        durationMinutes: Math.round((new Date(latest.end) - new Date(latest.start)) / 60000),
        recoveryScore: latest.score?.recovery_score ?? null,
        sleepPerformance: latest.score?.sleep_performance_percentage ?? null
      }
    });
  } catch (error) {
    console.error("Error fetching latest sleep:", error);
    res.status(500).json({
      error: "fetch_failed",
      detail: error.message
    });
  }
});

// Get 7-day sleep aggregates
app.get("/api/aggregates/7days", async (req, res) => {
  try {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 3600 * 1000);
    
    const sleep = await getJsonWithPagination("/developer/v1/activity/sleep", 25, {
      start: sevenDaysAgo.toISOString(),
      end: now.toISOString()
    });
    
    const nights = sleep.map(record => ({
      start: record.start,
      end: record.end,
      durationMin: Math.round((new Date(record.end) - new Date(record.start)) / 60000),
      recoveryScore: record.score?.recovery_score ?? null,
      sleepPerformance: record.score?.sleep_performance_percentage ?? null
    }));
    
    const durations = nights.map(n => n.durationMin);
    const recoveryScores = nights.map(n => n.recoveryScore).filter(s => s !== null);
    
    const avgDuration = durations.length
      ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length)
      : 0;
    
    const avgRecovery = recoveryScores.length
      ? Math.round(recoveryScores.reduce((a, b) => a + b, 0) / recoveryScores.length)
      : null;
    
    res.json({
      nights,
      averages: {
        durationMin: avgDuration,
        recoveryScore: avgRecovery,
        count: nights.length
      },
      period: {
        start: sevenDaysAgo.toISOString(),
        end: now.toISOString()
      }
    });
  } catch (error) {
    console.error("Error fetching aggregates:", error);
    res.status(500).json({
      error: "aggregate_failed",
      detail: error.message
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: "not_found",
    path: req.path,
    availableEndpoints: [
      "GET /health",
      "GET /api/sleep/latest",
      "GET /api/aggregates/7days"
    ]
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({
    error: "internal_server_error",
    detail: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`✅ DoseTrack WHOOP Proxy running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔒 API Key required for /api/* endpoints`);
  console.log(`⚡ Rate limit: 60 requests/minute`);
  
  if (!process.env.API_KEY) {
    console.warn("⚠️  WARNING: API_KEY not set in .env file");
  }
  if (!process.env.WHOOP_TOKEN) {
    console.warn("⚠️  WARNING: WHOOP_TOKEN not set in .env file");
  }
});

export { app, limiter, requireApiKey, getJsonWithPagination };
