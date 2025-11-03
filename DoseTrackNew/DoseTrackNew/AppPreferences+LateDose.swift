import SwiftUI

/// Extension to AppPreferences for Late Dose 2 Override helper methods
/// The actual @AppStorage properties are in AppPreferences.swift main class
extension AppPreferences {
    
    // MARK: - Late Dose 2 Override Helpers
    
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
///     Toggle("Allow late Dose 2 logging", isOn: $AppPreferences.shared.allowLateDose)
///     
///     Toggle("Require reason for late dose", isOn: $AppPreferences.shared.lateRequireReason)
///         .disabled(!AppPreferences.shared.allowLateDose)
///     
///     Stepper(value: $AppPreferences.shared.maxLateMinutes, in: 0...300, step: 10) {
///         if AppPreferences.shared.maxLateMinutes == 0 {
///             Text("Max late minutes: Unlimited")
///         } else {
///             Text("Max late minutes: \(AppPreferences.shared.maxLateMinutes)")
///         }
///     }
///     .disabled(!AppPreferences.shared.allowLateDose)
///     
///     TextField("Quick choices (5,10,15,30)", text: $AppPreferences.shared.lateQuickChoicesCSV)
///         .disabled(!AppPreferences.shared.allowLateDose)
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
