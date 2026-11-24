import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { APP_HTTP_OPTIONS, configureApp } from '../../src/app.setup';
import {
  FIREBASE_TOKEN_VERIFIER,
  MockFirebaseTokenVerifier,
} from '../../src/auth/firebase-token.verifier';
import { NotificationsModule } from '../../src/notifications/notifications.module';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import {
  createDeviceTokensStore,
  mockIdToken,
  sampleUsers,
} from './device-tokens.fakes';

describe('Ciclo de vida de DeviceToken /api/v1/notifications/devices (NOTIF-BE-03)', () => {
  let app: INestApplication<App>;
  let store: ReturnType<typeof createDeviceTokensStore>;
  let anaToken: string;
  let betoToken: string;

  beforeEach(async () => {
    store = createDeviceTokensStore(sampleUsers());
    anaToken = mockIdToken('firebase-ana', 'ana@test.com');
    betoToken = mockIdToken('firebase-beto', 'beto@test.com');

    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          load: [
            () => ({ FIREBASE_AUTH_MODE: 'mock', SMTP_HOST: 'localhost' }),
          ],
        }),
        PrismaModule,
        NotificationsModule,
      ],
    })
      .overrideProvider(PrismaService)
      .useValue(store)
      .overrideProvider(FIREBASE_TOKEN_VERIFIER)
      .useValue(new MockFirebaseTokenVerifier())
      .compile();

    app =
      moduleRef.createNestApplication<INestApplication<App>>(APP_HTTP_OPTIONS);
    configureApp(app);
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  const server = () => app.getHttpServer();

  it('sin token Bearer responde 401 en todos los endpoints de dispositivos', async () => {
    await request(server())
      .post('/api/v1/notifications/devices')
      .send({ token: 'fcm-1', platform: 'android' })
      .expect(401);
    await request(server()).get('/api/v1/notifications/devices').expect(401);
    await request(server())
      .get('/api/v1/notifications/devices/dev-1')
      .expect(401);
    await request(server())
      .delete('/api/v1/notifications/devices/dev-1')
      .expect(401);
    await request(server())
      .post('/api/v1/notifications/devices/revoke')
      .send({ token: 'fcm-1' })
      .expect(401);
  });

  it('registra un token FCM vinculado a User A y nunca devuelve el valor crudo del token', async () => {
    const fcmSecret = 'fcm-sensitive-token-value-12345';

    const res = await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({
        token: fcmSecret,
        platform: 'android',
        label: 'Pixel 8 de Ana',
      })
      .expect(200);

    expect(res.body).toMatchObject({
      id: expect.any(String),
      platform: 'android',
      label: 'Pixel 8 de Ana',
      lastSeenAt: expect.any(String),
      createdAt: expect.any(String),
      updatedAt: expect.any(String),
    });
    expect(JSON.stringify(res.body)).not.toContain(fcmSecret);
    expect(store.deviceTokens).toHaveLength(1);
    expect(store.deviceTokens[0].userId).toBe('user-ana');
  });

  it('reasigna el mismo token físico de User A a User B sin duplicados y corta acceso cruzado', async () => {
    const physicalToken = 'physical-device-fcm-token-abc';

    const anaReg = await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({
        token: physicalToken,
        platform: 'android',
        label: 'Celular de Ana',
      })
      .expect(200);

    const betoReg = await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${betoToken}`)
      .send({
        token: physicalToken,
        platform: 'android',
        label: 'Celular de Beto',
      })
      .expect(200);

    expect(betoReg.body.id).toBe(anaReg.body.id);
    expect(betoReg.body.label).toBe('Celular de Beto');
    expect(store.deviceTokens).toHaveLength(1);
    expect(store.deviceTokens[0].userId).toBe('user-beto');

    // User A pierde acceso cruzado: lista vacía y 404 en consulta/borrado del :id
    const anaList = await request(server())
      .get('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(200);
    expect(anaList.body).toEqual([]);

    await request(server())
      .get(`/api/v1/notifications/devices/${anaReg.body.id}`)
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(404);

    await request(server())
      .delete(`/api/v1/notifications/devices/${anaReg.body.id}`)
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(404);

    // User B conserva su fila activa
    const betoDevice = await request(server())
      .get(`/api/v1/notifications/devices/${betoReg.body.id}`)
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(200);
    expect(betoDevice.body.id).toBe(betoReg.body.id);
  });

  it('soporta rotación de token y revocación por :id y por token eliminando las filas', async () => {
    const initial = await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ token: 'fcm-v1', platform: 'ios', label: 'iPhone de Ana' })
      .expect(200);

    // Rotación atómica: registra fcm-v2 y depreca fcm-v1
    const rotated = await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({
        token: 'fcm-v2',
        platform: 'ios',
        label: 'iPhone de Ana',
        previousToken: 'fcm-v1',
      })
      .expect(200);

    expect(rotated.body.id).not.toBe(initial.body.id);
    expect(store.deviceTokens).toHaveLength(1);
    expect(store.deviceTokens[0].token).toBe('fcm-v2');

    // Revocación por :id
    await request(server())
      .delete(`/api/v1/notifications/devices/${rotated.body.id}`)
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(204);
    expect(store.deviceTokens).toHaveLength(0);

    // Nuevo registro y revocación por token en body (flujo logout / P3 off)
    await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ token: 'fcm-v3', platform: 'ios' })
      .expect(200);
    expect(store.deviceTokens).toHaveLength(1);

    await request(server())
      .post('/api/v1/notifications/devices/revoke')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ token: 'fcm-v3' })
      .expect(204);
    expect(store.deviceTokens).toHaveLength(0);
  });

  it('aislamiento S4: User B recibe 404 (nunca 403) al consultar o borrar el :id de User A y /revoke no toca tokens ajenos', async () => {
    const anaDevice = await request(server())
      .post('/api/v1/notifications/devices')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ token: 'fcm-ana-private', platform: 'android' })
      .expect(200);

    const getRes = await request(server())
      .get(`/api/v1/notifications/devices/${anaDevice.body.id}`)
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(404);
    expect(getRes.body.code).toBe('NOT_FOUND');

    const delRes = await request(server())
      .delete(`/api/v1/notifications/devices/${anaDevice.body.id}`)
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(404);
    expect(delRes.body.code).toBe('NOT_FOUND');

    // /revoke por valor ajeno responde 204 sin revelar existencia ni borrar el registro de Ana
    await request(server())
      .post('/api/v1/notifications/devices/revoke')
      .set('Authorization', `Bearer ${betoToken}`)
      .send({ token: 'fcm-ana-private' })
      .expect(204);

    expect(store.deviceTokens).toHaveLength(1);
    expect(store.deviceTokens[0].userId).toBe('user-ana');
  });

  it.each([
    ['token vacío', { token: '   ', platform: 'android' }],
    ['token numérico', { token: 12345, platform: 'android' }],
    ['token demasiado largo', { token: 'a'.repeat(513), platform: 'android' }],
    [
      'token con espacios internos',
      { token: 'secret token with spaces', platform: 'android' },
    ],
    ['plataforma inválida', { token: 'fcm-secret-999', platform: 'web' }],
    [
      'etiqueta vacía',
      { token: 'fcm-secret-999', platform: 'ios', label: '   ' },
    ],
    [
      'etiqueta demasiado larga',
      { token: 'fcm-secret-999', platform: 'ios', label: 'x'.repeat(101) },
    ],
    [
      'campo no permitido (userId)',
      { token: 'fcm-secret-999', platform: 'android', userId: 'user-beto' },
    ],
    [
      'previousToken inválido',
      {
        token: 'fcm-secret-999',
        platform: 'android',
        previousToken: '   ',
      },
    ],
  ])(
    'POST /devices con %s responde 400 y jamás filtra el token en el error',
    async (_caso, body) => {
      const res = await request(server())
        .post('/api/v1/notifications/devices')
        .set('Authorization', `Bearer ${anaToken}`)
        .send(body)
        .expect(400);

      expect(res.body.code).toBe('VALIDATION_ERROR');
      const serialized = JSON.stringify(res.body);
      expect(serialized).not.toContain('fcm-secret-999');
      expect(serialized).not.toContain('secret token with spaces');
      expect(serialized).not.toContain('a'.repeat(50));
      expect(store.deviceTokens).toHaveLength(0);
    },
  );

  it('POST /devices/revoke con payload inválido responde 400 sin filtrar el token', async () => {
    const oversized = 'z'.repeat(513);
    const res = await request(server())
      .post('/api/v1/notifications/devices/revoke')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ token: oversized })
      .expect(400);

    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(JSON.stringify(res.body)).not.toContain('z'.repeat(50));
  });

  it('documenta las rutas de dispositivos en OpenAPI (/api/docs-json)', async () => {
    const res = await request(server()).get('/api/docs-json').expect(200);
    const paths = res.body.paths as Record<string, Record<string, unknown>>;

    expect(paths['/api/v1/notifications/devices']?.post).toBeDefined();
    expect(paths['/api/v1/notifications/devices']?.get).toBeDefined();
    expect(paths['/api/v1/notifications/devices/revoke']?.post).toBeDefined();
    expect(paths['/api/v1/notifications/devices/{id}']?.get).toBeDefined();
    expect(paths['/api/v1/notifications/devices/{id}']?.delete).toBeDefined();
  });
});
