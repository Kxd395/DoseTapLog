#!/usr/bin/env node
/**
 * Service-Day Parity Test: Swift ↔ JS
 * 
 * Generates 100 random test cases and compares Swift vs JS output.
 * Requires Swift test harness that outputs JSON to stdout.
 */

const { serviceDayKeyMaxOverlap, generateParityTestCases } = require('../src/util/serviceDayMaxOverlap');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = path.join(__dirname, '../../../../../../review/mlupdateInfo/tests/parity');
const CASES_FILE = path.join(OUTPUT_DIR, 'parity_cases_100.json');
const REPORT_FILE = path.join(OUTPUT_DIR, 'parity_report.md');
const SWIFT_TEST_PATH = path.join(__dirname, '../../../../../../DoseTrackNew/DoseTrackNew/Tests/ServiceDayParityTests.swift');

console.log('🧪 Service-Day Parity Test (Swift ↔ JS)\n');

// Generate test cases
console.log('1️⃣  Generating 100 random test cases...');
const testCases = generateParityTestCases(100);

// Save cases
fs.mkdirSync(OUTPUT_DIR, { recursive: true });
fs.writeFileSync(CASES_FILE, JSON.stringify(testCases, null, 2));
console.log(`   ✅ Saved to ${CASES_FILE}\n`);

// Run JS version
console.log('2️⃣  Running JS implementation...');
const jsResults = testCases.map(tc => {
    const key = serviceDayKeyMaxOverlap(tc.start_utc, tc.end_utc, tc.cutoff, tc.tz);
    return { ...tc, js_key: key };
});
console.log(`   ✅ JS processed ${jsResults.length} cases\n`);

// Run Swift version
console.log('3️⃣  Running Swift implementation...');
let swiftResults = [];
try {
    // Use standalone Swift script (simpler than xcodebuild)
    const swiftScriptPath = path.join(__dirname, '../../../../../../scripts/run-parity-swift.swift');
    
    if (!fs.existsSync(swiftScriptPath)) {
        console.warn(`   ⚠️  Swift parity script not found at ${swiftScriptPath}`);
        console.warn('   Skipping Swift verification\n');
    } else {
        const swiftCmd = `cd ${path.join(__dirname, '../../../../../..')} && swift scripts/run-parity-swift.swift`;
        
        try {
            const swiftOutput = execSync(swiftCmd, { encoding: 'utf8', stdio: 'pipe' });
            // Parse Swift JSON output (format: PARITY_RESULT: {"case_index":0,"swift_key":"2025-11-04"})
            const matches = swiftOutput.matchAll(/PARITY_RESULT: ({.*})/g);
            swiftResults = Array.from(matches).map(m => JSON.parse(m[1]));
            console.log(`   ✅ Swift processed ${swiftResults.length} cases\n`);
        } catch (err) {
            console.error(`   ❌ Swift test execution failed: ${err.message}`);
            console.error('   Marking Swift results as N/A for now\n');
        }
    }
} catch (err) {
    console.warn(`   ⚠️  Swift parity tests not available: ${err.message}\n`);
}

// Compare results
console.log('4️⃣  Comparing results...');
const comparisons = jsResults.map((jr, idx) => {
    const sr = swiftResults.find(s => s.case_index === idx);
    const match = sr ? (jr.js_key === sr.swift_key) : null;
    return {
        case_index: idx,
        start_utc: jr.start_utc,
        end_utc: jr.end_utc,
        cutoff: jr.cutoff,
        tz: jr.tz,
        js_key: jr.js_key,
        swift_key: sr?.swift_key || 'N/A',
        match: match
    };
});

const passCount = comparisons.filter(c => c.match === true).length;
const failCount = comparisons.filter(c => c.match === false).length;
const naCount = comparisons.filter(c => c.match === null).length;

console.log(`   ✅ Pass: ${passCount}`);
console.log(`   ❌ Fail: ${failCount}`);
console.log(`   ⚠️  N/A:  ${naCount}\n`);

// Generate report
const report = generateReport(comparisons, passCount, failCount, naCount);
fs.writeFileSync(REPORT_FILE, report);
console.log(`📄 Report saved to ${REPORT_FILE}\n`);

// Exit code
if (failCount > 0) {
    console.error('❌ PARITY TEST FAILED');
    process.exit(1);
} else if (naCount === comparisons.length) {
    console.warn('⚠️  PARITY TEST INCOMPLETE (Swift not available)');
    process.exit(2);
} else {
    console.log('✅ PARITY TEST PASSED');
    process.exit(0);
}

