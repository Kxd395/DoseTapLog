//
//  NextAlertChip.swift
//  DoseTrack
//
//  Shows next scheduled alarm time and style
//  E.g., "🔔 02:55 (Strong)"
//

import SwiftUI

/// Compact chip showing next scheduled notification
struct NextAlertChip: View {
    let nextAlertTime: Date
    let alarmStyle: AlarmStyle
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: alarmStyle.symbol)
                .font(.caption2)
                .foregroundStyle(alarmStyle.color)
            
            Text(formatTime(nextAlertTime))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
            
            Text("(\(alarmStyle.displayName))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Formatting
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Alarm Style Definition

enum AlarmStyle: String, Codable, CaseIterable {
    case quiet
    case normal
    case strong
    
    var displayName: String {
        switch self {
        case .quiet: return "Quiet"
        case .normal: return "Normal"
        case .strong: return "Strong"
        }
    }
    
    var symbol: String {
        switch self {
        case .quiet: return "bell.slash"
        case .normal: return "bell"
        case .strong: return "bell.badge"
        }
    }
    
    var color: Color {
        switch self {
        case .quiet: return .gray
        case .normal: return .blue
        case .strong: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .quiet:
            return "Respects Focus/DND settings"
        case .normal:
            return "Standard notification sound"
        case .strong:
            return "Time-sensitive, breaks through Focus"
        }
    }
}

// MARK: - Preview

#Preview("Alert Styles") {
    VStack(spacing: 16) {
        NextAlertChip(
            nextAlertTime: Date().addingTimeInterval(3600),
            alarmStyle: .quiet
        )
        
        NextAlertChip(
            nextAlertTime: Date().addingTimeInterval(3600),
            alarmStyle: .normal
        )
        
        NextAlertChip(
            nextAlertTime: Date().addingTimeInterval(3600),
            alarmStyle: .strong
        )
    }
    .padding()
    .background(Palette.bg)
    .preferredColorScheme(.dark)
}
