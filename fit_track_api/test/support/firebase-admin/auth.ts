/** Sustituto de `firebase-admin/auth` solo para Jest; ver ./app.ts. */

export type DecodedIdToken = {
  uid: string;
  email?: string;
};

type VerifyIdToken = (
  idToken: string,
  checkRevoked?: boolean,
) => Promise<DecodedIdToken>;

const defaultVerifyIdToken: VerifyIdToken = () => {
  throw new Error('firebase-admin no está disponible en pruebas');
};

let verifyIdTokenImpl: VerifyIdToken = defaultVerifyIdToken;

/** Configura el comportamiento de verifyIdToken en pruebas del Admin verifier. */
export function __setVerifyIdToken(impl: VerifyIdToken): void {
  verifyIdTokenImpl = impl;
}

export function __resetFirebaseAdminAuth(): void {
  verifyIdTokenImpl = defaultVerifyIdToken;
}

export const getAuth = (_app?: unknown) => ({
  verifyIdToken: (idToken: string, checkRevoked?: boolean) =>
    verifyIdTokenImpl(idToken, checkRevoked),
  deleteUser: async (_uid: string) => undefined,
  revokeRefreshTokens: async (_uid: string) => undefined,
});
