## DoseTrack WHOOP Proxy

Express-based bridge that shields WHOOP API credentials behind a minimal service for the DoseTrack iOS client.

### Features
- `/health` heartbeat plus `/api/sleep/latest` and `/api/aggregates/7days` endpoints.
- API key enforcement (`x-api-key` header) and rate limiting via `express-rate-limit`.
- Pagination helper that walks WHOOP sleep records using `nextToken`.

### Configuration
Copy `.env.example` to `.env` and populate the values (see `docs/SECRETS.md` for guidance):

| Variable | Purpose |
|----------|---------|
| `API_KEY` | Shared secret required on every client request |
| `WHOOP_TOKEN` | WHOOP developer bearer token used when proxying |
| `WHOOP_BASE` | Optional override for WHOOP API base URL |
| `PORT` | Local port (defaults to 3000) |
| `RATE_LIMIT_WINDOW_MS` | Rate limiter window in ms |
| `RATE_LIMIT_MAX` | Max requests per window |

### Development
```bash
cd server
npm install
cp .env.example .env   # set secrets before running
npm start
```

Run tests with:
```bash
npm test
```

> Planned improvements: convert to TypeScript, extract modular routes/services, add pagination guards, and introduce structured logging.
