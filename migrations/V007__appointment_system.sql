-- ===========================================================================
-- V007: Sistema de citas + credenciales de paciente
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Credenciales de paciente
-- ---------------------------------------------------------------------------

ALTER TABLE "Patient"
    ADD COLUMN "PasswordHash" TEXT;

-- Un token activo por paciente a la vez; TokenHash/ExpiresAt son NULL cuando
-- el paciente no tiene sesión activa (equivale a logout).
CREATE TABLE "PatientRefreshToken" (
    "PatientRefreshTokenId" SERIAL      PRIMARY KEY,
    "PatientId"             INTEGER     NOT NULL REFERENCES "Patient" ("PatientId") UNIQUE,
    "TokenHash"             TEXT,
    "ExpiresAt"             TIMESTAMPTZ,
    "CreatedAt"             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 2. Catálogo: tipo de consulta
-- ---------------------------------------------------------------------------

CREATE TABLE "ConsultationType" (
    "ConsultationTypeId"   SERIAL      PRIMARY KEY,
    "ConsultationTypeCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                 VARCHAR(50) NOT NULL,
    "IsActive"             BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO "ConsultationType" ("Name") VALUES
    ('Virtual'),
    ('Presencial');

-- ---------------------------------------------------------------------------
-- 3. Catálogo: estado de cita
-- ---------------------------------------------------------------------------

CREATE TABLE "AppointmentStatus" (
    "AppointmentStatusId"   SERIAL      PRIMARY KEY,
    "AppointmentStatusCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                  VARCHAR(50) NOT NULL,
    "IsActive"              BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO "AppointmentStatus" ("Name") VALUES
    ('PendientePago'),
    ('Confirmado'),
    ('Completado'),
    ('Cancelado'),
    ('NoAsistio');

-- ---------------------------------------------------------------------------
-- 4. Slots de disponibilidad (administrados por el rol Administrador)
-- ---------------------------------------------------------------------------

CREATE TABLE "DoctorAvailability" (
    "DoctorAvailabilityId"   SERIAL      PRIMARY KEY,
    "DoctorAvailabilityCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "DoctorId"               INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "Date"                   DATE        NOT NULL,
    "StartTime"              TIME        NOT NULL,
    "IsBooked"               BOOLEAN     NOT NULL DEFAULT FALSE,
    "CreatedBy"              INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "CreatedAt"              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "DeletedAt"              TIMESTAMPTZ,
    "DeletedBy"              INTEGER              REFERENCES "User" ("UserId"),
    CONSTRAINT uq_doctor_date_time UNIQUE ("DoctorId", "Date", "StartTime")
);

CREATE INDEX idx_availability_doctor_date ON "DoctorAvailability" ("DoctorId", "Date");

-- ---------------------------------------------------------------------------
-- 5. Citas
-- ---------------------------------------------------------------------------

CREATE TABLE "Appointment" (
    "AppointmentId"        SERIAL      PRIMARY KEY,
    "AppointmentCode"      UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "PatientId"            INTEGER     NOT NULL REFERENCES "Patient" ("PatientId"),
    "DoctorId"             INTEGER     NOT NULL REFERENCES "User" ("UserId"),
    "DoctorAvailabilityId" INTEGER     NOT NULL REFERENCES "DoctorAvailability" ("DoctorAvailabilityId"),
    "ConsultationTypeId"   INTEGER     NOT NULL REFERENCES "ConsultationType" ("ConsultationTypeId"),
    "AppointmentStatusId"  INTEGER     NOT NULL REFERENCES "AppointmentStatus" ("AppointmentStatusId"),
    "ScheduledAt"          TIMESTAMPTZ NOT NULL,
    "CreatedAt"            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"            TIMESTAMPTZ,
    "UpdatedBy"            INTEGER              REFERENCES "User" ("UserId")
);

CREATE INDEX idx_appointment_patient_id ON "Appointment" ("PatientId");
CREATE INDEX idx_appointment_doctor_id  ON "Appointment" ("DoctorId");
