-- =============================================================================
-- V022: UserMfa - TOTP second factor for staff accounts (Phase 2b.1)
-- One row per user. A row with ConfirmedAt NULL is a pending enrollment and does
-- not affect login. SecretEncrypted is ChaCha-encrypted by the API.
-- LastUsedStep is the last accepted 30s TOTP step (replay protection).
-- =============================================================================

CREATE TABLE "UserMfa" (
    "UserMfaId"       SERIAL      PRIMARY KEY,
    "UserId"          INTEGER     NOT NULL UNIQUE REFERENCES "User" ("UserId"),
    "SecretEncrypted" TEXT        NOT NULL,
    "ConfirmedAt"     TIMESTAMPTZ,
    "LastUsedStep"    BIGINT,
    "CreatedAt"       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit row changes but never log the secret; LastUsedStep churns on every login.
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "UserMfa"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change('SecretEncrypted', 'LastUsedStep');
