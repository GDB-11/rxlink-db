-- =============================================================================
-- Admin Citas module — appointment management for Administrador
-- =============================================================================

WITH new_module AS (
    INSERT INTO "NavigationModule" ("Label", "Icon")
    VALUES ('Citas', 'calendar-plus')
    RETURNING "NavigationModuleId"
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Todas las citas', 'list', '/citas', 1
    FROM   new_module
    RETURNING "NavigationItemId", "NavigationModuleId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT 1, m."NavigationModuleId", NULL, 5 FROM new_module m
UNION ALL
SELECT 1, i."NavigationModuleId", i."NavigationItemId", 1 FROM new_item i;
