-- =============================================================================
-- V024: "Reportes" navigation module (Administrador)
-- Hosts the audit reports: activity by user, unattributed writes, break-glass.
-- Role IDs: 1 = Administrador (same convention as V011/V013)
-- =============================================================================

WITH new_module AS (
    INSERT INTO "NavigationModule" ("Label", "Icon")
    VALUES ('Reportes', 'report-analytics')
    RETURNING "NavigationModuleId"
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Auditoría', 'report-analytics', '/reportes', 1
    FROM   new_module
    RETURNING "NavigationItemId", "NavigationModuleId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT 1, m."NavigationModuleId", NULL, 6 FROM new_module m
UNION ALL
SELECT 1, i."NavigationModuleId", i."NavigationItemId", 1 FROM new_item i;
