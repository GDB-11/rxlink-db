-- Patient sessions (decision D31): refresh tokens rotate on every use, belong to a session family, and
-- replaying a used token revokes the whole family. One row per issued token (it was one row per patient).
-- Existing rows hold at most one single-device token each, so they are dropped: patients log in again.

DELETE FROM public."PatientRefreshToken";

ALTER TABLE public."PatientRefreshToken" DROP CONSTRAINT "PatientRefreshToken_PatientId_key";

ALTER TABLE public."PatientRefreshToken"
    ALTER COLUMN "TokenHash" SET NOT NULL,
    ALTER COLUMN "ExpiresAt" SET NOT NULL,
    ADD COLUMN "FamilyCode" uuid NOT NULL,
    ADD COLUMN "UsedAt" timestamp with time zone,
    ADD COLUMN "RevokedAt" timestamp with time zone;

CREATE UNIQUE INDEX "PatientRefreshToken_TokenHash_key" ON public."PatientRefreshToken" ("TokenHash");
CREATE INDEX "PatientRefreshToken_FamilyCode_idx" ON public."PatientRefreshToken" ("FamilyCode");
CREATE INDEX "PatientRefreshToken_PatientId_idx" ON public."PatientRefreshToken" ("PatientId");
