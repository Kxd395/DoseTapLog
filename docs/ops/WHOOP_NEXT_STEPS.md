# WHOOP Integration - Immediate Next Steps

**Created:** November 5, 2025  
**Status:** Planning Complete → Ready for Implementation

---

## ✅ What's Done

1. **Research Complete:**
   - WHOOP API fully documented (OpenAPI spec reviewed)
   - OAuth2 flow mapped out
   - Security best practices identified
   - Data schema designed

2. **Documentation Created:**
   - `docs/WHOOP_INTEGRATION_PLAN.md` (850+ lines, complete technical spec)
   - `docs/ops/WHOOP_INTEGRATION_SUMMARY.md` (quick reference)
   - `docs/ops/TODO.md` updated (12 new items: 69-80)

3. **Architecture Designed:**
   - Backend OAuth proxy (3 endpoints)
   - iOS OAuth flow (custom URL scheme)
   - Data model (NightFeatures)
   - Service day mapping algorithm
   - JSONL export format

---

## 🚀 Start Here: 3-Step Quickstart

### Step 1: Register with WHOOP ✅ COMPLETE (30 min)

**Status:** ✅ **COMPLETED November 5, 2025**

**Credentials Obtained:**
- ✅ Client ID: `6b7c7936-ecfc-489f-8b80-0cffb303af9e`
- ✅ Client Secret: `7f0faa286293acd22d17256281eaf98e7873a7be36e88d83c8fb149a52ae191b`
- ✅ Redirect URI: `dosetrack://oauth/whoop/callback`
- ✅ Scopes: `read:recovery read:sleep`
- ✅ Developer limit: 10 test users

**Stored in:**
- ✅ `docs/SECRETS.md` (credentials documented)
- ✅ `ios/Config.swift` (client ID added)
- ✅ `server/whoop-oauth-proxy/.env.example` (template created)

**Security:**
- ✅ Client secret NEVER committed to git
- ✅ .gitignore configured to exclude .env files
- ✅ Config.swift contains only public client_id

**Next:** Proceed to Step 2 (Deploy Backend)

---

1. Go to: https://developer.whoop.com/
2. Create account (use your DoseTrack/company email)
3. Click "Register Application"
4. Fill out form:
   - **App Name:** DoseTrack
   - **Description:** "Medication timing app for sodium oxybate dosing management"
   - **Redirect URI:** `dosetrack://oauth/whoop/callback`
   - **Scopes:** 
     - ✅ `read:recovery` (REQUIRED)
     - ✅ `read:sleep` (REQUIRED)
     - ⬜ `read:cycles` (optional)
     - ⬜ `read:profile` (optional)
5. Submit → Wait for approval (usually same day)
6. **Save credentials:**
   - `client_id` (example: `abc123def456`)
   - `client_secret` (example: `xyz789secret`)

**Store in:** `docs/SECRETS.md` (never commit to git)

```markdown
## WHOOP OAuth Credentials

- **Client ID:** `abc123def456`
- **Client Secret:** `xyz789secret` (NEVER commit to git!)
- **Registered:** 2025-11-05
- **Redirect URI:** `dosetrack://oauth/whoop/callback`
- **Scopes:** `read:recovery read:sleep`
```

**⏱️ Time:** 30 min (including approval wait)

---

### Step 2: Deploy Backend (2-3 hours) ⏳ READY TO START

**Action:** Get OAuth proxy running

**Prerequisites:**
- ✅ WHOOP credentials from Step 1
- ⏳ Node.js installed (v18+ recommended)
- ⏳ Railway CLI installed (or Cloud Functions if preferred)

**Quick Start Script:**

```bash
# 1. Navigate to backend directory
cd server/whoop-oauth-proxy

# 2. Create .env from template
cp .env.example .env

# 3. Edit .env with your actual credentials
# Use your favorite editor (nano, vim, VSCode, etc.)
nano .env

