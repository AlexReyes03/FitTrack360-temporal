import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import type {
  FirebaseTokenVerifier,
  VerifiedFirebaseToken,
} from './firebase-token.verifier';

/**
 * Verifica ID tokens con firebase-admin.
 * Lazy-init: no falla al arrancar Nest si faltan credenciales; falla al verificar.
 */
@Injectable()
export class FirebaseAdminTokenVerifier implements FirebaseTokenVerifier {
  private readonly logger = new Logger(FirebaseAdminTokenVerifier.name);
  private app: App | null = null;
  private initError: string | null = null;

  constructor(private readonly config: ConfigService) {}

  async verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken> {
    const auth = this.getAuthOrThrow();
    try {
      const decoded = await auth.verifyIdToken(idToken);
      const email = decoded.email;
      if (!email) {
        throw new UnauthorizedException('Token sin correo');
      }
      return { uid: decoded.uid, email };
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Token invalido');
    }
  }

  async revokeRefreshTokens(uid: string): Promise<void> {
    const auth = this.getAuthOrThrow();
    await auth.revokeRefreshTokens(uid);
  }

  private getAuthOrThrow() {
    this.ensureInitialized();
    if (!this.app) {
      throw new ServiceUnavailableException(
        this.initError ?? 'Firebase Admin no configurado',
      );
    }
    return getAuth(this.app);
  }

  private ensureInitialized(): void {
    if (this.app || this.initError) return;

    const existing = getApps()[0];
    if (existing) {
      this.app = existing;
      return;
    }

    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) {
      this.initError =
        'Falta FIREBASE_PROJECT_ID. Completa el checklist de Firebase Auth.';
      this.logger.warn(this.initError);
      return;
    }

    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = normalizeFirebasePrivateKey(
      this.config.get<string>('FIREBASE_PRIVATE_KEY'),
    );

    try {
      if (clientEmail && privateKey) {
        this.app = initializeApp({
          credential: cert({
            projectId,
            clientEmail,
            privateKey,
          }),
          projectId,
        });
        return;
      }

      // ADC / GOOGLE_APPLICATION_CREDENTIALS
      this.app = initializeApp({ projectId });
    } catch (error) {
      this.initError =
        error instanceof Error
          ? error.message
          : 'No se pudo inicializar Firebase Admin';
      this.logger.warn(this.initError);
    }
  }
}

/**
 * Docker --env-file no quita comillas ni convierte \n; dotenv local sí.
 * Normaliza ambos formatos al PEM que espera firebase-admin.
 */
function normalizeFirebasePrivateKey(
  value: string | undefined,
): string | undefined {
  if (!value) {
    return undefined;
  }
  let key = value.trim();
  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    key = key.slice(1, -1);
  }
  if (key.includes('\\n')) {
    key = key.replace(/\\n/g, '\n');
  }
  return key;
}
