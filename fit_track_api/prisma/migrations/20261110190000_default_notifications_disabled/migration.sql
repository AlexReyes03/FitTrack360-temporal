-- P3: el recordatorio diario empieza apagado hasta que el usuario lo activa
-- y concede el permiso (docs/permisos.md).
ALTER TABLE "UserSettings" ALTER COLUMN "notificationsEnabled" SET DEFAULT false;
