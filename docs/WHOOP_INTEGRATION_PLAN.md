# WHOOP Integration Plan

**Created:** November 5, 2025  
**Status:** Planning Phase  
**Priority:** High - Production-Ready OAuth2 Integration

---

## Executive Summary

WHOOP provides a production-grade OAuth2 API for accessing recovery, sleep, and physiological data. This document outlines the complete integration plan for DoseTrack to connect with WHOOP using best practices (OAuth2 flow, token management, proper security).

**Key Principle:** Never ask users for "API keys." Use proper OAuth2 authorization flow where users sign in through WHOOP and grant DoseTrack access.

---

## 1. WHOOP API Overview

### Base URL
- **Production API:** `https://api.prod.whoop.com/developer`
- **OAuth Authorization:** `https://api.prod.whoop.com/oauth/oauth2/auth`
- **Token Endpoint:** `https://api.prod.whoop.com/oauth/oauth2/token`

### Required OAuth2 Scopes

| Scope | Description | DoseTrack Use Case |
|-------|-------------|-------------------|
| `read:recovery` | Recovery score, HRV RMSSD, resting HR, SpO₂, skin temp | **PRIMARY** - Join recovery% to night features |
| `read:sleep` | Sleep performance%, stages, respiratory rate, efficiency | Validate against HealthKit sleep data |
| `read:cycles` | Physiological cycles, strain, avg HR | Optional - strain correlation with dose timing |
| `read:profile` | Name, email | User identification |
| `read:body_measurement` | Height, weight, max HR | Optional - population stats |

**Minimum Required:** `read:recovery` + `read:sleep`

---

## 2. OAuth2 Flow Architecture

### Step 1: Developer Registration
**Action Required:** Register DoseTrack with WHOOP Developer Portal

1. Go to: https://developer.whoop.com/
2. Create account → Register Application
3. Obtain:
   - `client_id` (public identifier)
   - `client_secret` (sensitive - store in server/backend)
4. Configure redirect URI: `dosetrack://oauth/whoop/callback` (custom URL scheme)

### Step 2: Authorization Code Flow

```
┌─────────────┐                                 ┌─────────────┐
│  DoseTrack  │                                 │    WHOOP    │
│  iOS App    │                                 │   OAuth2    │
└─────────────┘                                 └─────────────┘
       │                                               │
       │  1. User taps "Connect WHOOP"                │
       │──────────────────────────────────────────────>│
       │                                               │
       │  2. Open Safari with authorization URL       │
       │     https://api.prod.whoop.com/oauth/        │
       │     oauth2/auth?client_id=XXX&               │
       │     redirect_uri=dosetrack://oauth/whoop/    │
       │     callback&response_type=code&             │
       │     scope=read:recovery+read:sleep           │
       │                                               │
       │  3. User signs in to WHOOP → grants access   │
       │<──────────────────────────────────────────────│
       │                                               │
       │  4. WHOOP redirects with code:               │
       │     dosetrack://oauth/whoop/callback?        │
       │     code=AUTHORIZATION_CODE                  │
       │                                               │
       │  5. App intercepts URL → sends code to       │
       │     backend OAuth proxy                      │
       │──────────────────────────────────────────────>│
       │                                        ┌──────┴──────┐
       │                                        │  DoseTrack  │
       │                                        │  Backend    │
       │                                        │  (OAuth)    │
       │                                        └──────┬──────┘
       │                                               │
       │  6. Backend exchanges code for tokens        │
       │     POST /oauth/oauth2/token                 │
       │     client_id + client_secret + code ────────>│
       │                                               │
       │  7. WHOOP returns access + refresh tokens    │
       │<──────────────────────────────────────────────│
       │     {                                         │
       │       "access_token": "...",                  │
       │       "refresh_token": "...",                 │
       │       "expires_in": 3600                      │
       │     }                                         │
       │                                               │
       │  8. Backend stores tokens (encrypted) →       │
       │     Returns to app with session ID           │
       │<──────────────────────────────────────────────│
       │                                               │
       │  9. App stores session ID → Status: Connected│
       └───────────────────────────────────────────────┘
```

