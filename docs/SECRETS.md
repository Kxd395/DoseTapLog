# Secrets & Configuration Guide

This document is the authoritative reference for managing sensitive configuration across the DoseTrack stack. Follow these guidelines before running the app, sharing builds, or deploying the WHOOP proxy.

---

## 1. Secrets Inventory

| Name | Scope | Description | Storage Location | Example |
|------|-------|-------------|------------------|---------|
| `API_KEY` | WHOOP proxy | Shared secret the iOS client must send via `x-api-key` header. | `server/.env` (dotenv), optional 1Password vault | `dosetrack-local-dev` |
| `WHOOP_TOKEN` | WHOOP proxy | WHOOP developer bearer token used when proxying requests. Treat as highly sensitive. | `server/.env`, rotate monthly | `eyJhbGciOiJIUzI...` |
| `WHOOP_BASE` | WHOOP proxy | Optional override for WHOOP API base URL (e.g., staging). | `server/.env` | `https://api.prod.whoop.com` |
| `APP_GROUP_ID` | iOS | Identifier shared between app, widget, intents. | Xcode target settings, `.xcconfig` if added | `group.com.jefferson.dosetrack` |
| `BUNDLE_ID_APP` | iOS | Main app bundle identifier. | Xcode target settings | `com.jefferson.dosetrack` |
| `BUNDLE_ID_WIDGET` | iOS | Widget extension bundle identifier. | Xcode target settings | `com.jefferson.dosetrack.widget` |
| `HEALTHKIT_USAGE_REASON` | iOS | Info.plist string describing HealthKit use. | Info.plist | `Sleep data used to autofill final wake.` |

> Tip: if you introduce remote config, push tokens, or analytics, extend this table and update `.env.example` accordingly.

---

## 2. Managing WHOOP Proxy Secrets
1. Duplicate `server/.env.example` to `server/.env`.
2. Set `API_KEY` to a random string (16+ chars). Share only with trusted clients over secure channels.
3. Store `WHOOP_TOKEN` inside an organization password manager (1Password, Bitwarden). Never commit it.
4. For local runs, export secrets into your shell session or rely on dotenv:
   ```bash
   cd server
   cp .env.example .env
   # edit .env with secure values
   npm start
   ```
5. Rotate tokens regularly:
   - **API key:** whenever a device is lost or unauthorized access is suspected.
   - **WHOOP token:** per WHOOP policy or monthly, whichever is sooner.
6. When deploying, configure environment variables within the hosting provider (Heroku, Fly.io, etc.), not via committed files.

---

## 3. Managing iOS Identifiers & Secrets
- Add a shared `.xcconfig` (future task) to define `APP_GROUP_ID`, bundle IDs, and any API base URLs so they do not diverge across targets.
- HealthKit requires a privacy usage string; keep the wording aligned with regulatory guidance.
- If new secrets are required (e.g., remote configuration), prefer secure storage (Keychain, App Groups keychain sharing). Document those keys here.

---

## 4. Git Hygiene
- `.env`, `.xcconfig` with secrets, and any key material must stay out of source control.
- Verify `.gitignore` covers `server/.env`, derived data, build artifacts, and any future secret files.
- When sharing debug builds, scrub logs of WHOOP tokens or patient data.

---

## 5. Rotation & Incident Response Checklist
1. Revoke compromised WHOOP tokens via the developer portal.
2. Generate new token and update the secure vault.
3. Issue a new `API_KEY`, update clients, and remove the old key.
4. Update `docs/ops/ACTION_CHECKLIST.md` with follow-up tasks (e.g., re-run smoke tests).
5. Document the incident (who, what, when) inside your operational runbook.

Maintain this file as the canonical source for secrets. Whenever configuration changes, update this document and the associated templates.
