import { jest } from '@jest/globals';
import { Logger } from '@nestjs/common';
import { DevicePlatform, NotificationType } from '@prisma/client';
import { DeviceTokensService } from '../../src/notifications/device-tokens.service';
import { MockPushMessagingClient } from '../../src/notifications/push/mock.messaging-client';
import { NotificationPushService } from '../../src/notifications/push/notification-push.service';
import { PushMessagingUnavailableError } from '../../src/notifications/push/push-messaging.client';
import type { PrismaService } from '../../src/prisma/prisma.service';
import { createNotificationPushStore } from './notification-push.fakes';

describe('NotificationPushService (NOTIF-BE-04)', () => {
  let store: ReturnType<typeof createNotificationPushStore>;
  let mock: MockPushMessagingClient;
  let service: NotificationPushService;
  let warnSpy: ReturnType<typeof spyOnWarn>;

  function spyOnWarn() {
    return jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => {});
  }

  async function addToken(userId: string, token: string): Promise<void> {
    await store.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform: DevicePlatform.android },
      update: {},
    });
  }

  function tokensOf(userId: string): string[] {
    return store.deviceTokens
      .filter((row) => row.userId === userId)
      .map((row) => row.token);
  }

  function event(
    overrides: Partial<Parameters<NotificationPushService['dispatch']>[0]> = {},
  ) {
    return {
      userId: 'user-ana',
      notificationId: 'notif-1',
      type: NotificationType.NEW_LOGIN,
      title: 'Nuevo inicio de sesion',
      body: 'Se inicio sesion en un dispositivo nuevo',
      targetRoute: '/app/perfil',
      ...overrides,
    };
  }

  beforeEach(async () => {
    store = createNotificationPushStore();
    mock = new MockPushMessagingClient();
    const prisma = store as unknown as PrismaService;
    service = new NotificationPushService(
      prisma,
      new DeviceTokensService(prisma),
      mock,
    );
    warnSpy = spyOnWarn();
    jest.spyOn(Logger.prototype, 'debug').mockImplementation(() => {});

    await addToken('user-ana', 'fcm-ana-1');
    await addToken('user-ana', 'fcm-ana-2');
    await addToken('user-beto', 'fcm-beto-1');
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('NEW_LOGIN con notificationsEnabled=false envia a todos los tokens de Ana y a ninguno de Beto', async () => {
    store.settings.set('user-ana', { notificationsEnabled: false });

    const result = await service.dispatch(event());

    expect(result).toEqual({
      status: 'sent',
      sent: 2,
      failed: 0,
      removedInvalidTokens: 0,
    });
    expect(mock.sent).toEqual([
      {
        tokens: ['fcm-ana-1', 'fcm-ana-2'],
        title: 'Nuevo inicio de sesion',
        body: 'Se inicio sesion en un dispositivo nuevo',
        data: {
          notificationId: 'notif-1',
          type: 'NEW_LOGIN',
          targetRoute: '/app/perfil',
        },
      },
    ]);
    expect(mock.sent[0].tokens).not.toContain('fcm-beto-1');
  });

  it('PASSWORD_CHANGED sin fila UserSettings tambien envia', async () => {
    const result = await service.dispatch(
      event({ type: NotificationType.PASSWORD_CHANGED }),
    );

    expect(result.status).toBe('sent');
    expect(mock.sent).toHaveLength(1);
  });

  it('REMINDER con notificationsEnabled=false da skipped_preferences sin llamar al cliente', async () => {
    store.settings.set('user-ana', { notificationsEnabled: false });
    const findMany = jest.spyOn(store.deviceToken, 'findMany');

    const result = await service.dispatch(
      event({ type: NotificationType.REMINDER }),
    );

    expect(result).toEqual({
      status: 'skipped_preferences',
      sent: 0,
      failed: 0,
      removedInvalidTokens: 0,
    });
    expect(mock.sent).toEqual([]);
    expect(findMany).not.toHaveBeenCalled();
  });

  it('REMINDER sin fila UserSettings da skipped_preferences', async () => {
    const result = await service.dispatch(
      event({ type: NotificationType.REMINDER }),
    );

    expect(result.status).toBe('skipped_preferences');
    expect(mock.sent).toEqual([]);
  });

  it('REMINDER con true envia y SYSTEM con false da skipped_preferences', async () => {
    store.settings.set('user-ana', { notificationsEnabled: true });
    const reminder = await service.dispatch(
      event({ type: NotificationType.REMINDER }),
    );
    expect(reminder.status).toBe('sent');

    store.settings.set('user-ana', { notificationsEnabled: false });
    mock.reset();
    const system = await service.dispatch(
      event({ type: NotificationType.SYSTEM }),
    );
    expect(system.status).toBe('skipped_preferences');
    expect(mock.sent).toEqual([]);
  });

  it('usuario sin tokens da skipped_no_tokens sin llamar al cliente', async () => {
    store.deviceTokens.splice(0, store.deviceTokens.length);

    const result = await service.dispatch(event());

    expect(result.status).toBe('skipped_no_tokens');
    expect(mock.sent).toEqual([]);
  });

  it('targetRoute null omite la clave y todos los valores de data son string', async () => {
    await service.dispatch(event({ targetRoute: null }));

    const { data } = mock.sent[0];
    expect(data).toEqual({ notificationId: 'notif-1', type: 'NEW_LOGIN' });
    expect(Object.keys(data)).not.toContain('targetRoute');
    expect(Object.values(data).every((v) => typeof v === 'string')).toBe(true);
  });

  it('borra solo los tokens invalidos del usuario y conserva los demas', async () => {
    await addToken('user-ana', 'fcm-ana-3');
    await addToken('user-beto', 'fcm-ana-1-copia');
    mock.failWith('fcm-ana-1', 'messaging/registration-token-not-registered');
    mock.failWith('fcm-ana-2', 'messaging/invalid-registration-token');
    mock.failWith('fcm-ana-3', 'messaging/internal-error');

    const result = await service.dispatch(event());

    expect(result).toEqual({
      status: 'failed',
      sent: 0,
      failed: 3,
      removedInvalidTokens: 2,
    });
    expect(tokensOf('user-ana')).toEqual(['fcm-ana-3']);
    expect(tokensOf('user-beto')).toEqual(['fcm-beto-1', 'fcm-ana-1-copia']);
  });

  it('un token invalido no cuenta como exito y el resto sigue enviando', async () => {
    mock.failWith('fcm-ana-1', 'messaging/registration-token-not-registered');

    const result = await service.dispatch(event());

    expect(result).toEqual({
      status: 'sent',
      sent: 1,
      failed: 1,
      removedInvalidTokens: 1,
    });
    expect(tokensOf('user-ana')).toEqual(['fcm-ana-2']);
  });

  it('un error de red da failed, no rechaza, conserva tokens y no filtra datos en logs', async () => {
    mock.failNextSend(
      Object.assign(new Error('socket hang up token=abc'), {
        code: 'app/network-error',
      }),
    );

    await expect(service.dispatch(event())).resolves.toEqual({
      status: 'failed',
      sent: 0,
      failed: 0,
      removedInvalidTokens: 0,
    });

    expect(tokensOf('user-ana')).toEqual(['fcm-ana-1', 'fcm-ana-2']);
    expect(warnSpy).toHaveBeenCalledTimes(1);
    const logged = JSON.stringify(warnSpy.mock.calls);
    expect(logged).toContain('app/network-error');
    expect(logged).not.toContain('abc');
    expect(logged).not.toContain('socket hang up');
    expect(logged).not.toContain('PRIVATE KEY');
    expect(logged).not.toContain('fcm-ana-1');
  });

  it('PushMessagingUnavailableError da failed sin borrar tokens', async () => {
    mock.failNextSend(new PushMessagingUnavailableError('sin config'));

    const result = await service.dispatch(event());

    expect(result.status).toBe('failed');
    expect(tokensOf('user-ana')).toHaveLength(2);
    expect(JSON.stringify(warnSpy.mock.calls)).toContain(
      'PushMessagingUnavailableError',
    );
  });

  it('si userSettings.findUnique lanza da failed y no rechaza', async () => {
    jest
      .spyOn(store.userSettings, 'findUnique')
      .mockRejectedValue(new Error('db caida'));

    await expect(
      service.dispatch(event({ type: NotificationType.REMINDER })),
    ).resolves.toMatchObject({ status: 'failed' });
    expect(mock.sent).toEqual([]);
  });

  it('si el borrado de un token invalido lanza, no rechaza y sigue con los demas', async () => {
    mock.failWith('fcm-ana-1', 'messaging/registration-token-not-registered');
    mock.failWith('fcm-ana-2', 'messaging/registration-token-not-registered');
    jest
      .spyOn(store.deviceToken, 'deleteMany')
      .mockRejectedValueOnce(new Error('db caida'));

    const result = await service.dispatch(event());

    expect(result.removedInvalidTokens).toBe(1);
  });

  it('dispatchNotification delega con los mismos campos', async () => {
    const result = await service.dispatchNotification({
      id: 'notif-9',
      userId: 'user-ana',
      type: NotificationType.PASSWORD_CHANGED,
      title: 'Contrasena actualizada',
      body: 'Tu contrasena cambio',
      targetRoute: '/app/seguridad',
    });

    expect(result.status).toBe('sent');
    expect(mock.sent[0]).toMatchObject({
      title: 'Contrasena actualizada',
      body: 'Tu contrasena cambio',
      data: {
        notificationId: 'notif-9',
        type: 'PASSWORD_CHANGED',
        targetRoute: '/app/seguridad',
      },
    });
  });
});
