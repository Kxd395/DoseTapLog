//
//  SafetyBannerView.swift
//  DoseTrack
//
//  Status chips for safety, data sources, permissions
//  Always visible sticky header
//

import SwiftUI

struct SafetyBannerView: View {
    let perDoseMin: Double
    let perDoseMax: Double
    let nightlyTotal: Double
    let dose1: Double
    let dose2: Double
    let wakeSource: WakeSource
    let healthStatus: HealthKitStatus
    let whoopStatus: WHOOPStatus
    let onChangeSource: () -> Void
    let onFixPermissions: () -> Void
    let onTestWHOOP: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Safety chips
            HStack(spacing: 8) {
                SafetyChip(
                    title: "Per dose",
                    value: "\(formatGrams(perDoseMin))–\(formatGrams(perDoseMax))g",
                    isValid: perDoseSafe
                )
                
                SafetyChip(
                    title: "Night total",
                    value: "\(formatGrams(nightlyTotal))g",
                    isValid: nightlyTotalSafe
                )
            }
            
            // Row 2: Data sources
            HStack(spacing: 8) {
                StatusChip(
                    title: "Wake",
                    value: wakeSource.displayName,
                    icon: "heart.text.square",
                    color: wakeSource == .health ? .blue : .gray,
                    action: onChangeSource,
                    actionLabel: "Change"
                )
                
                StatusChip(
                    title: "Health",
                    value: healthStatus.displayName,
                    icon: "heart.fill",
                    color: healthStatus.color,
                    action: healthStatus == .denied ? onFixPermissions : nil,
                    actionLabel: "Fix"
                )
            }
            
            // Row 3: WHOOP status (if configured)
            if !AppPreferences.shared.whoopProxyURL.isEmpty {
                HStack(spacing: 8) {
                    StatusChip(
                        title: "WHOOP",
                        value: whoopStatus.displayName,
                        icon: "waveform.path.ecg",
                        color: whoopStatus.color,
                        action: onTestWHOOP,
                        actionLabel: "Test"
                    )
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Safety Validation
    
    private var perDoseSafe: Bool {
        dose1 >= perDoseMin && dose1 <= perDoseMax &&
        dose2 >= perDoseMin && dose2 <= perDoseMax
    }
    
    private var nightlyTotalSafe: Bool {
        let nightlyMin = 3.0
        let nightlyMax = 9.0
        return nightlyTotal >= nightlyMin && nightlyTotal <= nightlyMax
    }
    
    private func formatGrams(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Safety Chip

private struct SafetyChip: View {
    let title: String
    let value: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(isValid ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Status Chip

private struct StatusChip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let action: (() -> Void)?
    let actionLabel: String?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Types

enum WakeSource: String, Codable {
    case health = "Health"
    case manual = "Manual"
    
    var displayName: String {
        rawValue
    }
}

enum HealthKitStatus {
    case ok
    case denied
    case limited
    case unknown
    
    var displayName: String {
        switch self {
        case .ok: return "OK"
        case .denied: return "Denied"
        case .limited: return "Limited"
        case .unknown: return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .ok: return .green
        case .denied: return .red
        case .limited: return .orange
        case .unknown: return .gray
        }
    }
}

enum WHOOPStatus {
    case connected
    case offline
    case testing
    
    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .offline: return "Offline"
        case .testing: return "Testing..."
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .offline: return .red
        case .testing: return .orange
        }
    }
}

// MARK: - Preview

#Preview("All Safe") {
    SafetyBannerView(
        perDoseMin: 1.5,
        perDoseMax: 4.5,
        nightlyTotal: 6.5,
        dose1: 3.25,
        dose2: 3.25,
        wakeSource: .health,
        healthStatus: .ok,
        whoopStatus: .connected,
        onChangeSource: {},
        onFixPermissions: {},
        onTestWHOOP: {}
    )
}

#Preview("Safety Violation") {
    SafetyBannerView(
        perDoseMin: 1.5,
        perDoseMax: 4.5,
        nightlyTotal: 10.0, // Over max
        dose1: 5.0, // Over max
        dose2: 5.0, // Over max
        wakeSource: .manual,
        healthStatus: .denied,
        whoopStatus: .offline,
        onChangeSource: {},
        onFixPermissions: {},
        onTestWHOOP: {}
    )
}

#Preview("WHOOP Not Configured") {
    SafetyBannerView(
        perDoseMin: 1.5,
        perDoseMax: 4.5,
        nightlyTotal: 6.0,
        dose1: 3.0,
        dose2: 3.0,
        wakeSource: .health,
        healthStatus: .ok,
        whoopStatus: .offline,
        onChangeSource: {},
        onFixPermissions: {},
        onTestWHOOP: {}
    )
}
