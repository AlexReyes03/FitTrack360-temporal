import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

export const DEFAULT_DEV_CORS_ORIGINS = [
  'http://localhost:8080',
  'http://127.0.0.1:8080',
] as const;

export function resolveCorsOrigins(
  raw: string | undefined = process.env.CORS_ORIGINS,
): string[] {
  if (raw === undefined || raw.trim() === '') {
    return [...DEFAULT_DEV_CORS_ORIGINS];
  }
  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

export function buildCorsOptions(
  raw: string | undefined = process.env.CORS_ORIGINS,
): CorsOptions {
  return {
    origin: resolveCorsOrigins(raw),
    exposedHeaders: ['x-request-id'],
  };
}
