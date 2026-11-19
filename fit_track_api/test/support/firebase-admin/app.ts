/**
 * Sustituto de `firebase-admin/app` solo para Jest. firebase-admin carga `jose`,
 * que es ESM puro y Jest no puede requerir desde CommonJS; sin este stub,
 * cualquier suite que importe AppModule falla al cargar. Las pruebas de auth
 * usan FIREBASE_AUTH_MODE=mock y nunca verifican tokens reales.
 */
export type App = { name: string };

let apps: App[] = [];

export const getApps = (): App[] => apps;

export const initializeApp = (_options?: unknown): App => {
  const app = { name: '[DEFAULT]' };
  apps = [app];
  return app;
};

export const cert = <T>(creds: T): T => creds;

/** Limpia el estado del stub entre pruebas del Admin verifier. */
export function __resetFirebaseAdminApp(): void {
  apps = [];
}
