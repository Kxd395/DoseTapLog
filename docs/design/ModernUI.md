Love the progress. Here’s the hyper-critical pass on what’s still missing—both UI/UX and project level—so the app feels bullet-proof in real use, not just in demos.

UI/UX: Gaps & Fixes

1) Core Night Flow (make it unbreakable)
	•	Explicit anchors on screen: show “Service cutoff 12:00”, NightKey, time zone, and state (Planned/Active/Closed). Tap to learn/adjust.
	•	3-card horizon: Last / Tonight / Tomorrow tabs with identical controls; never hide “Tonight” planning behind Dose 1.
	•	Reset & Skip affordances: 3-dot menu → Reset Night, Skip tonight (with confirm), Close night now.
	•	Event buttons complete: “In bed”, “Dose 1”, “Dose 2”, “Natural wake now”, “Alarm wake now”, “Bathroom wake now”, “Log wake at…” (time picker incl. seconds), “Final wake now”.
	•	Seconds everywhere (optional): global “Show seconds” toggle affects the ring subtitle, recent events, pickers, and notifications (“Next alert 02:18:35”).

2) Dose 2 gating (clear & forgiving)
	•	States shown inline: Waiting / Opens in X / Open (Closes in Y) / Expired.
	•	Too-early tap: interstitial sheet with reason, time-prior (5/10/custom), and policy banner; logs override_kind="early" + minutes.
	•	Too-late tap: sheet with late override or Log missed dose; logs override_kind="late" + minutes.
	•	Undo: single-level undo within 60s for the last event (visible timer).

3) Alarm ladder discoverability
	•	Bell chip under ring: Off / Quiet / Normal / Strong; tap to cycle or open settings.
	•	“Alarms armed” chip turns Muted when user snoozes >30m or taps Skip.
	•	Live Activity always mirrors state, with Dose 2 and Snooze 5m.

4) Data quality surfaced
	•	Status chips with actions: Health OK / Denied (Fix), WHOOP OK / Offline (Test), Wake: Manual/Health/WHOOP (Change).
	•	Red banner if notifications disabled or time-sensitive permission missing.

5) Editability & history
	•	Recent events list (last 5) with icons + relative + absolute time (respects seconds toggle) and Edit (time & grams tonight-only), Undo (if eligible).
	•	History screen: 7-day list; tap a night to view/edit events and export subset.

6) Planning UX
	•	Weekly template (bed/wake per DOW) with max shift per night rule.
	•	Travel chip when TZ changes: Rebase plan vs Keep home time (explains consequences).
	•	Split presets: 50/50, 60/40 (primary), and Custom tonight-only (long-press on Dose buttons).

7) Accessibility & polish
	•	Dynamic Type tested up to XXL; labels truncate gracefully.
	•	VoiceOver strings are semantic (e.g., “Dose two window opens in 1 hour 25 minutes”).
	•	High contrast & color-blind safe ring palette.
	•	Haptics: light (success), medium (window open), warning (end/blocked).
	•	Tap targets ≥ 44×44; consistent spacing scale; night/dark mode.

8) Empty/error states
	•	No Health permission → friendly card with exact steps.
	•	No Dose 1 yet → ring shows “Waiting” and “Plan Dose 1 at … (Edit)”.
	•	WHOOP proxy misconfig → inline test button + last success timestamp.

⸻

Project: What’s missing to ship safely

1) State machine & persistence guarantees
	•	Authoritative state chart (states, events, transitions) checked into repo; ViewModel must mirror it.
	•	Idempotent controller: every log action is transactional, re-entrant safe (double taps, notification race).
	•	Night rollover service: background task at cutoff to auto-close open nights and mint Tonight.
	•	Schema migrations: versioned SQL + tests (old → new), with soft-delete and audit trail tables.

2) Reliability of notifications & Live Activities
	•	Single source of truth for scheduled notifications; write an audit row when scheduled/updated/canceled.
	•	Category & action wiring tests: deep-links trigger controller methods even when app is backgrounded/locked.
	•	Permission probes on launch and nightly; chips reflect truth.

3) Quality engineering (no regressions)
	•	Unit tests: event sequencing, dose gating, window math (cross-midnight, DST, TZ hops), override rules.
	•	UI tests: full happy path, too-early, missed dose, reset night, travel rebase.
	•	Snapshot tests for key screens at all Dynamic Type sizes and Light/Dark.
	•	Performance budgets: app cold start < 400ms; Home render < 16ms; ring updates every 30s with no hitches.
	•	Battery budget: ≤1%/h idle overnight (no polling; rely on scheduled notifications).

