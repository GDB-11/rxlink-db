-- Intentional differences between the old chain (V001-V013, V017-V041) and the squashed baseline.
BEGIN;
-- rows derived from the legacy catalog tables move to demo seed S004
DELETE FROM "PartnerSpecialty";
DELETE FROM "PartnerInsurance";
DELETE FROM "PartnerMedication";
DELETE FROM "ClinicStock";

DROP TABLE "Medication", "PharmaceuticalForm", "AdministrationRoute", "Frequency",
           "Allergy", "AllergySeverity", "Insurance", "Specialty", "Sex", "DocumentType" CASCADE;

ALTER TABLE "Person"             DROP COLUMN "SexId";
ALTER TABLE "PersonDocument"     DROP COLUMN "DocumentTypeId";
ALTER TABLE "User"               DROP COLUMN "SpecialtyId";
ALTER TABLE "PatientAllergy"     DROP COLUMN "AllergyId", DROP COLUMN "SeverityId";
ALTER TABLE "PrescriptionDetail" DROP COLUMN "MedicationId", DROP COLUMN "AdministrationRouteId", DROP COLUMN "FrequencyId";
ALTER TABLE "AppointmentPayment" DROP COLUMN "InsuranceId";

ALTER TABLE "Person"         ALTER COLUMN "SexCode" SET NOT NULL;
ALTER TABLE "PersonDocument" ALTER COLUMN "DocumentTypeCode" SET NOT NULL;
ALTER TABLE "PatientAllergy" ALTER COLUMN "AllergyCode" SET NOT NULL;
ALTER TABLE "PatientAllergy" ADD CONSTRAINT uq_patient_allergy UNIQUE ("PatientId", "AllergyCode");
ALTER TABLE "PrescriptionDetail"
    ALTER COLUMN "MedicationCode" SET NOT NULL,
    ALTER COLUMN "AdministrationRouteCode" SET NOT NULL,
    ALTER COLUMN "FrequencyCode" SET NOT NULL,
    ALTER COLUMN "MedicationGenericName" SET NOT NULL,
    ALTER COLUMN "MedicationConcentration" SET NOT NULL,
    ALTER COLUMN "PharmaceuticalFormName" SET NOT NULL,
    ALTER COLUMN "AdministrationRouteName" SET NOT NULL,
    ALTER COLUMN "FrequencyDescription" SET NOT NULL,
    ALTER COLUMN "FrequencyIntervalHours" SET NOT NULL;
ALTER TABLE "PrescriptionDetail" DROP CONSTRAINT "PrescriptionDetail_FrequencyIntervalHours_check";
ALTER TABLE "PrescriptionDetail" ADD CONSTRAINT "PrescriptionDetail_FrequencyIntervalHours_check" CHECK ("FrequencyIntervalHours" > 0);
ALTER TABLE "AppointmentPayment" ADD CONSTRAINT "AppointmentPayment_InsuranceName_check"
    CHECK ("InsuranceCode" IS NULL OR "InsuranceName" IS NOT NULL);
COMMIT;
