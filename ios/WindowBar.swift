//
//  WindowBar.swift
//  DoseTrack
//
//  Compact window status bar (replaces large countdown ring)
//  8-12pt tall pill with progress indicator and countdown text
//

import SwiftUI

/// Compact window status indicator - replaces the large countdown ring
struct WindowBar: View {
    enum Status {
        case waiting      // Before window opens
        case open         // Window is open
        case closingSoon  // Last 30 minutes of window
        case expired      // After window closed
    }
    
    let status: Status
    let progress: Double      // 0.0-1.0 across the entire window duration
    let leadingText: String   // e.g., "Opens in 1h 45m", "Ends in 12m", "Expired 5h ago"
    let showSeconds: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Palette.surfaceHi.opacity(0.8))
                    .frame(height: DT.windowBarHeight)
                
                // Progress fill
                GeometryReader { proxy in
                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(6, proxy.size.width * CGFloat(progress)), height: DT.windowBarHeight)
                }
                .frame(height: DT.windowBarHeight)
            }
            
            // Status label
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundStyle(fillColor)
                
                Text(leadingText)
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
                
                Spacer()
            }
            .padding(.horizontal, 2)
        }
        .padding(DT.pad)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Palette.surface)
        )
    }
    
    // MARK: - Computed Properties
    
    private var fillColor: Color {
        switch status {
        case .waiting:      return Palette.primary.opacity(0.55)
        case .open:         return Palette.primary
        case .closingSoon:  return Palette.warn
        case .expired:      return Palette.danger
        }
    }
    
    private var icon: String {
        switch status {
        case .waiting:      return "clock.badge"
        case .open:         return "bolt.fill"
        case .closingSoon:  return "hourglass.bottomhalf.filled"
        case .expired:      return "xmark.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview("Waiting") {
    WindowBar(
        status: .waiting,
        progress: 0.0,
        leadingText: "Opens in 1h 45m",
        showSeconds: false
    )
    .padding()
    .background(Palette.bg)
}

#Preview("Open") {
    WindowBar(
        status: .open,
        progress: 0.3,
        leadingText: "Ends in 42m 18s",
        showSeconds: true
    )
    .padding()
    .background(Palette.bg)
}

#Preview("Closing Soon") {
    WindowBar(
        status: .closingSoon,
        progress: 0.85,
        leadingText: "Ends in 8m 12s",
        showSeconds: true
    )
    .padding()
    .background(Palette.bg)
}

#Preview("Expired") {
    WindowBar(
        status: .expired,
        progress: 1.0,
        leadingText: "Expired 5h 3m ago",
        showSeconds: false
    )
    .padding()
    .background(Palette.bg)
}
