import express from "express";
import rateLimit from "express-rate-limit";
import fetch from "node-fetch";

export const limiter = rateLimit({ windowMs: 60 * 1000, max: 60, standardHeaders: true, legacyHeaders: false });
export function requireApiKey(req, res, next) { const expected = process.env.API_KEY; if (!expected || req.get("x-api-key") !== expected) return res.status(401).json({ error: "unauthorized" }); return next(); }
export async function getJsonWithPagination(path, initialLimit = 20, params = {}) {
  const base = process.env.WHOOP_BASE || "https://api.prod.whoop.com";
  let url = new URL(path, base);
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
  url.searchParams.set("limit", String(initialLimit));
  const token = process.env.WHOOP_TOKEN;
  const out = [];
  while (true) {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`WHOOP ${res.status}`);
    const json = await res.json();
    if (Array.isArray(json.records)) out.push(...json.records);
    const nextToken = json.nextToken || null;
    if (!nextToken) break;
    url.searchParams.set("nextToken", nextToken);
  }
  return out;
}
export function installAdditions(app) {
  app.use(limiter);
  app.use(requireApiKey);
  app.get("/api/aggregates/7days", async (req, res) => {
    try {
      const now = new Date();
      const start = new Date(now.getTime() - 7 * 24 * 3600 * 1000);
      const sleep = await getJsonWithPagination("/developer/sleep", 25, { start: start.toISOString(), end: now.toISOString() });
      const nights = sleep.map(r => ({ start: r.start, end: r.end, durationMin: Math.round((new Date(r.end) - new Date(r.start)) / 60000), recoveryScore: r.recoveryScore ?? null }));
      const durations = nights.map(n => n.durationMin);
      const avgDuration = durations.length ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length) : 0;
      res.json({ nights, averages: { durationMin: avgDuration, count: nights.length } });
    } catch (e) { res.status(500).json({ error: "aggregate_failed", detail: String(e) }); }
  });
}
