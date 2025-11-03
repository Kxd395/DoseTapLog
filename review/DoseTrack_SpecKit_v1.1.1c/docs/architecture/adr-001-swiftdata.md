# ADR 001 - Choose SwiftData for persistence
Status: Accepted

Context
SwiftData provides native Swift models with @Model and a lighter API surface compared to Core Data. DoseTrack needs a typed model, uniqueness on nightKey, and simple queries. The data size is small and local only.

Decision
Use SwiftData with @Model for DoseLog and a ModelContainer created at app start.

Consequences
- Faster development with less boilerplate.
- Migration steps must be documented for future schema changes.
- No external database, which aligns with the pilot's local first goal.
