-- ===========================================================================
-- V008: Diagnostic FK — PatientId → AppointmentId
-- ===========================================================================

DROP INDEX idx_diagnostic_patient_id;

ALTER TABLE "Diagnostic"
    DROP COLUMN "PatientId";

ALTER TABLE "Diagnostic"
    ADD COLUMN "AppointmentId" INTEGER NOT NULL REFERENCES "Appointment" ("AppointmentId");

CREATE INDEX idx_diagnostic_appointment_id ON "Diagnostic" ("AppointmentId");

-- 1 cita → máximo 1 diagnóstico activo (mismo patrón que uq_prescription_diagnostic)
CREATE UNIQUE INDEX uq_diagnostic_appointment
    ON "Diagnostic" ("AppointmentId")
    WHERE "DeletedAt" IS NULL;
