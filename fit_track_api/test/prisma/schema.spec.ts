import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

const SCHEMA = join(process.cwd(), 'prisma', 'schema.prisma');

/** Ejecuta `prisma validate` sobre un esquema; no necesita base de datos. */
function validateSchema(schemaPath: string): void {
  execFileSync(
    join(process.cwd(), 'node_modules', '.bin', 'prisma'),
    ['validate', '--schema', schemaPath],
    {
      env: {
        ...process.env,
        DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
      },
      stdio: 'pipe',
    },
  );
}

describe('prisma/schema.prisma', () => {
  // Regresión: un merge movió los índices del catálogo Exercise a
  // RoutineExercise y prisma generate dejó de funcionar en main.
  it('es un esquema válido para prisma generate', () => {
    expect(() => validateSchema(SCHEMA)).not.toThrow();
  });
});
