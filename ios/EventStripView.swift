//
//  EventStripView.swift
//  DoseTrack
//
//  Compact list of last 3 events with undo capability
//  Pinned under countdown ring
//

import SwiftUI

struct EventStripView: View {
    let events: [EventDisplayItem]
    let allowUndo: Bool
    let onUndo: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Events")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if allowUndo && !events.isEmpty {
                    Button(action: onUndo) {
                        Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if events.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.secondary)
                    Text("No events logged yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events) { event in
                        EventRow(event: event, isFirst: event.id == events.first?.id)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: EventDisplayItem
    let isFirst: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: event.icon)
                .font(.system(size: 14))
                .foregroundColor(event.color)
                .frame(width: 20)
            
            // Description
            Text(event.description)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Relative time
            Text(event.relativeTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isFirst ? Color(.systemGray5) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Data Model

struct EventDisplayItem: Identifiable {
    let id: UUID
    let description: String
    let relativeTime: String
    let icon: String
    let color: Color
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        description: String,
        relativeTime: String,
        icon: String,
        color: Color,
        timestamp: Date
    ) {
        self.id = id
        self.description = description
        self.relativeTime = relativeTime
        self.icon = icon
        self.color = color
        self.timestamp = timestamp
    }
}

// MARK: - Helper Extensions

extension EventDisplayItem {
    /// Create from DoseLog event
    static func from(eventType: String, grams: Double?, timestamp: Date) -> EventDisplayItem {
        let description: String
        let icon: String
        let color: Color
        
        switch eventType {
        case "dose1":
            description = "Dose 1 \(formatTime(timestamp)) • \(formatGrams(grams ?? 0))g"
            icon = "moon.fill"
            color = .blue
        case "dose2":
            description = "Dose 2 \(formatTime(timestamp)) • \(formatGrams(grams ?? 0))g"
            icon = "moon.zzz.fill"
            color = .purple
        case "in_bed":
            description = "In bed \(formatTime(timestamp))"
            icon = "bed.double.fill"
            color = .green
        case "bathroom":
            description = "Bathroom wake \(formatTime(timestamp))"
            icon = "figure.walk"
            color = .orange
        case "final_wake":
            description = "Final wake \(formatTime(timestamp))"
            icon = "sunrise.fill"
            color = .yellow
        default:
            description = "\(eventType) \(formatTime(timestamp))"
            icon = "clock"
            color = .gray
        }
        
        return EventDisplayItem(
            description: description,
            relativeTime: relativeTimeString(from: timestamp),
            icon: icon,
            color: color,
            timestamp: timestamp
        )
    }
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private static func formatGrams(_ grams: Double) -> String {
        String(format: "%.2f", grams)
    }
    
    private static func relativeTimeString(from date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        let minutes = Int(elapsed / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        
        if elapsed < 60 {
            return "Just now"
        } else if hours > 0 {
            return "\(hours)h \(mins)m ago"
        } else {
            return "\(minutes)m ago"
        }
    }
}

// MARK: - Preview

#Preview("With Events") {
    EventStripView(
        events: [
            EventDisplayItem(
                description: "Dose 1 23:05 • 3.25g",
                relativeTime: "2h 15m ago",
                icon: "moon.fill",
                color: .blue,
                timestamp: Date().addingTimeInterval(-135 * 60)
            ),
            EventDisplayItem(
                description: "In bed 22:58",
                relativeTime: "2h 22m ago",
                icon: "bed.double.fill",
                color: .green,
                timestamp: Date().addingTimeInterval(-142 * 60)
            ),
            EventDisplayItem(
                description: "Bathroom wake 03:30",
                relativeTime: "45m ago",
                icon: "figure.walk",
                color: .orange,
                timestamp: Date().addingTimeInterval(-45 * 60)
            )
        ],
        allowUndo: true,
        onUndo: {
            print("Undo tapped")
        }
    )
}

#Preview("Empty State") {
    EventStripView(
        events: [],
        allowUndo: false,
        onUndo: {}
    )
}

#Preview("No Undo") {
    EventStripView(
        events: [
            EventDisplayItem(
                description: "Dose 2 01:45 • 3.25g",
                relativeTime: "3h ago",
                icon: "moon.zzz.fill",
                color: .purple,
                timestamp: Date().addingTimeInterval(-180 * 60)
            )
        ],
        allowUndo: false,
        onUndo: {}
    )
}
