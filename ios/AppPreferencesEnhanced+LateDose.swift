import SwiftUI

/// Extension to AppPreferencesEnhanced for Late Dose 2 Override settings
/// These settings control whether users can log Dose 2 after the window closes
extension AppPreferencesEnhanced {
    
    // MARK: - Late Dose 2 Override Settings
    
    /// Allow logging Dose 2 after the window has closed
    @AppStorage("late_dose_allow", store: UserDefaults(suiteName: "group.com.jefferson.dosetrack"))
    var allowLateDose: Bool = true
    
    /// Require user to provide a reason when logging late Dose 2
    @AppStorage("late_dose_require_reason", store: UserDefaults(suiteName: "group.com.jefferson.dosetrack"))
    var lateRequireReason: Bool = true
    
    /// Maximum minutes after window end that late dose is allowed (0 = unlimited)
    @AppStorage("late_dose_max_minutes", store: UserDefaults(suiteName: "group.com.jefferson.dosetrack"))
    var maxLateMinutes: Int = 120
    
    /// Quick choice buttons for "how late" (comma-separated string like "5,10,15,30")
    @AppStorage("late_dose_quick_choices", store: UserDefaults(suiteName: "group.com.jefferson.dosetrack"))
    var lateQuickChoicesCSV: String = "5,10,15,30"
    
    // MARK: - Computed Helper
    
    /// Parse lateQuickChoicesCSV into array of integers
    var lateQuickChoices: [Int] {
        lateQuickChoicesCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && $0 <= 300 }
    }
    
    /// Check if a given number of minutes late violates the max limit
    func exceedsLateLimit(_ minutesLate: Int) -> Bool {
        guard maxLateMinutes > 0 else { return false } // 0 means unlimited
        return minutesLate > maxLateMinutes
    }
}

// MARK: - Settings UI Section

/// Add this section to your SettingsViewEnhanced.swift
///
/// Section {
///     Toggle("Allow late Dose 2 logging", isOn: $AppPreferencesEnhanced.shared.allowLateDose)
///     
///     Toggle("Require reason for late dose", isOn: $AppPreferencesEnhanced.shared.lateRequireReason)
///         .disabled(!AppPreferencesEnhanced.shared.allowLateDose)
///     
///     Stepper(value: $AppPreferencesEnhanced.shared.maxLateMinutes, in: 0...300, step: 10) {
///         if AppPreferencesEnhanced.shared.maxLateMinutes == 0 {
///             Text("Max late minutes: Unlimited")
///         } else {
///             Text("Max late minutes: \(AppPreferencesEnhanced.shared.maxLateMinutes)")
///         }
///     }
///     .disabled(!AppPreferencesEnhanced.shared.allowLateDose)
///     
///     TextField("Quick choices (5,10,15,30)", text: $AppPreferencesEnhanced.shared.lateQuickChoicesCSV)
///         .disabled(!AppPreferencesEnhanced.shared.allowLateDose)
/// } header: {
///     Text("Late Dose 2 Override")
/// } footer: {
///     VStack(alignment: .leading, spacing: 4) {
///         Text("• Allows logging Dose 2 after the window closes")
///         Text("• Records reality for adherence tracking")
///         Text("• Marked as 'late override' in exports")
///         Text("• Does NOT restart Live Activity or window")
///     }
///     .font(.footnote)
/// }
