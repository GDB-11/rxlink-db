-- =============================================================================
-- V013__citas_nueva_navigation.sql
-- Add "Nueva cita" sidebar item to the Administrador's Citas module.
--
-- V011 created the Citas module with a single item "Todas las citas" (/citas).
-- The booking form at /citas/nueva was reachable only via a button inside that
-- page, not from the sidebar directly.  This migration adds the missing item.
--
-- Admin Citas sidebar before: Todas las citas(1)
-- Admin Citas sidebar after:  Todas las citas(1) · Nueva cita(2)
--
-- Role IDs: 1 = Administrador
-- =============================================================================

WITH target_module AS (
    SELECT "NavigationModuleId"
    FROM   "NavigationModule"
    WHERE  "Label" = 'Citas'
      AND  "IsActive" = TRUE
),
new_item AS (
    INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder")
    SELECT "NavigationModuleId", 'Nueva cita', 'calendar-plus', '/citas/nueva', 2
    FROM   target_module
    RETURNING "NavigationItemId", "NavigationModuleId"
)
INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder")
SELECT 1, i."NavigationModuleId", i."NavigationItemId", 2
FROM   new_item i;
