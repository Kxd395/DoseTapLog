const express = require('express');
const rateLimit = require('express-rate-limit');
const fetch = require('node-fetch');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'test-api-key-local-dev-only';
const WHOOP_BASE = process.env.WHOOP_BASE || 'https://api.whoop.com/developer/v1';

const limiter = rateLimit({ windowMs: 60 * 1000, max: 60 });
app.use(limiter);

function requireApiKey(req, res, next) {
  const key = req.header('x-api-key');
  if (!key || key !== API_KEY) return res.status(401).json({ error: 'unauthorized' });
  next();
}

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'dosetrack-whoop-proxy', version: '1.0.0', time: new Date().toISOString() });
});

app.get('/api/whoop/v2/sleep/range', requireApiKey, async (req, res) => {
  try {
    const start = encodeURIComponent(req.query.start);
    const end = encodeURIComponent(req.query.end);
    const url = `${WHOOP_BASE}/activity/sleep?start=${start}&end=${end}&limit=25`;
    const data = await pagedGet(url);
    res.json({ count: data.length, items: data });
  } catch (e) {
    res.status(500).json({ error: 'fetch_failed', detail: String(e) });
  }
});

app.get('/api/whoop/v2/physiology/range', requireApiKey, async (req, res) => {
  try {
    const start = encodeURIComponent(req.query.start);
    const end = encodeURIComponent(req.query.end);
    const url = `${WHOOP_BASE}/recovery?start=${start}&end=${end}&limit=25`;
    const data = await pagedGet(url);
    res.json({ count: data.length, items: data });
  } catch (e) {
    res.status(500).json({ error: 'fetch_failed', detail: String(e) });
  }
});

async function pagedGet(url) {
  const token = process.env.WHOOP_TOKEN;
  if (!token) throw new Error('WHOOP_TOKEN not configured');
  let next = url;
  let items = [];
  while (next) {
    const resp = await fetch(next, { headers: { Authorization: `Bearer ${token}` } });
    if (!resp.ok) throw new Error(`WHOOP API ${resp.status}`);
    const json = await resp.json();
    if (Array.isArray(json.records)) { items = items.concat(json.records); }
    else if (Array.isArray(json)) { items = items.concat(json); }
    next = null;
  }
  return items;
}

app.listen(PORT, () => console.log(`proxy on ${PORT}`));
