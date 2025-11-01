# Dosing Tracker Starter - Xywav, HealthKit, WHOOP

This starter gives you:
- SwiftUI iOS app that logs Xywav doses, pulls Apple Health metrics, and fetches WHOOP data through a local proxy.
- Node OAuth proxy that handles WHOOP OAuth 2.0 and exposes simple endpoints you can call from the app.
- A dosing recommender that proposes a second dose window and split ratio from a 7 day log plus WHOOP recovery and sleep.

## Names to use for forms
- App name: Dosing Tracker
- iOS bundle id: org.axxessphila.dosingtracker
- WHOOP App name: Dosing Tracker - Personal
- WHOOP Redirect URI: http://localhost:8787/oauth/callback
- WHOOP scopes: read:sleep read:recovery read:cycles read:body_measurement read:profile offline

## Apple - macOS environment
- macOS Sonoma or newer
- Xcode 15 or newer
- Node 20 or newer
- iOS target 17 or newer

## Quick start

1. Register your WHOOP app
   - Go to WHOOP Developer Dashboard
   - Create a client
   - Set Redirect URI: http://localhost:8787/oauth/callback
   - Scopes: read:sleep read:recovery read:cycles read:body_measurement read:profile offline
   - Copy Client ID and Client Secret

2. Configure the OAuth proxy
   - cd server
   - Copy .env.example to .env and fill values
   - npm install
   - npm start
   - Visit http://localhost:8787 to start OAuth

3. Open the iOS project
   - Open Xcode
   - Create a new "App" project named "DosingTracker"
   - Set bundle id to org.axxessphila.dosingtracker
   - Add the Swift files from ios/ into your project
   - In Signing, select your Team
   - In Project Signing and Capabilities, add HealthKit
   - Run on your iPhone

4. App configuration
   - Update WhoopClient.serverBase if needed, default is http://localhost:8787
   - On first launch, grant Health permissions
   - Use the Log tab to record dose 1 and dose 2
   - The app will compute a suggested split and next dose window nightly

## WHOOP references
Authorization URL: https://api.prod.whoop.com/oauth/oauth2/auth
Token URL: https://api.prod.whoop.com/oauth/oauth2/token
Sleep docs and model: https://developer.whoop.com/docs/developing/user-data/sleep/
Recovery docs and model: https://developer.whoop.com/docs/developing/user-data/recovery/
API reference and scopes: https://developer.whoop.com/api/

## Privacy
- HealthKit data stays on device
- WHOOP keys are only in your local .env for the proxy
- App can be used offline if you skip WHOOP
