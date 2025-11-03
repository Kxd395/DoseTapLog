# DoseTrack Implementation Plan v1.1.1c

## Technical Architecture

### System Overview
DoseTrack is a hybrid system with a native iOS client and an optional Node.js proxy service:

```
┌─────────────────────────────────────────────────────────────┐
│                     DoseTrack iOS App                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   SwiftUI    │  │  SwiftData   │  │  HealthKit   │      │
│  │   Views      │──│   Models     │──│   Manager    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                            │                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Widget    │──│  App Intents │──│  App Group   │      │
│  │   Provider   │  │              │  │    Store     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS (optional)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   WHOOP Proxy Service                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Express    │──│  Rate Limit  │──│  Pagination  │      │
│  │   Router     │  │  Middleware  │  │   Helper     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                            │                                │
│                            │ WHOOP Developer API            │
│                            ▼                                │
│                  ┌──────────────────┐                       │
│                  │   WHOOP Cloud    │                       │
│                  └──────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles
1. **Local-First**: All patient data stored on-device; proxy never persists PHI
2. **Safety-Critical**: Multiple validation layers for dose bounds and timing
3. **Clinician-Ready**: CSV export optimized for clinical workflow integration
4. **Privacy-Preserving**: No cloud sync; explicit user consent for data export
5. **Modern Swift**: SwiftUI, Swift 6 concurrency, MainActor safety

---

## iOS Client Stack

### Platform & Tools
- **Language:** Swift 6.0+
- **UI Framework:** SwiftUI (iOS 17+)
- **Persistence:** SwiftData (backed by SwiftDataModelConfiguration)
- **Concurrency:** Swift Concurrency (async/await, MainActor)
- **Testing:** XCTest with in-memory SwiftData containers
- **Development Environment:** Xcode 15.4+
- **Target Deployment:** iOS 17.0+

### Key Dependencies
- **HealthKit:** Read-only Sleep Analysis access
- **WidgetKit:** Home screen widgets (small, medium, large)
- **App Intents:** Siri shortcuts and widget interactions
- **UserDefaults:** App Group shared container for widget communication

No third-party dependencies required for core functionality.

### Project Structure
```
ios/
├── DoseTrackApp.swift          # App entry point, SwiftData configuration
├── Models.swift                # DoseLog @Model, data types
├── Config.swift                # Constants (dose bounds, window, defaults)
├── DoseLogController.swift     # Persistence layer (to be refactored MainActor)
├── NightPlanRecommender.swift  # Dose calculation algorithm
├── HealthKitManager.swift      # HealthKit integration wrapper
├── CSVExporter.swift           # CSV generation and export
├── TodayLogView.swift          # Main screen (SwiftUI)
├── Rounding+Display.swift      # 0.25g rounding utility
├── Date+UTC.swift              # UTC + offset formatting
├── AppGroupStore.swift         # Widget/intent handoff
├── AppIntents+DoseLog.swift    # Siri shortcuts
├── Widget/
│   └── DoseWidgetProvider.swift  # WidgetKit timeline provider
└── Tests/
    └── DoseLogTests.swift      # XCTest suite
```

### Data Flow Architecture

#### Persistence Layer
**Current (v1.1.1c):**
```swift
// DoseLogController.swift
class DoseLogController {
    let modelContext: ModelContext
    
    func logDose1(nightKey: String, grams: Double)
    func logDose2(nightKey: String, grams: Double)
    func setFinalWake(nightKey: String, date: Date, provenance: String)
    func fetchOrCreateLog(for nightKey: String) -> DoseLog
    func consumePendingFromWidget()
}
```

**Planned (v1.2 refactor):**
- Make `DoseLogController` @MainActor-bound
- Extract view state into `@Observable` view model
- Use Swift Concurrency for background operations (CSV export, HealthKit queries)
- Isolate SwiftData operations to MainActor

#### View Layer
**Current:**
- Single `TodayLogView` screen with inline logic
- Direct calls to `DoseLogController` and `HealthKitManager`
- State managed with `@State` and `@Environment(\.modelContext)`

**Planned:**
```swift
@Observable
final class TodayViewModel {
    let plan: NightPlan
    var currentLog: DoseLog?
    var healthKitStatus: HealthKitStatus
    
