import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const apiRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const backupsDir = path.join(apiRoot, 'backups');

const user = process.env.POSTGRES_USER || 'fittrack';
const db = process.env.POSTGRES_DB || 'fittrack_db';

function stamp() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}` +
    `-${pad(now.getHours())}${pad(now.getMinutes())}`
  );
}

mkdirSync(backupsDir, { recursive: true });
const outFile = path.join(backupsDir, `fittrack-${stamp()}.dump`);

const result = spawnSync(
  'docker',
  [
    'compose',
    'exec',
    '-T',
    'postgres',
    'pg_dump',
    '-U',
    user,
    '-d',
    db,
    '-Fc',
  ],
  {
    cwd: apiRoot,
    encoding: 'buffer',
    maxBuffer: 1024 * 1024 * 512,
  },
);

if (result.status !== 0) {
  const err = result.stderr?.toString('utf8') || 'pg_dump falló';
  console.error(err);
  process.exit(result.status ?? 1);
}

writeFileSync(outFile, result.stdout);
console.log(`Respaldo creado: ${outFile}`);
