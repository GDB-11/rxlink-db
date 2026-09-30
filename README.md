# rxlink-db

PostgreSQL migrations for the RxLink partner database (`V001`…).

## Data rules

- **No branch-from-production for partner DBs.** Never create a dev, test, staging or demo database by branching, cloning or restoring a dump of a production database (this includes Neon branches of production). Non-production databases are built from migrations only, with synthetic seed data.
- **Seed migrations (V014–V016) are synthetic only** — generated names, non-existent e-mail domains, random document numbers, and a shared seeded password hash. Do not apply them to a production database, and never put real patient data in any migration file or commit.
- Seed data added in future migrations must follow the same rule.
