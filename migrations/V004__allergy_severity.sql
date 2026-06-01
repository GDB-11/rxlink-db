-- =============================================================================
-- Allergy Severity — catalog table + PatientAllergy FK
-- Requires PostgreSQL 18+
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Catalog
-- ---------------------------------------------------------------------------

CREATE TABLE "AllergySeverity" (
    "SeverityId"   SERIAL      PRIMARY KEY,
    "SeverityCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"         VARCHAR(50) NOT NULL,
    "SortOrder"    SMALLINT    NOT NULL DEFAULT 0,
    "IsActive"     BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- 2. FK on PatientAllergy (nullable — existing rows keep NULL)
-- ---------------------------------------------------------------------------

ALTER TABLE "PatientAllergy"
    ADD COLUMN "SeverityId" INTEGER REFERENCES "AllergySeverity" ("SeverityId");

CREATE INDEX idx_patient_allergy_severity_id ON "PatientAllergy" ("SeverityId");

-- ---------------------------------------------------------------------------
-- 3. Seed data (ordered by clinical severity)
-- ---------------------------------------------------------------------------

INSERT INTO "AllergySeverity" ("Name", "SortOrder") VALUES
    ('Leve',          1),
    ('Moderada',      2),
    ('Grave',         3),
    ('Anafiláctica',  4);
