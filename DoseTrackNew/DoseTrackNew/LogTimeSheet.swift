//
//  LogTimeSheet.swift
//  DoseTrack
//
//  Reusable time picker sheet for logging events with time adjustment
//  Supports "Now" + quick presets + wheel picker with seconds
//

import SwiftUI

/// Reusable sheet for logging events with time adjustment
struct LogTimeSheet: View {
    let action: NightAction
    let policy: TapPolicy
    let onLog: (Date) -> Void
    let onCancel: () -> Void
    
    // Optional: for Dose 2 override flow
    let windowStatus: String?
    let isOutsideWindow: Bool
    let onShowOverride: (() -> Void)?
    
    @State private var selectedTime = Date()
    @State private var useNow = true
    @State private var selectedPreset: Int? = nil
    
    private let presets: [(label: String, minutes: Int)] = [
        ("−10m", -10),
        ("−5m", -5),
        ("−1m", -1),
        ("+1m", +1),
        ("+5m", +5)
    ]
    
    init(
        action: NightAction,
        policy: TapPolicy,
        windowStatus: String? = nil,
        isOutsideWindow: Bool = false,
        onLog: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void,
        onShowOverride: (() -> Void)? = nil
    ) {
        self.action = action
        self.policy = policy
        self.windowStatus = windowStatus
        self.isOutsideWindow = isOutsideWindow
        self.onLog = onLog
        self.onCancel = onCancel
        self.onShowOverride = onShowOverride
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header icon + title
                VStack(spacing: 8) {
                    Image(systemName: action.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(Palette.primary)
                    
                    Text(action.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(Palette.text)
                }
                .padding(.top)
                
                // Window status (for Dose 2)
                if let status = windowStatus {
                    HStack {
                        Image(systemName: isOutsideWindow ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(isOutsideWindow ? .orange : .green)
                        Text(status)
                            .font(.subheadline)
                            .foregroundStyle(isOutsideWindow ? .orange : Palette.text)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isOutsideWindow ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                    )
                    
                    // Override button (for Dose 2 outside window)
                    if isOutsideWindow, let onShowOverride = onShowOverride {
                        Button {
                            onShowOverride()
                        } label: {
                            Label("Override Window", systemImage: "exclamationmark.triangle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
                
                Divider()
                
                // Time selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Time")
                        .font(.headline)
                        .foregroundStyle(Palette.text)
                    
                    // "Now" chip + quick presets
                    if policy.showQuickPresets {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // "Now" chip
                                TimeChip(label: "Now", isSelected: useNow) {
                                    useNow = true
                                    selectedPreset = nil
                                    selectedTime = Date()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                
                                // Preset chips
                                ForEach(presets.indices, id: \.self) { index in
                                    let preset = presets[index]
                                    TimeChip(
                                        label: preset.label,
                                        isSelected: selectedPreset == index
                                    ) {
                                        useNow = false
                                        selectedPreset = index
                                        selectedTime = Date().addingTimeInterval(Double(preset.minutes * 60))
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Wheel picker
                    if !useNow {
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            displayedComponents: policy.showSeconds ? [.hourMinuteAndSecond, .date] : [.hourAndMinute, .date]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .onChange(of: selectedTime) { _, _ in
                            selectedPreset = nil
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onLog(selectedTime)
                    } label: {
                        Text("Log \(action.displayName)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Palette.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.dim)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Palette.surface.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

/// Time preset chip
private struct TimeChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Palette.primary : Palette.surfaceHi)
                )
                .foregroundStyle(isSelected ? .white : Palette.text)
        }
    }
}

// MARK: - Preview

#Preview {
    LogTimeSheet(
        action: .dose1,
        policy: .defaultPolicy,
        windowStatus: "Opens in 12m",
        isOutsideWindow: true,
        onLog: { _ in },
        onCancel: { },
        onShowOverride: { }
    )
}
