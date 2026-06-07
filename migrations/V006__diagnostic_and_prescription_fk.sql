-- Catálogo de estados del diagnóstico
CREATE TABLE "DiagnosticStatus" (
    "DiagnosticStatusId"   SERIAL      PRIMARY KEY,
    "DiagnosticStatusCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                 VARCHAR(50) NOT NULL,
    "IsActive"             BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO "DiagnosticStatus" ("Name") VALUES
    ('Activo'),
    ('Inactivo');

-- ---------------------------------------------------------------------------

CREATE TABLE "Diagnostic" (
    "DiagnosticId"       SERIAL      PRIMARY KEY,
    "DiagnosticCode"     UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "PatientId"          INTEGER     NOT NULL REFERENCES "Patient" ("PatientId"),
    "DiagnosticStatusId" INTEGER     NOT NULL REFERENCES "DiagnosticStatus" ("DiagnosticStatusId"),
    "Description"        TEXT        NOT NULL,
    "DiagnosedAt"        DATE        NOT NULL,
    "Notes"              TEXT,
    "CreatedBy"          INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "CreatedAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "ModifiedBy"         INTEGER              REFERENCES "User" ("UserId"),
    "ModifiedAt"         TIMESTAMPTZ,
    "DeletedAt"          TIMESTAMPTZ,
    "DeletedBy"          INTEGER              REFERENCES "User" ("UserId")
);

CREATE INDEX idx_diagnostic_patient_id ON "Diagnostic" ("PatientId");
CREATE INDEX idx_diagnostic_status_id  ON "Diagnostic" ("DiagnosticStatusId");

-- ---------------------------------------------------------------------------

-- Prescription.Diagnosis (TEXT NOT NULL) queda obsoleto: la descripción
-- vive en Diagnostic.Description. Se elimina la columna y se reemplaza por
-- un FK NOT NULL hacia Diagnostic, garantizando que toda receta pertenece
-- a un diagnóstico.
ALTER TABLE "Prescription"
    DROP COLUMN "Diagnosis";

ALTER TABLE "Prescription"
    ADD COLUMN "DiagnosticId" INTEGER NOT NULL REFERENCES "Diagnostic" ("DiagnosticId");

-- Garantiza máximo 1 receta activa (no borrada) por diagnóstico
CREATE UNIQUE INDEX uq_prescription_diagnostic
    ON "Prescription" ("DiagnosticId")
    WHERE "DeletedAt" IS NULL;

CREATE INDEX idx_prescription_diagnostic_id ON "Prescription" ("DiagnosticId");
