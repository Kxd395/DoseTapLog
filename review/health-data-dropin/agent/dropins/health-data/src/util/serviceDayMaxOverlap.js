// serviceDayMaxOverlap.js
// Deterministic service-day bucketing using maximum temporal overlap rule
// Must produce IDENTICAL results to Swift implementation
// PRODUCTION VERSION: Uses date-fns-tz for correct timezone math

const { zonedTimeToUtc, utcToZonedTime, format } = require('date-fns-tz');
const { addDays, startOfDay, setHours } = require('date-fns');

/**
 * Assign sample to service day with maximum temporal overlap.
 * Ties → choose **earlier** day for stability.
 * 
 * @param {string} startUTC - ISO8601 timestamp (e.g., "2025-11-03T04:30:00Z")
 * @param {string} endUTC - ISO8601 timestamp
 * @param {number} cutoffHourLocal - Hour of day (0-23) when service day begins
 * @param {string} tzName - IANA timezone (e.g., "America/New_York")
 * @returns {string} Service day key in YYYY-MM-DD format
 */
function serviceDayKeyMaxOverlap(startUTC, endUTC, cutoffHourLocal, tzName) {
    const start = new Date(startUTC);
    const end = new Date(endUTC);
    
    // Convert UTC to target timezone
    const startZoned = utcToZonedTime(start, tzName);
    const endZoned = utcToZonedTime(end, tzName);
    
    // Find all candidate service days
    const candidates = [];
    
    // Start checking from day BEFORE start (in case sample starts before cutoff)
    let candidateDate = startOfDay(addDays(startZoned, -1));
    
    // Scan up to 4 days (handles long samples + timezone quirks + early starts)
    for (let i = 0; i < 4; i++) {
        // Service day boundaries in target timezone
        // Service day labeled with the ENDING day (when you wake up)
        // So "Nov 4" service day = Nov 3 noon → Nov 4 noon
        const serviceDayStart = setHours(candidateDate, cutoffHourLocal);
        const serviceDayEnd = setHours(addDays(candidateDate, 1), cutoffHourLocal);
        
        // Convert boundaries to UTC for overlap calculation
        const serviceDayStartUTC = zonedTimeToUtc(serviceDayStart, tzName);
        const serviceDayEndUTC = zonedTimeToUtc(serviceDayEnd, tzName);
        
        // Compute overlap in milliseconds
        const overlapStart = new Date(Math.max(start.getTime(), serviceDayStartUTC.getTime()));
        const overlapEnd = new Date(Math.min(end.getTime(), serviceDayEndUTC.getTime()));
        const overlap = Math.max(0, overlapEnd - overlapStart);
        
        if (overlap > 0) {
            // Label with the ENDING day (next day after candidateDate)
            const serviceDay = addDays(candidateDate, 1);
            candidates.push({
                day: format(serviceDay, 'yyyy-MM-dd', { timeZone: tzName }),
                overlap: overlap
            });
        }
        
        candidateDate = addDays(candidateDate, 1);
        
        // Early exit if well past end date
        if (candidateDate > addDays(endZoned, 1)) break;
    }
    
    if (candidates.length === 0) {
        // Fallback: use start date in target timezone
        return format(startOfDay(startZoned), 'yyyy-MM-dd', { timeZone: tzName });
    }
    
    // Sort: max overlap first, ties → earlier day
    candidates.sort((a, b) => {
        const overlapDiff = b.overlap - a.overlap;
        if (Math.abs(overlapDiff) < 10) { // Tie within 10ms
            return a.day.localeCompare(b.day); // Earlier day first (lexicographic)
        }
        return overlapDiff;
    });
    
    return candidates[0].day;
}

// MARK: - Unit Tests (Jest or Mocha)

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { serviceDayKeyMaxOverlap };
}

