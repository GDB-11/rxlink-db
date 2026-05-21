-- =============================================================================
-- Navigation System — PostgreSQL DDL
-- Requires PostgreSQL 18+
--
-- Adds role-based navigation configuration served via API.
-- The frontend consumes GET /api/navigation (JWT required) and receives
-- only the modules and items the authenticated user's role can access.
--
-- Key design decisions:
--   • NavigationModule   → topbar entries
--   • NavigationItem     → sidebar links (belong to one module)
--   • RoleNavigationAccess → many-to-many with per-role ordering
--       ∘ NavigationItemId IS NULL  → grants access to the module (topbar)
--       ∘ NavigationItemId NOT NULL → grants access to a specific item (sidebar)
--       ∘ DisplayOrder controls position independently per role
--
-- Naming conventions:
--   • Tables and columns  → PascalCase  (quoted identifiers)
--   • Constraints         → snake_case
--   • Indexes             → snake_case
-- =============================================================================


-- =============================================================================
-- 1. TABLES
-- =============================================================================

CREATE TABLE "NavigationModule" (
    "NavigationModuleId"   SERIAL      PRIMARY KEY,
    "NavigationModuleCode" UUID        NOT NULL DEFAULT uuidv7() UNIQUE,
    "Label"                VARCHAR(50) NOT NULL,
    "Icon"                 VARCHAR(50) NOT NULL,
    "IsActive"             BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

CREATE TABLE "NavigationItem" (
    "NavigationItemId"   SERIAL       PRIMARY KEY,
    "NavigationItemCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "NavigationModuleId" INTEGER      NOT NULL REFERENCES "NavigationModule" ("NavigationModuleId"),
    "Label"              VARCHAR(100) NOT NULL,
    "Icon"               VARCHAR(50)  NOT NULL,
    "Path"               VARCHAR(200) NOT NULL,
    "DisplayOrder"       INTEGER      NOT NULL CHECK ("DisplayOrder" > 0),
    "IsActive"           BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------

-- One row per (role, module) grants topbar access   → NavigationItemId IS NULL
-- One row per (role, module, item) grants sidebar   → NavigationItemId NOT NULL
-- DisplayOrder: topbar position when item IS NULL, sidebar position otherwise
CREATE TABLE "RoleNavigationAccess" (
    "RoleNavigationAccessId" SERIAL  PRIMARY KEY,
    "RoleId"                 INTEGER NOT NULL REFERENCES "Role" ("RoleId"),
    "NavigationModuleId"     INTEGER NOT NULL REFERENCES "NavigationModule" ("NavigationModuleId"),
    "NavigationItemId"       INTEGER          REFERENCES "NavigationItem" ("NavigationItemId"),
    "DisplayOrder"           INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT uq_role_nav_access
        UNIQUE ("RoleId", "NavigationModuleId", "NavigationItemId")
);


-- =============================================================================
-- 2. INDEXES
-- =============================================================================

CREATE INDEX idx_nav_item_module_id
    ON "NavigationItem" ("NavigationModuleId");

CREATE INDEX idx_role_nav_access_role_id
    ON "RoleNavigationAccess" ("RoleId");

CREATE INDEX idx_role_nav_access_module_id
    ON "RoleNavigationAccess" ("NavigationModuleId");

CREATE INDEX idx_role_nav_access_item_id
    ON "RoleNavigationAccess" ("NavigationItemId");

-- Covering index used by GET /api/navigation — fetches the full nav tree for a role
-- in one pass, ordered and filtered, without hitting the base tables twice.
CREATE INDEX idx_role_nav_access_lookup
    ON "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "DisplayOrder")
    INCLUDE ("NavigationItemId");


-- =============================================================================
-- 3. SEED DATA — Modules
--
-- IDs assigned sequentially by SERIAL:
--   1  Inicio          (shared base module — items differ per role)
--   2  Usuarios        (Administrador only)
--   3  Configuración   (Administrador only)
--   4  Reportes        (Administrador only)
--   5  Pacientes       (Doctor + Enfermero — items differ per role)
--   6  Recetas         (Doctor only)
--   7  Mi perfil       (Doctor + Enfermero)
--   8  Dispensación    (Enfermero only)
-- =============================================================================

INSERT INTO "NavigationModule" ("Label", "Icon") VALUES
    ('Inicio',          'layout-dashboard'),   -- 1
    ('Usuarios',        'users'),              -- 2
    ('Configuración',   'settings'),           -- 3
    ('Reportes',        'chart-bar'),          -- 4
    ('Pacientes',       'users'),              -- 5
    ('Recetas',         'file-text'),          -- 6
    ('Mi perfil',       'user-circle'),        -- 7
    ('Dispensación',    'pill');               -- 8


-- =============================================================================
-- 4. SEED DATA — Items
--
-- IDs assigned sequentially by SERIAL:
--
-- Module 1 — Inicio
--    1  Panel general        (Admin)
--    2  Panel clínico        (Doctor)
--    3  Recetas sin firmar   (Doctor)
--    4  Panel de turno       (Enfermero)
--    5  Pendientes del día   (Enfermero)
--
-- Module 2 — Usuarios
--    6  Lista de usuarios    (Admin)
--    7  Registrar usuario    (Admin)
--    8  Roles y permisos     (Admin)
--
-- Module 3 — Configuración
--    9  Medicamentos         (Admin)
--   10  Especialidades       (Admin)
--   11  Alergias             (Admin)
--   12  Tipos de documento   (Admin)
--
-- Module 4 — Reportes
--   13  Actividad de usuarios  (Admin)
--   14  Recetas emitidas       (Admin)
--
-- Module 5 — Pacientes
--   15  Lista de pacientes   (Doctor + Enfermero)
--   16  Registrar paciente   (Doctor)
--   17  Ver historial        (Enfermero)
--
-- Module 6 — Recetas
--   18  Mis recetas          (Doctor)
--   19  Nueva receta         (Doctor)
--   20  Borradores           (Doctor)
--
-- Module 7 — Mi perfil
--   21  Mis datos            (Doctor + Enfermero)
--   22  Cambiar contraseña   (Doctor + Enfermero)
--
-- Module 8 — Dispensación
--   23  Recetas activas      (Enfermero)
--   24  Dispensar receta     (Enfermero)
--   25  Historial dispensado (Enfermero)
-- =============================================================================

INSERT INTO "NavigationItem" ("NavigationModuleId", "Label", "Icon", "Path", "DisplayOrder") VALUES
    -- Module 1: Inicio
    (1, 'Panel general',        'home',            '/inicio',                      1),   --  1
    (1, 'Panel clínico',        'home',            '/inicio',                      1),   --  2
    (1, 'Recetas sin firmar',   'file-alert',      '/inicio/sin-firmar',           2),   --  3
    (1, 'Panel de turno',       'home',            '/inicio',                      1),   --  4
    (1, 'Pendientes del día',   'clock',           '/inicio/pendientes',           2),   --  5

    -- Module 2: Usuarios
    (2, 'Lista de usuarios',    'list',            '/usuarios',                    1),   --  6
    (2, 'Registrar usuario',    'user-plus',       '/usuarios/nuevo',              2),   --  7
    (2, 'Roles y permisos',     'lock',            '/usuarios/roles',              3),   --  8

    -- Module 3: Configuración
    (3, 'Medicamentos',         'pill',            '/configuracion/medicamentos',  1),   --  9
    (3, 'Especialidades',       'certificate',     '/configuracion/especialidades',2),   -- 10
    (3, 'Alergias',             'alert-triangle',  '/configuracion/alergias',      3),   -- 11
    (3, 'Tipos de documento',   'id-badge',        '/configuracion/documentos',    4),   -- 12

    -- Module 4: Reportes
    (4, 'Actividad de usuarios','activity',        '/reportes/usuarios',           1),   -- 13
    (4, 'Recetas emitidas',     'file-check',      '/reportes/recetas',            2),   -- 14

    -- Module 5: Pacientes
    (5, 'Lista de pacientes',   'list',            '/pacientes',                   1),   -- 15
    (5, 'Registrar paciente',   'user-plus',       '/pacientes/nuevo',             2),   -- 16
    (5, 'Ver historial',        'history',         '/pacientes/historial',         3),   -- 17

    -- Module 6: Recetas
    (6, 'Mis recetas',          'list',            '/recetas',                     1),   -- 18
    (6, 'Nueva receta',         'plus',            '/recetas/nueva',               2),   -- 19
    (6, 'Borradores',           'pencil',          '/recetas/borradores',          3),   -- 20

    -- Module 7: Mi perfil
    (7, 'Mis datos',            'id-badge',        '/perfil',                      1),   -- 21
    (7, 'Cambiar contraseña',   'lock',            '/perfil/clave',                2),   -- 22

    -- Module 8: Dispensación
    (8, 'Recetas activas',      'file-check',      '/dispensacion',                1),   -- 23
    (8, 'Dispensar receta',     'arrow-bar-right', '/dispensacion/dispensar',      2),   -- 24
    (8, 'Historial dispensado', 'history',         '/dispensacion/historial',      3);   -- 25


-- =============================================================================
-- 5. SEED DATA — Role navigation access
--
-- Role IDs:  1 = Administrador  |  2 = Doctor  |  3 = Enfermero
-- DisplayOrder on module rows (item IS NULL) = topbar position.
-- DisplayOrder on item rows                  = sidebar position for that role.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Administrador (RoleId = 1)
-- Topbar: Inicio(1) · Usuarios(2) · Configuración(3) · Reportes(4)
-- ---------------------------------------------------------------------------

INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder") VALUES

    -- Topbar entries
    (1, 1, NULL, 1),   -- Inicio
    (1, 2, NULL, 2),   -- Usuarios
    (1, 3, NULL, 3),   -- Configuración
    (1, 4, NULL, 4),   -- Reportes

    -- Inicio items
    (1, 1, 1, 1),      -- Panel general

    -- Usuarios items
    (1, 2, 6, 1),      -- Lista de usuarios
    (1, 2, 7, 2),      -- Registrar usuario
    (1, 2, 8, 3),      -- Roles y permisos

    -- Configuración items
    (1, 3, 9,  1),     -- Medicamentos
    (1, 3, 10, 2),     -- Especialidades
    (1, 3, 11, 3),     -- Alergias
    (1, 3, 12, 4),     -- Tipos de documento

    -- Reportes items
    (1, 4, 13, 1),     -- Actividad de usuarios
    (1, 4, 14, 2);     -- Recetas emitidas


-- ---------------------------------------------------------------------------
-- Doctor (RoleId = 2)
-- Topbar: Inicio(1) · Pacientes(2) · Recetas(3) · Mi perfil(4)
-- ---------------------------------------------------------------------------

INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder") VALUES

    -- Topbar entries
    (2, 1, NULL, 1),   -- Inicio
    (2, 5, NULL, 2),   -- Pacientes
    (2, 6, NULL, 3),   -- Recetas
    (2, 7, NULL, 4),   -- Mi perfil

    -- Inicio items
    (2, 1, 2, 1),      -- Panel clínico
    (2, 1, 3, 2),      -- Recetas sin firmar

    -- Pacientes items
    (2, 5, 15, 1),     -- Lista de pacientes
    (2, 5, 16, 2),     -- Registrar paciente

    -- Recetas items
    (2, 6, 18, 1),     -- Mis recetas
    (2, 6, 19, 2),     -- Nueva receta
    (2, 6, 20, 3),     -- Borradores

    -- Mi perfil items
    (2, 7, 21, 1),     -- Mis datos
    (2, 7, 22, 2);     -- Cambiar contraseña


-- ---------------------------------------------------------------------------
-- Enfermero (RoleId = 3)
-- Topbar: Inicio(1) · Pacientes(2) · Dispensación(3) · Mi perfil(4)
-- ---------------------------------------------------------------------------

INSERT INTO "RoleNavigationAccess" ("RoleId", "NavigationModuleId", "NavigationItemId", "DisplayOrder") VALUES

    -- Topbar entries
    (3, 1, NULL, 1),   -- Inicio
    (3, 5, NULL, 2),   -- Pacientes
    (3, 8, NULL, 3),   -- Dispensación
    (3, 7, NULL, 4),   -- Mi perfil

    -- Inicio items
    (3, 1, 4, 1),      -- Panel de turno
    (3, 1, 5, 2),      -- Pendientes del día

    -- Pacientes items
    (3, 5, 15, 1),     -- Lista de pacientes
    (3, 5, 17, 2),     -- Ver historial

    -- Dispensación items
    (3, 8, 23, 1),     -- Recetas activas
    (3, 8, 24, 2),     -- Dispensar receta
    (3, 8, 25, 3),     -- Historial dispensado

    -- Mi perfil items
    (3, 7, 21, 1),     -- Mis datos
    (3, 7, 22, 2);     -- Cambiar contraseña
