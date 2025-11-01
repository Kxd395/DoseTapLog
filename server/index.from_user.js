import express from "express";
import axios from "axios";
import dotenv from "dotenv";
import cors from "cors";
import crypto from "crypto";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth";
const TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";
const API_BASE = "https://api.prod.whoop.com/developer/v2";

let TOKENS = null; // dev only - for production use a secure store

function authHeader() {
  if (!TOKENS) return {};
  return { Authorization: `Bearer ${TOKENS.access_token}` };
}

app.get("/", (req, res) => {
  const state = crypto.randomBytes(8).toString("hex");
  const params = new URLSearchParams({
    response_type: "code",
    client_id: process.env.WHOOP_CLIENT_ID,
    redirect_uri: process.env.WHOOP_REDIRECT_URI,
    scope: "read:sleep read:recovery read:cycles read:body_measurement read:profile offline",
    state
  });
  const url = `${AUTH_URL}?${params.toString()}`;
  res.send(`<a href="${url}">Connect WHOOP</a>`);
});

app.get("/oauth/callback", async (req, res) => {
  const code = req.query.code;
  try {
    const body = new URLSearchParams({
      grant_type: "authorization_code",
      code,
      client_id: process.env.WHOOP_CLIENT_ID,
      client_secret: process.env.WHOOP_CLIENT_SECRET,
      redirect_uri: process.env.WHOOP_REDIRECT_URI
    });
    const resp = await axios.post(TOKEN_URL, body.toString(), {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
    TOKENS = resp.data;
    res.send("WHOOP connected. You can close this tab and return to the app.");
  } catch (e) {
    console.error(e.response?.data || e.message);
    res.status(500).send("Token exchange failed");
  }
});

app.get("/api/recovery/latest", async (req, res) => {
  try {
    const r = await axios.get(`${API_BASE}/recovery?limit=1`, { headers: authHeader() });
    const rec = r.data.records?.[0];
    const out = {
      recoveryScore: rec?.score?.recovery_score ?? null,
      rhr: rec?.score?.resting_heart_rate ?? null,
      hrvRMSSD: rec?.score?.hrv_rmssd_milli ?? null
    };
    res.json(out);
  } catch (e) {
    console.error(e.response?.data || e.message);
    res.status(500).json({ error: "recovery fetch failed" });
  }
});

app.get("/api/sleep/latest", async (req, res) => {
  try {
    const r = await axios.get(`${API_BASE}/sleep?limit=1`, { headers: authHeader() });
    const s = r.data.records?.[0];
    const out = {
      start: s?.start ?? null,
      end: s?.end ?? null,
      remMinutes: Math.round((s?.score?.stage_summary?.total_rem_sleep_time_milli ?? 0) / 60000),
      sWSMinutes: Math.round((s?.score?.stage_summary?.total_slow_wave_sleep_time_milli ?? 0) / 60000),
      efficiencyPercent: s?.score?.sleep_efficiency_percentage ?? null
    };
    res.json(out);
  } catch (e) {
    console.error(e.response?.data || e.message);
    res.status(500).json({ error: "sleep fetch failed" });
  }
});

const port = process.env.PORT || 8787;
app.listen(port, () => console.log(`WHOOP proxy on http://localhost:${port}`));
