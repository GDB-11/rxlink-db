-- 1) Columna de creación: se rellena con NOW() para filas existentes.
ALTER TABLE "Role"
    ADD COLUMN IF NOT EXISTS "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2) Columna de borrado lógico: NULL por defecto.
ALTER TABLE "Role"
    ADD COLUMN IF NOT EXISTS "DeletedAt" TIMESTAMPTZ NULL;

-- 3) Columna de auditoría "quién desactivó": FK lógica a "User"."UserId".
--    Se mantiene como INTEGER (no FK física) por la misma razón que el
--    resto del esquema: la columna nunca se expone al exterior.
ALTER TABLE "Role"
    ADD COLUMN IF NOT EXISTS "DeletedBy" INTEGER NULL;