---

## 3. Backend OAuth Proxy Requirements

### Why a Backend?
- **Security:** `client_secret` must NEVER be in iOS app (decompilable)
- **Token Management:** Refresh tokens server-side, not on device
- **Revocation Handling:** Centralized token lifecycle management

### Minimal Proxy Endpoints

#### POST /whoop/oauth/exchange
**Purpose:** Exchange authorization code for access/refresh tokens

**Request:**
```json
{
  "code": "AUTHORIZATION_CODE_FROM_WHOOP",
  "redirect_uri": "dosetrack://oauth/whoop/callback"
}
```

**Response:**
```json
{
  "session_id": "uuid-v4-session-identifier",
  "whoop_user_id": 10129,
  "expires_at": "2025-11-05T13:00:00Z",
  "scopes": ["read:recovery", "read:sleep"]
}
```

**Backend Logic:**
1. Validate code format
2. POST to `https://api.prod.whoop.com/oauth/oauth2/token`:
   ```
   grant_type=authorization_code
   code=<authorization_code>
   client_id=<your_client_id>
   client_secret=<your_client_secret>
   redirect_uri=dosetrack://oauth/whoop/callback
   ```
3. Receive:
   ```json
   {
     "access_token": "eyJhbGc...",
     "refresh_token": "def502...",
     "expires_in": 3600,
     "token_type": "Bearer"
   }
   ```
4. Store in database (encrypted):
   - `user_id` → `session_id` mapping
   - `access_token` (AES-256-GCM encrypted)
   - `refresh_token` (AES-256-GCM encrypted)
   - `expires_at` timestamp
5. Return session ID to app

#### POST /whoop/data/recovery
**Purpose:** Fetch recovery data for date range

**Request Headers:**
```
Authorization: Bearer <session_id>
```

**Request Body:**
```json
{
  "start": "2025-11-01T00:00:00Z",
  "end": "2025-11-05T23:59:59Z"
}
```

**Response:**
```json
{
  "records": [
    {
      "cycle_id": 93845,
      "sleep_id": "123e4567-e89b-12d3-a456-426614174000",
      "created_at": "2025-11-05T11:25:44.774Z",
      "recovery_score": 44.0,
      "resting_heart_rate": 64.0,
      "hrv_rmssd_milli": 31.813562,
      "spo2_percentage": 95.6875,
      "skin_temp_celsius": 33.7
    }
  ]
}
```

**Backend Logic:**
1. Validate session_id → look up access_token
2. Check if token expired → refresh if needed
3. GET `https://api.prod.whoop.com/developer/v2/recovery?start=<start>&end=<end>`
   - Header: `Authorization: Bearer <decrypted_access_token>`
4. Return data to app

#### POST /whoop/oauth/refresh
**Purpose:** Refresh expired access token (called automatically by backend)

**Internal Only** - Not exposed to app

**Logic:**
1. POST to `https://api.prod.whoop.com/oauth/oauth2/token`:
   ```
   grant_type=refresh_token
   refresh_token=<stored_refresh_token>
   client_id=<your_client_id>
   client_secret=<your_client_secret>
   ```
2. Update stored access_token + expires_at

#### DELETE /whoop/oauth/revoke
**Purpose:** User disconnects WHOOP from DoseTrack

**Request Headers:**
```
Authorization: Bearer <session_id>
```

**Response:**
```json
{
  "status": "revoked"
}
```

**Backend Logic:**
1. DELETE `https://api.prod.whoop.com/developer/v2/user/access`
   - Header: `Authorization: Bearer <access_token>`
2. Delete tokens from database
3. Return success

---

## 4. iOS App Implementation

### 4.1 Settings UI (SettingsViewEnhanced.swift)

**Add to Data Integrations section:**

