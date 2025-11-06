# WHOOP Integration - Quick Summary

**Date:** November 5, 2025  
**Status:** Research Complete → Ready for Implementation  
**Full Plan:** `docs/WHOOP_INTEGRATION_PLAN.md`

---

## What We Need from WHOOP

### Most Important: Recovery Data

```json
{
  "recovery_score": 44.0,          // 0-100% readiness
  "hrv_rmssd_milli": 31.8,         // Heart Rate Variability
  "resting_heart_rate": 64.0,      // Resting HR (bpm)
  "spo2_percentage": 95.69,         // Blood oxygen
  "skin_temp_celsius": 33.7         // Skin temperature
}
```

**Why:** Join `recovery_score` to DoseLog nights via `service_day_key` → ML features for predicting optimal dosing

---

## OAuth2 Flow (Not "API Keys")

### ❌ WRONG Approach
"Enter your WHOOP API key" → Bad UX, security risk, not supported by WHOOP

### ✅ CORRECT Approach
1. User taps "Connect WHOOP" in Settings
2. Safari opens → user signs in to WHOOP
3. WHOOP asks "Allow DoseTrack to access your recovery data?"
4. User approves → DoseTrack gets secure access token
5. Backend stores tokens safely (encrypted)
6. App fetches recovery data daily

**Industry Standard:** Same flow as "Sign in with Google" or "Connect to Spotify"

---

## Architecture

```
┌─────────────────┐
│  DoseTrack App  │
│      (iOS)      │
└────────┬────────┘
         │
         │ HTTPS
         ▼
┌─────────────────┐
│   DoseTrack     │ ◄──── YOU NEED TO BUILD THIS
│  OAuth Proxy    │       (Simple Node.js server)
│   (Backend)     │
└────────┬────────┘
         │
         │ OAuth2
         ▼
┌─────────────────┐
│  WHOOP API      │
│  (Production)   │
└─────────────────┘
```