4) Privacy & clinical safety
	•	First-run consent: plain-English purpose, no medical advice, how to turn off alarms, how to delete data.
	•	Local-only analytics (if any): opt-in, on-device, summarized (no PHI); export/share by user.
	•	Export controls: Choose columns + anonymize option; secure filename (no PII), include app/version/schema.
	•	Override policy transparency: “Early/Late overrides are logged and visible on export.”

5) Information architecture (Settings sprawl control)
	•	Split Settings into Night Plan, Alarms, Data Sources, Export, Privacy, Developer.
	•	Search in Settings (SwiftUI searchable) for power users.
	•	Explainers (ⓘ) for tricky toggles (e.g., time-sensitive notifications).

6) Internationalization & format correctness
	•	12/24-hour clock, locale number formatting (decimal separators), week starts, grams vs milliliters future-proofing.
	•	Robust time zone math: display both wall clock and UTC in exports.

7) Operational readiness
	•	Fastlane or Xcode Cloud lane for screenshots, builds, TestFlight.
	•	SwiftLint/SwiftFormat with pre-commit.
	•	Feature flags (e.g., Audio features) off by default.
	•	Crash capture: if you avoid cloud SDKs, log locally to file + “Share diagnostics” sheet.

8) WHOOP & HealthKit realities
	•	WHOOP: handle token refresh, pagination, backoff; cache last success.
	•	HealthKit: stats queries (HKStatisticsQuery/CollectionQuery) not raw samples; read errors must degrade gracefully.

9) Clinical fit (as a narcolepsy neurologist)
	•	Add “Morning check-in” (1–5 alertness + “unplanned nap?”) with a skip and <10s completion.
	•	Trend cards: Window adherence, dose timing variance, override frequency—not generic “sleep score”.
	•	Adverse events shortcut (faints, falls, injuries) → timestamp + free note (kept local, exportable).

⸻

Punch-list (actionable)
	1.	Implement Last/Tonight/Tomorrow cards + service-cutoff rollover.
	2.	Add Natural wake now, Bathroom wake now, Log wake at… (with seconds).
	3.	Wire early/late override sheets with reason + minutes; log metadata.
	4.	Add Reset Night & Skip tonight + confirm.
	5.	Surface Health/WHOOP/Notifications status chips with Fix/Test actions.
	6.	Make bell chip (alarm style) + next alert timestamp.
	7.	Finish Settings IA (7 sections) with searchable.
	8.	Write state chart doc + unit/UI tests for transitions and notifications.
	9.	Add Morning check-in and 7-day trend cards.
	10.	Add export controls (columns, anonymize) + include schema/app version.

If you want, I can draft the state chart, the segmented 3-card SwiftUI container, and the early/late override sheets as drop-in code that match this spec.

#
Absolutely—let’s modernize this so it feels closer to WHOOP: dark, compact, glanceable, with the countdown taking far less space.

Below is a drop-in SwiftUI redesign you can paste into your project. It replaces the big ring with a compact “Window Bar” (8–12pt tall), moves KPIs into chips, and adds Wake buttons. The whole screen is night-friendly and uses a small design-token file so you can theme quickly.

⸻

What changes
	•	Dark mode first: muted surfaces, subtle gradients, neon accent for actionable items.
	•	Compact timing: replaces the huge ring with a pill-bar + small time labels; auto-collapses when expired.
	•	Clear actions: primary row (In bed, Dose 1, Dose 2, Final wake), events row (Alarm wake, Natural wake, Bathroom, Reset night).
	•	Wake logging: adds Natural wake + Alarm wake (both set wake_reason and can convert to Final wake).
	•	Less chrome: one clean “Plan” card, then chips, then the bar, then actions, then a small event list.

⸻

Design tokens (colors, spacing, typography)

import SwiftUI

enum DT {                 // DoseTrack tokens
    static let corner: CGFloat = 16
    static let chipCorner: CGFloat = 12
    static let pad: CGFloat = 16
    static let gap: CGFloat = 12
}