```swift
Section(header: Text("Data Integrations")) {
    // Existing: Health Data Export
    NavigationLink(destination: HealthDataExportView()) {
        Label("Health Data Export", systemImage: "heart.text.square")
    }
    
    // NEW: WHOOP Integration
    NavigationLink(destination: WhoopIntegrationView()) {
        HStack {
            Label("WHOOP", systemImage: "waveform.path.ecg")
            Spacer()
            if whoopConnectionStatus == .connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if whoopConnectionStatus == .connecting {
                ProgressView()
            }
        }
    }
}
```

### 4.2 New View: WhoopIntegrationView.swift

**Location:** `ios/WhoopIntegrationView.swift`

**Features:**
- Connect/Disconnect button
- Last sync timestamp
- Recovery data preview (last 7 days)
- Status chip (connected/disconnected/syncing)
- Error handling

**Key Components:**

```swift
import SwiftUI

struct WhoopIntegrationView: View {
    @AppStorage("whoop_session_id") private var sessionId: String?
    @AppStorage("whoop_last_sync") private var lastSync: Double = 0
    @State private var isConnecting = false
    @State private var connectionStatus: WhoopStatus = .disconnected
    @State private var recentRecovery: [RecoveryRecord] = []
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Connection Status")) {
                HStack {
                    Text("Status")
                    Spacer()
                    statusBadge
                }
                
                if connectionStatus == .connected {
                    Text("Last Sync: \(formattedLastSync)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                if connectionStatus == .disconnected {
                    Button(action: connectWhoop) {
                        HStack {
                            Image(systemName: "link")
                            Text("Connect WHOOP")
                        }
                    }
                    .disabled(isConnecting)
                } else {
                    Button(action: syncRecoveryData) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Recovery Data")
                        }
                    }
                    
                    Button(action: disconnectWhoop) {
                        HStack {
                            Image(systemName: "link.badge.minus")
                            Text("Disconnect WHOOP")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            
            if connectionStatus == .connected && !recentRecovery.isEmpty {
                Section(header: Text("Recent Recovery (Last 7 Days)")) {
                    ForEach(recentRecovery) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.date, style: .date)
                                    .font(.headline)
                                Spacer()
                                recoveryBadge(record.recoveryScore)
                            }
                            
                            HStack(spacing: 12) {
                                metricView("HRV", "\(Int(record.hrvRmssd))ms")
                                metricView("RHR", "\(Int(record.restingHR))bpm")
                                if let spo2 = record.spo2 {
                                    metricView("SpO₂", "\(Int(spo2))%")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("WHOOP Integration")
        .onAppear(perform: loadConnectionStatus)
    }
    
    private func connectWhoop() {
        isConnecting = true
        errorMessage = nil
        
        // Generate OAuth URL
        let clientId = Config.whoopClientId // From Config.swift
        let redirectUri = "dosetrack://oauth/whoop/callback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let scopes = "read:recovery+read:sleep"
        let authUrl = "https://api.prod.whoop.com/oauth/oauth2/auth?client_id=\(clientId)&redirect_uri=\(redirectUri)&response_type=code&scope=\(scopes)"
        
        // Open Safari for OAuth
        if let url = URL(string: authUrl) {
            UIApplication.shared.open(url)
        }
        
        // App will handle callback via URL scheme (see AppDelegate/SceneDelegate)
    }
    
    private func syncRecoveryData() {
        // Fetch last 7 days
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        
        Task {
            do {
                let records = try await WhoopAPIClient.shared.fetchRecovery(
                    sessionId: sessionId!,
                    start: start,
                    end: end
                )
                
                await MainActor.run {
                    recentRecovery = records
                    lastSync = Date().timeIntervalSince1970
                    connectionStatus = .connected
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func disconnectWhoop() {
        Task {
            do {
                try await WhoopAPIClient.shared.revokeAccess(sessionId: sessionId!)
                
                await MainActor.run {
                    sessionId = nil
                    lastSync = 0
                    recentRecovery = []
                    connectionStatus = .disconnected
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Disconnect failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // ... helper views and formatters
}

enum WhoopStatus {
    case disconnected, connecting, connected, error
}

struct RecoveryRecord: Identifiable {
    let id = UUID()
    let date: Date
    let cycleId: Int
    let sleepId: String
    let recoveryScore: Double
    let hrvRmssd: Double
    let restingHR: Double
    let spo2: Double?
    let skinTemp: Double?
}
```