    @MainActor
    func loadTodayLog()
    
    @MainActor
    func logDose1()
    
    @MainActor
    func logDose2()
    
    func autofillWake() async
}
```

---

## SwiftData Model Design

### DoseLog Schema
```swift
@Model
final class DoseLog {
    @Attribute(.unique) var nightKey: String
    var nightStartUTC: Date
    var timezoneOffsetMinutes: Int
    
    var dose1TimeUTC: Date?
    var dose1Grams: Double?
    var dose2TimeUTC: Date?
    var dose2Grams: Double?
    
    var finalWakeTimeUTC: Date?
    var finalWakeProvenance: String?
    var bathroomWakeTimesUTC: [Date]?
    
    var morningAlertness: Int?
    var notes: String?
    
    init(nightKey: String, nightStartUTC: Date, timezoneOffsetMinutes: Int) {
        self.nightKey = nightKey
        self.nightStartUTC = nightStartUTC
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
    }
}
```

### Configuration
```swift
// DoseTrackApp.swift
let modelContainer = try ModelContainer(
    for: DoseLog.self,
    configurations: ModelConfiguration(
        isStoredInMemoryOnly: false,
        allowsSave: true
    )
)
```

### Migration Strategy
- Schema version tracked in UserDefaults
- Light migrations for new optional properties
- Custom migrations for breaking changes (e.g., nightKey algorithm update)
- Migration tests validate forward compatibility

---

## WHOOP Proxy Service

### Stack & Dependencies
- **Runtime:** Node.js 18+ (LTS)
- **Framework:** Express 4.x
- **Middleware:**
  - `cors`: Cross-origin support (local dev)
  - `express-rate-limit`: 60 req/min per IP
  - `dotenv`: Environment variable loading
- **HTTP Client:** `node-fetch` 3.x for WHOOP API calls
- **Future:** TypeScript migration for type safety

### Project Structure
```
server/
├── index.js                  # Express app entry point
├── package.json              # Dependencies, scripts
├── .env                      # Secrets (gitignored)
├── .env.example              # Template for secrets
└── test-server.js            # Integration test suite
```

### Endpoints Implementation

#### Health Check
```javascript
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'dosetrack-whoop-proxy',
    version: '1.0.0'
  });
});
```

#### Sleep Latest
```javascript
app.get('/api/sleep/latest', requireApiKey, async (req, res) => {
  const token = process.env.WHOOP_TOKEN;
  const response = await fetch('https://api.whoop.com/developer/v1/activity/sleep', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (!response.ok) {
    return res.status(500).json({ 
      error: 'fetch_failed', 
      detail: `WHOOP API error: ${response.status} ${response.statusText}` 
    });
  }
  
  const data = await response.json();
  res.json(data.records[0] || null);
});
```

#### 7-Day Aggregates
```javascript
app.get('/api/aggregates/7days', requireApiKey, async (req, res) => {
  const nights = await getJsonWithPagination(
    'https://api.whoop.com/developer/v1/activity/sleep',
    { limit: 25, start: sevenDaysAgo, end: now }
  );
  
  const avgRecovery = nights.reduce((sum, n) => sum + n.score.recovery_score, 0) / nights.length;
  const avgSleepMinutes = nights.reduce((sum, n) => sum + n.score.total_sleep_time_milli / 60000, 0) / nights.length;
  
  res.json({ avgRecovery, avgSleepMinutes, nights });
});
```

### Security & Configuration
```bash
# .env
API_KEY=test-api-key-local-dev-only  # Changed before production
WHOOP_TOKEN=your-whoop-token-here    # OAuth token from WHOOP developer portal
PORT=3000
```

**Security Measures:**
- API key validation on all `/api/*` routes
- Rate limiting prevents abuse
- CORS restricted to localhost in dev (remove in production)
- No logging of tokens or PHI
- HTTPS required for production deployment

### Deployment Strategy
**Development:**
- Run locally with `npm start`
- Proxy accessible at `http://localhost:3000`
- iOS app configured with local endpoint

**Production (future):**
- Deploy to Heroku, Railway, or Fly.io
- Environment variables via platform config
- HTTPS enforced
- Update iOS app with production URL
- Consider IP whitelisting or OAuth for iOS → proxy auth

---

## HealthKit Integration

### Authorization Flow
```swift
// HealthKitManager.swift
func requestAuthorization(completion: @escaping (Bool) -> Void) {
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    healthStore.requestAuthorization(
        toShare: [],  // Read-only
        read: [sleepType]
    ) { success, error in
        DispatchQueue.main.async {
            completion(success)
        }
    }
}
```

### Query Implementation
```swift
func fetchLatestFinalWake(
    bedtimeAnchor: Date,
    completion: @escaping (Date?, String?) -> Void
) {
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    let startDate = bedtimeAnchor.addingTimeInterval(-3600)  // 1 hour before
    let endDate = Date()
    
    let predicate = HKQuery.predicateForSamples(
        withStart: startDate,
        end: endDate,
        options: .strictEndDate
    )
    
    let query = HKSampleQuery(
        sampleType: sleepType,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
    ) { query, samples, error in
        guard let samples = samples as? [HKCategorySample] else {
            return completion(nil, nil)
        }
        
        let acceptedValues: Set<HKCategoryValueSleepAnalysis> = [
            .inBed, .asleepCore, .asleepDeep, .asleepREM
        ]
        
        let validSamples = samples.filter { 
            acceptedValues.contains(HKCategoryValueSleepAnalysis(rawValue: $0.value)!) 
        }
        
        if let latest = validSamples.first {
            completion(latest.endDate, "AppleHealth")
        } else {
            completion(nil, nil)
        }
    }
    
    healthStore.execute(query)
}
```

---

## Widget & App Intent Design

### Widget Timeline
```swift
// DoseWidgetProvider.swift
struct DoseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry(date: Date(), plan: defaultPlan)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        let plan = NightPlanRecommender.makePlan(
            totalNightG: UserDefaults.shared.totalNightG,
            splitFirstPct: UserDefaults.shared.splitFirstPct
        )
        
        let entry = DoseEntry(date: Date(), plan: plan)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}
```

### App Intents
```swift
// AppIntents+DoseLog.swift
struct LogDose1Intent: AppIntent {
    static var title: LocalizedStringResource = "Log Dose 1"
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let plan = NightPlanRecommender.makePlan(/* ... */)
        let action = PendingAction(
            id: UUID(),
            type: .logDose1,
            timestamp: Date(),
            doseGrams: plan.dose1DisplayG
        )
        
        AppGroupStore.shared.appendPendingAction(action)
        
        return .result()
    }
}
```

### App Group Communication
```swift
// AppGroupStore.swift
final class AppGroupStore {
    static let shared = AppGroupStore()
    private let defaults = UserDefaults(suiteName: "group.com.jefferson.dosetrack")!
    
