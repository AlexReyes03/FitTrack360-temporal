import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirebaseAdminTokenVerifier } from '../../src/auth/firebase-admin.verifier';
import { __resetFirebaseAdminApp } from '../support/firebase-admin/app';
import {
  __resetFirebaseAdminAuth,
  __setVerifyIdToken,
} from '../support/firebase-admin/auth';

describe('FirebaseAdminTokenVerifier', () => {
  beforeEach(() => {
    __resetFirebaseAdminApp();
    __resetFirebaseAdminAuth();
  });

  afterEach(() => {
    __resetFirebaseAdminApp();
    __resetFirebaseAdminAuth();
  });

  function createVerifier(): FirebaseAdminTokenVerifier {
    return new FirebaseAdminTokenVerifier(
      new ConfigService({
        FIREBASE_PROJECT_ID: 'demo-project',
        FIREBASE_CLIENT_EMAIL: 'demo@demo-project.iam.gserviceaccount.com',
        FIREBASE_PRIVATE_KEY:
          '-----BEGIN PRIVATE KEY-----\\nMIIE\\n-----END PRIVATE KEY-----\\n',
      }),
    );
  }

  it('pasa checkRevoked=true a auth.verifyIdToken', async () => {
    const calls: Array<{ token: string; checkRevoked?: boolean }> = [];
    __setVerifyIdToken(async (idToken, checkRevoked) => {
      calls.push({ token: idToken, checkRevoked });
      return { uid: 'uid-1', email: 'ana@test.com' };
    });

    const verifier = createVerifier();
    const result = await verifier.verifyIdToken('id-token-demo');

    expect(result).toEqual({ uid: 'uid-1', email: 'ana@test.com' });
    expect(calls).toEqual([{ token: 'id-token-demo', checkRevoked: true }]);
  });

  it('rechaza tokens revocados como UnauthorizedException', async () => {
    __setVerifyIdToken(async () => {
      throw Object.assign(new Error('Firebase ID token has been revoked.'), {
        code: 'auth/id-token-revoked',
      });
    });

    const verifier = createVerifier();
    await expect(
      verifier.verifyIdToken('revoked-token'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