### 4.3 API Client: WhoopAPIClient.swift

**Location:** `ios/WhoopAPIClient.swift`

**Purpose:** Handle all communication with DoseTrack backend OAuth proxy

```swift
import Foundation

class WhoopAPIClient {
    static let shared = WhoopAPIClient()
    
    private let baseURL = Config.whoopProxyURL // e.g., "https://api.dosetrack.app/whoop"
    
    // Called after OAuth redirect captures authorization code
    func exchangeCode(_ code: String) async throws -> String {
        let url = URL(string: "\(baseURL)/oauth/exchange")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "code": code,
            "redirect_uri": "dosetrack://oauth/whoop/callback"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhoopError.exchangeFailed
        }
        
        let result = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        return result.sessionId
    }
    
    func fetchRecovery(sessionId: String, start: Date, end: Date) async throws -> [RecoveryRecord] {
        let url = URL(string: "\(baseURL)/data/recovery")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let body = [
            "start": formatter.string(from: start),
            "end": formatter.string(from: end)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhoopError.fetchFailed
        }
        
        let result = try JSONDecoder().decode(RecoveryResponse.self, from: data)
        return result.records.map { record in
            RecoveryRecord(
                date: ISO8601DateFormatter().date(from: record.createdAt) ?? Date(),
                cycleId: record.cycleId,
                sleepId: record.sleepId,
                recoveryScore: record.score.recoveryScore,
                hrvRmssd: record.score.hrvRmssd,
                restingHR: record.score.restingHeartRate,
                spo2: record.score.spo2,
                skinTemp: record.score.skinTemp
            )
        }
    }
    
    func revokeAccess(sessionId: String) async throws {
        let url = URL(string: "\(baseURL)/oauth/revoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhoopError.revokeFailed
        }
    }
}

enum WhoopError: Error {
    case exchangeFailed
    case fetchFailed
    case revokeFailed
}

struct ExchangeResponse: Codable {
    let sessionId: String
    let whoopUserId: Int
    let expiresAt: String
    let scopes: [String]
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case whoopUserId = "whoop_user_id"
        case expiresAt = "expires_at"
        case scopes
    }
}

struct RecoveryResponse: Codable {
    let records: [RecoveryRecordAPI]
}

struct RecoveryRecordAPI: Codable {
    let cycleId: Int
    let sleepId: String
    let createdAt: String
    let score: RecoveryScoreAPI
    
    enum CodingKeys: String, CodingKey {
        case cycleId = "cycle_id"
        case sleepId = "sleep_id"
        case createdAt = "created_at"
        case score
    }
}

struct RecoveryScoreAPI: Codable {
    let recoveryScore: Double
    let hrvRmssd: Double
    let restingHeartRate: Double
    let spo2: Double?
    let skinTemp: Double?
    
    enum CodingKeys: String, CodingKey {
        case recoveryScore = "recovery_score"
        case hrvRmssd = "hrv_rmssd_milli"
        case restingHeartRate = "resting_heart_rate"
        case spo2 = "spo2_percentage"
        case skinTemp = "skin_temp_celsius"
    }
}
```

### 4.4 URL Scheme Handling (AppDelegate/SceneDelegate)

**Add to SceneDelegate.swift or App file:**

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    
    // Handle WHOOP OAuth callback
    if url.scheme == "dosetrack", url.host == "oauth", url.pathComponents.contains("whoop") {
        handleWhoopOAuthCallback(url)
    }
}

private func handleWhoopOAuthCallback(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
        print("❌ No authorization code in callback")
        return
    }
    
    Task {
        do {
            let sessionId = try await WhoopAPIClient.shared.exchangeCode(code)
            
            await MainActor.run {
                UserDefaults.standard.set(sessionId, forKey: "whoop_session_id")
                NotificationCenter.default.post(name: .whoopConnected, object: nil)
            }
        } catch {
            print("❌ Failed to exchange code: \(error)")
        }
    }
}

