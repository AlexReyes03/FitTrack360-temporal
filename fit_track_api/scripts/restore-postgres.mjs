import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const apiRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dumpArg = process.argv[2];

if (!dumpArg) {
  console.error(
    'Uso: node scripts/restore-postgres.mjs <ruta-al-dump.dump>',
  );
  process.exit(1);
}

const dumpPath = path.isAbsolute(dumpArg)
  ? dumpArg
  : path.resolve(process.cwd(), dumpArg);

if (!existsSync(dumpPath)) {
  console.error(`No existe el dump: ${dumpPath}`);
  process.exit(1);
}

const user = process.env.POSTGRES_USER || 'fittrack';
const db = process.env.POSTGRES_DB || 'fittrack_db';
const dumpBytes = readFileSync(dumpPath);

const result = spawnSync(
  'docker',
  [
    'compose',
    'exec',
    '-T',
    'postgres',
    'pg_restore',
    '-U',
    user,
    '-d',
    db,
    '--clean',
    '--if-exists',
    '--no-owner',
    '--no-acl',
  ],
  {
    cwd: apiRoot,
    input: dumpBytes,
    encoding: 'buffer',
    maxBuffer: 1024 * 1024 * 512,
  },
);

const stderr = result.stderr?.toString('utf8') ?? '';
if (result.status !== 0) {
  console.error(stderr || 'pg_restore falló');
  process.exit(result.status ?? 1);
}

if (stderr.trim()) {
  console.warn(stderr.trim());
}
console.log(`Restauración aplicada desde: ${dumpPath}`);
