import SwiftUI
import SwiftData

struct TodayLogView: View {
    @Environment(\.modelContext) private var context
    @State private var plan: NightPlan = NightPlanRecommender.makePlan(totalNightG: Config.defaultTotalGrams, preferredSplitFirstPct: 50, historyDose2ToWakeMinAvg: nil, recoveryScore0to100: nil)
    private var controller: DoseLogController { DoseLogController(context) }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    Text("Tonight plan").font(.headline)
                    Text(String(format: "Dose 1: %.2f g", plan.dose1DisplayG))
                    Text(String(format: "Dose 2: %.2f g", plan.dose2DisplayG))
                    Text("Window: \(plan.windowStartMinAfterDose1) to \(plan.windowEndMinAfterDose1) min after Dose 1")
                        .font(.caption)
                }
                HStack {
                    Button("Dose 1 now") {
                        controller.logDose1(at: Date(), gramsOverride: plan.dose1DisplayG)
                    }.buttonStyle(.borderedProminent)
                    Button("Dose 2 now") {
                        controller.logDose2(at: Date(), gramsOverride: plan.dose2DisplayG)
                    }.buttonStyle(.bordered)
                }
                HStack {
                    Button("Autofill wake from Health") {
                        HealthKitManager.shared.requestAuthorizationIfNeeded { ok in
                            guard ok else { return }
                            // Using bedtime as anchor from controller's derived night start
                            let (_, anchorUTC, _) = controller.currentNightKeyAndStartUTC()
                            let tolerance = 180
                            HealthKitManager.shared.fetchLatestFinalWake(nightAnchor: anchorUTC, toleranceMin: tolerance) { d, src in
                                if let d { controller.setFinalWake(d, provenance: src.rawValue) }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    Button("Export CSV") {
                        if let url = try? CSVExporter.exportAll(context: context) {
                            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .onAppear { controller.consumePendingFromWidget() }
            .navigationTitle("DoseTrack")
        }
    }
}
