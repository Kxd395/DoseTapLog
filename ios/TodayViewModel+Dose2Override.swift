//
//  TodayViewModel+Dose2Override.swift
//  DoseTrack
//
//  Dose 2 override system with two-tap confirmation for early/late doses
//  Based on comprehensive decision rules specification
//

import Foundation
import SwiftUI

// MARK: - Dose 2 Override Models

enum Dose2OverrideKind: String, Codable {
    case none
    case early
    case late
}

struct Dose2Gate {
    let enabled: Bool
    let reason: String   // why disabled or what will happen
    let kind: Dose2OverrideKind
    let minutesOffset: Int // early: positive minutes remaining to window; late: positive minutes past end
}

struct Dose2OverrideArmed {
    let kind: Dose2OverrideKind
    let armedAt: Date
    let expiresAt: Date
}

enum Dose2Override {
    case none
    case early(minutes: Int, reason: String)
    case late(minutes: Int, reason: String)
}

// MARK: - TodayViewModel Extension

extension TodayViewModel {
    
    // MARK: - Helper UI State Methods
    // Note: @Published properties (showEarlyDoseSheet, showLateDoseSheet, bannerMessage, bannerStyle)
    // are declared in TodayViewModel.swift main class to avoid extension stored property limitations
    
    func showBanner(message: String, style: BannerStyle) {
        bannerMessage = message
        bannerStyle = style
    }
    
    func dismissBanner() {
        bannerMessage = nil
    }
    
    // MARK: - Dose 2 Gate Evaluation
    
    /// Evaluate whether Dose 2 can be logged right now and what kind of action is required
    func evaluateDose2Gate(now: Date = Date()) -> Dose2Gate {
        guard let d1 = dose1TimeUTC else {
            return .init(
                enabled: false,
                reason: "Log Dose 1 first",
                kind: .none,
                minutesOffset: 0
            )
        }
        
        let elapsedMin = Int(now.timeIntervalSince(d1) / 60.0)
        let start = prefs.windowStartMin
        let end = prefs.windowEndMin
        
        // Too early (before window)
        if elapsedMin < start {
            let earlyBy = start - elapsedMin
            
            // Check if early dose is allowed within policy
            if prefs.allowEarlyDose && earlyBy <= prefs.maxEarlyMinutes {
                return .init(
                    enabled: true,
                    reason: "Early by \(earlyBy) min. Tap again to request override.",
                    kind: .early,
                    minutesOffset: earlyBy
                )
            } else {
                // Hard block: too early or early not allowed
                return .init(
                    enabled: false,
                    reason: "Window opens in \(earlyBy) min",
                    kind: .none,
                    minutesOffset: earlyBy
                )
            }
        }
        
        // Too late (after window)
        if elapsedMin > end {
            let lateBy = elapsedMin - end
            
            // Check if late dose is allowed within policy
            if lateBy <= prefs.maxLateMinutes && prefs.allowLateDose {
                return .init(
                    enabled: true,
                    reason: "Late by \(lateBy) min. Tap again to request override.",
                    kind: .late,
                    minutesOffset: lateBy
                )
            } else {
                // Hard block: too late or missed dose
                return .init(
                    enabled: false,
                    reason: "Window closed \(lateBy) min ago",
                    kind: .none,
                    minutesOffset: lateBy
                )
            }
        }
        
        // In window: normal dose allowed
        return .init(
            enabled: true,
            reason: "Within window",
            kind: .none,
            minutesOffset: 0
        )
    }
    
    // MARK: - Two-Tap Override System
    
    /// Override arming state (10-second window for second tap)
    private static var overrideArmed: Dose2OverrideArmed?
    private static var overrideDisarmTask: Task<Void, Never>?
    
    /// First tap on Dose 2 button - evaluate and either log immediately or arm override
    @MainActor
    func tryLogDose2Tapped() {
        let gate = evaluateDose2Gate(now: Date())
        
        guard gate.enabled else {
            // Show blocking message
            showBanner(gate.reason, style: .warning)
            
            // Offer helpful actions for hard blocks
            if gate.kind == .none && gate.minutesOffset > 0 {
                maybeOfferReminder(gate: gate)
            }
            
            return
        }
        
        switch gate.kind {
        case .none:
            // In window: log immediately
            logDose2Now(override: .none)
            
        case .early:
            // Check if already armed for early
            if let armed = Self.overrideArmed, armed.kind == .early, Date() < armed.expiresAt {
                // Second tap within 10 seconds: open sheet
                secondTapDose2()
            } else {
                // First tap: arm override
                armOverride(kind: .early, message: gate.reason, expiresInSec: 10)
            }
            
        case .late:
            // Check if already armed for late
            if let armed = Self.overrideArmed, armed.kind == .late, Date() < armed.expiresAt {
                // Second tap within 10 seconds: open sheet
                secondTapDose2()
            } else {
                // First tap: arm override
                armOverride(kind: .late, message: gate.reason, expiresInSec: 10)
            }
        }
    }
    