    func appendPendingAction(_ action: PendingAction) {
        var actions = pendingActions
        actions.append(action)
        
        if let data = try? JSONEncoder().encode(actions) {
            defaults.set(data, forKey: "pending_actions")
        }
    }
    
    var pendingActions: [PendingAction] {
        guard let data = defaults.data(forKey: "pending_actions"),
              let actions = try? JSONDecoder().decode([PendingAction].self, from: data) else {
            return []
        }
        return actions
    }
    
    func clearPendingActions() {
        defaults.removeObject(forKey: "pending_actions")
    }
}
```

---

## Testing Strategy

### Unit Tests (XCTest)
**Coverage Targets:**
- Safety logic: 100% (dose bounds, window, sequence validation)
- CSV formatting: 95% (HH:mm, timezone offset, header)
- Rounding: 100% (0.25g precision)
- Date utilities: 90% (UTC + offset conversions)

**Example Test:**
```swift
// DoseLogTests.swift
final class DoseLogTests: XCTestCase {
    func testSequenceValidation() throws {
        let log = DoseLog(nightKey: "2025-11-01", nightStartUTC: Date(), timezoneOffsetMinutes: -480)
        log.dose1TimeUTC = Date()
        log.dose2TimeUTC = Date().addingTimeInterval(150 * 60)  // 150 min later
        
        let (valid, error) = log.isValidSequence(windowStartMin: 150, windowEndMin: 240)
        
        XCTAssertTrue(valid)
        XCTAssertNil(error)
    }
    
