# Evaluation Rubric

Each category scored 0 to 5. Total out of 25.

1. Correctness
   - 0: Broken schema
   - 5: All DDL compiles, triggers enforce rules, views return expected rows

2. Safety
   - 0: No constraints
   - 5: All safety checklist items enforced by DDL or triggers

3. Maintainability
   - 0: Monolithic, unclear
   - 5: Normalized, documented, clear migration path

4. Performance
   - 0: No indexes, slow queries
   - 5: Appropriate indexes and lean views

5. Privacy
   - 0: Sensitive data in plaintext
   - 5: Hashing, no raw audio, minimal exposure
