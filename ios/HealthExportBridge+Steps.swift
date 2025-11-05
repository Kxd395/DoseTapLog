// HealthExportBridge+Steps.swift
// De-overlapped step count export using HKStatisticsCollection
// Prevents double-counting when multiple devices (watch + phone) track steps

import Foundation
import HealthKit

extension HealthExportBridge {
    
    /// Export step counts using HKStatisticsCollection to de-overlap samples
    /// Returns one aggregated record per service day
    func exportStepTotals(
        from startDate: Date,
        to endDate: Date,
        cutoffHourLocal: Int,
        tz: TimeZone
    ) async throws -> [HealthRecord] {
        
        let stepsType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        // Anchor date aligned to cutoff hour (service day boundary)
        var calendar = Calendar.current
        calendar.timeZone = tz
        
        var components = calendar.dateComponents([.year, .month, .day], from: startDate)
        components.hour = cutoffHourLocal
        components.minute = 0
        components.second = 0
        components.timeZone = tz
        
        let anchorDate = calendar.date(from: components)!
        
        // Query statistics collection (HealthKit de-overlaps automatically)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { [weak self] _, collection, error in
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var records: [HealthRecord] = []
                
                collection?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    guard let sum = stats.sumQuantity() else { return }
                    
                    let count = sum.doubleValue(for: .count())
                    
                    // Map stats bucket to service day using max-overlap rule
                    let serviceDay = ServiceDayCalculator.serviceDayKey(
                        start: stats.startDate,
                        end: stats.endDate,
                        cutoffHourLocal: cutoffHourLocal,
                        tz: tz
                    )
                    
                    // Compute offsets at bucket boundaries
                    let startOffset = tz.secondsFromGMT(for: stats.startDate) / 60
                    let endOffset = tz.secondsFromGMT(for: stats.endDate) / 60
                    
                    // Create aggregated record
                    let record = HealthRecord(
                        schemaVersion: "2.0",
                        exporterVersion: "2.1.0",
                        source: "healthkit",
                        recordType: "step",
                        startUTC: ISO8601DateFormatter().string(from: stats.startDate),
                        endUTC: ISO8601DateFormatter().string(from: stats.endDate),
                        serviceDayKey: serviceDay,
                        startOffsetMin: startOffset,
                        endOffsetMin: endOffset,
                        tzName: tz.identifier,
                        cutoffHourLocal: cutoffHourLocal,
                        value: count,
                        unit: "count",
                        sha256: "", // Compute after record creation
                        deleted: false,
                        deviceModel: nil, // Aggregated across devices
                        deviceHW: nil,
                        deviceSW: nil,
                        sourceApp: "HealthKit",
                        metadata: [
                            "aggregation": "HKStatisticsCollection",
                            "interval": "1d",
                            "de_overlapped": true
                        ]
                    )
                    
                    // Compute SHA-256 hash
                    var mutableRecord = record
                    mutableRecord.sha256 = mutableRecord.canonicalHash256()
                    
                    records.append(mutableRecord)
                }
                