# Add these values:
# WHOOP_CLIENT_ID=6b7c7936-ecfc-489f-8b80-0cffb303af9e
# WHOOP_CLIENT_SECRET=7f0faa286293acd22d17256281eaf98e7873a7be36e88d83c8fb149a52ae191b
# ENCRYPTION_KEY=$(openssl rand -hex 32)  # Generate this now
# API_KEY=dosetrack-whoop-dev-2025

# 4. Generate encryption key
echo "ENCRYPTION_KEY=$(openssl rand -hex 32)" >> .env

# 5. Install dependencies (after creating package.json and index.js)
npm install

# 6. Start local server
npm start
# Server will run on http://localhost:3000
```

**Status:** Ready to implement (code from `docs/WHOOP_INTEGRATION_PLAN.md` Section 6)

---

#### Option A: Railway (Recommended)

1. **Install Railway CLI:**
   ```bash
   npm install -g @railway/cli
   railway login
   ```

2. **Create project directory:**
   ```bash
   cd server
   mkdir whoop-oauth-proxy
   cd whoop-oauth-proxy
   npm init -y
   ```

3. **Install dependencies:**
   ```bash
   npm install express node-fetch@2
   ```

4. **Create `index.js`:**
   - Copy code from `docs/WHOOP_INTEGRATION_PLAN.md` Section 6 (Option A)
   - Complete 200-line Node.js server

5. **Create `package.json` start script:**
   ```json
   {
     "scripts": {
       "start": "node index.js"
     }
   }
   ```

6. **Deploy:**
   ```bash
   railway init
   railway up
   ```

7. **Set environment variables:**
   ```bash
   railway variables set WHOOP_CLIENT_ID=abc123def456
   railway variables set WHOOP_CLIENT_SECRET=xyz789secret
   railway variables set ENCRYPTION_KEY=$(openssl rand -hex 32)
   ```

8. **Get your URL:**
   ```bash
   railway status
   # Example output: https://whoop-oauth-proxy-production-abc123.up.railway.app
   ```

9. **Test endpoints:**
   ```bash
   curl https://YOUR_RAILWAY_URL.up.railway.app/whoop/health
   # Should return: {"status":"ok","service":"whoop-oauth-proxy"}
   ```

**⏱️ Time:** 2-3 hours (including Railway setup)

**Cost:** $5/month (Railway Hobby plan)

---

#### Option B: Google Cloud Functions (Alternative)

If you prefer serverless:

```bash
gcloud functions deploy whoop-oauth-proxy \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --set-env-vars WHOOP_CLIENT_ID=abc123,WHOOP_CLIENT_SECRET=xyz789,ENCRYPTION_KEY=...
```

**Cost:** ~$0.40/month (low volume, free tier covers most usage)

---

### Step 3: Test OAuth Flow (30 min)

**Action:** Verify end-to-end before iOS work

1. **Test authorization URL:**
   ```bash
   # Open in browser:
   https://api.prod.whoop.com/oauth/oauth2/auth?client_id=YOUR_CLIENT_ID&redirect_uri=dosetrack://oauth/whoop/callback&response_type=code&scope=read:recovery+read:sleep
   ```

2. **Sign in with your WHOOP account**
   - If you don't have one: https://join.whoop.com/ (1-month free trial)

3. **Capture authorization code:**
   - After approval, browser redirects to: `dosetrack://oauth/whoop/callback?code=AUTHORIZATION_CODE`
   - Copy the code (everything after `code=`)

4. **Test token exchange:**
   ```bash
   curl -X POST https://YOUR_BACKEND_URL/whoop/oauth/exchange \
     -H "Content-Type: application/json" \
     -d '{
       "code": "PASTE_AUTHORIZATION_CODE_HERE",
       "redirect_uri": "dosetrack://oauth/whoop/callback"
     }'
   
   # Should return:
   # {
   #   "session_id": "uuid-v4-session-id",
   #   "whoop_user_id": 10129,
   #   "expires_at": "2025-11-05T13:00:00Z",
   #   "scopes": ["read:recovery", "read:sleep"]
   # }
   ```

