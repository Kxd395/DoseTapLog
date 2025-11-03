# Server Checklist

- Node 18+
- npm ci
- npm test
- Start: PORT=3000 npm start
- curl http://localhost:3000/health
- curl -H 'API-KEY: test-api-key' http://localhost:3000/api/sleep/latest
- Validate 401 without API-KEY and 429 on rate limit
