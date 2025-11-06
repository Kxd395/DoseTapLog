//
//  WhoopIntegrationView.swift
//  DoseTrack
//
//  Created: November 5, 2025
//  Purpose: Settings UI for WHOOP integration
//  Features: OAuth connection, recovery data sync, disconnect
//

import SwiftUI

/// Settings view for WHOOP integration
/// Handles OAuth flow, data sync, and connection management
struct WhoopIntegrationView: View {
    // MARK: - State
    
    @AppStorage("whoop_session_id") private var sessionId: String?
    @AppStorage("whoop_user_id") private var whoopUserId: Int = 0
    @AppStorage("whoop_last_sync") private var lastSync: TimeInterval = 0
    
    @State private var connectionStatus: WhoopConnectionStatus = .disconnected
    @State private var isConnecting = false
    @State private var isSyncing = false
    @State private var recentRecovery: [RecoveryRecord] = []
    @State private var errorMessage: String?
    @State private var showingDisconnectConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Connection Status Section
            Section {
                HStack {
                    Text("Status")
                        .foregroundColor(.secondary)
                    Spacer()
                    statusBadge
                }
                
                if connectionStatus == .connected {
                    HStack {
                        Text("WHOOP User ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(whoopUserId)")
                            .foregroundColor(.primary)
                    }
                    
                    if lastSync > 0 {
                        HStack {
                            Text("Last Sync")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formattedLastSync)
                                .foregroundColor(.primary)
                        }
                    }
                }
            } header: {
                Text("Connection")
            }
            
            // Action Buttons Section
            Section {
                if connectionStatus == .disconnected {
                    Button(action: connectWhoop) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            Text("Connect WHOOP")
                            Spacer()
                            if isConnecting {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isConnecting)
                } else if connectionStatus == .connected {
                    Button(action: syncRecoveryData) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.green)
                            Text("Sync Recovery Data")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                    
                    Button(role: .destructive, action: { showingDisconnectConfirmation = true }) {
                        HStack {
                            Image(systemName: "link.badge.minus")
                            Text("Disconnect WHOOP")
                        }
                    }
                }
            } header: {
                Text("Actions")
            } footer: {
                if connectionStatus == .disconnected {
                    Text("Connect your WHOOP account to sync recovery metrics (HRV, resting heart rate, SpO₂) with your dose logs.")
                        .font(.caption)
                } else if connectionStatus == .connected {
                    Text("Recovery data is used to enhance your dose log exports for analysis.")
                        .font(.caption)
                }
            }
            
            // Error Section
            if let error = errorMessage {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    Button("Dismiss") {
                        errorMessage = nil
                    }
                    .font(.caption)
                } header: {
                    Text("Error")
                }
            }
            
            // Recent Recovery Data Section
            if connectionStatus == .connected && !recentRecovery.isEmpty {
                Section {
                    ForEach(recentRecovery) { record in
                        recoveryRow(for: record)
                    }
                } header: {
                    HStack {
                        Text("Recent Recovery")
                        Spacer()
                        Text("Last 7 Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(nil)
                    }
                }
            }
            
            // Info Section
            Section {
                HStack {
                    Text("About WHOOP Integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text("DoseTrack integrates with WHOOP to enrich your dose logs with recovery metrics. This data helps identify patterns between medication timing and sleep quality.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("WHOOP Integration")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Disconnect WHOOP?", isPresented: $showingDisconnectConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                disconnectWhoop()
            }
        } message: {
            Text("This will revoke DoseTrack's access to your WHOOP data. You can reconnect at any time.")
        }
        .onAppear {
            loadConnectionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .whoopConnected)) { notification in
            handleConnectionSuccess(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .whoopConnectionFailed)) { notification in
            handleConnectionFailure(notification)
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        switch connectionStatus {
        case .disconnected:
            Label("Disconnected", systemImage: "circle")
                .font(.caption)
                .foregroundColor(.secondary)
        case .connecting:
            Label("Connecting...", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundColor(.blue)
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .error:
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
    
    // MARK: - Recovery Row
    
    @ViewBuilder
    private func recoveryRow(for record: RecoveryRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                recoveryScoreBadge(record.recoveryScore)
            }
            
            // Metrics grid
            HStack(spacing: 16) {
                metricView(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(record.hrvRmssd))ms")
                metricView(icon: "heart.fill", label: "RHR", value: "\(Int(record.restingHR))bpm")
                if let spo2 = record.spo2 {
                    metricView(icon: "lungs.fill", label: "SpO₂", value: "\(Int(spo2))%")
                }
            }
            
            if let skinTemp = record.skinTemp {
                HStack(spacing: 16) {
                    metricView(icon: "thermometer", label: "Skin Temp", value: String(format: "%.1f°C", skinTemp))
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func metricView(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
    
    @ViewBuilder
    private func recoveryScoreBadge(_ score: Double) -> some View {
        let color: Color
        if score >= 67 {
            color = .green
        } else if score >= 34 {
            color = .yellow
        } else {
            color = .red
        }
        
        Text("\(Int(score))%")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
    
    // MARK: - Actions
    
    private func loadConnectionStatus() {
        if let sessionId = sessionId, !sessionId.isEmpty {
            connectionStatus = .connected
            
            // Auto-sync on appear if last sync > 24h ago
            let dayAgo = Date().timeIntervalSince1970 - (24 * 60 * 60)
            if lastSync < dayAgo && !isSyncing {
                syncRecoveryData()
            }
        } else {
            connectionStatus = .disconnected
        }
    }
    
    private func connectWhoop() {
        isConnecting = true
        connectionStatus = .connecting
        errorMessage = nil
        
        // Open OAuth flow in Safari
        if let url = URL(string: Config.whoopAuthorizationURL) {
            UIApplication.shared.open(url)
        } else {
            errorMessage = "Failed to generate authorization URL"
            connectionStatus = .error
            isConnecting = false
        }
        
        // isConnecting will be reset by notification handlers
    }
    
    private func syncRecoveryData() {
        guard let sessionId = sessionId, !sessionId.isEmpty else {
            errorMessage = "No active session. Please connect first."
            return
        }
        
        isSyncing = true
        errorMessage = nil
        
        // Fetch last 7 days
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        
        Task {
            do {
                let records = try await WhoopAPIClient.shared.fetchRecovery(
                    sessionId: sessionId,
                    start: start,
                    end: end
                )
                
                await MainActor.run {
                    recentRecovery = records.sorted { $0.date > $1.date }
                    lastSync = Date().timeIntervalSince1970
                    connectionStatus = .connected
                    isSyncing = false
                }
            } catch let error as WhoopError {
                await MainActor.run {
                    handleWhoopError(error)
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Sync failed: \(error.localizedDescription)"
                    connectionStatus = .error
                    isSyncing = false
                }
            }
        }
    }
    
    private func disconnectWhoop() {
        guard let sessionId = sessionId, !sessionId.isEmpty else { return }
        
        Task {
            do {
                try await WhoopAPIClient.shared.revokeAccess(sessionId: sessionId)
                
                await MainActor.run {
                    clearSession()
                }
            } catch {
                // Clear session locally even if revoke fails
                await MainActor.run {
                    clearSession()
                    errorMessage = "Disconnected locally. WHOOP revocation may have failed."
                }
            }
        }
    }
    
    private func clearSession() {
        self.sessionId = nil
        whoopUserId = 0
        lastSync = 0
        recentRecovery = []
        connectionStatus = .disconnected
        errorMessage = nil
        isConnecting = false
        isSyncing = false
    }
    
    // MARK: - Notification Handlers
    
    private func handleConnectionSuccess(_ notification: Notification) {
        if let session = notification.userInfo?["session"] as? WhoopSession {
            whoopUserId = session.whoopUserId
            connectionStatus = .connected
            isConnecting = false
            
            // Auto-sync after connecting
            syncRecoveryData()
        }
    }
    
    private func handleConnectionFailure(_ notification: Notification) {
        if let error = notification.userInfo?["error"] as? WhoopError {
            handleWhoopError(error)
        } else {
            errorMessage = "Failed to connect to WHOOP"
            connectionStatus = .error
        }
        isConnecting = false
    }
    
    private func handleWhoopError(_ error: WhoopError) {
        switch error {
        case .sessionExpired:
            errorMessage = error.localizedDescription
            clearSession()
        case .accessRevoked:
            errorMessage = error.localizedDescription
            clearSession()
        default:
            errorMessage = error.localizedDescription
            connectionStatus = .error
        }
    }
    
    // MARK: - Formatters
    
    private var formattedLastSync: String {
        guard lastSync > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: lastSync)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Connection Status

enum WhoopConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WhoopIntegrationView()
    }
}