    func testDose2TooSoon() throws {
        let log = DoseLog(nightKey: "2025-11-01", nightStartUTC: Date(), timezoneOffsetMinutes: -480)
        log.dose1TimeUTC = Date()
        log.dose2TimeUTC = Date().addingTimeInterval(100 * 60)  // 100 min later
        
        let (valid, error) = log.isValidSequence(windowStartMin: 150, windowEndMin: 240)
        
        XCTAssertFalse(valid)
        XCTAssertEqual(error, "Dose 2 too soon")
    }
}
```

### Integration Tests
**Widget/Intent Handoff:**
```swift
func testWidgetDoseLogging() throws {
    // 1. Simulate widget intent
    let intent = LogDose1Intent()
    _ = try await intent.perform()
    
    // 2. Verify pending action queued
    XCTAssertEqual(AppGroupStore.shared.pendingActions.count, 1)
    
    // 3. Simulate app consuming action
    let controller = DoseLogController(modelContext: inMemoryContext)
    controller.consumePendingFromWidget()
    
    // 4. Verify dose logged
    let log = try controller.fetchLog(for: todayNightKey())
    XCTAssertNotNil(log.dose1TimeUTC)
}
```

**WHOOP Proxy:**
```bash
# test-server.js
npm test  # Hits health, auth endpoints with curl-like requests
```

### Manual Testing Checklist
- [ ] First-run HealthKit permission prompt
- [ ] Dose 1 logging updates widget within 5 sec
- [ ] Dose 2 from widget writes to App Group
- [ ] CSV export opens share sheet
- [ ] Final wake autofill from HealthKit
- [ ] WHOOP proxy returns recovery score
- [ ] Local notifications at window start

### Pilot Validation (14 Days)
- Daily capture of Dose 1 + Dose 2
- Weekly CSV export to clinician
- Bug reporting form for crashes/data loss
- Success metric tracking (capture rate, completeness)

---

## Build & Deployment

### iOS App Build
```bash
# Debug build
xcodebuild -scheme DoseTrack \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Unit tests
xcodebuild -scheme DoseTrack \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test

# Archive for TestFlight
xcodebuild -scheme DoseTrack \
  -archivePath DoseTrack.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath DoseTrack.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

### WHOOP Proxy Deployment
```bash
# Local development
cd server
npm install
npm start

# Production (Heroku example)
heroku create dosetrack-whoop-proxy
heroku config:set API_KEY=<production-key>
heroku config:set WHOOP_TOKEN=<production-token>
git push heroku main
```

### Configuration Management
**iOS:**
- Bundle IDs: `com.jefferson.dosetrack`, `com.jefferson.dosetrack.widget`
- App Group: `group.com.jefferson.dosetrack`
- HealthKit entitlements: enabled
- Info.plist: `NSHealthShareUsageDescription`

**Server:**
- `.env` file (never committed)
- Environment variables on hosting platform
- Rotate API keys quarterly
- WHOOP token refresh flow (OAuth)

---

## Development Workflow

### Daily Development
```bash
# iOS changes
1. Edit Swift files
2. Run unit tests: Cmd+U in Xcode
3. Preview in simulator
4. Commit with descriptive message

# Proxy changes
1. Edit server/index.js
2. Restart server: npm start
3. Test with curl or test-server.js
4. Update docs if endpoints change
```

