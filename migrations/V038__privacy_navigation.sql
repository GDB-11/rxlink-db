-- =============================================================================
-- V038: "Privacidad" navigation module (Phase 11b.2)
-- Amendment-request review queue. Doctor only (RoleId 2), same as the API:
-- amendments are decided by a clinician. Disclosures live in the patient profile,
-- so they need no menu entry. The topbar entry goes after the role's last module.
-- =============================================================================

WITH new_module AS (
    INSERT INTO "NavigationModule" ("Label", "Icon")
    VALUES ('Privacidad', 'shield-lock')
    RETURNING "NavigationModuleId"
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Enmiendas', 'file-pencil', '/privacidad/enmiendas', 1
    FROM   new_module
    RETURNING "NavigationItemId", "NavigationModuleId"
),
roles AS (
    SELECT "RoleId" FROM "Role" WHERE "RoleId" = 2
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
