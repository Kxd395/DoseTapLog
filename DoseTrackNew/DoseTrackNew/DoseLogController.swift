import Foundation
import SwiftData
import os.log

/// DoseLogController: Implements DoseLogControllering protocol
/// Handles all persistence, transaction safety, and App Group coordination
final class DoseLogController: DoseLogControllering {
    let context: ModelContext
    private let logger = Logger(subsystem: "com.jefferson.dosetrack", category: "DoseLogController")
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.jefferson.dosetrack")!
    
    init(_ context: ModelContext) { 
        self.context = context
        // Run migration on first launch
        AppPreferences.migrateFromLegacy()
    }

    private func currentNightKeyAndStartUTC() -> (String, Date, Int) {
        let now = Date()
        let tzOffsetMin = TimeZone.current.secondsFromGMT() / 60
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: tzOffsetMin * 60)!
        let comps = DateComponents(hour: Config.defaultBedtimeHour, minute: Config.defaultBedtimeMinute)
        let bedtimeLocalToday = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        // If after midnight, map dose2 to same night by subtracting 1 day if needed
        let nightKey = cal.dateComponents([.year, .month, .day], from: bedtimeLocalToday).date.map {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = cal.timeZone; return df.string(from: $0)
        } ?? "unknown"
        // Convert bedtimeLocalToday to UTC for storage
        let bedtimeUTC = Date(timeIntervalSince1970: bedtimeLocalToday.timeIntervalSince1970 - Double(tzOffsetMin * 60))
        return (nightKey, bedtimeUTC, tzOffsetMin)
    }

    private func fetchOrCreateCurrentNight() -> DoseLog {
        let (key, startUTC, off) = currentNightKeyAndStartUTC()
        let descriptor = FetchDescriptor<DoseLog>(predicate: #Predicate { $0.nightKey == key })
        if let found = try? context.fetch(descriptor).first { return found }
        let log = DoseLog(nightKey: key, nightStartUTC: startUTC, timezoneOffsetMinutes: off)
        context.insert(log)
        try? context.save()
        return log
    }

    func logDose1(at date: Date, gramsOverride: Double?) {
        let log = fetchOrCreateCurrentNight()
        log.dose1TimeUTC = date
        if let g = gramsOverride { log.dose1Grams = safeDisplayGrams(g) }
        try? context.save()
    }

    func logDose2(at date: Date, gramsOverride: Double?) {
        let log = fetchOrCreateCurrentNight()
        log.dose2TimeUTC = date
        if let g = gramsOverride { log.dose2Grams = safeDisplayGrams(g) }
        try? context.save()
    }

    func setFinalWake(_ date: Date, provenance: String) {
        let log = fetchOrCreateCurrentNight()
        log.finalWakeTimeUTC = date
        log.finalWakeProvenance = provenance
        try? context.save()
    }

    func consumePendingFromWidget() {
        logger.debug("Consuming pending widget actions...")
        
        if let pending = AppGroupStore.consumePending() {
            logger.info("Processing pending action: \(pending.kind.rawValue)")
            switch pending.kind {
            case .dose1Now: 
                logDose1(at: pending.timestamp, gramsOverride: pending.grams)
            case .dose2Now: 
                logDose2(at: pending.timestamp, gramsOverride: pending.grams)
            }
        } else {
            logger.debug("No pending actions")
        }
    }
    
    // MARK: - DoseLogControllering Protocol Implementation
    
    func fetchOpenNight() -> (nightKey: String, dose1TimeUTC: Date?, dose2TimeUTC: Date?, finalWakeTimeUTC: Date?, timezoneOffsetMinutes: Int)? {
        let log = fetchOrCreateCurrentNight()
        return (
            nightKey: log.nightKey,
            dose1TimeUTC: log.dose1TimeUTC,
            dose2TimeUTC: log.dose2TimeUTC,
            finalWakeTimeUTC: log.finalWakeTimeUTC,
            timezoneOffsetMinutes: log.timezoneOffsetMinutes
        )
    }
    
    func fetchRecentEvents(limit: Int) -> [LoggedEvent] {
        // TODO: Implement event_log table for granular events
        // For now, synthesize from DoseLog
        guard let log = try? context.fetch(FetchDescriptor<DoseLog>(
            sortBy: [SortDescriptor(\DoseLog.nightStartUTC, order: .reverse)]
        )).first else {
            return []
        }
        
        var events: [LoggedEvent] = []
        
        if let bedtime = log.bedtimeUTC {
            events.append(LoggedEvent(
                kind: .inBed,
                timestampUTC: bedtime,
                detail: ""
            ))
        }
        
        if let d1Time = log.dose1TimeUTC {
            let grams = log.dose1Grams ?? 0
            events.append(LoggedEvent(
                kind: .dose1,
                timestampUTC: d1Time,
                detail: String(format: "%.2f g", grams)
            ))
        }
        
        if let d2Time = log.dose2TimeUTC {
            let grams = log.dose2Grams ?? 0
            events.append(LoggedEvent(
                kind: .dose2,
                timestampUTC: d2Time,
                detail: String(format: "%.2f g", grams)
            ))
        }
        
        for bathroomTime in log.bathroomWakeTimesUTC {
            events.append(LoggedEvent(
                kind: .bathroom,
                timestampUTC: bathroomTime,
                detail: ""
            ))
        }
        
        if let finalWake = log.finalWakeTimeUTC {
            events.append(LoggedEvent(
                kind: .finalWake,
                timestampUTC: finalWake,
                detail: log.finalWakeProvenance ?? "Manual"
            ))
        }
        
        // Sort by timestamp descending, take limit
        return events
            .sorted { $0.timestampUTC > $1.timestampUTC }
            .prefix(limit)
            .map { $0 }
    }
    
    func mintNightKeyIfNeeded() {
        let log = fetchOrCreateCurrentNight()
        logger.info("Minted or fetched nightKey: \(log.nightKey)")
    }
    
    func logInBedNow() {
        do {
            let log = fetchOrCreateCurrentNight()
            let now = Date()
            
            if log.bedtimeUTC == nil {
                log.bedtimeUTC = now
                try context.save()
                
                // Update App Group for last event (undo capability)
                updateLastEvent(kind: .inBed, timestamp: now)
                
                logger.info("✅ Logged In Bed Now: \(now)")
            } else {
                logger.warning("Bedtime already set for \(log.nightKey)")
            }
        } catch {
            logger.error("❌ Failed to log In Bed: \(error.localizedDescription)")
            enqueuePendingAction(.inBedNow, timestamp: Date())
        }
    }
    
    func logDose1Now(grams: Double) {
        do {
            let log = fetchOrCreateCurrentNight()
            let now = Date()
            
            log.dose1TimeUTC = now
            log.dose1Grams = safeDisplayGrams(grams)
            try context.save()
            
            // Update App Group
            updateLastEvent(kind: .dose1, timestamp: now)
            
            // Start Live Activity if enabled
            let prefs = AppPreferencesEnhanced.shared.toLegacyStruct()
            if prefs.liveActivityEnabled {
                startLiveActivityIfEnabled(
                    prefs: prefs,
                    dose1UTC: now,
                    windowStartMin: prefs.windowStartMin,
                    windowEndMin: prefs.windowEndMin
                )
            }
            
            logger.info("✅ Logged Dose 1: \(grams)g at \(now)")
        } catch {
            logger.error("❌ Failed to log Dose 1: \(error.localizedDescription)")
            enqueuePendingAction(.dose1Now(grams: grams), timestamp: Date())
        }
    }
    
    func logDose2Now(grams: Double, overrideEarlyMinutes: Int?, overrideReason: String?) {
        // Delegate to new unified API
        if let earlyMin = overrideEarlyMinutes, let reason = overrideReason {
            logDose2Now(grams: grams, overrideKind: "early", overrideMinutes: earlyMin, overrideReason: reason)
        } else {
            logDose2Now(grams: grams, overrideKind: nil, overrideMinutes: nil, overrideReason: nil)
        }
    }
    
    func logDose2Now(grams: Double, overrideKind: String?, overrideMinutes: Int?, overrideReason: String?) {
        do {
            let log = fetchOrCreateCurrentNight()
            let now = Date()
            
            log.dose2TimeUTC = now
            log.dose2Grams = safeDisplayGrams(grams)
            
            // Store override metadata in SwiftData model fields
            if let kind = overrideKind, let minutes = overrideMinutes, let reason = overrideReason {
                log.dose2IsOverride = true
                log.dose2OverrideKind = kind
                log.dose2OverrideMinutes = minutes
                log.dose2OverrideReason = reason
                
                // Also append to notes for backwards compatibility
                let override = "\(kind.capitalized) override: \(minutes)m, reason: \(reason)"
                log.notes = [log.notes, override].compactMap { $0 }.joined(separator: " | ")
                
                logger.info("💊 Logged Dose 2 with \(kind) override: \(minutes)m, reason: \(reason)")
            } else {
                logger.info("💊 Logged Dose 2: \(grams)g at \(now)")
            }
            
            try context.save()
            
            // Update App Group
            updateLastEvent(kind: .dose2, timestamp: now)
            
            // End Live Activity (even for late overrides)
            endLiveActivity()
            
        } catch {
            logger.error("❌ Failed to log Dose 2: \(error.localizedDescription)")
            enqueuePendingAction(.dose2Now(grams: grams), timestamp: Date())
        }
    }
    
    func logFinalWakeNow(provenance: String) {
        do {
            let log = fetchOrCreateCurrentNight()
            let now = Date()
            
            log.finalWakeTimeUTC = now
            log.finalWakeProvenance = provenance
            try context.save()
            
            updateLastEvent(kind: .finalWake, timestamp: now)
            
            logger.info("✅ Logged Final Wake: \(provenance) at \(now)")
        } catch {
            logger.error("❌ Failed to log Final Wake: \(error.localizedDescription)")
        }
    }
    
    func logAlarmWakeNow() {
        do {
            let log = fetchOrCreateCurrentNight()
            let now = Date()
            
            // Store alarm wake in notes or dedicated field
            let alarmNote = "Alarm wake: \(now.hhmm(withUTCOffsetMinutes: log.timezoneOffsetMinutes))"
            log.notes = [log.notes, alarmNote].compactMap { $0 }.joined(separator: " | ")
            try context.save()
            
            updateLastEvent(kind: .alarmWake, timestamp: now)
            
            logger.info("✅ Logged Alarm Wake at \(now)")
        } catch {
            logger.error("❌ Failed to log Alarm Wake: \(error.localizedDescription)")
        }
    }
    
    func logBathroomNow() {
        do {
            let log = fetchOrCreateCurrentNight()
            let now = Date()
            
            log.bathroomWakeTimesUTC.append(now)
            try context.save()
            
            updateLastEvent(kind: .bathroom, timestamp: now)
            
            logger.info("✅ Logged Bathroom at \(now)")
        } catch {
            logger.error("❌ Failed to log Bathroom: \(error.localizedDescription)")
        }
    }
    
    func undoLastEvent() {
        guard let lastEventKindRaw = appGroupDefaults.string(forKey: "lastEventKind"),
              let lastEventTime = appGroupDefaults.object(forKey: "lastEventTime") as? Date else {
            logger.warning("No last event to undo")
            return
        }
        
        // Check 60-second window
        let elapsed = Date().timeIntervalSince(lastEventTime)
        guard elapsed <= 60 else {
            logger.warning("Undo window expired: \(elapsed)s")
            clearLastEvent()
            return
        }
        
        guard let kind = LoggedEvent.Kind(rawValue: lastEventKindRaw) else {
            logger.error("Invalid event kind: \(lastEventKindRaw)")
            return
        }
        
        do {
            let log = fetchOrCreateCurrentNight()
            
            switch kind {
            case .inBed:
                log.bedtimeUTC = nil
            case .dose1:
                log.dose1TimeUTC = nil
                log.dose1Grams = nil
                endLiveActivity() // Cancel Live Activity if Dose 1 undone
            case .dose2:
                log.dose2TimeUTC = nil
                log.dose2Grams = nil
            case .bathroom:
                if !log.bathroomWakeTimesUTC.isEmpty {
                    log.bathroomWakeTimesUTC.removeLast()
                }
            case .alarmWake:
                // Remove from notes (complex - skip for now)
                break
            case .finalWake:
                log.finalWakeTimeUTC = nil
                log.finalWakeProvenance = nil
            }
            
            try context.save()
            clearLastEvent()
            
            logger.info("✅ Undid last event: \(kind.rawValue)")
        } catch {
            logger.error("❌ Failed to undo: \(error.localizedDescription)")
        }
    }
    
    func startLiveActivityIfEnabled(prefs: LegacyAppPreferences, dose1UTC: Date, windowStartMin: Int, windowEndMin: Int) {
        // TODO: Implement ActivityKit Live Activity
        logger.info("🔄 Live Activity start requested (not yet implemented)")
        // Implementation requires:
        // 1. Create DoseLiveActivity.swift with ActivityAttributes
        // 2. Request activity with dose1UTC, window times
        // 3. Store activity ID in App Group
    }
    
    func endLiveActivity() {
        // TODO: Implement ActivityKit Live Activity end
        logger.info("🔄 Live Activity end requested (not yet implemented)")
    }
    
    /// Reset/clear the current night session
    /// - Parameter archive: If true, marks session as "reset" in notes instead of deleting
    func resetCurrentNight(archive: Bool) {
        do {
            let descriptor = FetchDescriptor<DoseLog>(
                predicate: #Predicate { $0.finalWakeTimeUTC == nil },
                sortBy: [SortDescriptor(\.bedtimeUTC, order: .reverse)]
            )
            let logs = try context.fetch(descriptor)
            
            guard let currentLog = logs.first else {
                logger.warning("⚠️ No current night session to reset")
                return
            }
            
            if archive {
                // Archive approach: Mark as reset in notes, set final wake
                let resetNote = "\n[RESET by user at \(Date())] - Session was reset/abandoned"
                currentLog.notes = (currentLog.notes ?? "") + resetNote
                currentLog.finalWakeTimeUTC = Date()
                currentLog.finalWakeProvenance = "Reset"
                logger.info("📦 Archived current night: \(currentLog.nightKey)")
            } else {
                // Delete approach: Remove session entirely
                context.delete(currentLog)
                logger.info("🗑️ Deleted current night: \(currentLog.nightKey)")
            }
            
            try context.save()
            clearLastEvent() // Clear undo tracking
            
            logger.info("✅ Reset current night session (archive: \(archive))")
        } catch {
            logger.error("❌ Failed to reset night: \(error.localizedDescription)")
        }
    }
    
    /// Enhanced reset night with batch tracking and audit trail
    /// - Parameters:
    ///   - mode: Soft (archive) or Hard (delete)
    ///   - reason: User-provided reason for reset
    ///   - resetBatchId: UUID for undo tracking
    func resetNight(mode: ResetMode, reason: String, resetBatchId: String) {
        do {
            let descriptor = FetchDescriptor<DoseLog>(
                predicate: #Predicate { $0.finalWakeTimeUTC == nil },
                sortBy: [SortDescriptor(\.bedtimeUTC, order: .reverse)]
            )
            let logs = try context.fetch(descriptor)
            
            guard let currentLog = logs.first else {
                logger.warning("⚠️ No current night session to reset")
                return
            }
            
            // Write audit event before modifying
            let auditNote = "\n[RESET \(mode.rawValue.uppercased())] by user at \(Date())\nReason: \(reason)\nBatch ID: \(resetBatchId)"
            
            if mode == .soft {
                // Soft reset: Mark as closed by reset, preserve data
                currentLog.resetBatchId = resetBatchId
                currentLog.isClosedByReset = true
                currentLog.notes = (currentLog.notes ?? "") + auditNote
                currentLog.finalWakeTimeUTC = Date()
                currentLog.finalWakeProvenance = "Reset (Soft)"
                logger.info("📦 Soft reset current night: \(currentLog.nightKey), batch: \(resetBatchId)")
            } else {
                // Hard reset: Delete session entirely
                currentLog.resetBatchId = resetBatchId
                currentLog.notes = (currentLog.notes ?? "") + auditNote
                context.delete(currentLog)
                logger.info("🗑️ Hard reset (deleted) current night: \(currentLog.nightKey), batch: \(resetBatchId)")
            }
            
            try context.save()
            clearLastEvent()
            
            logger.info("✅ Reset night completed (mode: \(mode.rawValue), reason: \(reason))")
        } catch {
            logger.error("❌ Failed to reset night: \(error.localizedDescription)")
        }
    }
    
    /// Undo a soft reset within the undo window
    /// - Parameter resetBatchId: The batch ID from the original reset
    func undoResetNight(resetBatchId: String) {
        do {
            // Find the reset session by batch ID
            let descriptor = FetchDescriptor<DoseLog>(
                predicate: #Predicate { log in
                    log.resetBatchId == resetBatchId && log.isClosedByReset == true
                },
                sortBy: [SortDescriptor(\.bedtimeUTC, order: .reverse)]
            )
            let logs = try context.fetch(descriptor)
            
            guard let resetLog = logs.first else {
                logger.warning("⚠️ No reset session found with batch ID: \(resetBatchId)")
                return
            }
            
            // Restore the session
            resetLog.isClosedByReset = false
            resetLog.finalWakeTimeUTC = nil
            resetLog.finalWakeProvenance = nil
            
            // Add undo note
            let undoNote = "\n[UNDO RESET] at \(Date()) - Session restored from soft reset"
            resetLog.notes = (resetLog.notes ?? "") + undoNote
            
            try context.save()
            
            logger.info("↩️ Undid reset for night: \(resetLog.nightKey), batch: \(resetBatchId)")
        } catch {
            logger.error("❌ Failed to undo reset: \(error.localizedDescription)")
        }
    }
    
    /// Cancel Dose 2 notifications (stub for notification manager)
    func cancelDose2Notifications() {
        // TODO: Implement when NotificationManager is added
        logger.info("🔕 Cancelled Dose 2 notifications (stub)")
    }
    
    // MARK: - Private Helpers
    
    private func updateLastEvent(kind: LoggedEvent.Kind, timestamp: Date) {
        appGroupDefaults.set(kind.rawValue, forKey: "lastEventKind")
        appGroupDefaults.set(timestamp, forKey: "lastEventTime")
        logger.debug("Updated last event: \(kind.rawValue)")
    }
    
    private func clearLastEvent() {
        appGroupDefaults.removeObject(forKey: "lastEventKind")
        appGroupDefaults.removeObject(forKey: "lastEventTime")
        logger.debug("Cleared last event")
    }
    
    private func enqueuePendingAction(_ action: PendingActionKind, timestamp: Date) {
        // TODO: Implement durable pending action queue
        logger.warning("🔄 Pending action enqueued (queue not yet implemented): \(action)")
    }
}

// MARK: - Supporting Types

enum PendingActionKind: CustomStringConvertible {
    case inBedNow
    case dose1Now(grams: Double)
    case dose2Now(grams: Double)
    case bathroomNow
    case alarmWakeNow
    case finalWakeNow(provenance: String)
    
    var description: String {
        switch self {
        case .inBedNow: return "inBedNow"
        case .dose1Now(let grams): return "dose1Now(\(grams)g)"
        case .dose2Now(let grams): return "dose2Now(\(grams)g)"
        case .bathroomNow: return "bathroomNow"
        case .alarmWakeNow: return "alarmWakeNow"
        case .finalWakeNow(let provenance): return "finalWakeNow(\(provenance))"
        }
    }
}
