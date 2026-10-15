-- ---------------------------------------------------------------------------
-- Phase 5.1 (expand) — soft references by code to the future shared catalog.
--
-- Adds a nullable "...Code" UUID column (NO foreign key: the catalog will live
-- in another database) next to every integer FK that points into a catalog
-- table, backfills it from the local catalog tables (their codes are identical
-- to the catalog DB's by construction, see Phase 4.3) and indexes it.
--
-- Purely additive: the integer columns and local catalog tables stay
-- authoritative, nothing reads the new columns yet (Phase 6). Columns stay
-- nullable during the transition (an older API build keeps inserting only the
-- integer ids); a later contract step can make them NOT NULL.
-- ---------------------------------------------------------------------------

ALTER TABLE "Person"             ADD COLUMN "SexCode"                UUID;
ALTER TABLE "PersonDocument"     ADD COLUMN "DocumentTypeCode"       UUID;
ALTER TABLE "User"               ADD COLUMN "SpecialtyCode"          UUID;
ALTER TABLE "PatientAllergy"     ADD COLUMN "AllergyCode"            UUID;
ALTER TABLE "PatientAllergy"     ADD COLUMN "SeverityCode"           UUID;
ALTER TABLE "PrescriptionDetail" ADD COLUMN "MedicationCode"         UUID;
ALTER TABLE "PrescriptionDetail" ADD COLUMN "AdministrationRouteCode" UUID;
ALTER TABLE "PrescriptionDetail" ADD COLUMN "FrequencyCode"          UUID;
ALTER TABLE "AppointmentPayment" ADD COLUMN "InsuranceCode"          UUID;

-- The backfill is a schema change, not a user action: keep it out of the
-- row-level audit log (it would otherwise add one actor-less row per record).
ALTER TABLE "Person"             DISABLE TRIGGER trg_audit;
ALTER TABLE "PersonDocument"     DISABLE TRIGGER trg_audit;
ALTER TABLE "User"               DISABLE TRIGGER trg_audit;
ALTER TABLE "PatientAllergy"     DISABLE TRIGGER trg_audit;
ALTER TABLE "PrescriptionDetail" DISABLE TRIGGER trg_audit;
ALTER TABLE "AppointmentPayment" DISABLE TRIGGER trg_audit;

UPDATE "Person" t SET "SexCode" = c."SexCode"
  FROM "Sex" c WHERE c."SexId" = t."SexId";

UPDATE "PersonDocument" t SET "DocumentTypeCode" = c."DocumentTypeCode"
  FROM "DocumentType" c WHERE c."DocumentTypeId" = t."DocumentTypeId";

UPDATE "User" t SET "SpecialtyCode" = c."SpecialtyCode"
  FROM "Specialty" c WHERE c."SpecialtyId" = t."SpecialtyId";

UPDATE "PatientAllergy" t SET "AllergyCode" = c."AllergyCode"
  FROM "Allergy" c WHERE c."AllergyId" = t."AllergyId";

UPDATE "PatientAllergy" t SET "SeverityCode" = c."SeverityCode"
  FROM "AllergySeverity" c WHERE c."SeverityId" = t."SeverityId";

UPDATE "PrescriptionDetail" t SET
    "MedicationCode"          = m."MedicationCode",
    "AdministrationRouteCode" = r."AdministrationRouteCode",
    "FrequencyCode"           = f."FrequencyCode"
  FROM "Medication" m, "AdministrationRoute" r, "Frequency" f
  WHERE m."MedicationId" = t."MedicationId"
    AND r."AdministrationRouteId" = t."AdministrationRouteId"
    AND f."FrequencyId" = t."FrequencyId";

UPDATE "AppointmentPayment" t SET "InsuranceCode" = c."InsuranceCode"
  FROM "Insurance" c WHERE c."InsuranceId" = t."InsuranceId";

ALTER TABLE "Person"             ENABLE TRIGGER trg_audit;
ALTER TABLE "PersonDocument"     ENABLE TRIGGER trg_audit;
ALTER TABLE "User"               ENABLE TRIGGER trg_audit;
ALTER TABLE "PatientAllergy"     ENABLE TRIGGER trg_audit;
ALTER TABLE "PrescriptionDetail" ENABLE TRIGGER trg_audit;
ALTER TABLE "AppointmentPayment" ENABLE TRIGGER trg_audit;

-- Mirror the indexes that exist on the integer columns.
CREATE INDEX idx_person_sex_code                      ON "Person" ("SexCode");
CREATE INDEX idx_person_document_document_type_code   ON "PersonDocument" ("DocumentTypeCode");
CREATE INDEX idx_user_specialty_code                  ON "User" ("SpecialtyCode");
CREATE INDEX idx_patient_allergy_allergy_code         ON "PatientAllergy" ("AllergyCode");
CREATE INDEX idx_patient_allergy_severity_code        ON "PatientAllergy" ("SeverityCode");
CREATE INDEX idx_prescription_detail_medication_code  ON "PrescriptionDetail" ("MedicationCode");
CREATE INDEX idx_prescription_detail_admin_route_code ON "PrescriptionDetail" ("AdministrationRouteCode");
CREATE INDEX idx_prescription_detail_frequency_code   ON "PrescriptionDetail" ("FrequencyCode");
CREATE INDEX idx_appointment_payment_insurance_code   ON "AppointmentPayment" ("InsuranceCode");
