# DoseTrack v1.1.1c Drop In

Purpose: a ready to use skeleton aligned to Implementation Plan v1.1.1c

Quickstart
1. iOS
   - Open Xcode 15.4 or newer
   - Add ios files to the target
   - Enable HealthKit capability and App Group group.com.jefferson.dosetrack
2. WHOOP proxy
   - cd server && cp .env.example .env && npm install && npm start
   - curl http://localhost:3000/health
