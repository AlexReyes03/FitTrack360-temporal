import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirebaseAdminMessagingClient } from './firebase-admin.messaging-client';
import {
  DisabledPushMessagingClient,
  MockPushMessagingClient,
} from './mock.messaging-client';
import type { PushMessagingClient } from './push-messaging.client';

export type PushMessagingMode = 'admin' | 'mock' | 'disabled';

const logger = new Logger('PushMessagingFactory');

/**
 * `FIREBASE_MESSAGING_MODE` vacio hereda `FIREBASE_AUTH_MODE`:
 * `mock` da `mock`, cualquier otro valor da `admin`.
 */
export function resolvePushMessagingMode(
  config: ConfigService,
): PushMessagingMode {
  const raw = config.get<string>('FIREBASE_MESSAGING_MODE')?.trim();

  if (!raw) {
    const authMode = (
      config.get<string>('FIREBASE_AUTH_MODE') ?? 'admin'
    ).toLowerCase();
    return authMode === 'mock' ? 'mock' : 'admin';
  }

  const mode = raw.toLowerCase();
  if (mode === 'admin' || mode === 'mock' || mode === 'disabled') {
    return mode;
  }

  logger.warn('FIREBASE_MESSAGING_MODE desconocido; push deshabilitado');
  return 'disabled';
}

export function createPushMessagingClient(
  config: ConfigService,
): PushMessagingClient {
  switch (resolvePushMessagingMode(config)) {
    case 'admin':
      return new FirebaseAdminMessagingClient(config);
    case 'mock':
      return new MockPushMessagingClient();
    case 'disabled':
      return new DisabledPushMessagingClient();
  }
}