extension Notification.Name {
    static let whoopConnected = Notification.Name("WhoopConnected")
}
```

**Add to Info.plist:**

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>dosetrack</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.dosetrack.oauth</string>
    </dict>
</array>
```

### 4.5 Config.swift Updates

**Add WHOOP configuration:**

```swift
enum Config {
    // Existing...
    
    // WHOOP OAuth
    static let whoopClientId = "YOUR_WHOOP_CLIENT_ID" // From developer.whoop.com
    static let whoopProxyURL = "https://api.dosetrack.app/whoop" // Your backend
    
    #if DEBUG
    static let whoopProxyURL = "http://localhost:3000/whoop" // Local dev
    #endif
}
```

---

## 5. Data Integration with DoseLog

### 5.1 Schema Extension (Models.swift)

**Add to `DoseLog` or create `NightFeatures` model:**

```swift
struct NightFeatures: Codable {
    // Service day key (joins 1:1 with DoseLog)
    let nightKey: String // "2025-11-04T12:00:00Z"
    
    // WHOOP Recovery (from /v2/recovery endpoint)
    var whoopRecoveryPct: Double? // 0-100
    var whoopHrvRmssd: Double? // milliseconds
    var whoopRestingHR: Double? // bpm
    var whoopSpo2: Double? // percentage
    var whoopSkinTemp: Double? // celsius
    
    // Metadata
    var whoopCycleId: Int?
    var whoopSleepId: String?
    var whoopFetchedAt: Date?
    
    // Provenance
    var dataSource: String = "whoop_api_v2"
    var schemaVersion: Int = 1
}
```

### 5.2 Mapping WHOOP Recovery to Service Day

**Challenge:** WHOOP recovery is tied to sleep end time, DoseTrack uses noon cutoff

**Solution:** Map WHOOP `sleep_id` → HealthKit sleep end → service_day_key

**Algorithm:**

```swift
func mapWhoopRecoveryToServiceDay(_ recovery: RecoveryRecordAPI) -> String? {
    // 1. Fetch WHOOP sleep data by sleep_id
    let sleep = try await WhoopAPIClient.shared.fetchSleep(sleepId: recovery.sleepId)
    
    // 2. Parse sleep end time (UTC)
    let sleepEnd = ISO8601DateFormatter().date(from: sleep.end)!
    
    // 3. Convert to local timezone
    let localEnd = sleepEnd // Adjust for user's timezone
    
    // 4. Compute service day key (noon cutoff)
    let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: localEnd)!
    
    let serviceDay: Date
    if localEnd < noon {
        // Woke before noon → yesterday's service day
        serviceDay = Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    } else {
        // Woke after noon → today's service day
        serviceDay = noon
    }
    
    // 5. Format as night_key (UTC)
    let utcFormatter = ISO8601DateFormatter()
    utcFormatter.timeZone = TimeZone(identifier: "UTC")
    return utcFormatter.string(from: serviceDay) // "2025-11-04T12:00:00Z"
}
```

### 5.3 Export Format (JSONL)

**File:** `HealthExports/night_features_TIMESTAMP.jsonl`

**Example:**

```jsonl
{"type":"night_features","schema_version":1,"source":"whoop_api_v2"}
{"night_key":"2025-11-04T12:00:00Z","whoop_recovery_pct":44.0,"whoop_hrv_rmssd":31.81,"whoop_resting_hr":64.0,"whoop_spo2":95.69,"whoop_skin_temp":33.7,"whoop_cycle_id":93845,"whoop_sleep_id":"123e4567-e89b-12d3-a456-426614174000","whoop_fetched_at":"2025-11-05T10:00:00Z","data_source":"whoop_api_v2","schema_version":1}
{"night_key":"2025-11-03T12:00:00Z","whoop_recovery_pct":62.0,"whoop_hrv_rmssd":45.2,"whoop_resting_hr":58.0,"whoop_spo2":96.5,"whoop_skin_temp":34.1,"whoop_cycle_id":93844,"whoop_sleep_id":"223e4567-e89b-12d3-a456-426614174001","whoop_fetched_at":"2025-11-05T10:00:00Z","data_source":"whoop_api_v2","schema_version":1}
```

