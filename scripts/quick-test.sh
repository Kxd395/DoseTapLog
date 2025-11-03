#!/bin/bash
set -e

echo "🔍 DoseTrack Quick Test Script"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check if server directory exists
echo "1️⃣  Checking server files..."
if [ -f "server/package.json" ]; then
    echo -e "   ${GREEN}✅ server/package.json found${NC}"
else
    echo -e "   ${RED}❌ server/package.json missing${NC}"
    exit 1
fi

if [ -f "server/index.js" ]; then
    echo -e "   ${GREEN}✅ server/index.js found${NC}"
else
    echo -e "   ${RED}❌ server/index.js missing${NC}"
    exit 1
fi

# Test 2: Check if dependencies installed
echo ""
echo "2️⃣  Checking dependencies..."
if [ -d "server/node_modules" ]; then
    echo -e "   ${GREEN}✅ node_modules found${NC}"
    PKG_COUNT=$(ls server/node_modules | wc -l | tr -d ' ')
    echo -e "   📦 $PKG_COUNT packages installed"
else
    echo -e "   ${RED}❌ node_modules missing - run: cd server && npm install${NC}"
    exit 1
fi

# Test 3: Check iOS files
echo ""
echo "3️⃣  Checking iOS files..."
IOS_FILES=(
    "ios/Models.swift"
    "ios/Config.swift"
    "ios/NightPlanRecommender.swift"
    "ios/HealthKitManager.swift"
)

for file in "${IOS_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "   ${GREEN}✅${NC} $file"
    else
        echo -e "   ${RED}❌${NC} $file missing"
    fi
done

# Test 4: Check Spec Kit
echo ""
echo "4️⃣  Checking Spec Kit..."
if [ -f ".specify/memory/constitution.md" ]; then
    echo -e "   ${GREEN}✅ Constitution exists${NC}"
    SIZE=$(wc -c < .specify/memory/constitution.md | tr -d ' ')
    echo -e "   📄 $SIZE bytes"
else
    echo -e "   ${YELLOW}⚠️  Constitution not yet created${NC}"
fi

# Test 5: Check review kits
echo ""
echo "5️⃣  Checking Review Kits..."
if [ -d "review/DoseTrack_Consolidated_Review_Kit_v1.1.1c" ]; then
    echo -e "   ${GREEN}✅ Consolidated Review Kit found${NC}"
else
    echo -e "   ${YELLOW}⚠️  Consolidated Review Kit not found${NC}"
fi

# Test 6: Check documentation
echo ""
echo "6️⃣  Checking documentation..."
DOCS=(
    "ACTION_CHECKLIST.md"
    "FINAL_REVIEW_SUMMARY.md"
    "CONSOLIDATED_REVIEW_INTEGRATION.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        SIZE=$(wc -l < "$doc" | tr -d ' ')
        echo -e "   ${GREEN}✅${NC} $doc ($SIZE lines)"
    else
        echo -e "   ${YELLOW}⚠️${NC}  $doc not found"
    fi
done

echo ""
echo "================================"
echo "✅ Basic validation complete!"
echo ""
echo "📋 To start the server:"
echo "   cd server && npm start"
echo ""
echo "📋 To test the server (in another terminal):"
echo "   curl http://localhost:3000/health"
echo ""
echo "📋 To check if server is running:"
echo "   lsof -i :3000"
echo ""