**Why Backend?**
- WHOOP requires `client_secret` (MUST stay secret, can't be in iOS app)
- Token refresh logic (access tokens expire hourly)
- Security: Encrypted token storage

---

## What You Need to Register

1. **Go to:** https://developer.whoop.com/
2. **Create account** → "Register Application"
3. **Get:**
   - `client_id` (public, goes in iOS app)
   - `client_secret` (secret, goes in backend)
4. **Configure:**
   - Redirect URI: `dosetrack://oauth/whoop/callback`
   - Scopes: `read:recovery`, `read:sleep`

---

## Backend Requirements (Minimal)

**3 Endpoints:**

1. **POST /whoop/oauth/exchange**
   - Exchange authorization code for access/refresh tokens
   - Store encrypted tokens in database
   - Return session ID to app

2. **POST /whoop/data/recovery**
   - Fetch recovery data from WHOOP API
   - Auto-refresh expired tokens
   - Return JSON to app

3. **DELETE /whoop/oauth/revoke**
   - Revoke WHOOP access
   - Delete stored tokens
   - User disconnects

**Hosting Options:**
- Railway (easiest, $5/mo)
- Google Cloud Functions (serverless, pay-per-use)
- AWS Lambda (serverless)
- Your existing server (if you have one)

**Code:** See `docs/WHOOP_INTEGRATION_PLAN.md` Section 6 for complete Node.js implementation

---

## iOS Changes Required

### New Files to Create

1. **`ios/WhoopIntegrationView.swift`** (279 lines)
   - Settings UI: Connect/Disconnect button
   - Recovery data preview (last 7 days)
   - Status: Connected/Disconnected/Syncing

2. **`ios/WhoopAPIClient.swift`** (200 lines)
   - API calls to your backend
   - Token exchange logic
   - Recovery data fetching

3. **`ios/Models.swift` extension** (30 lines)
   - Add `NightFeatures` struct
   - Fields: `whoopRecoveryPct`, `whoopHrvRmssd`, etc.

### Modified Files

1. **`ios/SettingsViewEnhanced.swift`**
   - Add "WHOOP" navigation link

2. **`ios/Config.swift`**
   - Add `whoopClientId`
   - Add `whoopProxyURL`

3. **`DoseTrackApp.swift` or `SceneDelegate`**
   - Handle OAuth callback URL: `dosetrack://oauth/whoop/callback`

4. **`Info.plist`**
   - Register custom URL scheme

**Total Code:** ~500-600 lines new code + minor modifications

---

## Data Flow Example

### User Scenario
1. **Nov 4, 11pm:** User takes Dose 1
2. **Nov 5, 3am:** User takes Dose 2
3. **Nov 5, 8am:** User wakes up, WHOOP calculates recovery
4. **Nov 5, 12pm:** DoseTrack syncs recovery data (background task)
5. **Result:**
   ```json
   {
     "night_key": "2025-11-04T12:00:00Z",
     "dose1_utc": "2025-11-05T04:00:00Z",
     "dose2_utc": "2025-11-05T08:00:00Z",
     "final_wake_utc": "2025-11-05T13:00:00Z",
     "whoop_recovery_pct": 44.0,
     "whoop_hrv_rmssd": 31.8
   }
   ```

### Export to ML Pipeline
- File: `HealthExports/night_features_TIMESTAMP.jsonl`
- Format: One JSON object per line
- Join: `night_key` matches between DoseLog and NightFeatures

---

## Security Checklist

- [x] Use OAuth2 (not API keys) ✅
- [ ] Register app with WHOOP developer portal
- [ ] Store `client_secret` in backend environment variables
- [ ] Encrypt tokens at rest (AES-256-GCM)
- [ ] Use HTTPS for all communication
- [ ] Never store access/refresh tokens in iOS app
- [ ] Implement token refresh logic
- [ ] Handle revocation gracefully
- [ ] Update privacy policy (disclose WHOOP data collection)

---

## Implementation Timeline

### Week 1: Backend Setup
- Register with WHOOP
- Deploy OAuth proxy (Railway recommended)
- Test with curl/Postman

### Week 2: iOS OAuth Flow
- Create WhoopIntegrationView
- Implement URL scheme handling
- Test authorization end-to-end

### Week 3: Data Integration
- Add NightFeatures model
- Map recovery to service_day_key
- Export to JSONL

### Week 4: Polish
- Error handling
- Daily background sync
- Testing with real users

**Total:** 3-4 weeks (1 developer)

---

## Recommended Next Steps

1. **Review full plan:** Read `docs/WHOOP_INTEGRATION_PLAN.md`
2. **Register app:** Go to https://developer.whoop.com/ → create account
3. **Choose backend:** Recommend Railway for simplicity
4. **Prototype:** Implement backend OAuth proxy (2-3 days)
5. **Test:** Validate OAuth flow before iOS work

---

## Key Advantages Over "Auto Export" Apps

| Feature | Auto Export App | WHOOP API (This Plan) |
|---------|----------------|----------------------|
| **Setup** | User installs 3rd party app | Built into DoseTrack |
| **Reliability** | Depends on 3rd party | Direct WHOOP API |
| **Cadence** | User-controlled (manual) | Automatic daily sync |
| **Data Anchors** | No tombstones/deletions | Full API support |
| **Security** | 3rd party has access | OAuth2 best practices |
| **Privacy** | Data leaves WHOOP ecosystem | Direct user consent |

---

## Questions?

**See full documentation:**
- `docs/WHOOP_INTEGRATION_PLAN.md` - Complete technical spec
- Section 6: Backend code (Node.js)
- Section 4: iOS code (Swift)
- Section 10: Open questions

**Contact:**
- Review with stakeholders
- Decision: Approve/modify plan
- Blocked on: WHOOP developer account approval

---

**Version:** 1.0  
**Author:** GitHub Copilot  
**Last Updated:** November 5, 2025