**Join with DoseLog:**

```sql
-- Conceptual join (via normalize.js or ML pipeline)
SELECT 
    dl.night_key,
    dl.dose1_utc,
    dl.dose2_utc,
    dl.final_wake_utc,
    nf.whoop_recovery_pct,
    nf.whoop_hrv_rmssd
FROM dose_log dl
LEFT JOIN night_features nf ON dl.night_key = nf.night_key
WHERE dl.night_key >= '2025-11-01T12:00:00Z'
ORDER BY dl.night_key DESC;
```

---

## 6. Backend Implementation Options

### Option A: Cloud Function (Minimal)

**Platforms:**
- Google Cloud Functions (Node.js/Python)
- AWS Lambda (Node.js/Python)
- Railway (Node.js)
- Fly.io (Node.js)

**Example (Node.js/Express):**

```javascript
// server/whoop-oauth-proxy/index.js
const express = require('express');
const crypto = require('crypto');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

const app = express();
app.use(express.json());

const WHOOP_CLIENT_ID = process.env.WHOOP_CLIENT_ID;
const WHOOP_CLIENT_SECRET = process.env.WHOOP_CLIENT_SECRET;
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY; // 32-byte key for AES-256

// In-memory store (replace with Firestore/Postgres in production)
const sessions = new Map();

// POST /whoop/oauth/exchange
app.post('/whoop/oauth/exchange', async (req, res) => {
    const { code, redirect_uri } = req.body;
    
    try {
        // Exchange code for tokens
        const tokenResponse = await fetch('https://api.prod.whoop.com/oauth/oauth2/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                grant_type: 'authorization_code',
                code,
                client_id: WHOOP_CLIENT_ID,
                client_secret: WHOOP_CLIENT_SECRET,
                redirect_uri
            })
        });
        
        const tokens = await tokenResponse.json();
        
        if (!tokens.access_token) {
            return res.status(400).json({ error: 'Token exchange failed' });
        }
        
        // Fetch user profile
        const profileResponse = await fetch('https://api.prod.whoop.com/developer/v2/user/profile/basic', {
            headers: { 'Authorization': `Bearer ${tokens.access_token}` }
        });
        const profile = await profileResponse.json();
        
        // Generate session ID
        const sessionId = crypto.randomUUID();
        
        // Encrypt tokens
        const encryptedAccess = encrypt(tokens.access_token);
        const encryptedRefresh = encrypt(tokens.refresh_token);
        
        // Store session
        sessions.set(sessionId, {
            whoop_user_id: profile.user_id,
            access_token: encryptedAccess,
            refresh_token: encryptedRefresh,
            expires_at: Date.now() + (tokens.expires_in * 1000),
            scopes: ['read:recovery', 'read:sleep']
        });
        
        res.json({
            session_id: sessionId,
            whoop_user_id: profile.user_id,
            expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
            scopes: ['read:recovery', 'read:sleep']
        });
    } catch (error) {
        console.error('Exchange error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /whoop/data/recovery
app.post('/whoop/data/recovery', async (req, res) => {
    const sessionId = req.headers.authorization?.replace('Bearer ', '');
    const { start, end } = req.body;
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(401).json({ error: 'Invalid session' });
    }
    
    // Check if token expired → refresh
    if (Date.now() > session.expires_at) {
        await refreshToken(sessionId, session);
    }
    
    const accessToken = decrypt(session.access_token);
    
    try {
        const response = await fetch(
            `https://api.prod.whoop.com/developer/v2/recovery?start=${start}&end=${end}`,
            { headers: { 'Authorization': `Bearer ${accessToken}` } }
        );
        
        const data = await response.json();
        res.json(data);
    } catch (error) {
        console.error('Fetch error:', error);
        res.status(500).json({ error: 'Failed to fetch recovery data' });
    }
});