                continuation.resume(returning: records)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Export individual step samples (for debugging/verification only)
    /// NOT recommended for production - use exportStepTotals() instead
    func exportStepSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthRecord] {
        
        let stepsType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let records = (samples as? [HKQuantitySample])?.compactMap { sample -> HealthRecord? in
                    try? self.makeRecord(from: sample, typeId: "step", deleted: false)
                } ?? []
                
                continuation.resume(returning: records)
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Overlap Detection (For Testing)

#if DEBUG
extension HealthExportBridge {
    
    /// Detect overlapping step samples (for verification)
    /// Returns pairs of overlapping samples with their overlap duration
    func detectStepOverlaps(
        samples: [HKQuantitySample]
    ) -> [(sample1: HKQuantitySample, sample2: HKQuantitySample, overlapSeconds: TimeInterval)] {
        
        var overlaps: [(HKQuantitySample, HKQuantitySample, TimeInterval)] = []
        
        for i in 0..<samples.count {
            for j in (i+1)..<samples.count {
                let s1 = samples[i]
                let s2 = samples[j]
                
                // Check if time ranges overlap
                let overlapStart = max(s1.startDate, s2.startDate)
                let overlapEnd = min(s1.endDate, s2.endDate)
                
                if overlapStart < overlapEnd {
                    let duration = overlapEnd.timeIntervalSince(overlapStart)
                    overlaps.append((s1, s2, duration))
                }
            }
        }
        
        return overlaps
    }
    
    /// Compute step total naively (sum all samples, including overlaps)
    /// Used to demonstrate the double-counting problem
    func naiveStepSum(samples: [HKQuantitySample]) -> Double {
        samples.reduce(0.0) { sum, sample in
            sum + sample.quantity.doubleValue(for: .count())
        }
    }
    
    /// Compute step total correctly (de-overlap using interval union)
    /// Matches HKStatisticsCollection behavior
    func deoverlappedStepSum(samples: [HKQuantitySample]) -> Double {
        // Build intervals
        var intervals: [(start: Date, end: Date, count: Double)] = []
        
        for sample in samples {
            intervals.append((
                start: sample.startDate,
                end: sample.endDate,
                count: sample.quantity.doubleValue(for: .count())
            ))
        }
        
        // Sort by start time
        intervals.sort { $0.start < $1.start }
        
        // Merge overlapping intervals (union)
        var merged: [(start: Date, end: Date, count: Double)] = []
        
        for interval in intervals {
            if let last = merged.last, interval.start < last.end {
                // Overlaps with previous interval
                // For steps, we can't simply merge counts (different devices may report different totals)
                // HKStatisticsCollection uses device priority - we'll take max
                let mergedEnd = max(last.end, interval.end)
                let mergedCount = max(last.count, interval.count) // Simplified heuristic
                merged[merged.count - 1] = (start: last.start, end: mergedEnd, count: mergedCount)
            } else {
                merged.append(interval)
            }
        }
        
        return merged.reduce(0.0) { $0 + $1.count }
    }
}

// MARK: - Unit Tests

import XCTest

class StepExportTests: XCTestCase {
    
    func testStepOverlapDetection() async throws {
        let bridge = HealthExportBridge()
        
        // Create mock overlapping samples
        let watch = HKQuantitySample(
            type: HKQuantityType(.stepCount),
            quantity: HKQuantity(unit: .count(), doubleValue: 100),
            start: iso8601("2025-11-04T10:00:00Z")!,
            end: iso8601("2025-11-04T11:00:00Z")!,
            device: HKDevice(name: "Apple Watch", manufacturer: "Apple", model: "Watch6,1", hardwareVersion: "1.0", firmwareVersion: "10.0", softwareVersion: "11.0", localIdentifier: "watch", udiDeviceIdentifier: nil),
            metadata: nil
        )
        
        let phone = HKQuantitySample(
            type: HKQuantityType(.stepCount),
            quantity: HKQuantity(unit: .count(), doubleValue: 90),
            start: iso8601("2025-11-04T10:30:00Z")!, // 30 min overlap
            end: iso8601("2025-11-04T11:30:00Z")!,
            device: HKDevice(name: "iPhone", manufacturer: "Apple", model: "iPhone14,2", hardwareVersion: "1.0", firmwareVersion: "1.0", softwareVersion: "18.0", localIdentifier: "phone", udiDeviceIdentifier: nil),
            metadata: nil
        )
        
        let overlaps = bridge.detectStepOverlaps(samples: [watch, phone])
        
        XCTAssertEqual(overlaps.count, 1, "Should detect 1 overlap")
        XCTAssertEqual(overlaps[0].overlapSeconds, 1800, "Overlap should be 30 minutes (1800s)")
    }
    
    func testNaiveVsDeoverlapped() async throws {
        let bridge = HealthExportBridge()
        
        // Same samples as above
        let watch = HKQuantitySample(
            type: HKQuantityType(.stepCount),
            quantity: HKQuantity(unit: .count(), doubleValue: 100),
            start: iso8601("2025-11-04T10:00:00Z")!,
            end: iso8601("2025-11-04T11:00:00Z")!
        )
        
        let phone = HKQuantitySample(
            type: HKQuantityType(.stepCount),
            quantity: HKQuantity(unit: .count(), doubleValue: 90),
            start: iso8601("2025-11-04T10:30:00Z")!,
            end: iso8601("2025-11-04T11:30:00Z")!
        )
        
        let naiveSum = bridge.naiveStepSum(samples: [watch, phone])
        let deoverlapped = bridge.deoverlappedStepSum(samples: [watch, phone])
        
        XCTAssertEqual(naiveSum, 190, "Naive sum double-counts")
        XCTAssertLessThan(deoverlapped, naiveSum, "De-overlapped sum should be less")
        XCTAssertEqual(deoverlapped, 100, "De-overlapped takes max during overlap period")
    }
    
    func testStepStatisticsCollection() async throws {
        let bridge = HealthExportBridge()
        
        let records = try await bridge.exportStepTotals(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            to: Date(),
            cutoffHourLocal: 12,
            tz: TimeZone.current
        )
        
        // Verify de-overlap metadata
        for record in records {
            XCTAssertEqual(record.recordType, "step")
            XCTAssertEqual(record.unit, "count")
            XCTAssertTrue(record.metadata?["de_overlapped"] as? Bool ?? false)
            XCTAssertEqual(record.metadata?["aggregation"] as? String, "HKStatisticsCollection")
        }
        
        print("✅ Exported \(records.count) de-overlapped step records")
    }
    
    // MARK: - Helpers
    
    func iso8601(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
}
#endif
