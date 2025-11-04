//
//  WindowPill.swift
//  DoseTrack
//
//  Window status pill with live countdown (HH:MM:SS)
//  Shows: Waiting → Open → Expired states
//

import SwiftUI

/// Compact pill showing window state with live countdown
struct WindowPill: View {
    let dose1At: Date?
    let windowStartMin: Int
    let windowEndMin: Int
    let showSeconds: Bool
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let (label, style) = windowStatus(at: context.date)
            
            HStack(spacing: 6) {
                Image(systemName: style.symbol)
                    .font(.caption2)
                    .foregroundStyle(style.foreground)
                
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(style.foreground)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(style.background)
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Window State Logic
    
    private func windowStatus(at currentTime: Date) -> (label: String, style: PillStyle) {
        guard let d1 = dose1At else {
            return ("Waiting for Dose 1", .neutral)
        }
        
        let windowOpen = d1.addingTimeInterval(Double(windowStartMin) * 60)
        let windowClose = d1.addingTimeInterval(Double(windowEndMin) * 60)
        
        if currentTime < windowOpen {
            // Before window opens
            let remaining = windowOpen.timeIntervalSince(currentTime)
            return ("Opens in \(formatInterval(remaining))", .neutral)
        } else if currentTime <= windowClose {
            // Window is open
            let remaining = windowClose.timeIntervalSince(currentTime)
            return ("Ends in \(formatInterval(remaining))", .good)
        } else {
            // Window expired
            let elapsed = currentTime.timeIntervalSince(windowClose)
            return ("Expired \(formatInterval(elapsed)) ago", .bad)
        }
    }
    
    // MARK: - Formatting
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if showSeconds {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", hours, minutes)
        }
    }
    
    // MARK: - Pill Styles
    
    struct PillStyle {
        let symbol: String
        let foreground: Color
        let background: Color
        
        static let neutral = PillStyle(
            symbol: "clock",
            foreground: .white.opacity(0.8),
            background: Color.gray.opacity(0.3)
        )
        
        static let good = PillStyle(
            symbol: "clock.badge.checkmark",
            foreground: Color(red: 0.4, green: 0.9, blue: 0.5),
            background: Color(red: 0.2, green: 0.6, blue: 0.3).opacity(0.3)
        )
        
        static let bad = PillStyle(
            symbol: "clock.badge.exclamationmark",
            foreground: Color(red: 1.0, green: 0.4, blue: 0.4),
            background: Color(red: 0.8, green: 0.2, blue: 0.2).opacity(0.3)
        )
    }
}

// MARK: - Preview

#Preview("Window States") {
    VStack(spacing: 16) {
        // Before window (2 hours until open)
        WindowPill(
            dose1At: Date().addingTimeInterval(-(210 * 60 - 7200)),
            windowStartMin: 210,
            windowEndMin: 245,
            showSeconds: true
        )
        
        // Window open (10 minutes left)
        WindowPill(
            dose1At: Date().addingTimeInterval(-(235 * 60)),
            windowStartMin: 210,
            windowEndMin: 245,
            showSeconds: true
        )
        
        // Window expired (30 minutes ago)
        WindowPill(
            dose1At: Date().addingTimeInterval(-(275 * 60)),
            windowStartMin: 210,
            windowEndMin: 245,
            showSeconds: true
        )
        
        // No Dose 1 yet
        WindowPill(
            dose1At: nil,
            windowStartMin: 210,
            windowEndMin: 245,
            showSeconds: true
        )
    }
    .padding()
    .background(Palette.bg)
    .preferredColorScheme(.dark)
}
