# Secrets & Configuration Guide

This document is the authoritative reference for managing sensitive configuration across the DoseTrack stack. Follow these guidelines before running the app, sharing builds, or deploying the WHOOP proxy.

---

## 1. Secrets Inventory

| Name | Scope | Description | Storage Location | Example |
|------|-------|-------------|------------------|---------|
| `WHOOP_CLIENT_ID` | WHOOP OAuth2 | Public OAuth2 client identifier (safe to commit in code) | `ios/Config.swift`, `server/.env` | `6b7c7936-ecfc-489f-8b80-0cffb303af9e` |
| `WHOOP_CLIENT_SECRET` | WHOOP OAuth2 | **SENSITIVE** OAuth2 client secret (NEVER commit, backend only) | `server/.env`, 1Password vault | `7f0faa286293acd2...` |
| `WHOOP_REDIRECT_URI` | WHOOP OAuth2 | OAuth callback URL registered with WHOOP | `ios/Config.swift`, WHOOP dev portal | `dosetrack://oauth/whoop/callback` |
| `WHOOP_SCOPES` | WHOOP OAuth2 | Requested OAuth scopes | `ios/Config.swift` | `read:recovery read:sleep` |
| `ENCRYPTION_KEY` | WHOOP proxy | 32-byte hex key for AES-256-GCM token encryption | `server/.env`, generate with `openssl rand -hex 32` | `a1b2c3d4...` (64 hex chars) |
| `API_KEY` | WHOOP proxy | Shared secret the iOS client must send via `x-api-key` header. | `server/.env` (dotenv), optional 1Password vault | `dosetrack-local-dev` |
| `WHOOP_TOKEN` | WHOOP proxy (legacy) | **DEPRECATED** - Now using OAuth2 flow instead of bearer tokens | N/A | N/A |
| `WHOOP_BASE` | WHOOP proxy | Optional override for WHOOP API base URL (e.g., staging). | `server/.env` | `https://api.prod.whoop.com` |
| `APP_GROUP_ID` | iOS | Identifier shared between app, widget, intents. | Xcode target settings, `.xcconfig` if added | `group.com.jefferson.dosetrack` |
| `BUNDLE_ID_APP` | iOS | Main app bundle identifier. | Xcode target settings | `com.jefferson.dosetrack` |
| `BUNDLE_ID_WIDGET` | iOS | Widget extension bundle identifier. | Xcode target settings | `com.jefferson.dosetrack.widget` |
| `HEALTHKIT_USAGE_REASON` | iOS | Info.plist string describing HealthKit use. | Info.plist | `Sleep data used to autofill final wake.` |

> Tip: if you introduce remote config, push tokens, or analytics, extend this table and update `.env.example` accordingly.

---

## 2. WHOOP OAuth2 Credentials (Registered November 5, 2025)

### ✅ Production Credentials

**Client ID:** `6b7c7936-ecfc-489f-8b80-0cffb303af9e` (PUBLIC - safe to commit)  
**Client Secret:** `7f0faa286293acd22d17256281eaf98e7873a7be36e88d83c8fb149a52ae191b` (SENSITIVE - NEVER commit)  
**Redirect URI:** `dosetrack://oauth/whoop/callback`  
**Scopes:** `read:recovery read:sleep`  
**Registration Date:** November 5, 2025  
**Developer Limit:** 10 test users (submit for approval to launch to all WHOOP members)  
**Status:** ✅ Active (development mode)

### 🔒 Security Requirements

**NEVER commit client_secret to git:**
- ❌ Do NOT add to `Config.swift` or any iOS file
- ❌ Do NOT commit to `server/.env` (use `.env.example` template only)
- ✅ Store in backend environment variables only
- ✅ Store in 1Password/secure vault for team access

**Where to use:**
- `WHOOP_CLIENT_ID`: Safe to use in iOS app (`Config.swift`)
- `WHOOP_CLIENT_SECRET`: Backend only (`server/.env`, Railway/Cloud Functions environment)

### 📝 Backend Environment Variables

Create `server/whoop-oauth-proxy/.env` (NEVER commit):

```bash
# WHOOP OAuth2 Credentials
WHOOP_CLIENT_ID=6b7c7936-ecfc-489f-8b80-0cffb303af9e
WHOOP_CLIENT_SECRET=7f0faa286293acd22d17256281eaf98e7873a7be36e88d83c8fb149a52ae191b

# Token Encryption (generate with: openssl rand -hex 32)
ENCRYPTION_KEY=<GENERATE_NEW_KEY>

# Optional: API Key for iOS client authentication
API_KEY=dosetrack-whoop-dev-2025

# WHOOP API Base URL
WHOOP_BASE=https://api.prod.whoop.com
```

**Generate encryption key:**
```bash
openssl rand -hex 32
# Example output: a1b2c3d4e5f6...
```

### 📱 iOS Configuration

Update `ios/Config.swift`:

```swift
enum Config {
    // Existing...
    
    // WHOOP OAuth2 (registered 2025-11-05)
    static let whoopClientId = "6b7c7936-ecfc-489f-8b80-0cffb303af9e" // PUBLIC
    static let whoopRedirectUri = "dosetrack://oauth/whoop/callback"
    static let whoopScopes = "read:recovery read:sleep"
    
    #if DEBUG
    static let whoopProxyURL = "http://localhost:3000/whoop" // Local dev
    #else
    static let whoopProxyURL = "https://YOUR_BACKEND_URL/whoop" // Production (update after deployment)
    #endif
}
```