5. **Test recovery fetch:**
   ```bash
   curl -X POST https://YOUR_BACKEND_URL/whoop/data/recovery \
     -H "Authorization: Bearer YOUR_SESSION_ID" \
     -H "Content-Type: application/json" \
     -d '{
       "start": "2025-11-01T00:00:00Z",
       "end": "2025-11-05T23:59:59Z"
     }'
   
   # Should return:
   # {
   #   "records": [
   #     {
   #       "cycle_id": 93845,
   #       "sleep_id": "123e4567...",
   #       "recovery_score": 44.0,
   #       "hrv_rmssd_milli": 31.81,
   #       ...
   #     }
   #   ]
   # }
   ```

**⏱️ Time:** 30 min

**✅ Success Criteria:**
- Authorization URL redirects to WHOOP login
- Code exchange returns session_id
- Recovery fetch returns real data

---

## 📱 iOS Implementation (Week 2)

**After backend is working**, proceed with iOS:

### Phase 1: API Client (Day 1-2)

**File:** `ios/WhoopAPIClient.swift`

**Tasks:**
- [ ] Create file from template in `docs/WHOOP_INTEGRATION_PLAN.md` Section 4.3
- [ ] Update `Config.swift` with backend URL:
  ```swift
  static let whoopProxyURL = "https://YOUR_RAILWAY_URL.up.railway.app/whoop"
  ```
- [ ] Add error types: `WhoopError.exchangeFailed`, `.fetchFailed`, `.revokeFailed`
- [ ] Implement 4 methods: `exchangeCode`, `fetchRecovery`, `fetchSleep`, `revokeAccess`
- [ ] Test with mock responses

**DoD:** Client compiles, unit tests pass

---

### Phase 2: OAuth Flow (Day 3-4)

**Files:** 
- `ios/WhoopIntegrationView.swift` (new)
- `DoseTrackApp.swift` or `SceneDelegate.swift` (modify)
- `Info.plist` (add URL scheme)

**Tasks:**
- [ ] Create `WhoopIntegrationView.swift` from Section 4.2
- [ ] Add URL scheme to `Info.plist`:
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>dosetrack</string>
      </array>
    </dict>
  </array>
  ```
- [ ] Implement `scene(_:openURLContexts:)` callback handler
- [ ] Add "Connect WHOOP" link to `SettingsViewEnhanced.swift`
- [ ] Test end-to-end: tap → Safari → approve → callback → connected

**DoD:** OAuth flow works on device/simulator

---

### Phase 3: Data Integration (Day 5-7)

**Files:**
- `ios/Models.swift` (extend with `NightFeatures`)
- `ios/WhoopDataMapper.swift` (new - service day mapping)
- `ios/HealthDataExportView.swift` (modify - add WHOOP export)

**Tasks:**
- [ ] Add `NightFeatures` struct to `Models.swift`
- [ ] Implement `mapWhoopRecoveryToServiceDay()` algorithm
- [ ] Add WHOOP export to `performExport()` function
- [ ] Test JSONL output format
- [ ] Verify join with DoseLog via `night_key`

**DoD:** WHOOP data exports to JSONL, joins with DoseLog

---

### Phase 4: Polish & Testing (Day 8-10)

**Tasks:**
- [ ] Add daily background sync (BGAppRefreshTask)
- [ ] Error handling UI (retry button, error messages)
- [ ] Status chip in main UI (optional)
- [ ] Unit tests (80%+ coverage)
- [ ] Integration tests (full OAuth flow)
- [ ] Update PRD and docs
- [ ] Beta testing with real WHOOP users

**DoD:** Production-ready, tested, documented

---

## 📊 Progress Tracking

### Milestone 1: Backend Live ✅
- [x] WHOOP developer account approved
- [x] Backend deployed to Railway/Cloud Functions
- [x] OAuth flow tested with curl
- [x] Backend URL added to `Config.swift`

### Milestone 2: iOS OAuth Working ⏳
- [ ] WhoopAPIClient implemented
- [ ] WhoopIntegrationView created
- [ ] URL scheme callback handling
- [ ] End-to-end OAuth flow tested

### Milestone 3: Data Integration ⏳
- [ ] NightFeatures model added
- [ ] Service day mapping implemented
- [ ] WHOOP data exports to JSONL
- [ ] Join with DoseLog verified

### Milestone 4: Production Ready ⏳
- [ ] Background sync working
- [ ] Error handling complete
- [ ] Tests passing (80%+ coverage)
- [ ] Documentation updated
- [ ] Beta testing complete

---

## 🛑 Blockers & Dependencies

### Current Blockers:
- [ ] WHOOP developer account approval (Item 69)
- [ ] Backend hosting decision (Railway vs Cloud Functions)
- [ ] `client_id` and `client_secret` from WHOOP

### Dependencies:
- **Item 41 (ClockProvider):** Required for service day mapping (Item 76)
- **Item 70 (Backend):** Blocks all iOS OAuth work (Items 71-74)
- **Item 71 (API Client):** Blocks UI (Item 72) and data integration (Items 75-77)

---

## 💡 Tips & Gotchas

### OAuth2 Common Issues:

1. **"Invalid redirect_uri" error:**
   - Ensure EXACT match: `dosetrack://oauth/whoop/callback` (no trailing slash, no query params)
   - Check WHOOP developer portal settings

