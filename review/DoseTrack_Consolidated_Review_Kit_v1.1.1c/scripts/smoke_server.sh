#!/usr/bin/env bash
set -euo pipefail
API="${API_KEY:-test-api-key-local-dev-only}"
BASE="${BASE_URL:-http://localhost:3000}"

echo "Health:"
curl -s "${BASE}/health" | jq . || curl -s "${BASE}/health"

echo
echo "Aggregates without key (expect 401):"
curl -s -o /dev/null -w "%{http_code}\n" "${BASE}/api/aggregates/7days" || true

echo
echo "Aggregates with key:"
curl -s -H "x-api-key: ${API}" "${BASE}/api/aggregates/7days" | jq . || true

echo
echo "Done."
