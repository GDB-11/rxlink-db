-- ---------------------------------------------------------------------------
-- Phase 5.4 (expand) — PartnerMedication and ClinicStock.
--
-- Plan §6.5, D8, D25, D27. Keyed by the catalog MedicationCode (no FK: the
-- catalog lives in another database).
--
--   PartnerMedication : whether this partner lets doctors prescribe a catalog
--                       medication. Opt-in (D27): NO ROW = NOT ENABLED, so the
--                       backfill below must cover every medication in use.
--   ClinicStock       : per-clinic cached balance (the ledger arrives in
--                       Phase 10) and optional low-stock threshold.
--
-- Purely additive: Medication.IsActive stays authoritative until Phase 6/9.
-- ---------------------------------------------------------------------------

CREATE TABLE "PartnerMedication" (
    "MedicationCode" UUID        PRIMARY KEY,
    "IsEnabled"      BOOLEAN     NOT NULL DEFAULT FALSE,
    "UpdatedAt"      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedBy"      INTEGER     REFERENCES "User" ("UserId")
);

CREATE TABLE "ClinicStock" (
    "ClinicId"       INTEGER       NOT NULL REFERENCES "Clinic" ("ClinicId"),
    "MedicationCode" UUID          NOT NULL,
    "StockQuantity"  NUMERIC(12,3) NOT NULL DEFAULT 0 CHECK ("StockQuantity" >= 0),
    "ReorderLevel"   NUMERIC(12,3) CHECK ("ReorderLevel" >= 0),
    "UpdatedAt"      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    "UpdatedBy"      INTEGER       REFERENCES "User" ("UserId"),
    PRIMARY KEY ("ClinicId", "MedicationCode")
);

-- Backfill: EVERY local medication gets a row (so the orphan check is
-- complete); it is enabled iff it is currently prescribable (active, not
-- soft-deleted). Inactive/deleted ones are kept as disabled rows.
INSERT INTO "PartnerMedication" ("MedicationCode", "IsEnabled")
SELECT "MedicationCode", "IsActive" AND "DeletedAt" IS NULL
  FROM "Medication";

-- No stock concept exists today (no column or table), so seed the default
-- clinic at zero for each enabled medication; Phase 10 populates the real
-- balances through ledger entries. Zero means "not counted yet", not "out of
-- stock" — nothing reads ClinicStock before Phase 10.
INSERT INTO "ClinicStock" ("ClinicId", "MedicationCode")
SELECT c."ClinicId", pm."MedicationCode"
  FROM "Clinic" c
 CROSS JOIN "PartnerMedication" pm
 WHERE c."IsDefault" AND pm."IsEnabled";

-- Attached after the backfill so the schema change doesn't write actor-less
-- AuditLog rows. ClinicStock has a composite key: audit_row_change() logs
-- RecordKey = MedicationCode only; ClinicId is always present in
-- OldValues/NewValues, which is enough to tell clinics apart.
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PartnerMedication"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "ClinicStock"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
