-- =============================================================================
-- V023: Patient access policy (Phase 2b.2)
--
-- 1. "Role"."CanViewClinicalData": field-level permission. Roles without it
--    (Administrador by default) only see administrative patient data; the API
--    hides allergies, diagnostics and prescription detail from them.
-- 2. "BreakGlassGrant": a nurse reaching a patient outside their care team must
--    state a reason; the grant opens that patient to that user until ExpiresAt.
--    Every grant is also emitted as a 'Record.BreakGlassAccess' ActivityEvent
--    by the API and surfaced to the administrator in a report.
-- =============================================================================

ALTER TABLE "Role" ADD COLUMN "CanViewClinicalData" BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE "Role" SET "CanViewClinicalData" = TRUE WHERE "Name" IN ('Doctor', 'Enfermero');

CREATE TABLE "BreakGlassGrant" (
    "BreakGlassGrantId"   SERIAL      PRIMARY KEY,
    "BreakGlassGrantCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "UserId"              INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "PatientId"           INTEGER     NOT NULL REFERENCES "Patient" ("PatientId"),
    "Reason"              TEXT        NOT NULL,
    "GrantedAt"           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "ExpiresAt"           TIMESTAMPTZ NOT NULL,
    "IpAddress"           INET,

    CONSTRAINT chk_break_glass_reason  CHECK (char_length(btrim("Reason")) >= 10),
    CONSTRAINT chk_break_glass_expires CHECK ("ExpiresAt" > "GrantedAt")
);

-- Hot path: "does this user hold a live grant for this patient?"
CREATE INDEX idx_break_glass_user_patient ON "BreakGlassGrant" ("UserId", "PatientId", "ExpiresAt");
-- Administrator report, newest first.
CREATE INDEX idx_break_glass_granted_at   ON "BreakGlassGrant" ("GrantedAt");

-- Grants are evidence: never edited or removed (expiry is by timestamp).
CREATE FUNCTION break_glass_grant_immutable() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'BreakGlassGrant rows are append-only';
END;
$$;

CREATE TRIGGER trg_break_glass_immutable BEFORE UPDATE OR DELETE ON "BreakGlassGrant"
    FOR EACH ROW EXECUTE FUNCTION break_glass_grant_immutable();

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "BreakGlassGrant"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();

-- Care-team lookups filter Prescription by patient and status.
CREATE INDEX IF NOT EXISTS idx_prescription_patient_status
    ON "Prescription" ("PatientId", "PrescriptionStatusId") WHERE "DeletedAt" IS NULL;
