# DoseTrack WHOOP OAuth Proxy

Production-grade OAuth2 proxy for WHOOP API integration. Handles token exchange, refresh, and secure storage.

## Architecture

```
iOS App → OAuth Proxy (this) → WHOOP API
          ↑
          Stores encrypted tokens
          Returns session_id to client
```

**Security Features:**
- ✅ Tokens encrypted at rest (AES-256-GCM)
- ✅ Client never sees access_token or refresh_token
- ✅ Automatic token refresh
- ✅ Session-based authentication
- ✅ Optional API key protection

## Setup

### 1. Install Dependencies

```bash
cd server/whoop-oauth-proxy
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` and fill in:

```env
WHOOP_CLIENT_ID=6b7c7936-ecfc-489f-8b80-0cffb303af9e
WHOOP_CLIENT_SECRET=<from docs/SECRETS.md>
ENCRYPTION_KEY=<generate with: openssl rand -hex 32>
API_KEY=<optional: openssl rand -hex 16>
PORT=3000
```

**CRITICAL:** Generate a unique `ENCRYPTION_KEY`:

```bash
openssl rand -hex 32
```

### 3. Test Locally

```bash
npm start
```

Verify health check:

```bash
curl http://localhost:3000/health
```

Expected response:

```json
{
  "status": "ok",
  "service": "whoop-oauth-proxy",
  "version": "1.0.0",
  "active_sessions": 0,
  "uptime": 5.234
}
```

## Deployment

### Option A: Railway (Recommended)

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Create new project
railway init

# Set environment variables
railway variables set WHOOP_CLIENT_ID=6b7c7936-ecfc-489f-8b80-0cffb303af9e
railway variables set WHOOP_CLIENT_SECRET=<your_secret>
railway variables set ENCRYPTION_KEY=$(openssl rand -hex 32)

# Deploy
railway up
```

**Update iOS Config.swift** with Railway URL:

```swift
static let whoopProxyURL = "https://your-app.railway.app/whoop"
```

### Option B: Google Cloud Functions

```bash
gcloud functions deploy whoop-oauth-proxy \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point app \
  --set-env-vars WHOOP_CLIENT_ID=xxx,WHOOP_CLIENT_SECRET=yyy,ENCRYPTION_KEY=zzz
```

### Option C: Fly.io

```bash
flyctl launch
flyctl secrets set WHOOP_CLIENT_ID=xxx WHOOP_CLIENT_SECRET=yyy ENCRYPTION_KEY=zzz
flyctl deploy
```

## API Reference

### POST /whoop/oauth/exchange

Exchange OAuth authorization code for session ID.

**Request:**
```json
{
  "code": "abc123...",
  "redirect_uri": "dosetrack://oauth/whoop/callback"
}
```

**Response:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "whoop_user_id": 123456,
  "expires_at": "2025-11-05T12:00:00Z",
  "scopes": ["read:recovery", "read:sleep"]
}
```

### POST /whoop/data/recovery

Fetch recovery data for date range.

**Headers:**
- `Authorization: Bearer <session_id>`

**Request:**
```json
{
  "start": "2025-11-01T00:00:00Z",
  "end": "2025-11-05T23:59:59Z"
}
```

**Response:** (WHOOP API v2 format)
```json
{
  "records": [
    {
      "cycle_id": 93845,
      "sleep_id": "123e4567-e89b-12d3-a456-426614174000",
      "created_at": "2025-11-04T14:00:00Z",
      "score": {
        "recovery_score": 44,
        "hrv_rmssd_milli": 31.81,
        "resting_heart_rate": 64,
        "spo2_percentage": 95.69,
        "skin_temp_celsius": 33.7
      }
    }
  ]
}
```

### POST /whoop/data/sleep

Fetch sleep data (for service day mapping).

**Headers:**
- `Authorization: Bearer <session_id>`

**Request:**
```json
{
  "start": "2025-11-01T00:00:00Z",
  "end": "2025-11-05T23:59:59Z"
}
```

### DELETE /whoop/oauth/revoke

Revoke access and delete session.

**Headers:**
- `Authorization: Bearer <session_id>`

**Response:**
```json
{
  "status": "revoked"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "service": "whoop-oauth-proxy",
  "version": "1.0.0",
  "active_sessions": 3,
  "uptime": 123.45
}
```

## Security

### Token Storage

**Client (iOS):**
- Stores ONLY `session_id` in UserDefaults
- NEVER stores `access_token` or `refresh_token`

**Server (this proxy):**
- Encrypts tokens with AES-256-GCM
- Stores encrypted tokens in-memory (Map)
- **Production:** Migrate to Redis/Firestore/Postgres

### Encryption

**Algorithm:** AES-256-GCM (Galois/Counter Mode)
- **Key:** 32-byte hex string (from `ENCRYPTION_KEY`)
- **IV:** 16 random bytes per encryption
- **Auth Tag:** 16 bytes for integrity check

**Format:** `base64(IV || Auth_Tag || Ciphertext)`

### HTTPS

**Local Development:** HTTP allowed  
**Production:** HTTPS enforced (Railway/Cloud Functions default)

### Rate Limiting

WHOOP API limits (estimated):
- **Recovery endpoint:** ~100 requests/hour
- **OAuth token exchange:** ~10/hour

**Mitigation:**
- Client syncs once daily (background task)
- Backend caches recovery data (future enhancement)

## Testing

### Manual Test: OAuth Flow

1. **Start local server:**
   ```bash
   npm start
   ```

2. **Get authorization code:**
   - Open in browser:
     ```
     https://api.prod.whoop.com/oauth/oauth2/auth?response_type=code&client_id=6b7c7936-ecfc-489f-8b80-0cffb303af9e&redirect_uri=http://localhost:3000/test&scope=read:recovery%20read:sleep
     ```
   - Sign in with WHOOP account
   - Copy `code` from redirect URL

3. **Exchange code:**
   ```bash
   curl -X POST http://localhost:3000/whoop/oauth/exchange \
     -H "Content-Type: application/json" \
     -d '{
       "code": "<paste_code_here>",
       "redirect_uri": "http://localhost:3000/test"
     }'
   ```

4. **Fetch recovery data:**
   ```bash
   curl -X POST http://localhost:3000/whoop/data/recovery \
     -H "Authorization: Bearer <session_id_from_step_3>" \
     -H "Content-Type: application/json" \
     -d '{
       "start": "2025-11-01T00:00:00Z",
       "end": "2025-11-05T23:59:59Z"
     }'
   ```

### Automated Test

```bash
npm test
```

## Production Checklist

- [ ] Environment variables set (no hardcoded secrets)
- [ ] HTTPS enforced (Railway/Cloud Functions default)
- [ ] ENCRYPTION_KEY rotated (never reuse dev key)
- [ ] API_KEY enabled for client authentication
- [ ] Session store migrated to Redis/Firestore (if high traffic)
- [ ] Monitoring enabled (Sentry, Datadog, etc.)
- [ ] Rate limiting added (express-rate-limit)
- [ ] CORS configured for production domain only

## Troubleshooting

### "Token exchange failed"

**Cause:** Invalid authorization code (used twice or expired)  
**Fix:** Generate new code (codes expire after 10 minutes)

### "Session expired, please reconnect"

**Cause:** Refresh token expired (60 days)  
**Fix:** User must reconnect via OAuth flow

### "Failed to fetch recovery data"

**Cause:** Invalid date range or missing scopes  
**Fix:** Verify `start`/`end` in ISO 8601 format, check scopes include `read:recovery`

## License

MIT
