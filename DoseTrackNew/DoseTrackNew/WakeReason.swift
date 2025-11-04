//
//  WakeReason.swift
//  DoseTrack
//
//  Wake event reason tracking for clinical context
//

import Foundation

/// Wake event reasons for detailed sleep tracking
enum WakeReason: String, CaseIterable, Codable, Identifiable {
    case natural = "natural"
    case alarm = "alarm"
    case bathroom = "bathroom"
    case doseRecoil = "dose_recoil"
    case noise = "noise"
    case pain = "pain"
    case anxiety = "anxiety"
    case nightmare = "nightmare"
    case childPet = "child_pet"
    case workShift = "work_shift"
    case other = "other"
    
    var id: String { rawValue }
    
    /// User-facing label
    var label: String {
        switch self {
        case .natural: return "Natural"
        case .alarm: return "Alarm"
        case .bathroom: return "Bathroom"
        case .doseRecoil: return "Dose recoil"
        case .noise: return "Noise"
        case .pain: return "Pain"
        case .anxiety: return "Anxiety"
        case .nightmare: return "Nightmare"
        case .childPet: return "Child or pet"
        case .workShift: return "Work shift"
        case .other: return "Other"
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .natural: return "sunrise.fill"
        case .alarm: return "alarm.fill"
        case .bathroom: return "toilet.fill"
        case .doseRecoil: return "pills.circle.fill"
        case .noise: return "speaker.wave.3.fill"
        case .pain: return "cross.case.fill"
        case .anxiety: return "heart.text.square"
        case .nightmare: return "moon.zzz.fill"
        case .childPet: return "person.2.wave.2.fill"
        case .workShift: return "briefcase.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}