    /// Arm override and show sticky banner for 10 seconds
    @MainActor
    private func armOverride(kind: Dose2OverrideKind, message: String, expiresInSec: Int) {
        let now = Date()
        let expires = now.addingTimeInterval(TimeInterval(expiresInSec))
        
        Self.overrideArmed = Dose2OverrideArmed(
            kind: kind,
            armedAt: now,
            expiresAt: expires
        )
        
        // Show yellow warning banner
        showBanner(message, style: .warning)
        
        // Auto-disarm after expiration
        Self.overrideDisarmTask?.cancel()
        Self.overrideDisarmTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(expiresInSec))
            if !Task.isCancelled {
                disarmOverride()
            }
        }
    }
    
    /// Disarm override and clear banner
    @MainActor
    private func disarmOverride() {
        Self.overrideArmed = nil
        Self.overrideDisarmTask?.cancel()
        Self.overrideDisarmTask = nil
        clearBanner()
    }
    
    /// Second tap within 10-second window: open appropriate sheet
    @MainActor
    private func secondTapDose2() {
        guard let armed = Self.overrideArmed else { return }
        
        // Cancel auto-disarm while sheet is open
        Self.overrideDisarmTask?.cancel()
        
        switch armed.kind {
        case .early:
            showEarlyDoseSheet = true
        case .late:
            showLateDoseSheet = true
        case .none:
            break
        }
    }
    
    /// Long-press on Dose 2 button: jump straight to appropriate sheet
    @MainActor
    func longPressDose2() {
        let gate = evaluateDose2Gate(now: Date())
        
        guard gate.enabled else {
            // Haptics removed - not accessible from extension
            return
        }
        
        switch gate.kind {
        case .early:
            showEarlyDoseSheet = true
        case .late:
            showLateDoseSheet = true
        case .none:
            // In window: long-press does nothing special
            break
        }
    }
    
    // MARK: - Override Confirmation (called from sheets)
    
    /// Confirm early Dose 2 override from EarlyDoseSheet
    @MainActor
    func confirmEarlyDose2(reason: String, timePriorMin: Int) {
        disarmOverride()
        logDose2Now(override: .early(minutes: timePriorMin, reason: reason))
    }
    
    /// Confirm late Dose 2 override from LateDoseSheet
    @MainActor
    func confirmLateDose2(reason: String) {
        let lateBy = evaluateDose2Gate(now: Date()).minutesOffset
        disarmOverride()
        logDose2Now(override: .late(minutes: lateBy, reason: reason))
    }
    
    // MARK: - Dose 2 Logging with Override Support
    
    /// Log Dose 2 with optional override information
    @MainActor
    func logDose2Now(override: Dose2Override) {
        ensureNightKeyMintedIfNeeded()
        
        guard nightKey != nil else {
            showBanner("Start a night first", style: .error)
            return
        }
        
        guard dose1TimeUTC != nil else {
            showBanner("Log Dose 1 first", style: .error)
            return
        }
        
        let planDose2 = prefs.planDose2G
        let now = Date()
        
        // Log to controller based on override type
        switch override {
        case .none:
            controller.logDose2Now(grams: planDose2, overrideKind: nil, overrideMinutes: nil, overrideReason: nil)
        case .early(let minutes, let reason):
            controller.logDose2Now(grams: planDose2, overrideKind: "early", overrideMinutes: minutes, overrideReason: reason)
        case .late(let minutes, let reason):
            controller.logDose2Now(grams: planDose2, overrideKind: "late", overrideMinutes: minutes, overrideReason: reason)
        }
        
        dose2TimeUTC = now
        
        // End Live Activity and notifications
        endDose2LiveActivityIfRunning()
        cancelDose2Notifications()
        
        // Refresh UI
        refreshFromStore()
        
        // Success feedback
        switch override {
        case .early:
            showBanner("Dose 2 logged (early override)", style: .success)
        case .late:
            showBanner("Dose 2 logged (late override)", style: .success)
        case .none:
            showBanner("Dose 2 logged", style: .success)
        }
    }
    
    // MARK: - Private Helper Methods
    // Note: All @Published properties and BannerStyle enum are in TodayViewModel.swift main class
    
    private func showBanner(_ message: String, style: BannerStyle) {
        bannerMessage = message
        bannerStyle = style
    }
    
    private func clearBanner() {
        bannerMessage = nil
    }
    
    // MARK: - Reminder Offers
    
    /// Offer "Remind me at window start" or "Snooze 5m" for hard blocks
    private func maybeOfferReminder(gate: Dose2Gate) {
        // TODO: Implement reminder scheduling
        // For too-early blocks: offer to remind at window start
        // For too-late blocks: offer to log as missed dose
    }
}
