import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../prisma/prisma.service';
import {
  FIREBASE_TOKEN_VERIFIER,
  type FirebaseTokenVerifier,
} from './firebase-token.verifier';

export interface AuthPayload {
  sub: string;
  email: string;
  firebaseUid: string;
}

/** Alias histórico: controllers usan request.user.sub como userId de Postgres. */
export type JwtPayload = AuthPayload;

export type AuthenticatedRequest = Request & { user?: AuthPayload };

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    @Inject(FIREBASE_TOKEN_VERIFIER)
    private readonly verifier: FirebaseTokenVerifier,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Token requerido');
    }

    const idToken = header.slice('Bearer '.length);
    let verified;
    try {
      verified = await this.verifier.verifyIdToken(idToken);
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }
      throw new UnauthorizedException('Token invalido');
    }

    const user = await this.prisma.user.findUnique({
      where: { firebaseUid: verified.uid },
    });
    if (!user) {
      throw new UnauthorizedException('Usuario no sincronizado');
    }

    request.user = {
      sub: user.id,
      email: user.email,
      firebaseUid: verified.uid,
    };
    return true;
  }
}

/** Nombre previo del guard; se reexporta para no romper imports de módulos. */
export { FirebaseAuthGuard as JwtAuthGuard };
