-- ---------------------------------------------------------------------------
-- Phase 5.2 (expand) — snapshots of catalog values on documents.
--
-- A prescription is a clinical/legal document: it must read the same forever,
-- even if the catalog entry is later corrected or deactivated. Store the
-- values as prescribed next to the codes added in V028. Likewise
-- AppointmentPayment keeps the insurer name beside its amount/coverage
-- snapshots. (Plan §6.2.)
--
-- Purely additive and nullable: an older API build keeps inserting rows
-- without snapshots until Phase 6 writes them (captured on write, refreshed
-- while the prescription is Borrador, frozen once signed). The backfill uses
-- the still-present local catalog tables.
-- ---------------------------------------------------------------------------

ALTER TABLE "PrescriptionDetail" ADD COLUMN "MedicationGenericName"    VARCHAR(200);
ALTER TABLE "PrescriptionDetail" ADD COLUMN "MedicationCommercialName" VARCHAR(200);
ALTER TABLE "PrescriptionDetail" ADD COLUMN "MedicationConcentration"  VARCHAR(50);
ALTER TABLE "PrescriptionDetail" ADD COLUMN "PharmaceuticalFormName"   VARCHAR(100);
ALTER TABLE "PrescriptionDetail" ADD COLUMN "AdministrationRouteName"  VARCHAR(100);
ALTER TABLE "PrescriptionDetail" ADD COLUMN "FrequencyDescription"     VARCHAR(200);
ALTER TABLE "PrescriptionDetail" ADD COLUMN "FrequencyIntervalHours"   INTEGER
    CHECK ("FrequencyIntervalHours" IS NULL OR "FrequencyIntervalHours" > 0);

ALTER TABLE "AppointmentPayment" ADD COLUMN "InsuranceName" VARCHAR(100);

-- Schema change, not a user action: keep the backfill out of the row-level
-- audit log (it would add one actor-less row per record).
ALTER TABLE "PrescriptionDetail" DISABLE TRIGGER trg_audit;
ALTER TABLE "AppointmentPayment" DISABLE TRIGGER trg_audit;

UPDATE "PrescriptionDetail" t SET
    "MedicationGenericName"    = m."GenericName",
    "MedicationCommercialName" = m."CommercialName",
    "MedicationConcentration"  = m."Concentration",
    "PharmaceuticalFormName"   = pf."Name",
    "AdministrationRouteName"  = r."Name",
    "FrequencyDescription"     = f."Description",
    "FrequencyIntervalHours"   = f."IntervalHours"
  FROM "Medication" m
  JOIN "PharmaceuticalForm" pf ON pf."PharmaceuticalFormId" = m."PharmaceuticalFormId",
       "AdministrationRoute" r,
       "Frequency" f
  WHERE m."MedicationId" = t."MedicationId"
    AND r."AdministrationRouteId" = t."AdministrationRouteId"
    AND f."FrequencyId" = t."FrequencyId";

UPDATE "AppointmentPayment" t SET "InsuranceName" = i."Name"
  FROM "Insurance" i WHERE i."InsuranceId" = t."InsuranceId";

ALTER TABLE "PrescriptionDetail" ENABLE TRIGGER trg_audit;
ALTER TABLE "AppointmentPayment" ENABLE TRIGGER trg_audit;
