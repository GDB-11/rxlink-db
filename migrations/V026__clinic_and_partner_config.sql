-- =============================================================================
-- V026: Clinic and PartnerConfig (Phase 3.1)
-- Operational, partner-owned configuration (architecture doc §10).
-- Identity (name, logo, branding) is NOT stored here: it comes from the
-- registry once Phase 4+ exists.
--
-- "Clinic": physical-site data. One default row today; kept as a table so
-- several clinics can be supported later without moving data (D25).
-- "PartnerConfig": single-row deployment settings. "PartnerCode" is a
-- placeholder until Phase 4 registers the partner; provisioning then overwrites
-- it with the registry value (startup check in Phase 7.3).
-- =============================================================================

CREATE TABLE "Clinic" (
    "ClinicId"                 SERIAL       PRIMARY KEY,
    "ClinicCode"               UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                     VARCHAR(150) NOT NULL,
    "Address"                  VARCHAR(250),
    "District"                 VARCHAR(100),
    "Province"                 VARCHAR(100),
    "Department"               VARCHAR(100),
    "Phone"                    VARCHAR(30),
    "Email"                    VARCHAR(150),
    "Website"                  VARCHAR(250),
    "FacilityRegistrationCode" VARCHAR(50),   -- IPRESS code in Peru, if the partner has one
    "IsDefault"                BOOLEAN      NOT NULL DEFAULT FALSE,
    "IsActive"                 BOOLEAN      NOT NULL DEFAULT TRUE,
    "UpdatedAt"                TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "UpdatedBy"                INTEGER      REFERENCES "User" ("UserId")
);

-- Exactly one default clinic: at most one TRUE row here, and the seed below
-- inserts it.
CREATE UNIQUE INDEX uq_clinic_single_default ON "Clinic" ("IsDefault") WHERE "IsDefault";

CREATE TABLE "PartnerConfig" (
    "PartnerConfigId" INTEGER     PRIMARY KEY DEFAULT 1 CHECK ("PartnerConfigId" = 1),
    "PartnerCode"     UUID        NOT NULL DEFAULT uuidv7(),
    "UpdatedAt"       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedBy"       INTEGER     REFERENCES "User" ("UserId")
);

INSERT INTO "Clinic" ("Name", "IsDefault") VALUES ('Sede Principal', TRUE);
INSERT INTO "PartnerConfig" ("PartnerConfigId") VALUES (1);

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "Clinic"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PartnerConfig"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