// Run tests if executed directly
if (require.main === module) {
    const assert = require('assert');
    
    console.log('Running service day max-overlap tests...\n');
    
    // Test 1: Normal sleep post-cutoff
    {
        const key = serviceDayKeyMaxOverlap(
            '2025-11-03T04:30:00Z', // 23:30 EST
            '2025-11-04T11:30:00Z', // 06:30 EST
            12,
            'America/New_York'
        );
        assert.strictEqual(key, '2025-11-04', 'Test 1: Majority overlap is Nov 4');
        console.log('✅ Test 1: Normal sleep post-cutoff');
    }
    
    // Test 2: Early bedtime
    {
        const key = serviceDayKeyMaxOverlap(
            '2025-11-03T02:00:00Z', // 21:00 EST
            '2025-11-04T09:00:00Z', // 04:00 EST
            12,
            'America/New_York'
        );
        assert.strictEqual(key, '2025-11-04', 'Test 2: 4h > 3h → Nov 4');
        console.log('✅ Test 2: Early bedtime pre-cutoff');
    }
    
    // Test 3: DST spring forward
    {
        const key = serviceDayKeyMaxOverlap(
            '2025-03-09T06:30:00Z',  // 01:30 EST
            '2025-03-09T12:45:00Z',  // 08:45 EDT
            12,
            'America/New_York'
        );
        assert.strictEqual(key, '2025-03-09', 'Test 3: DST spring forward');
        console.log('✅ Test 3: DST spring forward');
    }
    
    // Test 4: DST fall back
    {
        const key = serviceDayKeyMaxOverlap(
            '2025-11-02T04:30:00Z',  // 00:30 EDT
            '2025-11-02T12:30:00Z',  // 07:30 EST
            12,
            'America/New_York'
        );
        assert.strictEqual(key, '2025-11-02', 'Test 4: DST fall back');
        console.log('✅ Test 4: DST fall back');
    }
    
    // Test 5: Exact tie (earlier day wins)
    {
        const key = serviceDayKeyMaxOverlap(
            '2025-11-03T05:00:00Z',  // 00:00 EST Nov 3 midnight
            '2025-11-04T05:00:00Z',  // 00:00 EST Nov 4 midnight (24h sleep)
            12,
            'America/New_York'
        );
        assert.strictEqual(key, '2025-11-03', 'Test 5: Tie → earlier day wins');
        console.log('✅ Test 5: Exact tie (earlier day wins)');
    }
    
    // Test 6: Short nap (single day)
    {
        const key = serviceDayKeyMaxOverlap(
            '2025-11-04T19:00:00Z',  // 14:00 EST (after noon cutoff)
            '2025-11-04T20:30:00Z',  // 15:30 EST
            12,
            'America/New_York'
        );
        assert.strictEqual(key, '2025-11-05', 'Test 6: Nap after cutoff belongs to next service day');
        console.log('✅ Test 6: Short nap (single day)');
    }
    
    console.log('\n🎉 All tests passed!');
}

// MARK: - Parity Test with Swift

/**
 * To verify parity with Swift implementation:
 * 
 * 1. Generate 100 random sleep spans with:
 *    - Random start times (18:00 - 02:00 local)
 *    - Random durations (4-10 hours)
 *    - Random cutoffs (10-14)
 *    - Random timezones (America/New_York, America/Denver, Europe/London)
 * 
 * 2. Compute service_day_key in both Swift and JS
 * 
 * 3. Assert 100% match
 * 
 * Example test generator:
 */
function generateParityTestCases(count = 100) {
    const timezones = ['America/New_York', 'America/Denver', 'Europe/London', 'Asia/Tokyo'];
    const cutoffs = [10, 11, 12, 13, 14];
    const cases = [];
    
    for (let i = 0; i < count; i++) {
        const tz = timezones[Math.floor(Math.random() * timezones.length)];
        const cutoff = cutoffs[Math.floor(Math.random() * cutoffs.length)];
        
        // Random start date
        const baseDate = new Date('2025-11-01T00:00:00Z');
        baseDate.setDate(baseDate.getDate() + Math.floor(Math.random() * 30)); // Nov 1-30
        
        // Random start hour (18:00 - 02:00 local)
        const startHour = Math.random() < 0.7 
            ? 18 + Math.floor(Math.random() * 6)  // 18-23
            : Math.floor(Math.random() * 3);      // 00-02
        
        baseDate.setUTCHours(startHour, Math.floor(Math.random() * 60), 0, 0);
        
        // Random duration (4-10 hours)
        const durationMs = (4 + Math.random() * 6) * 3600 * 1000;
        const endDate = new Date(baseDate.getTime() + durationMs);
        
        const testCase = {
            start_utc: baseDate.toISOString(),
            end_utc: endDate.toISOString(),
            cutoff: cutoff,
            tz: tz
        };
        
        cases.push(testCase);
    }
    
    return cases;
}

// Export parity test generator
if (typeof module !== 'undefined' && module.exports) {
    module.exports.generateParityTestCases = generateParityTestCases;
}
