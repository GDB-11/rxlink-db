-- ---------------------------------------------------------------------------
-- Phase 10.2 — dispensing below the balance (override).
--
-- Plan §11.3, D14. A nurse may dispense more than the clinic holds if they give
-- a reason. The ledger then takes the balance negative so the discrepancy is
-- visible until an Entry/Adjustment reconciles it, which is why the
-- "StockQuantity >= 0" check on the cache goes away.
--
-- "ShortfallQuantity" on a Dispense movement is the part of "Quantity" that was
-- not backed by stock; the override reason goes in "Reason".
-- ---------------------------------------------------------------------------

ALTER TABLE "ClinicStock" DROP CONSTRAINT "ClinicStock_StockQuantity_check";

ALTER TABLE "StockMovement"
    ADD COLUMN "ShortfallQuantity" NUMERIC(12,3),
    ADD CONSTRAINT ck_stock_movement_shortfall
        CHECK ("ShortfallQuantity" IS NULL
               OR ("MovementType" = 'Dispense'
                   AND "ShortfallQuantity" > 0
                   AND "ShortfallQuantity" <= "Quantity"
                   AND length(btrim(COALESCE("Reason", ''))) > 0));

CREATE INDEX idx_stock_movement_shortfall ON "StockMovement" ("OccurredAt")
    WHERE "ShortfallQuantity" IS NOT NULL;