### 🚀 Deployment Checklist

**Railway:**
```bash
railway variables set WHOOP_CLIENT_ID=6b7c7936-ecfc-489f-8b80-0cffb303af9e
railway variables set WHOOP_CLIENT_SECRET=7f0faa286293acd22d17256281eaf98e7873a7be36e88d83c8fb149a52ae191b
railway variables set ENCRYPTION_KEY=$(openssl rand -hex 32)
railway variables set API_KEY=dosetrack-whoop-prod-2025
```

**Google Cloud Functions:**
```bash
gcloud functions deploy whoop-oauth-proxy \
  --set-env-vars WHOOP_CLIENT_ID=6b7c7936-ecfc-489f-8b80-0cffb303af9e,\
WHOOP_CLIENT_SECRET=7f0faa286293acd22d17256281eaf98e7873a7be36e88d83c8fb149a52ae191b,\
ENCRYPTION_KEY=<GENERATED_KEY>,\
API_KEY=dosetrack-whoop-prod-2025
```

### 📊 Development Limits

**Current Status:** 10 test users  
**To launch to all WHOOP members:** Submit app for approval via WHOOP Developer Portal

**Test User Strategy:**
1. Use your own WHOOP account for development
2. Invite 2-3 beta testers with WHOOP devices
3. Reserve remaining slots for stakeholder demos
4. Monitor usage, test all OAuth flows
5. Collect feedback before requesting full approval

### 🔄 Rotation Policy

**Client Secret Rotation:**
- Rotate every 90 days (calendar reminder)
- Rotate immediately if leaked or suspected compromise
- Update backend environment variables
- No app updates needed (backend only)

**Encryption Key Rotation:**
- Rotate every 180 days or when team member leaves
- Requires re-authorization of all users (old tokens can't be decrypted)
- Plan maintenance window, notify users

---

## 3. Managing WHOOP Proxy Secrets (UPDATED)

**Legacy WHOOP_TOKEN approach is deprecated.** Use OAuth2 credentials above.

1. Create backend directory:
   ```bash
   mkdir -p server/whoop-oauth-proxy
   cd server/whoop-oauth-proxy
   ```

2. Copy template and configure:
   ```bash
   cp .env.example .env
   # Edit .env with credentials from Section 2
   ```

3. Generate encryption key:
   ```bash
   openssl rand -hex 32 >> .env
   # Add as: ENCRYPTION_KEY=<output>
   ```

4. Store secrets in password manager:
   - **Store:** Client secret, encryption key, API key
   - **Label:** "DoseTrack WHOOP OAuth Credentials (2025-11-05)"
   - **Share:** Only with backend developers
   - **Audit:** Review access quarterly

5. Local development:
   ```bash
   cd server/whoop-oauth-proxy
   npm install
   npm start
   # Server runs on http://localhost:3000
   ```

6. Deployment (Railway):
   ```bash
   railway login
   railway init
   railway up
   # Set environment variables (see Section 2)
   railway status  # Get production URL
   ```

7. Update iOS Config.swift with production URL after deployment

---

## 4. Managing iOS Identifiers & Secrets
- Add a shared `.xcconfig` (future task) to define `APP_GROUP_ID`, bundle IDs, and any API base URLs so they do not diverge across targets.
- HealthKit requires a privacy usage string; keep the wording aligned with regulatory guidance.
- If new secrets are required (e.g., remote configuration), prefer secure storage (Keychain, App Groups keychain sharing). Document those keys here.

---

## 5. Git Hygiene

**Critical: NEVER commit these files:**
- `server/whoop-oauth-proxy/.env` (contains client_secret, encryption_key)
- Any file containing `WHOOP_CLIENT_SECRET` or `ENCRYPTION_KEY`
- `.xcconfig` files with production secrets
- Backup files, editor temp files with secrets

**Verify .gitignore includes:**
```
# Secrets
server/**/.env
server/**/.env.local
*.secret
*.key

# Build artifacts
DoseTrackNew/build/
DoseTrackNew/DerivedData/

# Xcode
*.xcconfig
xcuserdata/
```

**Before committing:**
```bash
# Verify no secrets in staged files
git diff --staged | grep -E "(CLIENT_SECRET|ENCRYPTION_KEY|7f0faa28)"
# Should return nothing

# Check for accidentally staged .env files
git status | grep "\.env"
# Should return nothing (or only .env.example)
```

**If secret was committed:**
1. Rotate compromised credentials immediately
2. Revoke WHOOP client_secret via developer portal
3. Generate new client_secret and encryption_key
4. Remove from git history:
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch server/whoop-oauth-proxy/.env" \
     --prune-empty --tag-name-filter cat -- --all
   ```
5. Force push (coordinate with team)
6. Document incident in `docs/ops/INCIDENTS.md`

---

## 6. Rotation & Incident Response Checklist
1. Revoke compromised WHOOP tokens via the developer portal.
2. Generate new token and update the secure vault.
3. Issue a new `API_KEY`, update clients, and remove the old key.
4. Update `docs/ops/ACTION_CHECKLIST.md` with follow-up tasks (e.g., re-run smoke tests).
5. Document the incident (who, what, when) inside your operational runbook.

Maintain this file as the canonical source for secrets. Whenever configuration changes, update this document and the associated templates.
