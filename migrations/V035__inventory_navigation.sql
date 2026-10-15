-- =============================================================================
-- V035: "Inventario" navigation module (Phase 10.3)
-- Stock list, movement history, entries/adjustments and the inventory report.
-- Administrador (RoleId 1) and Enfermero (RoleId 3), same as the inventory API.
-- The topbar entry goes after each role's last module.
-- =============================================================================

WITH new_module AS (
    INSERT INTO "NavigationModule" ("Label", "Icon")
    VALUES ('Inventario', 'packages')
    RETURNING "NavigationModuleId"
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Inventario', 'packages', '/inventario', 1
    FROM   new_module
    RETURNING "NavigationItemId", "NavigationModuleId"
),
roles AS (
    SELECT "RoleId" FROM "Role" WHERE "RoleId" IN (1, 3)
),
module_access AS (
    INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
    SELECT r."RoleId", m."NavigationModuleId", NULL,
           COALESCE((SELECT MAX(a."DisplayOrder") FROM "RoleNavigationAccess" a
                     WHERE a."RoleId" = r."RoleId" AND a."NavigationItemId" IS NULL), 0) + 1
    FROM new_module m CROSS JOIN roles r
    RETURNING 1
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT r."RoleId", i."NavigationModuleId", i."NavigationItemId", 1
FROM new_item i CROSS JOIN roles r;