2. **"Code has expired" error:**
   - Authorization codes expire in ~10 minutes
   - Test quickly after receiving code
   - In production, app handles this automatically

3. **Token refresh failing:**
   - Check `refresh_token` is stored correctly
   - Verify backend auto-refresh logic
   - WHOOP tokens expire in 1 hour (3600s)

4. **Rate limiting (429 errors):**
   - WHOOP API has rate limits (exact limits not documented)
   - Implement exponential backoff: 1s, 2s, 4s, 8s
   - Cache recovery data locally (avoid redundant fetches)

### iOS URL Scheme Issues:

1. **Callback not captured:**
   - Verify `Info.plist` has URL scheme
   - Check `scene(_:openURLContexts:)` is implemented
   - Test with: `xcrun simctl openurl booted "dosetrack://oauth/whoop/callback?code=test"`

2. **Session not persisting:**
   - Use `@AppStorage` or `UserDefaults` for `session_id`
   - Never store `access_token` or `refresh_token` in iOS app
   - Backend handles token storage

---

## 🔒 Security Checklist

Before production:

- [ ] `client_secret` stored in backend environment variables (NEVER in iOS app)
- [ ] Tokens encrypted at rest (AES-256-GCM)
- [ ] HTTPS enforced for all communication
- [ ] `session_id` is opaque (no user data in ID)
- [ ] Token refresh logic tested (simulate expiration)
- [ ] Revocation works (DELETE /whoop/oauth/revoke)
- [ ] Privacy policy updated (disclose WHOOP data collection)
- [ ] Error messages don't leak sensitive info
- [ ] Rate limiting implemented (prevent abuse)

---

## 📞 Support & Questions

**Documentation:**
- Full Plan: `docs/WHOOP_INTEGRATION_PLAN.md`
- Quick Summary: `docs/ops/WHOOP_INTEGRATION_SUMMARY.md`
- TODO Items: `docs/ops/TODO.md` (Items 69-80)

**External Resources:**
- WHOOP API Docs: https://developer.whoop.com/api
- OAuth2 Spec: https://oauth.net/2/
- Railway Docs: https://docs.railway.app/

**Questions?**
- Review full plan first
- Check "Open Questions" in Section 10 of main plan
- Consult with stakeholders on hosting/budget decisions

---

**Version:** 1.0  
**Last Updated:** November 5, 2025  
**Estimated Total Time:** 3-4 weeks (1 developer)
