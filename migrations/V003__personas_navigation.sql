-- =============================================================================
-- Personas Navigation — replace unused registration routes
-- Requires PostgreSQL 18+
--
-- Replaces the unused stub routes:
--   • /usuarios/nuevo   (Administrador — item 7 "Registrar usuario")
--   • /pacientes/nuevo  (Doctor        — item 16 "Registrar paciente")
-- with the new PersonsPage routes added in the personas feature branch.
-- RoleNavigationAccess rows are untouched — same modules, same display order.
-- =============================================================================

-- Administrador → Usuarios module sidebar
UPDATE "NavigationItem"
SET "Label" = 'Personas',
    "Icon"  = 'users',
    "Path"  = '/usuarios/personas'
WHERE "NavigationItemId" = 7;   -- was: Registrar usuario → /usuarios/nuevo

-- Doctor → Pacientes module sidebar
UPDATE "NavigationItem"
SET "Label" = 'Personas',
    "Icon"  = 'users',
    "Path"  = '/pacientes/personas'
WHERE "NavigationItemId" = 16;  -- was: Registrar paciente → /pacientes/nuevo
