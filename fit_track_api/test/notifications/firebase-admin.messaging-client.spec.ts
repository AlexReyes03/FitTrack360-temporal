import { jest } from '@jest/globals';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirebaseAdminMessagingClient } from '../../src/notifications/push/firebase-admin.messaging-client';
import { PushMessagingUnavailableError } from '../../src/notifications/push/push-messaging.client';
import {
  __resetFirebaseAdminApp,
  getApps,
  initializeApp,
} from '../support/firebase-admin/app';
import {
  __resetFirebaseAdminMessaging,
  __setSendEachForMulticast,
  type MulticastMessage,
} from '../support/firebase-admin/messaging';

describe('FirebaseAdminMessagingClient', () => {
  beforeEach(() => {
    __resetFirebaseAdminApp();
    __resetFirebaseAdminMessaging();
  });

  afterEach(() => {
    __resetFirebaseAdminApp();
    __resetFirebaseAdminMessaging();
  });

  const fullConfig = {
    FIREBASE_PROJECT_ID: 'demo-project',
    FIREBASE_CLIENT_EMAIL: 'demo@demo-project.iam.gserviceaccount.com',
    FIREBASE_PRIVATE_KEY:
      '-----BEGIN PRIVATE KEY-----\\nMIIE\\n-----END PRIVATE KEY-----\\n',
  };

  function createClient(values: Record<string, string> = fullConfig) {
    return new FirebaseAdminMessagingClient(new ConfigService(values));
  }

  function allSuccess(message: MulticastMessage) {
    return Promise.resolve({
      responses: message.tokens.map(() => ({ success: true })),
      successCount: message.tokens.length,
      failureCount: 0,
    });
  }

  it('llama a sendEachForMulticast con notification, data y tokens y mapea success/error.code por indice', async () => {
    const calls: MulticastMessage[] = [];
    __setSendEachForMulticast((message) => {
      calls.push(message);
      return Promise.resolve({
        responses: [
          { success: true },
          {
            success: false,
            error: { code: 'messaging/registration-token-not-registered' },
          },
        ],
        successCount: 1,
        failureCount: 1,
      });
    });

    const results = await createClient().send({
      tokens: ['t1', 't2'],
      title: 'Titulo',
      body: 'Cuerpo',
      data: { notificationId: 'n1', type: 'NEW_LOGIN' },
    });

    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({
      tokens: ['t1', 't2'],
      notification: { title: 'Titulo', body: 'Cuerpo' },
      data: { notificationId: 'n1', type: 'NEW_LOGIN' },
    });
    expect(results).toEqual([
      { token: 't1', ok: true, errorCode: undefined },
      {
        token: 't2',
        ok: false,
        errorCode: 'messaging/registration-token-not-registered',
      },
    ]);
  });

  it('parte 501 tokens en 2 llamadas (500 + 1) y concatena resultados en orden', async () => {
    const sizes: number[] = [];
    __setSendEachForMulticast((message) => {
      sizes.push(message.tokens.length);
      return allSuccess(message);
    });
    const tokens = Array.from({ length: 501 }, (_, i) => `token-${i}`);

    const results = await createClient().send({
      tokens,
      title: 't',
      body: 'b',
      data: {},
    });

    expect(sizes).toEqual([500, 1]);
    expect(results.map((r) => r.token)).toEqual(tokens);
  });

  it('sin FIREBASE_PROJECT_ID lanza PushMessagingUnavailableError y no llama al SDK', async () => {
    const warn = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => {});
    const sdk = jest.fn(allSuccess);
    __setSendEachForMulticast(sdk);
    const client = createClient({});

    await expect(
      client.send({ tokens: ['t1'], title: 't', body: 'b', data: {} }),
    ).rejects.toBeInstanceOf(PushMessagingUnavailableError);
    await expect(
      client.send({ tokens: ['t1'], title: 't', body: 'b', data: {} }),
    ).rejects.toBeInstanceOf(PushMessagingUnavailableError);
    expect(sdk).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    warn.mockRestore();
  });

  it('reutiliza la app existente sin un segundo initializeApp', async () => {
    const existing = initializeApp();
    __setSendEachForMulticast(allSuccess);

    await createClient({}).send({
      tokens: ['t1'],
      title: 't',
      body: 'b',
      data: {},
    });

    expect(getApps()).toEqual([existing]);
  });
});