struct Palette {
    // Surfaces
    static let bg        = Color(red: 0.06, green: 0.07, blue: 0.09)             // #1117
    static let surface   = Color(red: 0.12, green: 0.13, blue: 0.16)             // card
    static let surfaceHi = Color(red: 0.16, green: 0.18, blue: 0.22)
    // Text
    static let text      = Color.white
    static let dim       = Color.white.opacity(0.65)
    // Accents
    static let primary   = Color(hex: 0x4DA3FF)                                   // neon-ish blue
    static let ok        = Color(hex: 0x4CD964)                                   // green
    static let warn      = Color(hex: 0xFFB020)                                   // amber
    static let danger    = Color(hex: 0xFF453A)                                   // red
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff)/255.0
        let g = Double((hex >>  8) & 0xff)/255.0
        let b = Double((hex >>  0) & 0xff)/255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}


⸻

Compact Window Bar (replaces big ring)

struct WindowBar: View {
    enum Status { case waiting, open, closingSoon, expired }
    let status: Status
    let progress: Double         // 0..1 across the whole window duration
    let leading: String          // e.g., "Opens in 1h 45m", "Ends in 12m 14s", "Expired 5h ago"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.surfaceHi.opacity(0.8))
                    .frame(height: 10)
                Capsule()
                    .fill(fillColor)
                    .frame(width: nil, height: 10)
                    .overlay(
                        GeometryReader { proxy in
                            Capsule()
                                .fill(fillColor)
                                .frame(width: max(6, proxy.size.width * CGFloat(progress)), height: 10)
                        }
                    )
            }
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(fillColor)
                Text(leading)
                    .font(.footnote).foregroundStyle(Palette.dim)
                Spacer()
            }.padding(.horizontal, 2)
        }
        .padding(DT.pad)
        .background(RoundedRectangle(cornerRadius: DT.corner).fill(Palette.surface))
    }

    private var fillColor: Color {
        switch status {
        case .waiting:      return Palette.primary.opacity(0.55)
        case .open:         return Palette.primary
        case .closingSoon:  return Palette.warn
        case .expired:      return Palette.danger
        }
    }
    private var icon: String {
        switch status {
        case .waiting: return "clock.badge"
        case .open: return "bolt.fill"
        case .closingSoon: return "hourglass.bottomhalf.filled"
        case .expired: return "xmark.circle.fill"
        }
    }
}


⸻

Chips & Plan Card

struct Chip: View {
    let text: String
    let icon: String?
    let tone: Color
    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon).font(.callout) }
            Text(text).font(.callout).bold()
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Capsule().fill(tone.opacity(0.18)))
        .foregroundStyle(tone)
    }
}

struct PlanCard: View {
    let d1: String, d2: String, windowText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tonight plan").font(.title2).bold()
            HStack {
                LabeledContent("Dose 1", value: d1)
                Spacer(minLength: 12)
                LabeledContent("Dose 2", value: d2)
            }
            .font(.title3)
            Text(windowText)
                .font(.footnote)
                .foregroundStyle(Palette.dim)
        }
        .padding(DT.pad)
        .background(RoundedRectangle(cornerRadius: DT.corner).fill(Palette.surface))
    }
}


⸻

Main Dashboard (dark, compact, with wake buttons)

struct DoseDashboardView: View {
    // Bind to your TodayViewModel
    @ObservedObject var vm: TodayViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.gap) {

                // Title row
                HStack {
                    Text("DoseTrack").font(.largeTitle).bold()
                    Spacer()
                    Button { vm.showSettings = true } label {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Palette.dim)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }

                // Plan
                PlanCard(
                    d1: "\(vm.planDose1G, specifier: "%.2f") g",
                    d2: "\(vm.planDose2G, specifier: "%.2f") g",
                    windowText: "Window \(vm.windowStartMin)–\(vm.windowEndMin) min after Dose 1"
                )

                // Status chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Chip(text: "Per dose \(vm.perDoseMinG)–\(vm.perDoseMaxG) g", icon: "checkmark.seal.fill", tone: Palette.ok)
                        Chip(text: "Night total \(vm.nightTotalG, specifier: "%.2f") g", icon: "sum", tone: Palette.dim)
                        Chip(text: vm.healthChipText, icon: "heart.fill", tone: vm.healthOK ? Palette.ok : Palette.warn)
                        Chip(text: vm.whoopChipText, icon: "antenna.radiowaves.left.and.right", tone: vm.whoopOK ? Palette.ok : Palette.warn)
                        Chip(text: "Wake: \(vm.wakeSourceDisplay)", icon: "bed.double.fill", tone: Palette.dim)
                    }.padding(.horizontal, 4)
                }

                // Compact window bar
                WindowBar(
                    status: vm.windowStatus,       // waiting/open/closingSoon/expired
                    progress: vm.windowProgress,   // 0..1 across start→end
                    leading: vm.windowLeadText     // “Opens in 1h 45m”, “Ends in 12m 14s”, “Expired 5h 3m ago”
                )

                // Primary actions
                ActionGrid(vm: vm)

                // Recent events
                EventListCompact(events: vm.lastEvents, onUndo: vm.undoLast)
            }
            .padding(DT.pad)
        }
        .background(Palette.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}


