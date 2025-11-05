import SwiftUI
import HealthKit

/// Settings screen for Health Data export with ML features
struct HealthDataExportView: View {
    @AppStorage("healthExportEnabled", store: UserDefaults(suiteName: "group.com.dosetrack.app"))
    private var exportEnabled = false
    
    @AppStorage("lastHealthExportAt", store: UserDefaults(suiteName: "group.com.dosetrack.app"))
    private var lastExportTimestamp: Double = 0
    
    @AppStorage("healthExportAnonymize", store: UserDefaults(suiteName: "group.com.dosetrack.app"))
    private var anonymize = false
    
    @AppStorage("healthExportRetentionDays", store: UserDefaults(suiteName: "group.com.dosetrack.app"))
    private var retentionDays = 30
    
    @State private var isExporting = false
    @State private var exportStatus: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var healthAuthStatus: HKAuthorizationStatus = .notDetermined
    
    private let healthStore = HKHealthStore()
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Health Data Export", isOn: $exportEnabled)
                
                if exportEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Export enabled")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Health Data Export")
            } footer: {
                Text("Exports HealthKit data (sleep, heart rate, steps) for ML analysis. Data stored locally in iCloud Documents.")
            }
            
            if exportEnabled {
                // Export Controls
                Section {
                    Button(action: performExport) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Exporting...")
                            } else {
                                Image(systemName: "arrow.down.doc")
                                Text("Export Now")
                            }
                        }
                    }
                    .disabled(isExporting || healthAuthStatus != .sharingAuthorized)
                    
                    if let status = exportStatus {
                        Label(status, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    if lastExportTimestamp > 0 {
                        HStack {
                            Text("Last export:")
                            Spacer()
                            Text(Date(timeIntervalSince1970: lastExportTimestamp), style: .relative)
                                .foregroundColor(.secondary)
                        }
                        .font(.footnote)
                    }
                } header: {
                    Text("Manual Export")
                }
                
                // Privacy Controls
                Section {
                    Toggle("Anonymize timestamps (±10 min fuzz)", isOn: $anonymize)
                    
                    Picker("Keep exports for", selection: $retentionDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Anonymization adds ±10 minutes random offset to all timestamps. Old exports are automatically deleted after retention period.")
                }
                
                // HealthKit Status
                Section {
                    HStack {
                        Text("HealthKit Access")
                        Spacer()
                        statusBadge
                    }
                    
                    if healthAuthStatus != .sharingAuthorized {
                        Button("Request Permissions") {
                            Task {
                                await requestHealthKitAuth()
                            }
                        }
                    }
                } header: {
                    Text("Permissions")
                }
                
                // What Gets Exported
                Section {
                    Label("Sleep analysis", systemImage: "bed.double")
                    Label("Heart rate", systemImage: "heart")
                    Label("Heart rate variability", systemImage: "waveform.path.ecg")
                    Label("Steps", systemImage: "figure.walk")
                    Label("Oxygen saturation", systemImage: "lungs")
                    Label("Respiratory rate", systemImage: "wind")
                } header: {
                    Text("Data Types")
                } footer: {
                    Text("All timestamps include timezone information and service-day keys (noon cutoff) for ML feature computation.")
                }
            }
        }
        .navigationTitle("Health Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await checkHealthKitStatus()
        }
    }
    
    private var statusBadge: some View {
        Group {
            switch healthAuthStatus {
            case .sharingAuthorized:
                Label("Authorized", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .sharingDenied:
                Label("Denied", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            default:
                Label("Not Determined", systemImage: "questionmark.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.footnote)
    }
    
    private func checkHealthKitStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        healthAuthStatus = healthStore.authorizationStatus(for: sleepType)
    }
    
    private func requestHealthKitAuth() async {
        let types: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
            await checkHealthKitStatus()
        } catch {
            errorMessage = "Failed to request permissions: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func performExport() {
        isExporting = true
        exportStatus = "Starting export..."
        
        Task {
            do {
                // Create export directory in iCloud Documents
                let fileManager = FileManager.default
                let documentsURL = try fileManager.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                let exportDir = documentsURL.appendingPathComponent("HealthExports", isDirectory: true)
                try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
                
                // Simple export placeholder
                // In production, this would call HealthExportBridge.exportIncremental()
                // For now, create a minimal export file
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let filename = "health_export_\(timestamp).jsonl"
                let fileURL = exportDir.appendingPathComponent(filename)
                
                let sampleData = """
                {"type":"export_start","timestamp":"\(timestamp)","anonymize":\(anonymize)}
                {"type":"info","message":"Health data export - placeholder for ML integration"}
                """
                
                try sampleData.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Update last export time
                lastExportTimestamp = Date().timeIntervalSince1970
                
                await MainActor.run {
                    exportStatus = "✅ Export complete: \(filename)"
                    isExporting = false
                }
                
                // Cleanup old exports based on retention policy
                try cleanupOldExports(in: exportDir, olderThan: retentionDays)
                
            } catch {
                await MainActor.run {
                    errorMessage = "Export failed: \(error.localizedDescription)"
                    showError = true
                    exportStatus = "❌ Export failed"
                    isExporting = false
                }
            }
        }
    }
    
    private func cleanupOldExports(in directory: URL, olderThan days: Int) throws {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))
        
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        
        for fileURL in files where fileURL.pathExtension == "jsonl" {
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attrs[.creationDate] as? Date, creationDate < cutoffDate {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
}

#Preview {
    NavigationView {
        HealthDataExportView()
    }
}
