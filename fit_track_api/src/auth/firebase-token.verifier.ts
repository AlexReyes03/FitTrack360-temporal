/** Claims mínimos de un ID token de Firebase Auth. */
export interface VerifiedFirebaseToken {
  uid: string;
  email: string;
}

/**
 * Abstracción para verificar ID tokens. En producción usa firebase-admin;
 * en tests o sin Service Account usa el modo mock.
 */
export interface FirebaseTokenVerifier {
  verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken>;
  /** Revoca refresh tokens del usuario en Firebase (logout remoto). */
  revokeRefreshTokens?(uid: string): Promise<void>;
  deleteUser?(uid: string): Promise<void>;
}

export const FIREBASE_TOKEN_VERIFIER = Symbol('FIREBASE_TOKEN_VERIFIER');

/** Prefijo de tokens aceptados solo cuando FIREBASE_AUTH_MODE=mock. */
export const MOCK_ID_TOKEN_PREFIX = 'mock:';

/**
 * Verifier de desarrollo/CI: acepta `mock:<uid>:<email>` sin Admin SDK.
 * No usar en producción.
 */
export class MockFirebaseTokenVerifier implements FirebaseTokenVerifier {
  async verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken> {
    if (!idToken.startsWith(MOCK_ID_TOKEN_PREFIX)) {
      throw new Error('Token mock invalido');
    }
    const rest = idToken.slice(MOCK_ID_TOKEN_PREFIX.length);
    const sep = rest.indexOf(':');
    if (sep <= 0 || sep === rest.length - 1) {
      throw new Error('Token mock invalido');
    }
    // mock:<uid>:<email> o mock:<uid>:<email>:<provider>; el proveedor se
    // acepta para simular Google pero el backend no lo usa.
    const [uid, email = ''] = rest.split(':');
    if (!uid || !email.includes('@')) {
      throw new Error('Token mock invalido');
    }
    return { uid, email };
  }

  async deleteUser(_uid: string): Promise<void> {
    // No existe una identidad persistida en modo mock.
  }

  async revokeRefreshTokens(_uid: string): Promise<void> {
    // No-op en mock.
  }
}
