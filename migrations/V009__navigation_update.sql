-- =============================================================================
-- Navigation Update — align with current codebase modules
-- Requires PostgreSQL 18+
--
-- Changes:
--   REMOVED  Module 4 "Reportes"        — never built, no active plan
--   REMOVED  Item  3  Recetas sin firmar → /inicio/sin-firmar
--   REMOVED  Item  5  Pendientes del día → /inicio/pendientes
--   REMOVED  Item  8  Roles y permisos   → /usuarios/roles
--   REMOVED  Item 12  Tipos de documento → /configuracion/documentos
--   REMOVED  Item 17  Ver historial      → /pacientes/historial
--                     (replaced by /pacientes/[patientCode]/perfil)
--   UPDATED  Module 8 Dispensación → Enfermero
--            Items 23-25 /dispensacion/* → single item at /enfermero
--   ADDED    Module 9 "Doctores" (Administrador)
--            Item   → /doctores
-- =============================================================================


-- =============================================================================
-- 1. Deactivate scrapped items (no route, no active plan)
-- =============================================================================

UPDATE "NavigationItem"
SET    "IsActive" = FALSE
WHERE  "NavigationItemId" IN (
    3,   -- Recetas sin firmar  → /inicio/sin-firmar
    5,   -- Pendientes del día  → /inicio/pendientes
    8,   -- Roles y permisos    → /usuarios/roles
    12,  -- Tipos de documento  → /configuracion/documentos
    17   -- Ver historial       → /pacientes/historial
);

DELETE FROM "RoleNavigationAccess"
WHERE "NavigationItemId" IN (3, 5, 8, 12, 17);


-- =============================================================================
-- 2. Deactivate Reportes module entirely (scrapped)
-- =============================================================================

UPDATE "NavigationModule"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 4;

UPDATE "NavigationItem"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 4;   -- items 13, 14

DELETE FROM "RoleNavigationAccess"
WHERE  "NavigationModuleId" = 4;   -- removes topbar + item rows for Administrador


-- =============================================================================
-- 3. Redesign Module 8: Dispensación → Enfermero
--
--    The nurse dispensing workflow was redesigned: instead of separate
--    /dispensacion sub-pages, nurses use a unified patient-search interface
--    at /enfermero (see nurse-module/ planning docs).
-- =============================================================================

UPDATE "NavigationModule"
SET    "Label" = 'Enfermero',
       "Icon"  = 'nurse'
WHERE  "NavigationModuleId" = 8;

-- Deactivate old dispensación items (23 Recetas activas, 24 Dispensar receta,
-- 25 Historial dispensado).
UPDATE "NavigationItem"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 8;

DELETE FROM "RoleNavigationAccess"
WHERE  "NavigationItemId" IN (23, 24, 25);

-- The topbar access row (RoleId=3, ModuleId=8, ItemId=NULL) is preserved
-- and now represents the renamed "Enfermero" module.

-- Insert the single new item and grant Enfermero (RoleId=3) access to it.
WITH new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    VALUES (8, 'Buscar paciente', 'clipboard-heart', '/enfermero', 1)
    RETURNING "NavigationItemId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT 3, 8, "NavigationItemId", 1 FROM new_item;


-- =============================================================================
-- 4. Add Doctores module (Administrador only)
--
--    Admin manages doctor availability: lists doctors and configures time
--    slots at /doctores and /doctores/[userCode]/disponibilidad
--    (see doctor-availability/ planning docs).
--
--    DisplayOrder 4 is available after removing Reportes (was position 4).
-- =============================================================================

WITH new_module AS (
    INSERT INTO "NavigationModule" ("Label", "Icon")
    VALUES ('Doctores', 'stethoscope')
    RETURNING "NavigationModuleId"
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Lista de doctores', 'list', '/doctores', 1
    FROM   new_module
    RETURNING "NavigationItemId", "NavigationModuleId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
-- Topbar entry for Administrador at position 4 (slot freed by Reportes removal)
SELECT 1, m."NavigationModuleId", NULL, 4 FROM new_module m
UNION ALL
-- Sidebar item
SELECT 1, i."NavigationModuleId", i."NavigationItemId", 1 FROM new_item i;
