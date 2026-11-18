/** Sustituto de `firebase-admin/auth` solo para Jest; ver ./app.ts. */
export const getAuth = (): never => {
  throw new Error('firebase-admin no está disponible en pruebas');
};
