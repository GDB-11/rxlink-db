-- ===========================================================================
-- V017: Precios de especialidad, catálogo de seguros y pago real de citas
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Precios de especialidad (Presencial / Virtual)
-- ---------------------------------------------------------------------------
-- DEFAULT 0 existe únicamente para que el ALTER TABLE no falle contra las
-- filas existentes; se sobrescribe de inmediato con precios reales abajo.
-- La API exige estos campos (> 0) al crear/editar una especialidad, por lo
-- que el default nunca es un valor con el que la aplicación opere.

ALTER TABLE "Specialty"
    ADD COLUMN "PriceInPerson" NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN "PriceVirtual"  NUMERIC(10,2) NOT NULL DEFAULT 0;

UPDATE "Specialty" SET "PriceInPerson" = v."PriceInPerson", "PriceVirtual" = v."PriceVirtual"
FROM (VALUES
    ('Medicina General',                    80.00,  50.00),
    ('Cardiología',                        140.00, 100.00),
    ('Neurología',                         140.00, 100.00),
    ('Pediatría',                           90.00,  60.00),
    ('Ginecología y Obstetricia',          120.00,  85.00),
    ('Traumatología y Ortopedia',          130.00,  90.00),
    ('Dermatología',                       110.00,  80.00),
    ('Oftalmología',                       110.00,  80.00),
    ('Otorrinolaringología',               110.00,  80.00),
    ('Gastroenterología',                  120.00,  85.00),
    ('Neumología',                         120.00,  85.00),
    ('Endocrinología',                     110.00,  80.00),
    ('Reumatología',                       110.00,  80.00),
    ('Nefrología',                         120.00,  85.00),
    ('Urología',                           120.00,  85.00),
    ('Oncología',                          160.00, 110.00),
    ('Hematología',                        140.00, 100.00),
    ('Infectología',                       110.00,  80.00),
    ('Psiquiatría',                        120.00,  90.00),
    ('Medicina Interna',                   100.00,  70.00),
    ('Cirugía General',                    150.00, 100.00),
    ('Cirugía Cardiovascular',             200.00, 130.00),
    ('Cirugía Plástica y Reconstructiva',  180.00, 120.00),
    ('Anestesiología',                     150.00, 100.00),
    ('Radiología e Imagen',                100.00,  70.00),
    ('Medicina de Emergencias',            130.00,  90.00),
    ('Geriatría',                          100.00,  70.00),
    ('Medicina Física y Rehabilitación',    90.00,  60.00),
    ('Nutrición Clínica',                   80.00,  55.00),
    ('Odontología General',                 90.00,  60.00)
) AS v("Name", "PriceInPerson", "PriceVirtual")
WHERE "Specialty"."Name" = v."Name";

-- ---------------------------------------------------------------------------
-- 2. Catálogo: seguros (Perú)
-- ---------------------------------------------------------------------------

CREATE TABLE "Insurance" (
    "InsuranceId"         SERIAL       PRIMARY KEY,
    "InsuranceCode"       UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "Name"                VARCHAR(100) NOT NULL,
    "CoveragePercentage"  NUMERIC(5,2) NOT NULL CHECK ("CoveragePercentage" BETWEEN 0 AND 100),
    "IsActive"            BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO "Insurance" ("Name", "CoveragePercentage") VALUES
    ('EsSalud',          100.00),
    ('SIS',              100.00),
    ('Pacífico Seguros',  80.00),
    ('Rimac Seguros',     80.00),
    ('La Positiva',       70.00),
    ('Mapfre Perú',       70.00),
    ('Sanitas Perú',      75.00);

-- ---------------------------------------------------------------------------
-- 3. Pago de cita — snapshot del monto/cobertura al momento de resolverse
-- ---------------------------------------------------------------------------
-- Existe solo una vez que el pago se resuelve (seguro o particular); una
-- cita "Pendiente de pago" por "pagar después" no tiene fila aquí todavía.

CREATE TABLE "AppointmentPayment" (
    "AppointmentPaymentId" SERIAL      PRIMARY KEY,
    "AppointmentId"         INTEGER       NOT NULL UNIQUE REFERENCES "Appointment" ("AppointmentId"),
    "InsuranceId"           INTEGER                REFERENCES "Insurance" ("InsuranceId"),
    "BaseAmount"            NUMERIC(10,2) NOT NULL,
    "CoveragePercentage"    NUMERIC(5,2)  NOT NULL DEFAULT 0,
    "CoveredAmount"         NUMERIC(10,2) NOT NULL,
    "PatientAmount"         NUMERIC(10,2) NOT NULL,
    "RecordedBy"            INTEGER                REFERENCES "User" ("UserId"),
    "CreatedAt"             TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 4. Navegación — "Seguros" bajo Configuración (Administrador)
-- ---------------------------------------------------------------------------

WITH new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Seguros', 'shield-check', '/configuracion/seguros', 5
    FROM "NavigationModule" WHERE "Label" = 'Configuración'
    RETURNING "NavigationItemId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT r."RoleId", nm."NavigationModuleId", ni."NavigationItemId", 5
FROM new_item ni
CROSS JOIN "NavigationModule" nm
CROSS JOIN "Role" r
WHERE nm."Label" = 'Configuración' AND r."Name" = 'Administrador';
