-- ---------------------------------------------------------------------------
-- Phase 11b.3a — restrictions and confidential communications (45 CFR 164.522).
-- Plan §19.4.
--
-- One row per patient (absent row = no restriction: every channel allowed, the
-- contact data in Person is used). A patient can:
--   * refuse a channel ("AllowEmail" / "AllowSms" = FALSE) — the notification
--     worker then skips that row with reason 'PatientPreference';
--   * ask to be reached somewhere else ("AlternativeEmail" / "AlternativePhone")
--     — the worker uses it INSTEAD of Person.Email / Person.Phone.
-- The alternative contact is PHI-adjacent, so it is excluded from the row audit
-- trigger payload (the audit still records that the row changed).
-- ---------------------------------------------------------------------------

CREATE TABLE "PatientCommunicationPreference" (
    "PatientCommunicationPreferenceId" SERIAL PRIMARY KEY,
    "PatientId"        INTEGER      NOT NULL UNIQUE REFERENCES "Patient" ("PatientId"),
    "AllowEmail"       BOOLEAN      NOT NULL DEFAULT TRUE,
    "AllowSms"         BOOLEAN      NOT NULL DEFAULT TRUE,
    "AlternativeEmail" VARCHAR(254),
    "AlternativePhone" VARCHAR(20),
    "UpdatedAt"        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_comm_pref_email CHECK (
        "AlternativeEmail" IS NULL
        OR ("AlternativeEmail" = btrim("AlternativeEmail") AND "AlternativeEmail" ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
    CONSTRAINT ck_comm_pref_phone CHECK (
        "AlternativePhone" IS NULL OR "AlternativePhone" ~ '^\+?[0-9 ]{6,19}$')
);

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PatientCommunicationPreference"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change('AlternativeEmail', 'AlternativePhone');