### Code Review Checklist
- [ ] Safety logic changes have test coverage
- [ ] SwiftUI changes update `UI_UX_ASCII.md`
- [ ] CSV schema changes update `CSV_SCHEMA.md`
- [ ] Secrets not committed
- [ ] SwiftLint passes (future)
- [ ] MainActor annotations correct

### Release Process
1. Version bump in Xcode project
2. Update CHANGELOG.md
3. Run full test suite
4. Archive and export IPA
5. Upload to TestFlight
6. Pilot test for 3 days minimum
7. Submit for App Store review

---

## Future Technical Work

### Swift 6 Concurrency Migration
- Make `DoseLogController` @MainActor-isolated
- Extract view models with `@Observable` macro
- Use `Sendable` conformance for data types
- Audit for data races with Swift 6 strict mode

### Proxy Improvements
- Migrate to TypeScript for type safety
- Split routes into separate modules
- Add request/response validation (Zod or similar)
- Implement WHOOP token refresh flow
- Add Prometheus metrics endpoint

### Testing Expansion
- UI tests with XCUITest
- Widget snapshot tests
- Performance profiling (Time Profiler)
- Memory leak detection (Instruments)

### Observability
- Structured logging with `os.Logger`
- Crash reporting integration (Sentry or Crashlytics)
- Analytics events (local only, no PHI)
- CSV export audit trail

---

## Dependencies & Licensing

### iOS
- **Platform Frameworks:** SwiftUI, SwiftData, HealthKit, WidgetKit (Apple)
- **License:** Proprietary iOS app; no open-source dependencies

### WHOOP Proxy
- **express:** MIT
- **express-rate-limit:** MIT
- **node-fetch:** MIT
- **dotenv:** BSD-2-Clause
- **cors:** MIT

No GPL or copyleft dependencies; safe for commercial use.

---

## Appendices

### A. File Tree
```
DoseTrack_v1.1.1c/
├── ios/
│   ├── DoseTrackApp.swift
│   ├── Models.swift
│   ├── Config.swift
│   ├── DoseLogController.swift
│   ├── NightPlanRecommender.swift
│   ├── HealthKitManager.swift
│   ├── CSVExporter.swift
│   ├── TodayLogView.swift
│   ├── Rounding+Display.swift
│   ├── Date+UTC.swift
│   ├── AppGroupStore.swift
│   ├── AppIntents+DoseLog.swift
│   ├── Widget/
│   │   └── DoseWidgetProvider.swift
│   └── Tests/
│       └── DoseLogTests.swift
├── server/
│   ├── index.js
│   ├── package.json
│   ├── .env.example
│   └── test-server.js
├── docs/
│   ├── README.md
│   ├── PRD_v1.2.md
│   ├── PRODUCT_DESCRIPTION.md
│   ├── SECRETS.md
│   ├── design/
│   │   ├── UI_UX_ASCII.md
│   │   └── LOGIC_MAP.md
│   └── ops/
│       └── ACTION_CHECKLIST.md
├── .specify/
│   └── memory/
│       ├── constitution.md
│       ├── spec.md
│       └── plan.md (this file)
└── README.md
```

### B. Command Reference
```bash
# iOS
xcodebuild -list                                    # List schemes
xcodebuild test -scheme DoseTrack -destination ...  # Run tests
swift-format lint ios/                              # Future: Lint

# Server
npm install                                         # Install deps
npm start                                           # Start proxy
npm test                                            # Run tests
node server/index.js                                # Direct start

# Utilities
./quick-test.sh                                     # Validate setup
./demo-server.sh                                    # Start & test proxy
```

### C. Glossary
- **MainActor:** Swift concurrency actor ensuring UI operations run on main thread
- **SwiftData:** Apple's declarative persistence framework (Core Data successor)
- **@Observable:** Swift macro for observable state management
- **App Group:** Shared container for data exchange between app and extensions
- **Timeline Provider:** WidgetKit protocol for scheduling widget updates

---

**Plan Version:** 1.0.0  
**Aligned with:** DoseTrack v1.1.1c, Constitution v1.0.0, Spec v1.0.0  
**Last Updated:** November 1, 2025