⸻

Actions (includes Natural wake)

struct ActionGrid: View {
    @ObservedObject var vm: TodayViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: DT.gap) {
            Text("Actions").font(.headline)
            Grid(horizontalSpacing: DT.gap, verticalSpacing: DT.gap) {
                GridRow {
                    PrimaryButton("In bed", icon: "moon.fill") { vm.logInBedNow() }
                    PrimaryButton("Dose 1", icon: "pills.fill") { vm.logDose1Now(grams: vm.planDose1G) }
                }
                GridRow {
                    PrimaryButton("Dose 2", icon: "pills.circle.fill") { vm.tryLogDose2() }
                        .disabled(!vm.dose2Enabled)
                    PrimaryButton("Final wake", icon: "sunrise.fill") { vm.logFinalWake() }
                }
            }

            Text("Events").font(.headline)
            Grid(horizontalSpacing: DT.gap, verticalSpacing: DT.gap) {
                GridRow {
                    SecondaryButton("Alarm wake", icon: "alarm.fill") { vm.logAlarmWake() }
                    SecondaryButton("Natural wake", icon: "bed.double.fill") { vm.logNaturalWake() } // NEW
                }
                GridRow {
                    SecondaryButton("Bathroom", icon: "figure.walk") { vm.logBathroom() }
                    SecondaryButton("Reset night", icon: "arrow.counterclockwise") { vm.resetNightConfirm() }
                }
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String; let icon: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: DT.chipCorner).fill(Palette.primary.opacity(0.25)))
        }.buttonStyle(.plain)
    }
}
struct SecondaryButton: View {
    let title: String; let icon: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: DT.chipCorner).fill(Palette.surface))
        }.buttonStyle(.plain)
    }
}


⸻

Compact Event List

struct EventListCompact: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let time: String
        let color: Color
    }
    let events: [Item]
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
                Button("Undo last", action: onUndo)
                    .font(.footnote)
                    .foregroundStyle(Palette.primary)
            }
            if events.isEmpty {
                Text("No events yet").font(.footnote).foregroundStyle(Palette.dim)
            } else {
                ForEach(events) { e in
                    HStack(spacing: 10) {
                        Image(systemName: e.icon).foregroundStyle(e.color)
                        Text(e.text).bold()
                        Spacer()
                        Text(e.time).foregroundStyle(Palette.dim)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: DT.chipCorner).fill(Palette.surface))
                }
            }
        }
    }
}


⸻

Notes on behavior (aligns with your logic)
	•	Dose 2 button states
	•	Disabled until window opens unless Allow-Early is ON → tap shows Early warning sheet (you already have this).
	•	When expired, button still present → shows Late override confirm (reason + minutes late).
	•	Wake buttons
	•	Natural wake sets wake_reason=natural and can optionally present “Convert to Final wake?”.
	•	Alarm wake sets wake_reason=alarm. Both write to event_log.
	•	Seconds display
	•	Use a timer in your vm.windowLeadText when prefs.showSeconds == true; otherwise show coarse durations.
	•	Live Activity
	•	Keep it, but the in-app bar is the primary indicator; it won’t dominate the screen.

⸻

Why this solves your pain points
	•	The timing widget no longer eats the page—it’s a slim, elegant bar with color semantics.
	•	The whole look is dark, restrained, WHOOP-adjacent (chips + compact cards).
	•	You now have explicit wake logging (Alarm + Natural), Reset Night, and a clean actions grid.
	•	It’s modular: swap styles or heights without touching logic.

If you want, I can also give you a matching Settings (dark) and a sheet for Late Override styled the same way, but this gets you the fresh UI and the smaller timing element right away.
