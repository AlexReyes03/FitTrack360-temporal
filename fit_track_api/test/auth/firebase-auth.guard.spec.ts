import {
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import type { ExecutionContext } from '@nestjs/common';
import { FirebaseAuthGuard } from '../../src/auth/firebase-auth.guard';
import type { FirebaseTokenVerifier } from '../../src/auth/firebase-token.verifier';
import type { PrismaService } from '../../src/prisma/prisma.service';

function createContext(authorization?: string): ExecutionContext {
  const request: { headers: { authorization?: string }; user?: unknown } = {
    headers: { authorization },
  };
  return {
    switchToHttp: () => ({
      getRequest: () => request,
    }),
  } as ExecutionContext;
}

describe('FirebaseAuthGuard', () => {
  const prisma = {
    user: {
      findUnique: async () => null,
    },
  } as unknown as PrismaService;

  it('repropaga ServiceUnavailableException (503) sin convertirlo en 401', async () => {
    const verifier: FirebaseTokenVerifier = {
      verifyIdToken: async () => {
        throw new ServiceUnavailableException('Firebase Admin no configurado');
      },
    };
    const guard = new FirebaseAuthGuard(verifier, prisma);

    await expect(
      guard.canActivate(createContext('Bearer cualquier-token')),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('mapea fallos de token a UnauthorizedException', async () => {
    const verifier: FirebaseTokenVerifier = {
      verifyIdToken: async () => {
        throw new Error('firma invalida');
      },
    };
    const guard = new FirebaseAuthGuard(verifier, prisma);

    await expect(
      guard.canActivate(createContext('Bearer token-malo')),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
