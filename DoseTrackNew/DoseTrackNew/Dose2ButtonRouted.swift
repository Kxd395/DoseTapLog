//
//  Dose2Button.swift
//  DoseTrack
//
//  Always-tappable Dose 2 button with visual lock state and gate routing
//

import SwiftUI

extension NightCardViewModern {
    
    // MARK: - Dose 2 Button Logic
    
    /// Dose 2 button is always tappable, but shows lock state visually
    func dose2Button(_ night: DoseLog) -> some View {
        ActionButton(
            title: "Dose 2",
            icon: "pills.circle.fill",
            style: .primary(locked: dose2IsLocked(night)),
            caption: dose2StatusCaption(night)
        ) {
            tryLogDose2(night)
        }
        .accessibilityHint(dose2StatusCaption(night))
    }
    
    /// Visual lock state (grayed out but still tappable)
    private func dose2IsLocked(_ night: DoseLog) -> Bool {
        let gate = evaluateDose2Gate(
            now: Date(),
            dose1At: night.dose1TimeUTC,
            dose2At: night.dose2TimeUTC,
            policy: Dose2Policy.from(prefs)
        )
        
        switch gate {
        case .ready:
            return false  // Unlocked, within window
        default:
            return true   // Locked visually, but still tappable
        }
    }
    
    /// Status caption shown below button
    private func dose2StatusCaption(_ night: DoseLog) -> String {
        let policy = Dose2Policy.from(prefs)
        let gate = evaluateDose2Gate(
            now: Date(),
            dose1At: night.dose1TimeUTC,
            dose2At: night.dose2TimeUTC,
            policy: policy
        )
        
        switch gate {
        case .ready:
            return "Within window"
        case .needDose1:
            return "Log Dose 1 first"
        case .alreadyLogged:
            return "Already logged"
        case .tooEarly(let minutes):
            return "Opens in \(minutes)m"
        case .tooLate(let minutes):
            return "Closed \(minutes)m ago"
        }
    }
    
    // MARK: - Gate Evaluation & Routing
    
    /// Always-tappable implementation
    /// Routes to appropriate sheet based on gate state
    func tryLogDose2(_ night: DoseLog) {
        print("🔵 tryLogDose2 called - ROUTED VERSION")
        
        let policy = Dose2Policy.from(prefs)
        let gate = evaluateDose2Gate(
            now: Date(),
            dose1At: night.dose1TimeUTC,
            dose2At: night.dose2TimeUTC,
            policy: policy
        )
        
        switch gate {
        case .ready:
            // ✅ Within window - log immediately
            logDose2Now(night)
            
        case .needDose1:
            // ❌ No Dose 1 logged yet
            presentationQueue.present(.needDose1)
            
        case .alreadyLogged:
            // ⚠️ Dose 2 already recorded
            presentationQueue.present(.dose2AlreadyLogged)
            
        case .tooEarly(let minutes):
            // ⏰ Before window start
            if minutes <= policy.earlyMaxOverrideMin {
                // Within override limit - show Early Override sheet
                presentationQueue.present(.dose2Early(minutes: minutes))
            } else {
                // Outside limit - hard block
                presentationQueue.present(.dose2Blocked(
                    reason: "Too early by \(minutes)m (limit: \(policy.earlyMaxOverrideMin)m)"
                ))
            }
            
        case .tooLate(let minutes):
            // ⏰ After window end
            if minutes <= policy.lateMaxOverrideMin {
                // Within override limit - show Late Override sheet
                presentationQueue.present(.dose2Late(minutes: minutes))
            } else {
                // Outside limit - hard block
                presentationQueue.present(.dose2Blocked(
                    reason: "Too late by \(minutes)m (limit: \(policy.lateMaxOverrideMin)m)"
                ))
            }
        }
    }
    
    // MARK: - Logging Actions
    
    /// Log Dose 2 immediately (within window)
    private func logDose2Now(_ night: DoseLog) {
        night.dose2TimeUTC = Date()
        night.dose2Grams = prefs.planDose2G
        night.dose2IsOverride = false
        night.currentLifecycleState = .awaitWake
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ Logged Dose 2: \(night.dose2Grams ?? 0)g")
        } catch {
            print("❌ Failed to log Dose 2: \(error)")
        }
    }
    
    /// Log Dose 2 with early override
    func confirmEarlyDose2(night: DoseLog, minutes: Int, reason: String, timePriorMin: Int?) {
        night.dose2TimeUTC = Date()
        night.dose2Grams = prefs.planDose2G
        night.dose2IsOverride = true
        night.dose2OverrideKind = "early"
        night.dose2OverrideMinutes = minutes
        night.dose2OverrideReason = reason
        night.currentLifecycleState = .awaitWake
        
        // TODO: Audit log
        // audit.log(.dose2Logged(override: "early", minutes: minutes, reason: reason, source: "app", nightKey: night.nightKey))
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ Logged Dose 2 (early override): \(minutes)m early, reason: \(reason)")
        } catch {
            print("❌ Failed to log early Dose 2: \(error)")
        }
    }
    
    /// Log Dose 2 with late override
    func confirmLateDose2(night: DoseLog, minutes: Int, reason: String, mode: LateDoseMode) {
        if mode == .takenNow {
            night.dose2TimeUTC = Date()
            night.dose2Grams = prefs.planDose2G
            night.dose2IsOverride = true
            night.dose2OverrideKind = "late"
            night.dose2OverrideMinutes = minutes
            night.dose2OverrideReason = reason
            night.currentLifecycleState = .awaitWake
            
            // TODO: Audit log
            // audit.log(.dose2Logged(override: "late", minutes: minutes, reason: reason, source: "app", nightKey: night.nightKey))
            
            do {
                try modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                print("✅ Logged Dose 2 (late override): \(minutes)m late, reason: \(reason)")
            } catch {
                print("❌ Failed to log late Dose 2: \(error)")
            }
        } else {
            // Log as missed dose
            night.notes = (night.notes ?? "") + " [Dose 2 missed: \(reason)]"
            night.currentLifecycleState = .closed
            
            do {
                try modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                print("⚠️ Logged missed Dose 2: \(reason)")
            } catch {
                print("❌ Failed to log missed Dose 2: \(error)")
            }
        }
    }
}

// MARK: - Late Dose Mode

enum LateDoseMode: String {
    case takenNow = "taken_now"
    case missed = "missed"
}

// MARK: - Action Button Style

extension ActionButton {
    enum Style {
        case primary(locked: Bool)
        case secondary
        
        var foregroundColor: Color {
            switch self {
            case .primary(let locked):
                return locked ? .gray : .white
            case .secondary:
                return .white.opacity(0.8)
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .primary(let locked):
                return locked ? Color.gray.opacity(0.3) : Color.blue
            case .secondary:
                return Color.gray.opacity(0.2)
            }
        }
        
        var iconOpacity: Double {
            switch self {
            case .primary(let locked):
                return locked ? 0.5 : 1.0
            case .secondary:
                return 0.8
            }
        }
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let title: String
    let icon: String
    let style: Style
    let caption: String?
    let action: () -> Void
    
    init(title: String, 
         icon: String, 
         style: Style = .primary(locked: false),
         caption: String? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.caption = caption
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                        .opacity(style.iconOpacity)
                    
                    Text(title)
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(style.backgroundColor)
                .foregroundColor(style.foregroundColor)
                .cornerRadius(12)
            }
            
            if let caption = caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit() // For time values
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
