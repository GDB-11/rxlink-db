-- =============================================================================
-- V010__consultas_navigation.sql
-- Adds "Consultas" module for the Doctor role.
--
-- Topbar before: Inicio(1) · Pacientes(2) · Recetas(3) · Mi perfil(4)
-- Topbar after:  Inicio(1) · Consultas(2) · Pacientes(3) · Recetas(4) · Mi perfil(5)
--
-- Role IDs: 2 = Doctor
-- =============================================================================


-- 1. Shift existing Doctor topbar entries to make room at position 2.
UPDATE "RoleNavigationAccess"
SET    "DisplayOrder" = "DisplayOrder" + 1
WHERE  "RoleId"            = 2
  AND  "NavigationItemId"  IS NULL
  AND  "DisplayOrder"      >= 2;


-- 2. Create the module and its single sidebar item, then grant Doctor access.
WITH new_module AS (
    INSERT INTO "NavigationModule" ("Label", "Icon")
    VALUES ('Consultas', 'calendar')
    RETURNING "NavigationModuleId"
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Mis citas', 'calendar', '/consultas', 1
    FROM   new_module
    RETURNING "NavigationItemId", "NavigationModuleId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
-- Topbar entry for Doctor at position 2
SELECT 2, m."NavigationModuleId", NULL, 2 FROM new_module m
UNION ALL
-- Sidebar item
SELECT 2, i."NavigationModuleId", i."NavigationItemId", 1 FROM new_item i;
