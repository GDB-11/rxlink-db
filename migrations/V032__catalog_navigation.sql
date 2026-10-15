-- =============================================================================
-- V032: Navigation for the shared catalog (Phase 7.2)
-- "Alergias" goes away: allergies are read-only reference data now, only the
-- selectors use them. The other catalog pages are renamed to match what they
-- do today (the partner enables items and edits its own prices/levels).
-- Same style as V012/V017.
-- =============================================================================

DELETE FROM "RoleNavigationAccess"
WHERE "NavigationItemId" IN (SELECT "NavigationItemId" FROM "NavigationItem" WHERE "Path" = '/configuracion/alergias');

UPDATE "NavigationItem" SET "IsActive" = FALSE WHERE "Path" = '/configuracion/alergias';

UPDATE "NavigationItem" SET "Label" = 'Medicamentos del centro'  WHERE "Path" = '/configuracion/medicamentos';
UPDATE "NavigationItem" SET "Label" = 'Especialidades del centro' WHERE "Path" = '/configuracion/especialidades';
UPDATE "NavigationItem" SET "Label" = 'Seguros aceptados'         WHERE "Path" = '/configuracion/seguros';
