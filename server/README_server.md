WHOOP proxy server add-ons for DoseTrack

Summary
- Adds simple rate limiting and a 7 day aggregates endpoint for sleep
- Includes a pagination helper aligned to WHOOP collection APIs

Env
- API_KEY: required header value for clients
- WHOOP_BASE: default https://api.prod.whoop.com
- WHOOP_TOKEN: bearer token for development only

Run
- npm install express express-rate-limit node-fetch
- node index.additions.js integration is manual per README
