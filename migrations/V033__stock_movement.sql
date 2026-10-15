-- ---------------------------------------------------------------------------
-- Phase 10.1 — StockMovement ledger.
--
-- Plan §11.1, D14, D25. The ledger is the source of truth; ClinicStock
-- ."StockQuantity" is a cache updated in the same transaction as every
-- movement (the API does that, and locks the ClinicStock row FOR UPDATE).
--
-- Deviation from the §11.1 sketch: "Quantity" stays a positive number but a
-- "Direction" column (+1 / -1) is stored, because an Adjustment can go either
-- way and "sign derived from type" cannot express that. The CHECKs pin the
-- direction of every other type, so Direction is never a free choice there.
--
-- Append-only, like ActivityEvent: UPDATE/DELETE are revoked and blocked by a
-- trigger. Corrections are new movements (Adjustment).
-- ---------------------------------------------------------------------------

CREATE TABLE "StockMovement" (
    "StockMovementId"      BIGSERIAL     PRIMARY KEY,
    "StockMovementCode"    UUID          NOT NULL DEFAULT uuidv7() UNIQUE,
    "ClinicId"             INTEGER       NOT NULL REFERENCES "Clinic" ("ClinicId"),
    "MedicationCode"       UUID          NOT NULL,   -- catalog code, no FK (other database)
    "MovementType"         VARCHAR(20)   NOT NULL,
    "Direction"            SMALLINT      NOT NULL,
    "Quantity"             NUMERIC(12,3) NOT NULL CHECK ("Quantity" > 0),
    "BatchNumber"          VARCHAR(50),
    "ExpiresOn"            DATE,
    "PrescriptionDetailId" INTEGER       REFERENCES "PrescriptionDetail" ("PrescriptionDetailId"),
    "Reason"               TEXT,
    "UserId"               INTEGER       REFERENCES "User" ("UserId"),
    "OccurredAt"           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_stock_movement_type
        CHECK ("MovementType" IN ('Entry', 'Dispense', 'Adjustment', 'Loss', 'Return')),
    CONSTRAINT ck_stock_movement_direction
        CHECK ("Direction" IN (1, -1)),
    CONSTRAINT ck_stock_movement_direction_by_type
        CHECK (("MovementType" IN ('Entry', 'Return')   AND "Direction" =  1)
            OR ("MovementType" IN ('Dispense', 'Loss')  AND "Direction" = -1)
            OR  "MovementType" = 'Adjustment'),
    CONSTRAINT ck_stock_movement_reason
        CHECK ("MovementType" NOT IN ('Adjustment', 'Loss')
               OR length(btrim(COALESCE("Reason", ''))) > 0),
    CONSTRAINT ck_stock_movement_dispense_detail
        CHECK (("MovementType" = 'Dispense') = ("PrescriptionDetailId" IS NOT NULL))
);

CREATE INDEX idx_stock_movement_med_time    ON "StockMovement" ("ClinicId", "MedicationCode", "OccurredAt" DESC);
CREATE INDEX idx_stock_movement_detail      ON "StockMovement" ("PrescriptionDetailId")
    WHERE "PrescriptionDetailId" IS NOT NULL;
CREATE INDEX idx_stock_movement_user_time   ON "StockMovement" ("UserId", "OccurredAt");

REVOKE UPDATE, DELETE, TRUNCATE ON "StockMovement" FROM PUBLIC;

CREATE OR REPLACE FUNCTION stock_movement_immutable() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'StockMovement is append-only (% not allowed)', TG_OP;
END;
$$;

CREATE TRIGGER trg_stock_movement_immutable
    BEFORE UPDATE OR DELETE ON "StockMovement"
    FOR EACH ROW EXECUTE FUNCTION stock_movement_immutable();

-- No audit_row_change trigger: the table is itself an append-only record with
-- UserId/OccurredAt, and the AuditLog copy would only duplicate it.
