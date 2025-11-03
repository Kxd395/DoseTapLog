#!/usr/bin/env node

/**
 * Test script for DoseTrack WHOOP Proxy Server
 * Tests health check and API endpoints (with mock data when WHOOP_TOKEN not available)
 */

import fetch from "node-fetch";
import dotenv from "dotenv";

dotenv.config();

const BASE_URL = "http://localhost:3000";
const API_KEY = process.env.API_KEY || "test-api-key-local-dev-only";

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m"
};

function log(msg, color = colors.reset) {
  console.log(`${color}${msg}${colors.reset}`);
}

async function testEndpoint(name, url, options = {}) {
  try {
    log(`\n🧪 Testing: ${name}`, colors.blue);
    log(`   URL: ${url}`);
    
    const startTime = Date.now();
    const response = await fetch(url, options);
    const duration = Date.now() - startTime;
    
    const contentType = response.headers.get("content-type");
    let data;
    
    if (contentType && contentType.includes("application/json")) {
      data = await response.json();
    } else {
      data = await response.text();
    }
    
    log(`   Status: ${response.status} ${response.statusText}`);
    log(`   Duration: ${duration}ms`);
    
    if (response.ok) {
      log(`   ✅ PASS`, colors.green);
      console.log("   Response:", JSON.stringify(data, null, 2).split('\n').map(l => '   ' + l).join('\n'));
      return { success: true, data, status: response.status };
    } else {
      log(`   ❌ FAIL`, colors.red);
      console.log("   Error:", JSON.stringify(data, null, 2).split('\n').map(l => '   ' + l).join('\n'));
      return { success: false, data, status: response.status };
    }
  } catch (error) {
    log(`   ❌ ERROR: ${error.message}`, colors.red);
    return { success: false, error: error.message };
  }
}

async function runTests() {
  log("\n" + "=".repeat(60), colors.blue);
  log("DoseTrack WHOOP Proxy Server Tests", colors.blue);
  log("=".repeat(60), colors.blue);
  
  const results = [];
  
  // Test 1: Health check (no auth required)
  results.push(await testEndpoint(
    "Health Check",
    `${BASE_URL}/health`
  ));
  
  // Test 2: API endpoint without auth (should fail)
  results.push(await testEndpoint(
    "Latest Sleep - No Auth (should fail)",
    `${BASE_URL}/api/sleep/latest`
  ));
  
  // Test 3: API endpoint with wrong auth (should fail)
  results.push(await testEndpoint(
    "Latest Sleep - Wrong API Key (should fail)",
    `${BASE_URL}/api/sleep/latest`,
    {
      headers: {
        "x-api-key": "wrong-key"
      }
    }
  ));
  
  // Test 4: API endpoint with correct auth
  results.push(await testEndpoint(
    "Latest Sleep - With Auth",
    `${BASE_URL}/api/sleep/latest`,
    {
      headers: {
        "x-api-key": API_KEY
      }
    }
  ));
  
  // Test 5: 7-day aggregates endpoint
  results.push(await testEndpoint(
    "7-Day Aggregates - With Auth",
    `${BASE_URL}/api/aggregates/7days`,
    {
      headers: {
        "x-api-key": API_KEY
      }
    }
  ));
  
  // Test 6: 404 Not Found
  results.push(await testEndpoint(
    "Invalid Endpoint (should 404)",
    `${BASE_URL}/api/invalid`
  ));
  
  // Test 7: Rate limiting (make 5 quick requests)
  log(`\n🧪 Testing: Rate Limiting (5 rapid requests)`, colors.blue);
  const rateLimitResults = [];
  for (let i = 0; i < 5; i++) {
    const result = await testEndpoint(
      `Rate Limit Test ${i + 1}/5`,
      `${BASE_URL}/api/sleep/latest`,
      {
        headers: {
          "x-api-key": API_KEY
        }
      }
    );
    rateLimitResults.push(result);
  }
  
  // Summary
  log("\n" + "=".repeat(60), colors.blue);
  log("Test Summary", colors.blue);
  log("=".repeat(60), colors.blue);
  
  const passed = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  
  log(`\n✅ Passed: ${passed}`, colors.green);
  log(`❌ Failed: ${failed}`, colors.red);
  log(`📊 Total: ${results.length}`, colors.blue);
  
  // Expected failures (auth tests)
  const expectedFailures = results.filter((r, i) => {
    return [1, 2, 5].includes(i) && !r.success; // Tests that should fail
  }).length;
  
  if (expectedFailures > 0) {
    log(`\n⚠️  Note: ${expectedFailures} expected failures (auth/404 tests)`, colors.yellow);
  }
  
  if (!process.env.WHOOP_TOKEN || process.env.WHOOP_TOKEN === "your-whoop-token-here") {
    log(`\n⚠️  WHOOP_TOKEN not configured - API calls will fail with real WHOOP API`, colors.yellow);
    log(`   Set WHOOP_TOKEN in .env file for full integration testing`, colors.yellow);
  }
  
  log("\n" + "=".repeat(60) + "\n", colors.blue);
}

// Check if server is running
async function checkServer() {
  try {
    await fetch(`${BASE_URL}/health`);
    return true;
  } catch (error) {
    return false;
  }
}

// Main execution
(async () => {
  const serverRunning = await checkServer();
  
  if (!serverRunning) {
    log("❌ Server is not running at " + BASE_URL, colors.red);
    log("\nPlease start the server first:", colors.yellow);
    log("   cd server", colors.yellow);
    log("   npm start", colors.yellow);
    log("\nThen run this test script again.", colors.yellow);
    process.exit(1);
  }
  
  await runTests();
})();
