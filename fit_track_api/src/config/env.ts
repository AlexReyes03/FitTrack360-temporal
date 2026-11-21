import { resolveApiPort } from './port';

export type AppEnv = Record<string, unknown>;

function readTrimmed(env: AppEnv, key: string): string {
  const raw = env[key];
  if (typeof raw !== 'string') {
    return '';
  }
  return raw.trim();
}

function missing(name: string): never {
  throw new Error(`Falta la variable de entorno obligatoria: ${name}`);
}

function requireNonEmpty(env: AppEnv, name: string): string {
  const value = readTrimmed(env, name);
  if (value === '') {
    missing(name);
  }
  return value;
}

function resolveAuthMode(env: AppEnv): 'admin' | 'mock' {
  const raw = readTrimmed(env, 'FIREBASE_AUTH_MODE');
  if (raw === '' || raw === 'admin') {
    return 'admin';
  }
  if (raw === 'mock') {
    return 'mock';
  }
  throw new Error('FIREBASE_AUTH_MODE inválido: usa "admin" o "mock"');
}

function requireFirebaseAdmin(env: AppEnv): void {
  requireNonEmpty(env, 'FIREBASE_PROJECT_ID');

  const credentialsPath = readTrimmed(env, 'GOOGLE_APPLICATION_CREDENTIALS');
  if (credentialsPath !== '') {
    return;
  }

  requireNonEmpty(env, 'FIREBASE_CLIENT_EMAIL');
  requireNonEmpty(env, 'FIREBASE_PRIVATE_KEY');
}

export function validateEnv(env: AppEnv): AppEnv {
  requireNonEmpty(env, 'DATABASE_URL');
  resolveApiPort(typeof env.PORT === 'string' ? env.PORT : undefined);

  const authMode = resolveAuthMode(env);
  if (authMode === 'admin') {
    requireFirebaseAdmin(env);
  }

  return env;
}
