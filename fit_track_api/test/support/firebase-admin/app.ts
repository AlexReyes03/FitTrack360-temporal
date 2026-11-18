/**
 * Sustituto de `firebase-admin/app` solo para Jest. firebase-admin carga `jose`,
 * que es ESM puro y Jest no puede requerir desde CommonJS; sin este stub,
 * cualquier suite que importe AppModule falla al cargar. Las pruebas de auth
 * usan FIREBASE_AUTH_MODE=mock y nunca verifican tokens reales.
 */
const notAvailable = (): never => {
  throw new Error('firebase-admin no está disponible en pruebas');
};

export type App = { name: string };
export const getApps = (): App[] => [];
export const initializeApp = notAvailable;
export const cert = notAvailable;
