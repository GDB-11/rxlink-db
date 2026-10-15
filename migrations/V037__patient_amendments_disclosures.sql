-- ---------------------------------------------------------------------------
-- Phase 11b.2 — amendment requests (45 CFR 164.526) and accounting of
-- disclosures (45 CFR 164.528). Plan §19.4.
--
-- Amendments: the patient asks for a correction; a clinician accepts or denies it
-- with a reason. The clinical record is NEVER overwritten: an accepted request only
-- stores the clinician's "AmendmentText", which is shown next to the original data.
-- A decided request is immutable (trigger), and so is the patient's own wording.
--
-- Disclosures: one row per disclosure outside treatment/payment/operations. The row
-- says WHO received information, WHY and WHAT KIND — never a copy of the clinical
-- content. Append-only: a mistake is not edited, it is documented by a new row.
-- ---------------------------------------------------------------------------

CREATE TABLE "PatientAmendmentRequest" (
    "AmendmentRequestId"   BIGSERIAL    PRIMARY KEY,
    "AmendmentRequestCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "PatientId"            INTEGER      NOT NULL REFERENCES "Patient" ("PatientId"),
    "TargetArea"           VARCHAR(20)  NOT NULL,
    "RequestedChange"      TEXT         NOT NULL,
    "Status"               VARCHAR(10)  NOT NULL DEFAULT 'Pendiente',
    "RequestedAt"          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "ReviewedBy"           INTEGER               REFERENCES "User" ("UserId"),
    "ReviewedAt"           TIMESTAMPTZ,
    "DecisionReason"       TEXT,
    "AmendmentText"        TEXT,
    CONSTRAINT ck_amendment_area   CHECK ("TargetArea" IN
        ('Profile', 'Allergies', 'Diagnostics', 'Prescriptions', 'Appointments', 'Other')),
    CONSTRAINT ck_amendment_status CHECK ("Status" IN ('Pendiente', 'Aceptada', 'Denegada')),
    CONSTRAINT ck_amendment_change CHECK (char_length(btrim("RequestedChange")) BETWEEN 10 AND 2000),
    CONSTRAINT ck_amendment_review CHECK (
        ("Status" = 'Pendiente'
            AND "ReviewedBy" IS NULL AND "ReviewedAt" IS NULL
            AND "DecisionReason" IS NULL AND "AmendmentText" IS NULL)
        OR ("Status" = 'Aceptada'
            AND "ReviewedBy" IS NOT NULL AND "ReviewedAt" IS NOT NULL
            AND "DecisionReason" IS NOT NULL AND "AmendmentText" IS NOT NULL)
        OR ("Status" = 'Denegada'
            AND "ReviewedBy" IS NOT NULL AND "ReviewedAt" IS NOT NULL
            AND "DecisionReason" IS NOT NULL AND "AmendmentText" IS NULL))
);

CREATE INDEX idx_amendment_patient ON "PatientAmendmentRequest" ("PatientId", "RequestedAt" DESC);
CREATE INDEX idx_amendment_pending ON "PatientAmendmentRequest" ("RequestedAt") WHERE "Status" = 'Pendiente';

CREATE OR REPLACE FUNCTION amendment_request_guard() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'PatientAmendmentRequest is append-only (DELETE not allowed)';
    END IF;
    IF OLD."Status" <> 'Pendiente' THEN
        RAISE EXCEPTION 'A decided amendment request cannot be changed';
    END IF;
    IF NEW."PatientId" <> OLD."PatientId"
       OR NEW."TargetArea" <> OLD."TargetArea"
       OR NEW."RequestedChange" <> OLD."RequestedChange"
       OR NEW."RequestedAt" <> OLD."RequestedAt" THEN
        RAISE EXCEPTION 'The patient''s request cannot be rewritten';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_amendment_guard
    BEFORE UPDATE OR DELETE ON "PatientAmendmentRequest"
    FOR EACH ROW EXECUTE FUNCTION amendment_request_guard();

-- ---------------------------------------------------------------------------

CREATE TABLE "PatientDisclosure" (
    "DisclosureId"   BIGSERIAL    PRIMARY KEY,
    "DisclosureCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "PatientId"      INTEGER      NOT NULL REFERENCES "Patient" ("PatientId"),
    "DisclosedAt"    TIMESTAMPTZ  NOT NULL,
    "RecipientName"  VARCHAR(200) NOT NULL,
    "RecipientType"  VARCHAR(20)  NOT NULL,
    "Purpose"        VARCHAR(300) NOT NULL,
    "Description"    VARCHAR(500) NOT NULL,
    "RecordedBy"     INTEGER      NOT NULL REFERENCES "User" ("UserId"),
    "RecordedAt"     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_disclosure_recipient_type CHECK ("RecipientType" IN
        ('Authority', 'Court', 'PublicHealth', 'Insurer', 'Family', 'Researcher', 'Other')),
    CONSTRAINT ck_disclosure_text CHECK (
        char_length(btrim("RecipientName")) > 0
        AND char_length(btrim("Purpose")) > 0
        AND char_length(btrim("Description")) > 0)
);

CREATE INDEX idx_disclosure_patient ON "PatientDisclosure" ("PatientId", "DisclosedAt" DESC);

CREATE OR REPLACE FUNCTION patient_disclosure_immutable() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'PatientDisclosure is append-only (% not allowed)', TG_OP;
END;
$$;

CREATE TRIGGER trg_disclosure_immutable
    BEFORE UPDATE OR DELETE ON "PatientDisclosure"
    FOR EACH ROW EXECUTE FUNCTION patient_disclosure_immutable();

-- Row-level audit (V019): who recorded or decided what.
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PatientAmendmentRequest"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PatientDisclosure"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
