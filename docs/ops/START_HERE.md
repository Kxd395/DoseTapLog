# START HERE – DoseTrack v1.1.1c

Welcome! Use this to orient yourself and jump into the right docs.

---

## 1. Read First
- `README.md` – canonical architecture, setup, and roadmap.
- `docs/SECRETS.md` – configuration and secrets handling.
- `docs/ops/ACTION_CHECKLIST.md` – prioritized engineering tasks.

---

## 2. Quick Verification
```bash
cd server
npm install
npm start        # requires populated .env (see docs/SECRETS.md)

curl http://localhost:3000/health
```

For a scripted smoke test run `scripts/quick-test.sh` after configuring secrets.

---

## 3. Immediate Next Steps
1. Resolve the night anchoring bug and add SwiftData coverage.
2. Introduce the SwiftUI view model and main-actor enforcement.
3. Modularize the WHOOP proxy and add configuration validation.

Update the SSOT (`README.md`) and checklist as you land changes.
