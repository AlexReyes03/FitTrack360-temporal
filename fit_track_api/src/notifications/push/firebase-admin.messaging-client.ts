import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { normalizeFirebasePrivateKey } from '../../auth/firebase-admin.verifier';
import {
  PushMessagingUnavailableError,
  type PushMessage,
  type PushMessagingClient,
  type PushSendResult,
} from './push-messaging.client';

/** Limite de tokens por llamada a `sendEachForMulticast`. */
const FCM_MULTICAST_BATCH_SIZE = 500;

/**
 * Envia push con firebase-admin Messaging.
 * Lazy-init: no falla al arrancar Nest si faltan credenciales; falla al enviar.
 */
@Injectable()
export class FirebaseAdminMessagingClient implements PushMessagingClient {
  private readonly logger = new Logger(FirebaseAdminMessagingClient.name);
  private app: App | null = null;
  private initFailed = false;

  constructor(private readonly config: ConfigService) {}

  async send(message: PushMessage): Promise<PushSendResult[]> {
    const messaging = getMessaging(this.getAppOrThrow());
    const results: PushSendResult[] = [];

    for (
      let start = 0;
      start < message.tokens.length;
      start += FCM_MULTICAST_BATCH_SIZE
    ) {
      const tokens = message.tokens.slice(
        start,
        start + FCM_MULTICAST_BATCH_SIZE,
      );
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: { title: message.title, body: message.body },
        data: message.data,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });

      response.responses.forEach((item, index) => {
        results.push({
          token: tokens[index],
          ok: item.success,
          errorCode: item.error?.code,
        });
      });
    }

    return results;
  }

  private getAppOrThrow(): App {
    this.ensureInitialized();
    if (!this.app) {
      throw new PushMessagingUnavailableError(
        'Firebase Messaging no configurado',
      );
    }
    return this.app;
  }

  private ensureInitialized(): void {
    if (this.app || this.initFailed) return;

    const existing = getApps()[0];
    if (existing) {
      this.app = existing;
      return;
    }

    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) {
      this.failInit('Falta FIREBASE_PROJECT_ID; push no disponible');
      return;
    }

    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = normalizeFirebasePrivateKey(
      this.config.get<string>('FIREBASE_PRIVATE_KEY'),
    );

    try {
      this.app =
        clientEmail && privateKey
          ? initializeApp({
              credential: cert({ projectId, clientEmail, privateKey }),
              projectId,
            })
          : initializeApp({ projectId });
    } catch {
      this.failInit('No se pudo inicializar Firebase Messaging');
    }
  }

  /** Mensaje fijo: el error del SDK puede incluir fragmentos de la credencial. */
  private failInit(reason: string): void {
    this.initFailed = true;
    this.logger.warn(reason);
  }
}
