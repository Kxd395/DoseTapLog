//
//  MorningSurveyView.swift
//  DoseTrack
//
import SwiftUI
import SwiftData

struct MorningSurveyView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var logs: [DoseLog]
    @State private var alcoholUnits: Double = 0
    @State private var alcoholTime: Date? = nil
    @State private var stress: Int = 3
    @State private var roomLight: String = "dark"
    @State private var screenOff: Date? = nil

    let nightKey: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Morning Survey").font(.title2).bold()

            HStack {
                Text("Alcohol units")
                Spacer()
                Stepper(value: $alcoholUnits, in: 0...6, step: 0.5) {
                    Text(String(format: "%.1f", alcoholUnits))
                }.frame(maxWidth: 180)
            }

            DatePicker("Alcohol time", selection: Binding(get: {
                alcoholTime ?? Date()
            }, set: { alcoholTime = $0 }), displayedComponents: [.hourAndMinute])
                .labelsHidden()

            HStack {
                Text("Stress").frame(maxWidth: .infinity, alignment: .leading)
                Picker("Stress", selection: $stress) {
                    ForEach(1...5, id: \.self) { v in Text("\(v)") }
                }.pickerStyle(.segmented).frame(maxWidth: 200)
            }

            HStack {
                Text("Room light").frame(maxWidth: .infinity, alignment: .leading)
                Picker("Light", selection: $roomLight) {
                    Text("dark").tag("dark")
                    Text("dim").tag("dim")
                    Text("bright").tag("bright")
                }.pickerStyle(.segmented).frame(maxWidth: 260)
            }

            Toggle("Use current time as Screen Off", isOn: Binding(get: {
                screenOff != nil
            }, set: { on in
                screenOff = on ? Date() : nil
            }))

            Button("Save Survey") {
                save()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            // seed defaults
            screenOff = screenOff ?? Date()
        }
    }

    private func save() {
        guard let log = logs.first(where: { $0.nightKey == nightKey }) else { return }
        var survey = try? ctx.fetch(FetchDescriptor<NightSurvey>(predicate: #Predicate { $0.nightKey == nightKey })).first
        if survey == nil {
            survey = NightSurvey(nightKey: nightKey)
            ctx.insert(survey!)
        }
        survey!.alcohol_units = alcoholUnits
        survey!.alcohol_timeUTC = alcoholTime
        survey!.stress_1to5 = stress
        survey!.room_light = roomLight
        survey!.screen_last_off_timeUTC = screenOff
        // compute feature vector id
        let fv = FeatureVectorBuilder.featureVector(for: log, survey: survey)
        log.ml_feature_vector_id = FeatureVectorBuilder.stableId(from: fv)
        try? ctx.save()
    }
}
