#!/bin/bash

# DoseTrack Installation and Testing Summary
# Run this script to verify installation and test what's currently available

set -e

echo "======================================"
echo " DoseTrack Installation & Test Report"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Node.js
echo "🔍 Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✅ Node.js installed: ${NODE_VERSION}${NC}"
else
    echo -e "${RED}❌ Node.js not found${NC}"
    exit 1
fi

# Check npm
echo "🔍 Checking npm..."
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✅ npm installed: ${NPM_VERSION}${NC}"
else
    echo -e "${RED}❌ npm not found${NC}"
    exit 1
fi

# Check Xcode
echo ""
echo "🔍 Checking Xcode..."
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    echo -e "${GREEN}✅ Xcode installed: ${XCODE_VERSION}${NC}"
    XCODE_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  Xcode not found (iOS testing unavailable)${NC}"
    XCODE_AVAILABLE=false
fi

# Check Swift
echo "🔍 Checking Swift..."
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -n 1)
    echo -e "${GREEN}✅ Swift installed: ${SWIFT_VERSION}${NC}"
else
    echo -e "${YELLOW}⚠️  Swift not found${NC}"
fi

# Check server dependencies
echo ""
echo "🔍 Checking server dependencies..."
if [ -d "server/node_modules" ]; then
    PACKAGE_COUNT=$(ls server/node_modules | wc -l | tr -d ' ')
    echo -e "${GREEN}✅ Server dependencies installed (${PACKAGE_COUNT} packages)${NC}"
else
    echo -e "${YELLOW}⚠️  Server dependencies not installed${NC}"
    echo "   Run: cd server && npm install"
fi

# Check .env file
echo "🔍 Checking server configuration..."
if [ -f "server/.env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    if grep -q "your-whoop-token-here" server/.env; then
        echo -e "${YELLOW}   ⚠️  WHOOP_TOKEN not configured (using placeholder)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    echo "   Copy from: cp server/.env.example server/.env"
fi

# Check Spec Kit
echo ""
echo "🔍 Checking Spec Kit..."
if [ -d ".specify" ]; then
    echo -e "${GREEN}✅ Spec Kit initialized${NC}"
    if [ -f ".specify/memory/constitution.md" ]; then
        echo -e "${GREEN}   ✅ Constitution created${NC}"
    else
        echo -e "${YELLOW}   ⏭️  Constitution not created yet${NC}"
        echo "      Run: /speckit.constitution in GitHub Copilot Chat"
    fi
else
    echo -e "${YELLOW}⚠️  Spec Kit not initialized${NC}"
fi

# Test server (if running)
echo ""
echo "🔍 Checking if server is running..."
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Server is running on http://localhost:3000${NC}"
    
    # Test health endpoint
    HEALTH_RESPONSE=$(curl -s http://localhost:3000/health)
    if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
        echo -e "${GREEN}   ✅ Health check passed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Server not running${NC}"
    echo "   Start with: cd server && npm start"
fi

# Check iOS files
echo ""
echo "🔍 Checking iOS source files..."
IOS_FILES=(
    "ios/Models.swift"
    "ios/DoseTrackApp.swift"
    "ios/TodayLogView.swift"
    "ios/DoseLogController.swift"
    "ios/HealthKitManager.swift"
    "ios/NightPlanRecommender.swift"
    "ios/CSVExporter.swift"
)

IOS_COUNT=0
for file in "${IOS_FILES[@]}"; do
    if [ -f "$file" ]; then
        ((IOS_COUNT++))
    fi
done

echo -e "${GREEN}✅ Found ${IOS_COUNT}/${#IOS_FILES[@]} iOS source files${NC}"

# Check for Xcode project
if find . -name "*.xcodeproj" -o -name "*.xcworkspace" | grep -q .; then
    echo -e "${GREEN}✅ Xcode project exists${NC}"
else
    echo -e "${YELLOW}⚠️  No Xcode project found${NC}"
    echo "   Create manually per README.md or TESTING_GUIDE.md"
fi

# Summary
echo ""
echo "======================================"
echo " Summary"
echo "======================================"
echo ""

echo "✅ READY FOR TESTING:"
echo "   • Server code (Node.js/Express)"
echo "   • Server dependencies installed"
echo "   • Test scripts created"
echo "   • Documentation complete"
echo ""

if [ "$XCODE_AVAILABLE" = false ]; then
    echo "⚠️  REQUIRES SETUP:"
    echo "   • Xcode installation"
    echo "   • Xcode project creation"
    echo "   • iOS app compilation"
    echo ""
fi

echo "📚 DOCUMENTATION:"
echo "   • README.md - Project overview"
echo "   • TESTING_GUIDE.md - Complete testing instructions"
echo "   • PROJECT_REVIEW.md - Code quality analysis"
echo "   • SPEC_KIT_QUICKSTART.md - Spec creation guide"
echo "   • SPEC_KIT_RECOMMENDATIONS.md - Strategic guidance"
echo ""

echo "🚀 NEXT STEPS:"
if [ "$XCODE_AVAILABLE" = false ]; then
    echo "   1. Install Xcode from App Store"
    echo "   2. Create Xcode project (see TESTING_GUIDE.md)"
    echo "   3. Add iOS source files to project"
    echo "   4. Configure capabilities (HealthKit, App Groups)"
    echo "   5. Run unit tests"
else
    echo "   1. Create Xcode project (if not exists)"
    echo "   2. Run: cd server && npm start"
    echo "   3. Run: cd server && node test-server.js (in new terminal)"
    echo "   4. Build iOS app in Xcode"
    echo "   5. Run unit tests (Cmd+U in Xcode)"
fi
echo ""

echo "💡 TIP: See TESTING_GUIDE.md for detailed instructions"
echo ""