// DELETE /whoop/oauth/revoke
app.delete('/whoop/oauth/revoke', async (req, res) => {
    const sessionId = req.headers.authorization?.replace('Bearer ', '');
    
    const session = sessions.get(sessionId);
    if (!session) {
        return res.status(401).json({ error: 'Invalid session' });
    }
    
    const accessToken = decrypt(session.access_token);
    
    try {
        await fetch('https://api.prod.whoop.com/developer/v2/user/access', {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${accessToken}` }
        });
        
        sessions.delete(sessionId);
        res.json({ status: 'revoked' });
    } catch (error) {
        console.error('Revoke error:', error);
        res.status(500).json({ error: 'Revocation failed' });
    }
});

// Helper: Refresh token
async function refreshToken(sessionId, session) {
    const refreshToken = decrypt(session.refresh_token);
    
    const response = await fetch('https://api.prod.whoop.com/oauth/oauth2/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: refreshToken,
            client_id: WHOOP_CLIENT_ID,
            client_secret: WHOOP_CLIENT_SECRET
        })
    });
    
    const tokens = await response.json();
    
    session.access_token = encrypt(tokens.access_token);
    session.expires_at = Date.now() + (tokens.expires_in * 1000);
    sessions.set(sessionId, session);
}

// Helper: AES-256-GCM encryption
function encrypt(plaintext) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-gcm', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    
    return Buffer.concat([iv, authTag, encrypted]).toString('base64');
}

function decrypt(ciphertext) {
    const buffer = Buffer.from(ciphertext, 'base64');
    const iv = buffer.slice(0, 16);
    const authTag = buffer.slice(16, 32);
    const encrypted = buffer.slice(32);
    
    const decipher = crypto.createDecipheriv('aes-256-gcm', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
    decipher.setAuthTag(authTag);
    
    return decipher.update(encrypted) + decipher.final('utf8');
}

app.listen(3000, () => console.log('WHOOP OAuth Proxy running on :3000'));
```

**Deployment:**

```bash
# Railway (easiest)
railway login
railway init
railway up

# Or Google Cloud Functions
gcloud functions deploy whoop-oauth-proxy \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --set-env-vars WHOOP_CLIENT_ID=xxx,WHOOP_CLIENT_SECRET=yyy,ENCRYPTION_KEY=zzz
```

### Option B: Existing Server Extension

If you already have a backend (e.g., for server/ directory), add these endpoints to your existing Express/Flask/Django app.

---

## 7. Security Considerations

### 7.1 Token Storage

**iOS App:**
- Store ONLY `session_id` in `@AppStorage` or UserDefaults
- NEVER store `access_token` or `refresh_token` on device
- Use App Groups if needed for Widget extension

**Backend:**
- Encrypt tokens at rest (AES-256-GCM)
- Use dedicated encryption key (not database password)
- Store encryption key in secret manager (Google Secret Manager, AWS Secrets Manager)

### 7.2 HTTPS Only

- All communication must use HTTPS (enforce in production)
- Use TLS 1.2+ for backend
- Certificate pinning optional (for high security)

### 7.3 Rate Limiting

WHOOP API has rate limits (not documented in OpenAPI spec, likely standard OAuth2 limits):

- Implement exponential backoff
- Cache recovery data locally (avoid redundant fetches)
- Sync once daily (background task at noon cutoff)

### 7.4 Error Handling

**401 Unauthorized → Token Expired:**
- Backend auto-refreshes using refresh_token
- If refresh fails → prompt user to reconnect

**404 Not Found → User Revoked Access:**
- Clear session_id from app
- Update UI to "Disconnected"

**429 Rate Limited:**
- Retry with exponential backoff (1s, 2s, 4s, 8s)
- Show "Rate limited, retrying..." message

---

## 8. Testing Plan

### 8.1 OAuth Flow Test

1. **Happy Path:**
   - User taps "Connect WHOOP"
   - Safari opens → user signs in
   - App receives callback with code
   - Backend exchanges code for tokens
   - Status shows "Connected"

2. **Error Cases:**
   - User cancels OAuth → no code in callback
   - Invalid code → backend returns 400
   - Network error → show retry button

### 8.2 Recovery Data Fetch

1. **Initial Sync:**
   - Fetch last 30 days of recovery data
   - Map to service_day_key using sleep end times
   - Export to JSONL

2. **Incremental Sync:**
   - Daily background task at noon
   - Fetch only new recovery records (start = last_sync)
   - Append to existing JSONL

### 8.3 Token Refresh

1. **Simulate Expiration:**
   - Set expires_at to past timestamp
   - Fetch recovery data
   - Verify backend auto-refreshes token
   - Data fetch succeeds

### 8.4 Disconnection

1. **User Revokes:**
   - Tap "Disconnect WHOOP"
   - Backend calls /v2/user/access DELETE
   - Session deleted
   - Status shows "Disconnected"

---

## 9. Implementation Timeline

### Phase 1: Backend Setup (Week 1)
- [ ] Register app at developer.whoop.com
- [ ] Deploy OAuth proxy (Railway/Cloud Functions)
- [ ] Implement /oauth/exchange endpoint
- [ ] Implement /data/recovery endpoint
- [ ] Test with Postman/curl

### Phase 2: iOS OAuth Flow (Week 2)
- [ ] Create WhoopIntegrationView.swift
- [ ] Add WhoopAPIClient.swift
- [ ] Implement URL scheme handling
- [ ] Test authorization flow end-to-end
- [ ] Add to SettingsViewEnhanced

### Phase 3: Data Integration (Week 3)
- [ ] Extend Models.swift with NightFeatures
- [ ] Implement service_day_key mapping
- [ ] Add WHOOP data to JSONL export
- [ ] Test join with DoseLog

### Phase 4: Polish & Testing (Week 4)
- [ ] Add error handling
- [ ] Implement daily background sync
- [ ] Create unit tests (OAuth, mapping)
- [ ] Documentation (README, PRD update)
- [ ] Beta testing with real WHOOP users

**Total Estimated Effort:** 3-4 weeks (1 developer)

---

## 10. Open Questions

1. **WHOOP Developer Registration:**
   - Do we have a developer account? If not, who registers?
   - What's the approval timeline?

2. **Backend Hosting:**
   - Preference: Railway, Google Cloud, AWS, or existing server?
   - Budget for hosting? (Cloud Functions: ~$5-10/month for low volume)

3. **Token Persistence:**
   - Use Firestore, PostgreSQL, or in-memory (dev only)?
   - Backup/disaster recovery plan?

4. **Privacy Policy:**
   - Update privacy policy to disclose WHOOP data collection
   - GDPR/CCPA compliance (data deletion on request)

5. **Multi-User Support:**
   - One DoseTrack user can connect multiple WHOOP accounts? (likely no)
   - Handle account switching?

---

## 11. References

- **WHOOP API Docs:** https://developer.whoop.com/api
- **OpenAPI Spec:** https://api.prod.whoop.com/developer/doc/openapi.json
- **OAuth2 RFC:** https://datatracker.ietf.org/doc/html/rfc6749
- **DoseTrack Constitution:** `.specify/memory/constitution.md` (Principle II: Local-First Privacy)
- **PRD:** `docs/PRD_v1.2.md` (Health Data Export section)

---

## 12. Next Steps

**Immediate Actions:**

1. **Decision:** Approve this integration plan (review with stakeholders)
2. **Register:** Create WHOOP developer account at https://developer.whoop.com/
3. **Backend:** Choose hosting platform (recommend Railway for simplicity)
4. **Prototype:** Implement Phase 1 (backend OAuth proxy) in 2-3 days
5. **Test:** Validate OAuth flow with curl before iOS work

**Blocked On:**
- WHOOP developer account approval
- Backend hosting decision
- `client_id` and `client_secret` from WHOOP

---

**Document Version:** 1.0  
**Author:** GitHub Copilot  
**Reviewed By:** [Pending]  
**Approved By:** [Pending]
