-- =============================================================================
-- V041: "Aviso de privacidad" menu entry (Phase 11b.3b)
-- Publishing a new version of the Notice of Privacy Practices is an
-- Administrador task. Reuses the "Privacidad" module created in V038 (Doctor
-- only so far) and gives it to the Administrador too.
-- =============================================================================

WITH m AS (
    SELECT "NavigationModuleId" FROM "NavigationModule" WHERE "Label" = 'Privacidad'
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Aviso de privacidad', 'file-text', '/privacidad/aviso', 2
    FROM m
    RETURNING "NavigationItemId", "NavigationModuleId"
),
module_access AS (
    INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
    SELECT 1, m."NavigationModuleId", NULL,
           COALESCE((SELECT MAX(a."DisplayOrder") FROM "RoleNavigationAccess" a
                     WHERE a."RoleId" = 1 AND a."NavigationItemId" IS NULL), 0) + 1
    FROM m
    RETURNING 1
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT 1, i."NavigationModuleId", i."NavigationItemId", 1
FROM new_item i;
