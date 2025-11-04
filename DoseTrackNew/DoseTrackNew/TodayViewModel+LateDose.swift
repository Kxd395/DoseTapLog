import SwiftUI
import Foundation

/// Extension to TodayViewModel for Late Dose 2 Override support
/// Adds methods and computed properties for logging Dose 2 after window closes
extension TodayViewModel {
    
    // MARK: - Computed Properties for Late Dose
    
    /// True if the Dose 2 window has closed (time > windowEndMinutes after Dose 1)
    var isAfterWindow: Bool {
        guard let d1 = dose1TimeUTC else { return false }
        guard dose2TimeUTC == nil else { return false } // Already logged
        
        let elapsedMinutes = Date().timeIntervalSince(d1) / 60.0
        return elapsedMinutes > Double(windowEndMinutes)
    }
    
    /// Number of minutes after the window end
    var minutesAfterWindow: Int {
        guard let d1 = dose1TimeUTC else { return 0 }
        
        let elapsedMinutes = Date().timeIntervalSince(d1) / 60.0
        let afterWindow = elapsedMinutes - Double(windowEndMinutes)
        
        return max(0, Int(afterWindow))
    }
    
    // Note: isBeforeWindowButEligibleEarly is defined in TodayViewModel.swift main class
    // Do NOT redeclare here - it causes compilation errors
    
    // MARK: - Late Dose Methods
    
    /// Present the late dose override sheet
    func presentLateDoseSheet() {
        guard isAfterWindow else {
            print("⚠️ Cannot present late dose sheet: window not expired")
            return
        }
        
        guard AppPreferencesEnhanced.shared.allowLateDose else {
            print("⚠️ Late dose logging is disabled in settings")
            return
        }
        
        // Present sheet (parent view binds to this)
        // Parent view should check vm.isAfterWindow and show LateDoseSheetView
    }
    
    /// Confirm late dose logging with reason and minutes late
    /// Called from LateDoseSheetView onConfirm callback
    func confirmLateDose(reason: String, minutesLate: Int) {
        guard let nightKey = nightKey else {
            print("❌ Cannot log late dose: no active night session")
            return
        }
        
        guard isAfterWindow else {
            print("❌ Cannot log late dose: window has not expired")
            return
        }
        
        print("📦 Logging late Dose 2:")
        print("  • NightKey: \(nightKey)")
        print("  • Amount: \(prefs.planDose2G)g")
        print("  • Minutes late: \(minutesLate)")
        print("  • Reason: \(reason)")
        
        // Log to controller with override metadata
        controller.logDose2Now(
            grams: prefs.planDose2G,
            overrideKind: "late",
            overrideMinutes: minutesLate,
            overrideReason: reason
        )
        
        // Refresh state from store
        refreshFromStore()
        
        // Note: Do NOT restart Live Activity for late doses
        // The window is closed, activity should remain ended
    }
    
    /// Try to log Dose 2 - handles in-window, early, and late cases
    func tryLogDose2() {
        guard let d1 = dose1TimeUTC else {
            print("⚠️ Cannot log Dose 2: Dose 1 not logged")
            return
        }
        
        guard dose2TimeUTC == nil else {
            print("⚠️ Dose 2 already logged")
            return
        }
        
        let elapsedMinutes = Date().timeIntervalSince(d1) / 60.0
        
        // Case 1: Within window (normal)
        if elapsedMinutes >= Double(windowStartMinutes) && elapsedMinutes <= Double(windowEndMinutes) {
            print("✅ Logging Dose 2 within window")
            controller.logDose2Now(
                grams: prefs.planDose2G,
                overrideKind: nil,
                overrideMinutes: nil,
                overrideReason: nil
            )
            refreshFromStore()
            return
        }
        
        // Case 2: Before window (early override required)
        if elapsedMinutes < Double(windowStartMinutes) {
            if AppPreferencesEnhanced.shared.allowEarlyDose {
                let earlyThreshold = Double(windowStartMinutes - AppPreferencesEnhanced.shared.maxEarlyMinutes)
                if elapsedMinutes >= earlyThreshold {
                    print("⏰ Early dose eligible - presenting sheet")
                    showEarlyDoseSheet = true
                    return
                } else {
                    print("❌ Too early for early dose override")
                    return
                }
            } else {
                print("❌ Early dose not allowed in settings")
                return
            }
        }
        
        // Case 3: After window (late override required)
        if elapsedMinutes > Double(windowEndMinutes) {
            if AppPreferencesEnhanced.shared.allowLateDose {
                print("⏰ Late dose eligible - parent should show late dose sheet")
                // Parent view should check isAfterWindow and present LateDoseSheetView
                return
            } else {
                print("❌ Late dose not allowed in settings")
                return
            }
        }
    }
}

// MARK: - DoseLogControllering Protocol Extension

/// Update the protocol to support override parameters
/// Add this to your existing DoseLogControllering protocol definition:
///
/// ```swift
/// protocol DoseLogControllering {
///     // ... existing methods ...
///     
///     func logDose2Now(
///         grams: Double,
///         overrideKind: String?,      // "early" or "late"
///         overrideMinutes: Int?,      // How many minutes early/late
///         overrideReason: String?     // User-provided reason
///     )
/// }
/// ```

// MARK: - Usage Example

/// In your TodayLogView:
///
/// ```swift
/// // Show late dose button when window expired
/// if vm.isAfterWindow && AppPreferencesEnhanced.shared.allowLateDose {
///     Button("Log Dose 2 (late)") {
///         showLateDoseSheet = true
///     }
///     .buttonStyle(.borderedProminent)
///     .tint(.orange)
/// }
///
/// // Present late dose sheet
/// .sheet(isPresented: $showLateDoseSheet) {
///     LateDoseSheetView(
///         isPresented: $showLateDoseSheet,
///         dose2Grams: vm.prefs.planDose2G,
///         minutesAfterWindow: vm.minutesAfterWindow,
///         requireReason: AppPreferencesEnhanced.shared.lateRequireReason,
///         quickChoices: AppPreferencesEnhanced.shared.lateQuickChoices,
///         maxLateMinutes: AppPreferencesEnhanced.shared.maxLateMinutes,
///         onConfirm: { reason, minutesLate in
///             vm.confirmLateDose(reason: reason, minutesLate: minutesLate)
///         }
///     )
/// }
/// ```