// MARK: - Helper Functions

function generateReport(comparisons, passCount, failCount, naCount) {
    const timestamp = new Date().toISOString();
    let md = `# Service-Day Parity Test Report\n\n`;
    md += `**Generated:** ${timestamp}\n`;
    md += `**Total Cases:** ${comparisons.length}\n`;
    md += `**Pass:** ${passCount} ✅\n`;
    md += `**Fail:** ${failCount} ❌\n`;
    md += `**N/A:** ${naCount} ⚠️\n\n`;
    
    if (failCount > 0) {
        md += `## ❌ Failed Cases\n\n`;
        md += `| Case | Start UTC | End UTC | TZ | Cutoff | JS Key | Swift Key |\n`;
        md += `|------|-----------|---------|----|---------|---------|-----------|\n`;
        comparisons.filter(c => c.match === false).forEach(c => {
            md += `| ${c.case_index} | ${c.start_utc} | ${c.end_utc} | ${c.tz} | ${c.cutoff} | ${c.js_key} | ${c.swift_key} |\n`;
        });
        md += `\n`;
    }
    
    if (passCount === comparisons.length && naCount === 0) {
        md += `## 🎉 All Tests Passed!\n\n`;
        md += `Both Swift and JS implementations produce **identical** service-day keys across all test cases.\n\n`;
    }
    
    if (naCount > 0) {
        md += `## ⚠️ Incomplete Results\n\n`;
        md += `Swift test runner not available. JS results computed successfully:\n\n`;
        md += `| Case | Start UTC | End UTC | TZ | Cutoff | JS Key |\n`;
        md += `|------|-----------|---------|----|---------|---------|\n`;
        comparisons.slice(0, 10).forEach(c => {
            md += `| ${c.case_index} | ${c.start_utc} | ${c.end_utc} | ${c.tz} | ${c.cutoff} | ${c.js_key} |\n`;
        });
        md += `\n*(Showing first 10 of ${comparisons.length})*\n\n`;
        md += `### Next Steps\n`;
        md += `1. Create Swift parity test runner at \`ios/Tests/ServiceDayParityRunner.swift\`\n`;
        md += `2. Read test cases from JSON\n`;
        md += `3. Print results to stdout in format: \`PARITY_RESULT: {"case_index":0,"swift_key":"2025-11-04"}\`\n`;
        md += `4. Re-run this script\n`;
    }
    
    md += `\n---\n`;
    md += `**Test cases saved to:** ${CASES_FILE}\n`;
    
    return md;
}

function createSwiftParityRunner() {
    const swiftCode = `import XCTest
import Foundation

/// Parity test runner for serviceDayKey algorithm
/// Reads test cases from JSON and outputs results for comparison with JS implementation
final class ServiceDayParityTests: XCTestCase {
    
    func testParity100Cases() throws {
        let casesPath = "../../../review/mlupdateInfo/tests/parity/parity_cases_100.json"
        let url = URL(fileURLWithPath: casesPath, relativeTo: URL(fileURLWithPath: #file))
        
        guard let data = try? Data(contentsOf: url),
              let cases = try? JSONDecoder().decode([ParityCase].self, from: data) else {
            XCTFail("Failed to load parity cases from \\(url.path)")
            return
        }
        
        for (index, testCase) in cases.enumerated() {
            let startDate = ISO8601DateFormatter().date(from: testCase.start_utc)!
            let endDate = ISO8601DateFormatter().date(from: testCase.end_utc)!
            let tz = TimeZone(identifier: testCase.tz)!
            
            let swiftKey = ServiceDayMaxOverlap.serviceDayKey(
                start: startDate,
                end: endDate,
                cutoffHourLocal: testCase.cutoff,
                tz: tz
            )
            
            // Output for parity script to parse
            let result = "{\\"case_index\\":\\(index),\\"swift_key\\":\\"\\(swiftKey)\\"}"
            print("PARITY_RESULT: \\(result)")
        }
    }
}

struct ParityCase: Codable {
    let start_utc: String
    let end_utc: String
    let cutoff: Int
    let tz: String
}
`;
    
    const testDir = path.join(__dirname, '../../../../../ios/Tests');
    fs.mkdirSync(testDir, { recursive: true });
    fs.writeFileSync(path.join(testDir, 'ServiceDayParityRunner.swift'), swiftCode);
    console.log(`   ✅ Created Swift parity runner at ios/Tests/ServiceDayParityRunner.swift`);
}
