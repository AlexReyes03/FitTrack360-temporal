import { NotFoundException } from '@nestjs/common';
import { DevicePlatform } from '@prisma/client';
import { DeviceTokensService } from '../../src/notifications/device-tokens.service';
import type { PrismaService } from '../../src/prisma/prisma.service';
import { createDeviceTokensStore } from './device-tokens.fakes';

describe('DeviceTokensService (NOTIF-BE-03)', () => {
  let store: ReturnType<typeof createDeviceTokensStore>;
  let service: DeviceTokensService;

  beforeEach(() => {
    store = createDeviceTokensStore();
    service = new DeviceTokensService(store as unknown as PrismaService);
  });

  it('registra un token FCM vinculado al userId autenticado y omite el token en la respuesta', async () => {
    const result = await service.register('user-ana', {
      token: 'fcm-token-ana-1',
      platform: DevicePlatform.android,
      label: 'Pixel 8 de Ana',
    });

    expect(result).toMatchObject({
      id: expect.any(String),
      platform: DevicePlatform.android,
      label: 'Pixel 8 de Ana',
      lastSeenAt: expect.any(String),
    });
    expect(result).not.toHaveProperty('token');
    expect(store.deviceTokens).toHaveLength(1);
    expect(store.deviceTokens[0]).toMatchObject({
      userId: 'user-ana',
      token: 'fcm-token-ana-1',
      deviceLabel: 'Pixel 8 de Ana',
    });
  });

  it('hace upsert idempotente para el mismo usuario sin duplicados y conserva label si se omite', async () => {
    const first = await service.register('user-ana', {
      token: 'fcm-token-ana-1',
      platform: DevicePlatform.android,
      label: 'Pixel 8',
    });

    const second = await service.register('user-ana', {
      token: 'fcm-token-ana-1',
      platform: DevicePlatform.ios,
    });

    expect(second.id).toBe(first.id);
    expect(second.platform).toBe(DevicePlatform.ios);
    expect(second.label).toBe('Pixel 8');
    expect(store.deviceTokens).toHaveLength(1);
  });

  it('reasigna el mismo token físico de User A a User B sin duplicados ni fuga de etiqueta', async () => {
    const first = await service.register('user-ana', {
      token: 'shared-device-token',
      platform: DevicePlatform.android,
      label: 'Teléfono personal de Ana',
    });

    const reassigned = await service.register('user-beto', {
      token: 'shared-device-token',
      platform: DevicePlatform.android,
    });

    expect(reassigned.id).toBe(first.id);
    expect(reassigned.label).toBeNull();
    expect(store.deviceTokens).toHaveLength(1);
    expect(store.deviceTokens[0].userId).toBe('user-beto');

    await expect(service.findAll('user-ana')).resolves.toEqual([]);
    await expect(service.findOne('user-ana', first.id)).rejects.toThrow(
      NotFoundException,
    );
    await expect(service.findOne('user-beto', first.id)).resolves.toMatchObject(
      { id: first.id },
    );
  });

  it('rota el token revocando el previousToken solo si pertenece al mismo usuario', async () => {
    await service.register('user-ana', {
      token: 'old-token-ana',
      platform: DevicePlatform.android,
    });
    await service.register('user-beto', {
      token: 'token-beto-intacto',
      platform: DevicePlatform.ios,
    });

    // User A rota su token
    await service.register('user-ana', {
      token: 'new-token-ana',
      platform: DevicePlatform.android,
      previousToken: 'old-token-ana',
    });

    // User B intenta rotar pasando el token de User A como previousToken
    await service.register('user-beto', {
      token: 'new-token-beto',
      platform: DevicePlatform.ios,
      previousToken: 'new-token-ana',
    });

    expect(store.deviceTokens.map((d) => d.token).sort()).toEqual([
      'new-token-ana',
      'new-token-beto',
      'token-beto-intacto',
    ]);
  });

  it('revoca por id validando ownership y lanza 404 ante id inexistente o ajeno (S4)', async () => {
    const anaDevice = await service.register('user-ana', {
      token: 'token-ana-delete',
      platform: DevicePlatform.android,
    });

    await expect(service.removeById('user-beto', anaDevice.id)).rejects.toThrow(
      NotFoundException,
    );
    expect(store.deviceTokens).toHaveLength(1);

    await service.removeById('user-ana', anaDevice.id);
    expect(store.deviceTokens).toHaveLength(0);

    await expect(service.removeById('user-ana', anaDevice.id)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('revoca por valor de token únicamente para el usuario actor sin afectar registros ajenos', async () => {
    await service.register('user-ana', {
      token: 'token-ana-revoke',
      platform: DevicePlatform.ios,
    });

    await service.revokeByToken('user-beto', 'token-ana-revoke');
    expect(store.deviceTokens).toHaveLength(1);

    await service.revokeByToken('user-ana', 'token-ana-revoke');
    expect(store.deviceTokens).toHaveLength(0);

    // Idempotente cuando el token ya no existe
    await expect(
      service.revokeByToken('user-ana', 'token-ana-revoke'),
    ).resolves.toBeUndefined();
  });
});
