# ADR 002 - Use App Groups for widget writes
Status: Accepted

Context
The widget needs to log events when the app may not be in the foreground. Direct store access from the widget is not reliable.

Decision
Use App Groups with a small PendingAction JSON written by App Intents. The main app consumes and applies the action on activation.

Consequences
- Reliable background handoff.
- Simple data contract.
- Requires enabling the same App Group on app and widget targets.
