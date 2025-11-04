//
//  PresentationRouter.swift
//  DoseTrack
//
//  Centralized sheet/overlay routing with priority-based preemption
//  Eliminates boolean-explosion and enforces modal stack policy
//

import SwiftUI
import Observation

/// Single source of truth for all sheet presentations
/// Replaces 7-8 individual @State showX flags
enum SheetRoute: Identifiable, Equatable {
    case settings
    case wake(isFinal: Bool)
    case dose2Early(minutes: Int)
    case dose2Late(minutes: Int)
    case dose2Blocked(reason: String)
    case needDose1
    case dose2AlreadyLogged
    case resetNight
    case timeZoneRebase
    
    var id: String {
        switch self {
        case .settings: return "settings"
        case .wake(let isFinal): return "wake_\(isFinal)"
        case .dose2Early(let m): return "dose2Early_\(m)"
        case .dose2Late(let m): return "dose2Late_\(m)"
        case .dose2Blocked(let r): return "dose2Blocked_\(r)"
        case .needDose1: return "needDose1"
        case .dose2AlreadyLogged: return "dose2AlreadyLogged"
        case .resetNight: return "resetNight"
        case .timeZoneRebase: return "timeZoneRebase"
        }
    }
}

/// Overlay routes for non-blocking UI elements
enum OverlayRoute: Equatable {
    case toast(String)
    case autoTurnoverClosed(prevNightKey: String)
}

/// External entry points (notifications, widgets, deep links)
enum ExternalRoute {
    case dose2Now
    case snooze5m
    case logMissedDose2
    case openWake(final: Bool)
    case openSettings
    case resetNight
}

/// Priority-based presentation policy
/// Higher rank = more important, preempts lower priority sheets
struct PresentationPolicy {
    static func rank(_ route: SheetRoute) -> Int {
        switch route {
        case .resetNight:           return 100  // User-critical action
        case .dose2Blocked:         return 90   // Safety hard stop
        case .dose2Early, .dose2Late: return 80 // Override decision
        case .needDose1:            return 70   // Prerequisite action
        case .dose2AlreadyLogged:   return 60   // Edit/undo option
        case .wake:                 return 50   // Event logging
        case .settings:             return 40   // Configuration
        case .timeZoneRebase:       return 30   // System notification
        }
    }
    
    /// Determine if route should restore after app termination
    static func shouldRestore(_ route: SheetRoute) -> Bool {
        switch route {
        case .resetNight, .dose2Blocked:
            return true  // Blocking modals restore
        default:
            return false // Others reopen only if condition still holds
        }
    }
}

/// Presentation queue with priority-based preemption
/// Ensures only one sheet presents at a time, with proper priority handling
@Observable
final class PresentationQueue {
    var current: SheetRoute?
    private var pending: [SheetRoute] = []
    
    /// Present a sheet, respecting priority order
    /// - Higher priority routes preempt current sheet
    /// - Lower priority routes enqueue for later
    func present(_ route: SheetRoute) {
        guard let cur = current else {
            current = route
            return
        }
        
        if PresentationPolicy.rank(route) > PresentationPolicy.rank(cur) {
            // Preempt current sheet with higher priority
            pending.insert(cur, at: 0)
            current = route
        } else {
            // Enqueue lower priority for after current dismisses
            pending.append(route)
        }
    }
    
    /// Called when current sheet dismisses
    /// Presents next highest-priority pending sheet
    func didDismiss() {
        if pending.isEmpty {
            current = nil
        } else {
            // Sort by priority and present highest
            current = pending.sorted { 
                PresentationPolicy.rank($0) > PresentationPolicy.rank($1) 
            }.first
            pending.removeAll()
        }
    }
    
    /// Clear all pending presentations
    func clearPending() {
        pending.removeAll()
    }
    
    /// Check if a specific route is currently presented
    func isPresenting(_ route: SheetRoute) -> Bool {
        current?.id == route.id
    }
}

// MARK: - State Restoration

/// Persistence for presentation state across app terminations
struct PresentationState: Codable {
    var selectedHorizon: String // "lastNight", "tonight", "tomorrow"
    var pendingRoute: String?   // Restored only if shouldRestore() = true
    
    static let key = "PresentationState"
    
    static func load() -> PresentationState? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(PresentationState.self, from: data) else {
            return nil
        }
        return state
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// MARK: - External Routing

extension PresentationQueue {
    /// Handle external entry points (notifications, widgets, deep links)
    /// Always routes to Tonight horizon first, then presents appropriate sheet
    func handleExternal(_ route: ExternalRoute, 
                       onSwitchToTonight: @escaping () -> Void,
                       controller: DoseLogControllering,
                       onOverlay: @escaping (OverlayRoute) -> Void) {
        // Force switch to Tonight tab
        onSwitchToTonight()
        
        switch route {
        case .dose2Now:
            // Notification "Log Dose 2 now" action
            // Will evaluate gate and show appropriate sheet
            break // Handled by tryLogDose2() in caller
            
        case .snooze5m:
            controller.snoozeDose2Notification()
            onOverlay(.toast("Snoozed 5 minutes"))
            
        case .logMissedDose2:
            controller.logMissedDose2()
            onOverlay(.toast("Logged missed Dose 2"))
            
        case .openWake(let final):
            present(.wake(isFinal: final))
            
        case .openSettings:
            present(.settings)
            
        case .resetNight:
            present(.resetNight)
        }
    }
}
