-- ---------------------------------------------------------------------------
-- Phase 11b.3b — Notice of Privacy Practices (45 CFR 164.520) and consent /
-- authorization records for uses beyond treatment, payment and operations
-- (45 CFR 164.508). Plan §19.4.
--
-- PrivacyNotice: one row per published version of the partner's NPP. Versions are
-- immutable; a correction is a new version. The CURRENT notice is the one with the
-- highest Version whose EffectiveFrom is not in the future.
--
-- PatientPrivacyNoticeAck: the patient's acknowledgment of ONE version (date, version,
-- who captured it). RecordedBy NULL = the patient acknowledged it themselves (app).
-- Append-only, one per patient and version.
--
-- PatientConsent: one row per authorization granted. Never edited and never deleted;
-- the only allowed change is the revocation (RevokedAt/RevokedBy/RevokedReason),
-- once. RevokedBy NULL = the patient revoked it themselves. A new authorization after revoking is a new row.
-- ---------------------------------------------------------------------------

CREATE TABLE "PrivacyNotice" (
    "PrivacyNoticeId"   SERIAL       PRIMARY KEY,
    "PrivacyNoticeCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Version"           INTEGER      NOT NULL UNIQUE,
    "Title"             VARCHAR(200) NOT NULL,
    "Body"              TEXT         NOT NULL,
    "EffectiveFrom"     DATE         NOT NULL,
    "PublishedBy"       INTEGER      NOT NULL REFERENCES "User" ("UserId"),
    "PublishedAt"       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_privacy_notice_text CHECK (
        char_length(btrim("Title")) > 0 AND char_length(btrim("Body")) BETWEEN 20 AND 50000)
);

CREATE TABLE "PatientPrivacyNoticeAck" (
    "PatientPrivacyNoticeAckId" BIGSERIAL   PRIMARY KEY,
    "PatientId"                 INTEGER     NOT NULL REFERENCES "Patient" ("PatientId"),
    "PrivacyNoticeId"           INTEGER     NOT NULL REFERENCES "PrivacyNotice" ("PrivacyNoticeId"),
    "AcknowledgedAt"            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "RecordedBy"                INTEGER              REFERENCES "User" ("UserId"),
    CONSTRAINT uq_privacy_ack UNIQUE ("PatientId", "PrivacyNoticeId")
);

CREATE TABLE "PatientConsent" (
    "PatientConsentId"   BIGSERIAL    PRIMARY KEY,
    "PatientConsentCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "PatientId"          INTEGER      NOT NULL REFERENCES "Patient" ("PatientId"),
    "ConsentType"        VARCHAR(20)  NOT NULL,
    "Description"        VARCHAR(500) NOT NULL,
    "GrantedAt"          TIMESTAMPTZ  NOT NULL,
    "RecordedBy"         INTEGER      NOT NULL REFERENCES "User" ("UserId"),
    "RecordedAt"         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "RevokedAt"          TIMESTAMPTZ,
    "RevokedBy"          INTEGER               REFERENCES "User" ("UserId"),
    "RevokedReason"      VARCHAR(500),
    CONSTRAINT ck_consent_type CHECK ("ConsentType" IN
        ('Research', 'Marketing', 'ThirdPartySharing', 'Other')),
    CONSTRAINT ck_consent_description CHECK (char_length(btrim("Description")) > 0),
    CONSTRAINT ck_consent_revocation CHECK (
        ("RevokedAt" IS NULL AND "RevokedBy" IS NULL AND "RevokedReason" IS NULL)
        OR ("RevokedAt" IS NOT NULL AND char_length(btrim("RevokedReason")) > 0))
);

CREATE INDEX idx_consent_patient ON "PatientConsent" ("PatientId", "GrantedAt" DESC);
CREATE INDEX idx_privacy_ack_patient ON "PatientPrivacyNoticeAck" ("PatientId");

CREATE OR REPLACE FUNCTION privacy_append_only() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION '% is append-only (% not allowed)', TG_TABLE_NAME, TG_OP;
END;
$$;

CREATE TRIGGER trg_privacy_notice_immutable
    BEFORE UPDATE OR DELETE ON "PrivacyNotice"
    FOR EACH ROW EXECUTE FUNCTION privacy_append_only();
CREATE TRIGGER trg_privacy_ack_immutable
    BEFORE UPDATE OR DELETE ON "PatientPrivacyNoticeAck"
    FOR EACH ROW EXECUTE FUNCTION privacy_append_only();

CREATE OR REPLACE FUNCTION patient_consent_guard() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'PatientConsent is append-only (DELETE not allowed)';
    END IF;
    IF OLD."RevokedAt" IS NOT NULL THEN
        RAISE EXCEPTION 'A revoked consent cannot be changed';
    END IF;
    IF NEW."RevokedAt" IS NULL
       OR NEW."PatientId" <> OLD."PatientId"
       OR NEW."ConsentType" <> OLD."ConsentType"
       OR NEW."Description" <> OLD."Description"
       OR NEW."GrantedAt" <> OLD."GrantedAt"
       OR NEW."RecordedBy" <> OLD."RecordedBy"
       OR NEW."RecordedAt" <> OLD."RecordedAt" THEN
        RAISE EXCEPTION 'The only allowed change to a consent is its revocation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_consent_guard
    BEFORE UPDATE OR DELETE ON "PatientConsent"
    FOR EACH ROW EXECUTE FUNCTION patient_consent_guard();

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PrivacyNotice"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PatientPrivacyNoticeAck"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PatientConsent"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
