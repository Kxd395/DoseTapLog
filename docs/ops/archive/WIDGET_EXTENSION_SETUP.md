# Widget Extension Setup for Live Activities

## Overview
This guide explains how to add a Widget Extension target to display Live Activities on the Lock Screen.

## Steps to Add Widget Extension

### 1. Create Widget Extension Target in Xcode

1. Open `DoseTrackIOS.xcodeproj` in Xcode
2. Click **File → New → Target**
3. Select **Widget Extension**
4. Configure:
   - Product Name: `DoseTrackWidget`
   - Include Configuration Intent: **NO** (unchecked)
   - Organization Identifier: `AxxessPhilly`
   - Bundle Identifier: `AxxessPhilly.DoseTrackIOS.DoseTrackWidget`
5. Click **Finish**
6. When prompted "Activate 'DoseTrackWidget' scheme?", click **Activate**

### 2. Enable Live Activities

1. Select the **DoseTrackWidget** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Push Notifications** (required for Live Activities)
5. Ensure **App Groups** is already configured with `group.com.jefferson.dosetrack`

### 3. Create Live Activity Widget

Replace the generated `DoseTrackWidget.swift` file with the following:

```swift
import WidgetKit
import SwiftUI
import ActivityKit

@available(iOS 16.1, *)
struct DoseWindowLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseWindowAttributes.self) { context in
            // Lock Screen UI
            DoseWindowLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI (iPhone 14 Pro+)
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Dose 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(String(format: "%.2f", context.state.dose2G))g")
                        .font(.caption)
                        .bold()
                }
                DynamicIslandExpandedRegion(.center) {
                    DoseWindowProgressView(
                        openAt: context.state.openAt,
                        closeAt: context.state.closeAt
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Link(destination: URL(string: "dosetrack://dose2now")!) {
                            Text("Log Dose 2")
                                .font(.caption)
                                .padding(8)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Link(destination: URL(string: "dosetrack://snooze?m=5")!) {
                            Text("Snooze 5m")
                                .font(.caption)
                                .padding(8)
                                .background(.secondary, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                    }
                }
            } compactLeading: {
                Text("💊")
            } compactTrailing: {
                Text(timeRemaining(context.state.openAt, context.state.closeAt))
                    .font(.caption2)
            } minimal: {
                Text("💊")
            }
        }
    }
    
    private func timeRemaining(_ open: Date, _ close: Date) -> String {
        let now = Date()
        if now < open {
            let mins = Int(open.timeIntervalSince(now) / 60)
            return "\(mins)m"
        } else if now <= close {
            let mins = Int(close.timeIntervalSince(now) / 60)
            return "⏰\(mins)m"
        } else {
            return "Ended"
        }
    }
}

struct DoseWindowLockScreenView: View {
    let context: ActivityViewContext<DoseWindowAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dose 2 Window")
                    .font(.headline)
                Text("\(String(format: "%.2f", context.state.dose2G))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            DoseWindowProgressView(
                openAt: context.state.openAt,
                closeAt: context.state.closeAt
            )
            .frame(width: 60, height: 60)
        }
        .padding()
        .activityBackgroundTint(.blue.opacity(0.1))
    }
}

struct DoseWindowProgressView: View {
    let openAt: Date
    let closeAt: Date
    
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { timeline in
            let now = timeline.date
            let progress = calculateProgress(now: now)
            let statusText = getStatusText(now: now)
            
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor(now: now), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text(statusText)
                        .font(.caption2)
                        .bold()
                    if progress > 0 && progress < 1 {
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func calculateProgress(now: Date) -> Double {
        if now < openAt {
            return 0
        } else if now > closeAt {
            return 1
        } else {
            let total = closeAt.timeIntervalSince(openAt)
            let elapsed = now.timeIntervalSince(openAt)
            return min(1.0, max(0.0, elapsed / total))
        }
    }
    
    private func getStatusText(now: Date) -> String {
        if now < openAt {
            let mins = Int(openAt.timeIntervalSince(now) / 60)
            return "\(mins)m"
        } else if now <= closeAt {
            let mins = Int(closeAt.timeIntervalSince(now) / 60)
            return "\(mins)m left"
        } else {
            return "Ended"
        }
    }
    
    private func progressColor(now: Date) -> Color {
        if now < openAt {
            return .yellow
        } else if now <= closeAt {
            return .green
        } else {
            return .red
        }
    }
}

@available(iOS 16.1, *)
@main
struct DoseTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        DoseWindowLiveActivity()
    }
}
```

### 4. Configure URL Scheme (for Deep Links)

1. Select the **DoseTrackIOS** (main app) target
2. Go to **Info** tab
3. Expand **URL Types**
4. Click **+** to add a new URL type:
   - Identifier: `com.jefferson.dosetrack`
   - URL Schemes: `dosetrack`
   - Role: `Editor`

### 5. Handle Deep Links in App

Add this to `DoseTrackApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct DoseTrackApp: App {
    var body: some Scene {
        WindowGroup {
            TodayLogView()
        }
        .modelContainer(for: [DoseLog.self, NightPlan.self, EventLog.self])
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "dosetrack" else { return }
        
        switch url.host {
        case "dose2now":
            // Trigger Dose 2 logging
            NotificationCenter.default.post(name: .init("LogDose2"), object: nil)
        case "snooze":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let minutesStr = components.queryItems?.first(where: { $0.name == "m" })?.value,
               let minutes = Int(minutesStr) {
                NudgeScheduler.shared.scheduleSnooze(minutes: minutes)
            }
        default:
            break
        }
    }
}
```

### 6. Build & Test

1. Select **DoseTrackIOS** scheme
2. Build and run (⌘R)
3. Tap "Dose 1 now" in the app
4. Lock the device (⌘L in simulator)
5. You should see the Live Activity on the Lock Screen with:
   - Countdown progress ring
   - Time remaining
   - Deep link buttons (Dose 2, Snooze)

## File Structure After Setup

```
DoseTrackIOS/
├── DoseTrackIOS.xcodeproj
├── DoseTrackIOS/              # Main app target
│   ├── DoseTrackApp.swift
│   ├── TodayLogView.swift
│   ├── DoseWindowActivity.swift
│   └── ... other files
└── DoseTrackWidget/           # Widget extension target (NEW)
    ├── DoseTrackWidget.swift  # Live Activity implementation
    ├── Assets.xcassets
    └── Info.plist
```

## Troubleshooting

### Live Activity Doesn't Appear
- Ensure Widget Extension target is added correctly
- Check that Live Activities are enabled in iOS Settings → [App Name]
- Verify App Groups capability is configured for both targets

### Deep Links Don't Work
- Confirm URL scheme is registered in main app target
- Check that `.onOpenURL` handler is in DoseTrackApp.swift
- URLs must match scheme exactly: `dosetrack://dose2now`

### Build Errors
- Clean build folder: ⇧⌘K
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Rebuild: ⌘B

## Next Steps

1. ✅ Widget extension target created
2. ✅ Live Activity UI implemented
3. ✅ Deep links configured
4. ✅ App Groups shared between targets
5. 🔄 Test on physical device (simulator may have limitations)
6. 🔄 Submit for App Store review (requires Live Activities entitlement)
