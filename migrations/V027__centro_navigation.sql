-- =============================================================================
-- V027: "Centro" navigation item under Configuración (Administrador)
-- Operational clinic data (address, contact, facility registration code).
-- Same style as V017 (Seguros).
-- =============================================================================

WITH new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Centro', 'building-hospital', '/configuracion/centro', 6
    FROM "NavigationModule" WHERE "Label" = 'Configuración'
    RETURNING "NavigationItemId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT r."RoleId", nm."NavigationModuleId", ni."NavigationItemId", 6
FROM new_item ni
CROSS JOIN "NavigationModule" nm
CROSS JOIN "Role" r
WHERE nm."Label" = 'Configuración' AND r."Name" = 'Administrador';
