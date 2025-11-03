//
//  CountdownRingView.swift
//  DoseTrack
//
//  Circular progress indicator with context-aware status text
//  Shows elapsed time from Dose 1 and window timing
//

import SwiftUI

struct CountdownRingView: View {
    let dose1Time: Date?
    let windowStartMin: Int
    let windowEndMin: Int
    let disabledReason: String
    
    @State private var currentTime = Date()
    
    var body: some View {
        TimelineView(.periodic(from: dose1Time ?? Date(), by: 30)) { context in
            VStack(spacing: 12) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    // Center text (elapsed time)
                    if let dose1 = dose1Time {
                        VStack(spacing: 2) {
                            Text(elapsedText(from: dose1, now: context.date))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(ringColor)
                            Text("elapsed")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: "moon.stars")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("No Dose 1")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Status text below ring
                VStack(spacing: 4) {
                    Text(statusText(now: context.date))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if !disabledReason.isEmpty {
                        Text(disabledReason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Progress from 0.0 (at Dose 1) to 1.0 (at windowEnd)
    private var progress: CGFloat {
        guard let dose1 = dose1Time else { return 0.0 }
        let elapsed = Date().timeIntervalSince(dose1) / 60.0 // minutes
        let totalWindow = Double(windowEndMin)
        let progress = min(max(elapsed / totalWindow, 0.0), 1.0)
        return CGFloat(progress)
    }
    
    /// Ring color based on current window state
    private var ringColor: Color {
        guard let dose1 = dose1Time else { return .gray }
        let elapsed = Date().timeIntervalSince(dose1) / 60.0
        
        if elapsed < Double(windowStartMin) {
            return .orange // Before window
        } else if elapsed <= Double(windowEndMin) {
            return .green // In window
        } else {
            return .red // After window
        }
    }
    
    // MARK: - Helper Methods
    
    /// Format elapsed time as "2h 15m" or "45m"
    private func elapsedText(from dose1: Date, now: Date) -> String {
        let elapsed = Int(now.timeIntervalSince(dose1) / 60.0)
        let hours = elapsed / 60
        let minutes = elapsed % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Context-aware status text
    private func statusText(now: Date) -> String {
        guard let dose1 = dose1Time else {
            return "Log Dose 1 to start timer"
        }
        
        let elapsed = now.timeIntervalSince(dose1) / 60.0 // minutes
        
        if elapsed < Double(windowStartMin) {
            // Before window
            let remaining = Double(windowStartMin) - elapsed
            return "Window opens in \(formatDuration(remaining))"
        } else if elapsed <= Double(windowEndMin) {
            // In window
            let remaining = Double(windowEndMin) - elapsed
            return "Window closes in \(formatDuration(remaining))"
        } else {
            // After window
            let overdue = elapsed - Double(windowEndMin)
            return "Window expired \(formatDuration(overdue)) ago"
        }
    }
    
    /// Format duration as "1h 45m" or "28m"
    private func formatDuration(_ minutes: Double) -> String {
        let totalMin = Int(minutes.rounded())
        let hours = totalMin / 60
        let mins = totalMin % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Preview

#Preview("Before Window") {
    CountdownRingView(
        dose1Time: Date().addingTimeInterval(-60 * 60), // 1 hour ago
        windowStartMin: 150,
        windowEndMin: 240,
        disabledReason: "Window opens at 01:45"
    )
}

#Preview("In Window") {
    CountdownRingView(
        dose1Time: Date().addingTimeInterval(-180 * 60), // 3 hours ago
        windowStartMin: 150,
        windowEndMin: 240,
        disabledReason: ""
    )
}

#Preview("After Window") {
    CountdownRingView(
        dose1Time: Date().addingTimeInterval(-270 * 60), // 4.5 hours ago
        windowStartMin: 150,
        windowEndMin: 240,
        disabledReason: "Window expired 30 min ago"
    )
}

#Preview("No Dose 1") {
    CountdownRingView(
        dose1Time: nil,
        windowStartMin: 150,
        windowEndMin: 240,
        disabledReason: "Log Dose 1 first"
    )
}
