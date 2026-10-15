-- =============================================================================
-- V025: Account lockout + absolute session limit (Phase 2b.3)
--
-- UserLockout: consecutive failed credential attempts per staff user. Counts
--   password AND MFA-code failures; reset on a completed login. Deliberately a
--   separate table (not User columns) so the churn is not audited row by row;
--   lockouts are reported through ActivityEvent (Auth.AccountLocked) instead.
-- RefreshToken.SessionStartedAt: when the login that created the token chain
--   happened. Rotation copies it, so the API can end a session after an absolute
--   limit no matter how often it is refreshed.
-- =============================================================================

CREATE TABLE "UserLockout" (
    "UserId"       INTEGER     PRIMARY KEY REFERENCES "User" ("UserId"),
    "FailedCount"  INTEGER     NOT NULL DEFAULT 0,
    "LockedUntil"  TIMESTAMPTZ,
    "LastFailedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE "RefreshToken"
    ADD COLUMN "SessionStartedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Existing sessions: treat the token's own creation as the session start.
UPDATE "RefreshToken" SET "SessionStartedAt" = "CreatedAt";
