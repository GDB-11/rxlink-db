-- =============================================================================
-- V012__remove_pacientes_recetas_navigation.sql
-- Remove Pacientes and Recetas modules from navigation.
--
-- Pacientes (Module 5):
--   Patient registration moved to /usuarios/personas.
--   Doctors navigate to patients through Consultas; nurses through /enfermero.
--   The /pacientes and /pacientes/[code]/perfil routes remain accessible via
--   direct links but no longer need a dedicated topbar module.
--
-- Recetas (Module 6):
--   The /recetas/* routes were dropped and never fully implemented.
--   Module 6 items (18 Mis recetas, 19 Nueva receta, 20 Borradores) are dead
--   links; remove them and their role access rows.
--
-- Doctor topbar before:  Inicio(1) · Consultas(2) · Pacientes(3) · Recetas(4) · Mi perfil(5)
-- Doctor topbar after:   Inicio(1) · Consultas(2) · Mi perfil(3)
--
-- Enfermero topbar before: Inicio(1) · Pacientes(2) · Enfermero(3) · Mi perfil(4)
-- Enfermero topbar after:  Inicio(1) · Enfermero(2) · Mi perfil(3)
--
-- Role IDs: 1 = Administrador  |  2 = Doctor  |  3 = Enfermero
-- =============================================================================


-- =============================================================================
-- 1. Remove RoleNavigationAccess rows for both modules (all roles)
-- =============================================================================

DELETE FROM "RoleNavigationAccess"
WHERE "NavigationModuleId" IN (5, 6);


-- =============================================================================
-- 2. Deactivate Module 5 "Pacientes" and its items
-- =============================================================================

UPDATE "NavigationModule"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 5;

UPDATE "NavigationItem"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 5;   -- items 15, 16, 17 (17 already inactive)


-- =============================================================================
-- 3. Deactivate Module 6 "Recetas" and its items
-- =============================================================================

UPDATE "NavigationModule"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 6;

UPDATE "NavigationItem"
SET    "IsActive" = FALSE
WHERE  "NavigationModuleId" = 6;   -- items 18, 19, 20


-- =============================================================================
-- 4. Reorder Doctor topbar: close the gap left by Pacientes(3) and Recetas(4)
--    Mi perfil was at position 5 → moves to 3.
-- =============================================================================

UPDATE "RoleNavigationAccess"
SET    "DisplayOrder" = 3
WHERE  "RoleId"           = 2          -- Doctor
  AND  "NavigationItemId" IS NULL
  AND  "DisplayOrder"     = 5;         -- Mi perfil module topbar row


-- =============================================================================
-- 5. Reorder Enfermero topbar: close the gap left by Pacientes(2)
--    Enfermero was at position 3 → moves to 2.
--    Mi perfil was at position 4 → moves to 3.
-- =============================================================================

UPDATE "RoleNavigationAccess"
SET    "DisplayOrder" = "DisplayOrder" - 1
WHERE  "RoleId"           = 3          -- Enfermero
  AND  "NavigationItemId" IS NULL
  AND  "DisplayOrder"     >= 3;        -- Enfermero(3→2), Mi perfil(4→3)
