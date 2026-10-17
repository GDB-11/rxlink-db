# rxlink-db

PostgreSQL migrations for the RxLink partner database.

## Migration stream

The stream was squashed (Phase 9.9, decision D32: no production, clean rebuild) into a new baseline.
The former `V001`–`V041` chain lives only in git history under the tag **`pre-squash-v041`**.

| File | Content |
| --- | --- |
| `V001__baseline_schema.sql` | Tables, constraints, indexes, functions, immutability triggers |
| `V002__baseline_reference_data.sql` | Roles, prescription/appointment/diagnostic statuses, consultation types, default clinic, `PartnerConfig` |
| `V003__baseline_navigation.sql` | Navigation modules, items and role access (final state) |
| `V004__baseline_audit_triggers.sql` | `trg_audit` attachments (last, so reference data is not logged) |

The partner DB holds **no catalog master data** (sex, document types, specialties, medications, allergies,
forms, routes, frequencies, insurances): it lives in the catalog DB and is referenced by `…Code` columns,
without foreign keys. `scripts/orphan-check.sh` verifies that every such code resolves in the catalog.
`scripts/squash-drops.sql` is the hand-written list of intentional differences between the old chain and the
baseline, used by the equivalence check of Phase 9.13.

## Data rules

- **No branch-from-production for partner DBs.** Never create a dev, test, staging or demo database by branching, cloning or restoring a dump of a production database. Non-production databases are built from migrations only, with synthetic seed data.
- **Demo data lives in `seeds/` (Phase 9.10), never in `migrations/`; load it with `scripts/apply-seeds.sh <db>`.** Seeds are synthetic only — generated names, non-existent e-mail domains, random document numbers, and a shared seeded password hash. Never apply them to a database with real patients, and never put real patient data in any file or commit.
