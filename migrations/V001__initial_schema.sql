-- =============================================================================
-- Prescription System — PostgreSQL DDL
-- Requires PostgreSQL 18+
--
-- Naming conventions:
--   • Tables and columns  → PascalCase  (quoted identifiers)
--   • Constraints         → snake_case
--   • Indexes             → snake_case
--   • Functions           → snake_case
--   • Schema              → snake_case
-- =============================================================================

-- =============================================================================
-- 1. CATALOGS
-- =============================================================================

CREATE TABLE "DocumentType" (
    "DocumentTypeId"   SERIAL       PRIMARY KEY,
    "DocumentTypeCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"             VARCHAR(20) NOT NULL,
    "IsActive"         BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "Sex" (
    "SexId"    SERIAL      PRIMARY KEY,
    "SexCode"  UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"     VARCHAR(50) NOT NULL
);

-- ---------------------------------------------------------------------------

CREATE TABLE "Role" (
    "RoleId"      SERIAL       PRIMARY KEY,
    "RoleCode"    UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"        VARCHAR(50)  NOT NULL,
    "Description" TEXT,
    "IsActive"    BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "Specialty" (
    "SpecialtyId"   SERIAL       PRIMARY KEY,
    "SpecialtyCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"          VARCHAR(100) NOT NULL,
    "IsActive"      BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "PharmaceuticalForm" (
    "PharmaceuticalFormId"   SERIAL       PRIMARY KEY,
    "PharmaceuticalFormCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                   VARCHAR(100) NOT NULL,
    "IsActive"               BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "AdministrationRoute" (
    "AdministrationRouteId"   SERIAL       PRIMARY KEY,
    "AdministrationRouteCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                    VARCHAR(100) NOT NULL,
    "IsActive"                BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "Frequency" (
    "FrequencyId"   SERIAL       PRIMARY KEY,
    "FrequencyCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Description"   VARCHAR(200) NOT NULL,
    "IntervalHours" INTEGER      NOT NULL CHECK ("IntervalHours" > 0),
    "IsActive"      BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "Allergy" (
    "AllergyId"   SERIAL       PRIMARY KEY,
    "AllergyCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"        VARCHAR(150) NOT NULL,
    "Description" TEXT,
    "IsActive"    BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "PrescriptionStatus" (
    "PrescriptionStatusId"   SERIAL      PRIMARY KEY,
    "PrescriptionStatusCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                   VARCHAR(50) NOT NULL,
    "Description"            TEXT,
    "IsActive"               BOOLEAN     NOT NULL DEFAULT TRUE
);


-- =============================================================================
-- 2. IDENTITY
-- =============================================================================

CREATE TABLE "Person" (
    "PersonId"              SERIAL       PRIMARY KEY,
    "PersonCode"            UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Names"                 VARCHAR(200) NOT NULL,
    "Surnames"              VARCHAR(150) NOT NULL,
    "BirthDate"             DATE         NOT NULL,
    "SexId"                 INTEGER      NOT NULL REFERENCES "Sex" ("SexId"),
    "Phone"                 VARCHAR(30)  NOT NULL,
    "AlternativePhone"      VARCHAR(30),
    "Email"                 VARCHAR(254) NOT NULL,
    "Address"               TEXT,
    "EmergencyContactName"  VARCHAR(200),
    "EmergencyContactPhone" VARCHAR(30)
);

-- ---------------------------------------------------------------------------

CREATE TABLE "PersonDocument" (
    "PersonDocumentId"   SERIAL      PRIMARY KEY,
    "PersonDocumentCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "PersonId"           INTEGER     NOT NULL REFERENCES "Person" ("PersonId"),
    "DocumentTypeId"     INTEGER     NOT NULL REFERENCES "DocumentType" ("DocumentTypeId"),
    "Number"             VARCHAR(50) NOT NULL,
    "IssueDate"          DATE,
    "ExpirationDate"     DATE,
    CONSTRAINT chk_person_document_dates
        CHECK ("ExpirationDate" IS NULL OR "IssueDate" IS NULL OR "ExpirationDate" >= "IssueDate")
);


-- =============================================================================
-- 3. SYSTEM ACCESS
-- =============================================================================

CREATE TABLE "User" (
    "UserId"        SERIAL       PRIMARY KEY,
    "UserCode"      UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "PersonId"      INTEGER      NOT NULL REFERENCES "Person" ("PersonId"),
    "RoleId"        INTEGER      NOT NULL REFERENCES "Role" ("RoleId"),
    "SpecialtyId"   INTEGER               REFERENCES "Specialty" ("SpecialtyId"),
    "Username"      VARCHAR(100) NOT NULL UNIQUE,
    "Email"         VARCHAR(254) NOT NULL UNIQUE,
    "PasswordHash"  TEXT         NOT NULL,
    "LicenseNumber" VARCHAR(100),
    "IsActive"      BOOLEAN      NOT NULL DEFAULT TRUE,
    "CreatedAt"     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "LastAccess"    TIMESTAMPTZ,
    "DeletedAt"     TIMESTAMPTZ,
    "DeletedBy"     INTEGER               REFERENCES "User" ("UserId")
);

-- ---------------------------------------------------------------------------

CREATE TABLE "RefreshToken" (
    "RefreshTokenId"   SERIAL      PRIMARY KEY,
    "UserId"           INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "TokenHash"        TEXT        NOT NULL,
    "ExpiresAt"        TIMESTAMPTZ NOT NULL,
    "CreatedAt"        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "IpAddress"        INET,
    "UserAgent"        TEXT,
    "RevokedAt"        TIMESTAMPTZ,
    "RevokedBy"        INTEGER              REFERENCES "User" ("UserId")

    CONSTRAINT chk_refresh_token_revocation
        CHECK ("RevokedAt" IS NULL OR "RevokedAt" >= "CreatedAt")
);


-- =============================================================================
-- 4. CLINICAL
-- =============================================================================

CREATE TABLE "Patient" (
    "PatientId"           SERIAL      PRIMARY KEY,
    "PatientCode"         UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "PersonId"            INTEGER     NOT NULL REFERENCES "Person" ("PersonId"),
    "MedicalRecordNumber" VARCHAR(50) NOT NULL UNIQUE,
    "IsActive"            BOOLEAN     NOT NULL DEFAULT TRUE,
    "DeletedAt"           TIMESTAMPTZ,
    "DeletedBy"           INTEGER              REFERENCES "User" ("UserId")
);

-- ---------------------------------------------------------------------------

CREATE TABLE "PatientAllergy" (
    "PatientAllergyId"   SERIAL      PRIMARY KEY,
    "PatientAllergyCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "PatientId"          INTEGER     NOT NULL REFERENCES "Patient" ("PatientId"),
    "AllergyId"          INTEGER     NOT NULL REFERENCES "Allergy" ("AllergyId"),
    "Notes"              TEXT,
    "DeletedAt"          TIMESTAMPTZ,
    "DeletedBy"          INTEGER     REFERENCES "User" ("UserId"),
    CONSTRAINT uq_patient_allergy UNIQUE ("PatientId", "AllergyId")
);


-- =============================================================================
-- 5. MEDICATIONS
-- =============================================================================

CREATE TABLE "Medication" (
    "MedicationId"          SERIAL       PRIMARY KEY,
    "MedicationCode"        UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "PharmaceuticalFormId"  INTEGER      NOT NULL REFERENCES "PharmaceuticalForm" ("PharmaceuticalFormId"),
    "AdministrationRouteId" INTEGER      NOT NULL REFERENCES "AdministrationRoute" ("AdministrationRouteId"),
    "GenericName"           VARCHAR(200) NOT NULL,
    "CommercialName"        VARCHAR(200),
    "Concentration"         VARCHAR(50)  NOT NULL,
    "IsActive"              BOOLEAN      NOT NULL DEFAULT TRUE,
    "DeletedAt"             TIMESTAMPTZ,
    "DeletedBy"             INTEGER               REFERENCES "User" ("UserId")
);


-- =============================================================================
-- 6. CORE BUSINESS
-- =============================================================================

CREATE TABLE "Prescription" (
    "PrescriptionId"       SERIAL      PRIMARY KEY,
    "PrescriptionCode"     UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "UserId"               INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "PatientId"            INTEGER     NOT NULL REFERENCES "Patient" ("PatientId"),
    "PrescriptionStatusId" INTEGER     NOT NULL REFERENCES "PrescriptionStatus" ("PrescriptionStatusId"),
    "Diagnosis"            TEXT        NOT NULL,
    "Notes"                TEXT,
    "ValidUntil"           DATE        NOT NULL,
    "SignedAt"             TIMESTAMPTZ,
    "SignedBy"             INTEGER              REFERENCES "User" ("UserId"),
    "DispensedAt"          TIMESTAMPTZ,
    "DispensedBy"          INTEGER              REFERENCES "User" ("UserId"),
    "CreatedBy"            INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "CreatedAt"            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "ModifiedBy"           INTEGER              REFERENCES "User" ("UserId"),
    "ModifiedAt"           TIMESTAMPTZ,
    "DeletedAt"            TIMESTAMPTZ,
    "DeletedBy"            INTEGER              REFERENCES "User" ("UserId"),

    CONSTRAINT chk_prescription_valid_until
        CHECK ("ValidUntil" >= "CreatedAt"::DATE),
        
    CONSTRAINT chk_prescription_signed
        CHECK (
            ("SignedAt" IS NULL AND "SignedBy" IS NULL) OR
            ("SignedAt" IS NOT NULL AND "SignedBy" IS NOT NULL)
        ),
        
    CONSTRAINT chk_prescription_signed_after_created
        CHECK ("SignedAt" IS NULL OR "SignedAt" >= "CreatedAt"),
        
    CONSTRAINT chk_prescription_dispensed_requires_signature
        CHECK ("DispensedAt" IS NULL OR "SignedAt" IS NOT NULL),
    CONSTRAINT chk_prescription_dispensed
        CHECK (
            ("DispensedAt" IS NULL AND "DispensedBy" IS NULL) OR
            ("DispensedAt" IS NOT NULL AND "DispensedBy" IS NOT NULL)
        )
);

-- ---------------------------------------------------------------------------

CREATE TABLE "PrescriptionDetail" (
    "PrescriptionDetailId"   SERIAL       PRIMARY KEY,
    "PrescriptionDetailCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "PrescriptionId"         INTEGER      NOT NULL REFERENCES "Prescription" ("PrescriptionId"),
    "MedicationId"           INTEGER      NOT NULL REFERENCES "Medication" ("MedicationId"),
    "AdministrationRouteId"  INTEGER      NOT NULL REFERENCES "AdministrationRoute" ("AdministrationRouteId"),
    "FrequencyId"            INTEGER      NOT NULL REFERENCES "Frequency" ("FrequencyId"),
    "Dose"                   VARCHAR(100) NOT NULL,
    "DurationDays"           INTEGER      NOT NULL CHECK ("DurationDays" > 0),
    "Instructions"           TEXT
);


-- =============================================================================
-- 7. AUDIT
-- =============================================================================

CREATE TABLE "AuditLog" (
    "AuditLogId"  BIGSERIAL    PRIMARY KEY,
    "TableName"   VARCHAR(100) NOT NULL,
    "RecordId"    INTEGER      NOT NULL,
    "Action"      VARCHAR(10)  NOT NULL CHECK ("Action" IN ('INSERT', 'UPDATE', 'DELETE')),
    "OldValues"   JSONB,                       -- NULL on INSERT
    "NewValues"   JSONB,                       -- NULL on DELETE
    "UserId"      INTEGER               REFERENCES "User" ("UserId"),   -- NULL for system actions
    "OccurredAt"  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "IpAddress"   INET
);


-- =============================================================================
-- INDEXES
-- =============================================================================

-- --- Person ---
CREATE INDEX idx_person_sex_id    ON "Person" ("SexId");
CREATE INDEX idx_person_last_surnames ON "Person" ("Surnames");

-- --- PersonDocument ---
CREATE INDEX idx_person_document_person_id        ON "PersonDocument" ("PersonId");
CREATE INDEX idx_person_document_document_type_id ON "PersonDocument" ("DocumentTypeId");

-- --- User ---
CREATE INDEX idx_user_person_id    ON "User" ("PersonId");
CREATE INDEX idx_user_role_id      ON "User" ("RoleId");
CREATE INDEX idx_user_specialty_id ON "User" ("SpecialtyId");
CREATE INDEX idx_user_is_active    ON "User" ("IsActive") WHERE "IsActive" = TRUE;

-- --- RefreshToken ---
CREATE INDEX idx_refresh_token_user_id ON "RefreshToken" ("UserId");
CREATE INDEX idx_refresh_token_active
    ON "RefreshToken" ("UserId", "ExpiresAt")
    WHERE "RevokedAt" IS NULL;

-- --- Patient ---
CREATE INDEX idx_patient_person_id ON "Patient" ("PersonId");
CREATE INDEX idx_patient_is_active ON "Patient" ("IsActive") WHERE "IsActive" = TRUE;

-- --- PatientAllergy ---
CREATE INDEX idx_patient_allergy_patient_id ON "PatientAllergy" ("PatientId");
CREATE INDEX idx_patient_allergy_allergy_id ON "PatientAllergy" ("AllergyId");

-- --- Medication ---
CREATE INDEX idx_medication_pharmaceutical_form_id  ON "Medication" ("PharmaceuticalFormId");
CREATE INDEX idx_medication_administration_route_id ON "Medication" ("AdministrationRouteId");
CREATE INDEX idx_medication_generic_name            ON "Medication" ("GenericName");

-- --- Prescription ---
CREATE INDEX idx_prescription_user_id     ON "Prescription" ("UserId");
CREATE INDEX idx_prescription_patient_id  ON "Prescription" ("PatientId");
CREATE INDEX idx_prescription_status_id   ON "Prescription" ("PrescriptionStatusId");
CREATE INDEX idx_prescription_valid_until ON "Prescription" ("ValidUntil");
CREATE INDEX idx_prescription_unsigned
    ON "Prescription" ("UserId", "CreatedAt")
    WHERE "SignedAt" IS NULL AND "DeletedAt" IS NULL;

-- --- PrescriptionDetail ---
CREATE INDEX idx_prescription_detail_prescription_id ON "PrescriptionDetail" ("PrescriptionId");
CREATE INDEX idx_prescription_detail_medication_id   ON "PrescriptionDetail" ("MedicationId");
CREATE INDEX idx_prescription_detail_admin_route_id  ON "PrescriptionDetail" ("AdministrationRouteId");
CREATE INDEX idx_prescription_detail_frequency_id    ON "PrescriptionDetail" ("FrequencyId");

-- --- AuditLog ---
CREATE INDEX idx_audit_log_table_record  ON "AuditLog" ("TableName", "RecordId");
CREATE INDEX idx_audit_log_user_time     ON "AuditLog" ("UserId", "OccurredAt");
CREATE INDEX idx_audit_log_occurred_brin ON "AuditLog" USING BRIN ("OccurredAt");


-- =============================================================================
-- SEED DATA — Catalogs
-- =============================================================================

INSERT INTO "Sex" ("Name") VALUES
    ('Masculino'), ('Femenino');

INSERT INTO "DocumentType" ("Name") VALUES
    ('DNI'), ('Pasaporte'), ('Carné de extranjería');

INSERT INTO "Role" ("Name", "Description") VALUES
    ('Administrador',   'Control de usuarios, configuración y accesos'),
    ('Doctor',          'Puede crear y gestionar recetas'),
    ('Enfermero',       'Acceso a asistencia clínica');

INSERT INTO "PrescriptionStatus" ("Name", "Description") VALUES
    ('Borrador',   'Receta creada pero aún no firmada; no es clínicamente válida'),
    ('Activo',     'Receta firmada y válida, pendiente de dispensación'),
    ('Suspendido', 'Suspendido temporalmente por el médico prescriptor'),
    ('Finalizado', 'Finalización del tratamiento'),
    ('Dispensado', 'Se le han entregado los medicamentos al paciente'),
    ('Caducado',   'La receta caducó sin que se dispensara el medicamento');

INSERT INTO "AdministrationRoute" ("Name") VALUES
    ('Oral'), ('Intravenosa'), ('Intramuscular'), ('Subcutánea'),
    ('Tópica'), ('Inhalatoria'), ('Sublingual'), ('Rectal');

INSERT INTO "PharmaceuticalForm" ("Name") VALUES
    ('Tableta'), ('Cápsula'), ('Jarabe'), ('Solución inyectable'),
    ('Crema'), ('Ungüento'), ('Gotas'), ('Parche'), ('Supositorio'), ('Polvo');

INSERT INTO "Frequency" ("Description", "IntervalHours") VALUES
    ('Una vez al día', 24),
    ('Dos veces al día', 12),
    ('Cada 8 horas', 8),
    ('Cada 6 horas', 6),
    ('Cada 4 horas', 4),
    ('Cada 12 horas', 12),
    ('Una vez a la semana', 168),
    ('Días alternos', 48);

INSERT INTO "Specialty" ("Name") VALUES
    ('Medicina General'),
    ('Cardiología'),
    ('Neurología'),
    ('Pediatría'),
    ('Ginecología y Obstetricia'),
    ('Traumatología y Ortopedia'),
    ('Dermatología'),
    ('Oftalmología'),
    ('Otorrinolaringología'),
    ('Gastroenterología'),
    ('Neumología'),
    ('Endocrinología'),
    ('Reumatología'),
    ('Nefrología'),
    ('Urología'),
    ('Oncología'),
    ('Hematología'),
    ('Infectología'),
    ('Psiquiatría'),
    ('Medicina Interna'),
    ('Cirugía General'),
    ('Cirugía Cardiovascular'),
    ('Cirugía Plástica y Reconstructiva'),
    ('Anestesiología'),
    ('Radiología e Imagen'),
    ('Medicina de Emergencias'),
    ('Geriatría'),
    ('Medicina Física y Rehabilitación'),
    ('Nutrición Clínica'),
    ('Odontología General');