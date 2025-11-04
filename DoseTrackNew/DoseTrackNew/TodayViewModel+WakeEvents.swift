//
//  TodayViewModel+WakeEvents.swift
//  DoseTrack
//
//  Wake event logging with full clinical context
//

import Foundation
import UIKit

extension TodayViewModel {
    
    /// Log a wake event with full context
    /// - Parameters:
    ///   - reason: The reason for waking
    ///   - isFinal: Whether this is the final wake for the night
    ///   - wasAlarmInterrupted: Whether an alarm was interrupted (only relevant for alarm wakes)
    ///   - overrideTime: Custom timestamp (defaults to now)
    ///   - note: Optional note about the wake event
    func logWakeNow(reason: WakeReason,
                    isFinal: Bool,
                    wasAlarmInterrupted: Bool = false,
                    overrideTime: Date? = nil,
                    note: String? = nil) {
        ensureNightKeyMintedIfNeeded()
        
        guard let nightKey = nightKey else {
            print("⚠️ Cannot log wake: no night key")
            return
        }
        
        let timestamp = overrideTime ?? Date()
        
        // Log wake event to controller
        if isFinal {
            controller.logFinalWakeNow(provenance: reason.rawValue)
            finalWakeTimeUTC = timestamp
        } else if reason == .alarm {
            controller.logAlarmWakeNow()
        } else if reason == .bathroom {
            controller.logBathroomNow()
        }
        
        refreshFromStore()
        haptics(.success)
    }
    
    /// Fast path for alarm wake (existing button behavior)
    func logAlarmWake() {
        logWakeNow(
            reason: .alarm,
            isFinal: false,
            wasAlarmInterrupted: true
        )
    }
    
    /// Show wake sheet for alarm wake with reason selection
    func showAlarmWakeSheet() {
        wakeSheetType = .alarm
        showWakeSheet = true
    }
    
    /// Log bathroom wake (common shortcut)
    func logBathroomWake() {
        logWakeNow(
            reason: .bathroom,
            isFinal: false
        )
    }
    
    /// Show wake sheet for bathroom wake with reason selection
    func showBathroomWakeSheet() {
        wakeSheetType = .bathroom
        showWakeSheet = true
    }
    
    /// Show wake sheet for final wake with reason selection
    func showFinalWakeSheet() {
        wakeSheetType = .finalWake
        showWakeSheet = true
    }
    
    /// Check if wake happened during dose 2 window
    var isWakeDuringDose2Window: Bool {
        guard let d1 = dose1TimeUTC else { return false }
        guard dose2TimeUTC == nil else { return false } // Already taken dose 2
        
        let now = Date()
        let minutesSinceD1 = Int(now.timeIntervalSince(d1) / 60)
        
        return minutesSinceD1 >= AppPreferences.shared.windowStartMin &&
               minutesSinceD1 <= AppPreferences.shared.windowEndMin
    }
    
    /// Suggest converting alarm wake to final wake after timeout
    func checkAlarmWakeTimeout() {
        // Implementation for auto-suggest converting alarm wake to final wake
        // after X minutes of inactivity (optional feature)
    }
    
    // MARK: - Internal Helper Methods (accessible to other extensions)
    
    func ensureNightKeyMintedIfNeeded() {
        if nightKey == nil {
            controller.mintNightKeyIfNeeded()
            refreshFromStore()
        }
    }
    
    func endDose2LiveActivityIfRunning() {
        controller.endLiveActivity()
    }
    
    func cancelDose2Notifications() {
        controller.cancelDose2Notifications()
    }
    
    func haptics(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        #if !os(macOS)
        if AppPreferences.shared.hapticsEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(style)
        }
        #endif
    }
}

// MARK: - DoseLogController Wake Extension

extension DoseLogController {
    
    /// Log a wake event with full context
    func logWake(sleepSessionKey: String,
                 timestampUTC: Date,
                 reason: WakeReason,
                 isFinal: Bool,
                 wasAlarmInterrupted: Bool,
                 note: String?) {
        
        let eventType: String = isFinal ? "final_wake" : "alarm_wake"
        
        // Store wake event in event_log with context
        // This would integrate with your existing event logging system
        // Example SQL:
        // INSERT INTO event_log (sleep_session_id, event_type, timestamp_utc, 
        //                        wake_reason, is_final, was_alarm_interrupted, note)
        // VALUES (?, ?, ?, ?, ?, ?, ?)
        
        print("📝 Logged wake: \(reason.label), final: \(isFinal), interrupted: \(wasAlarmInterrupted)")
        
        // If using SwiftData/CoreData, create LoggedEvent with wake context
        let event = LoggedEvent(
            kind: isFinal ? .finalWake : .alarmWake,
            timestampUTC: timestampUTC,
            detail: reason.label
        )
        
        // Store to your data layer
    }
}
