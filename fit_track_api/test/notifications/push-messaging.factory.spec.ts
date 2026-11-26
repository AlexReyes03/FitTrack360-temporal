import { jest } from '@jest/globals';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirebaseAdminMessagingClient } from '../../src/notifications/push/firebase-admin.messaging-client';
import {
  DisabledPushMessagingClient,
  MockPushMessagingClient,
} from '../../src/notifications/push/mock.messaging-client';
import {
  createPushMessagingClient,
  resolvePushMessagingMode,
} from '../../src/notifications/push/push-messaging.factory';

describe('push-messaging.factory', () => {
  // ConfigService.get consulta process.env antes que su config interna, lo que
  // hace depender el spec de las variables del CI. El stub lo aisla.
  const config = (values: Record<string, string>) =>
    ({ get: (key: string) => values[key] }) as unknown as ConfigService;

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it.each([
    [{ FIREBASE_MESSAGING_MODE: 'admin' }, FirebaseAdminMessagingClient],
    [{ FIREBASE_MESSAGING_MODE: 'MOCK' }, MockPushMessagingClient],
    [{ FIREBASE_MESSAGING_MODE: 'Disabled' }, DisabledPushMessagingClient],
    [
      { FIREBASE_MESSAGING_MODE: 'admin', FIREBASE_AUTH_MODE: 'mock' },
      FirebaseAdminMessagingClient,
    ],
  ])('modo explicito %j', (values, expected) => {
    expect(createPushMessagingClient(config(values))).toBeInstanceOf(expected);
  });

  it.each([
    [{ FIREBASE_AUTH_MODE: 'mock' }, MockPushMessagingClient],
    [
      { FIREBASE_AUTH_MODE: 'MOCK', FIREBASE_MESSAGING_MODE: '  ' },
      MockPushMessagingClient,
    ],
    [{ FIREBASE_AUTH_MODE: 'admin' }, FirebaseAdminMessagingClient],
    [{}, FirebaseAdminMessagingClient],
  ])('vacio hereda FIREBASE_AUTH_MODE %j', (values, expected) => {
    expect(createPushMessagingClient(config(values))).toBeInstanceOf(expected);
  });

  it('un valor desconocido da Disabled y avisa una vez sin repetir el valor', () => {
    const warn = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => {});

    const client = createPushMessagingClient(
      config({ FIREBASE_MESSAGING_MODE: 'secreto-raro' }),
    );

    expect(client).toBeInstanceOf(DisabledPushMessagingClient);
    expect(warn).toHaveBeenCalledWith(
      'FIREBASE_MESSAGING_MODE desconocido; push deshabilitado',
    );
    expect(
      resolvePushMessagingMode(config({ FIREBASE_MESSAGING_MODE: 'x' })),
    ).toBe('disabled');
  });

  it('DisabledPushMessagingClient no envia nada', async () => {
    await expect(new DisabledPushMessagingClient().send()).resolves.toEqual([]);
  });
});
