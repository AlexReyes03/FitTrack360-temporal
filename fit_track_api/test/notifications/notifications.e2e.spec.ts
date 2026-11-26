import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Notification, NotificationType } from '@prisma/client';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { APP_HTTP_OPTIONS, configureApp } from '../../src/app.setup';
import {
  FIREBASE_TOKEN_VERIFIER,
  MockFirebaseTokenVerifier,
} from '../../src/auth/firebase-token.verifier';
import { NotificationsModule } from '../../src/notifications/notifications.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import {
  createDeviceTokensStore,
  mockIdToken,
  sampleUsers,
} from './device-tokens.fakes';

type Where = {
  userId?: string;
  id?: string;
  isRead?: boolean;
  type?: NotificationType;
};
function fakeStore() {
  const store = createDeviceTokensStore(sampleUsers());
  const notifications: Notification[] = [
    {
      id: 'a1',
      userId: 'user-ana',
      type: 'NEW_LOGIN',
      title: 'Acceso',
      body: 'Nuevo acceso',
      isRead: false,
      readAt: null,
      targetRoute: null,
      metadata: null,
      createdAt: new Date('2026-01-03'),
    },
    {
      id: 'a2',
      userId: 'user-ana',
      type: 'PASSWORD_CHANGED',
      title: 'Clave',
      body: 'Actualizada',
      isRead: true,
      readAt: new Date('2026-01-02'),
      targetRoute: null,
      metadata: null,
      createdAt: new Date('2026-01-02'),
    },
    {
      id: 'a3',
      userId: 'user-ana',
      type: 'REMINDER',
      title: 'Aviso',
      body: 'Entrena',
      isRead: false,
      readAt: null,
      targetRoute: null,
      metadata: null,
      createdAt: new Date('2026-01-01'),
    },
    {
      id: 'b1',
      userId: 'user-beto',
      type: 'SYSTEM',
      title: 'Privado',
      body: 'Beto',
      isRead: false,
      readAt: null,
      targetRoute: null,
      metadata: null,
      createdAt: new Date('2026-01-04'),
    },
  ];
  const match = (row: Notification, where: Where) =>
    Object.entries(where).every(
      ([key, value]) => row[key as keyof Notification] === value,
    );
  return {
    ...store,
    notifications,
    notification: {
      findMany: async ({
        where,
        skip,
        take,
      }: {
        where: Where;
        skip: number;
        take: number;
      }) =>
        notifications
          .filter((n) => match(n, where))
          .sort(
            (a, b) =>
              b.createdAt.getTime() - a.createdAt.getTime() ||
              b.id.localeCompare(a.id),
          )
          .slice(skip, skip + take),
      count: async ({ where }: { where: Where }) =>
        notifications.filter((n) => match(n, where)).length,
      findFirst: async ({ where }: { where: Where }) =>
        notifications.find((n) => match(n, where)) ?? null,
      updateMany: async ({
        where,
        data,
      }: {
        where: Where;
        data: { isRead: boolean; readAt: Date | null };
      }) => {
        const found = notifications.filter((n) => match(n, where));
        found.forEach((n) => Object.assign(n, data));
        return { count: found.length };
      },
      deleteMany: async ({ where }: { where: Where }) => {
        const found = notifications.filter((n) => match(n, where));
        for (const row of found)
          notifications.splice(notifications.indexOf(row), 1);
        return { count: found.length };
      },
    },
  };
}

describe('Notificaciones /api/v1/notifications', () => {
  let app: INestApplication<App>;
  let store: ReturnType<typeof fakeStore>;
  const ana = `Bearer ${mockIdToken('firebase-ana', 'ana@test.com')}`;
  const beto = `Bearer ${mockIdToken('firebase-beto', 'beto@test.com')}`;
  const url = '/api/v1/notifications';
  beforeEach(async () => {
    store = fakeStore();
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          load: [
            () => ({ FIREBASE_AUTH_MODE: 'mock', SMTP_HOST: 'localhost' }),
          ],
        }),
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

  it('requiere autenticación y valida consultas y cuerpo', async () => {
    await request(server()).get(url).expect(401);
    for (const query of [
      'isRead=yes',
      'type=OTHER',
      'page=0',
      'page=1000001',
      'pageSize=101',
      'unexpected=x',
    ]) {
      await request(server())
        .get(`${url}?${query}`)
        .set('Authorization', ana)
        .expect(400);
    }
    for (const payload of [
      {},
      { isRead: 'true' },
      { isRead: true, userId: 'user-beto' },
    ]) {
      await request(server())
        .patch(`${url}/a1/read`)
        .set('Authorization', ana)
        .send(payload)
        .expect(400);
    }
  });

  it('pagina y filtra por lectura y tipo sin mezclar usuarios, con tipos del cliente', async () => {
    const page = await request(server())
      .get(`${url}?page=2&pageSize=1`)
      .set('Authorization', ana)
      .expect(200);
    expect(page.body).toMatchObject({
      page: 2,
      pageSize: 1,
      total: 3,
      items: [{ id: 'a2', type: 'password_changed', body: 'Actualizada' }],
    });
    const unread = await request(server())
      .get(`${url}?isRead=false`)
      .set('Authorization', ana)
      .expect(200);
    expect(unread.body.items.map((n: { id: string }) => n.id)).toEqual([
      'a1',
      'a3',
    ]);
    const read = await request(server())
      .get(`${url}?isRead=true&type=password_changed`)
      .set('Authorization', ana)
      .expect(200);
    expect(read.body.items).toMatchObject([
      { id: 'a2', type: 'password_changed' },
    ]);
    const login = await request(server())
      .get(`${url}?type=new_login`)
      .set('Authorization', ana)
      .expect(200);
    expect(login.body.items).toMatchObject([{ id: 'a1', type: 'new_login' }]);
    await request(server())
      .get(`${url}/devices`)
      .set('Authorization', ana)
      .expect(200);
  });

  it('actualiza lectura y conteo; limita lecturas y escrituras a su dueño', async () => {
    await request(server())
      .get(`${url}/unread-count`)
      .set('Authorization', ana)
      .expect(200, { count: 2 });
    const read = await request(server())
      .patch(`${url}/a1/read`)
      .set('Authorization', ana)
      .send({ isRead: true })
      .expect(200);
    expect(read.body).toMatchObject({
      id: 'a1',
      isRead: true,
      readAt: expect.any(String),
    });
    await request(server())
      .get(`${url}/unread-count`)
      .set('Authorization', ana)
      .expect(200, { count: 1 });
    const unread = await request(server())
      .patch(`${url}/a1/read`)
      .set('Authorization', ana)
      .send({ isRead: false })
      .expect(200);
    expect(unread.body).toMatchObject({ isRead: false, readAt: null });
    for (const id of ['b1', 'missing']) {
      await request(server())
        .get(`${url}/${id}`)
        .set('Authorization', ana)
        .expect(404);
      await request(server())
        .patch(`${url}/${id}/read`)
        .set('Authorization', ana)
        .send({ isRead: true })
        .expect(404);
      await request(server())
        .delete(`${url}/${id}`)
        .set('Authorization', ana)
        .expect(404);
    }
    await request(server())
      .delete(`${url}/a1`)
      .set('Authorization', ana)
      .expect(204);
    await request(server())
      .get(`${url}/unread-count`)
      .set('Authorization', ana)
      .expect(200, { count: 1 });
    await request(server())
      .get(`${url}/b1`)
      .set('Authorization', beto)
      .expect(200);
  });

  it('marcado y borrado masivos son idempotentes y no afectan al otro usuario', async () => {
    await request(server())
      .patch(`${url}/read-all`)
      .set('Authorization', ana)
      .expect(200, { count: 2 });
    await request(server())
      .patch(`${url}/read-all`)
      .set('Authorization', ana)
      .expect(200, { count: 0 });
    await request(server())
      .get(`${url}/unread-count`)
      .set('Authorization', beto)
      .expect(200, { count: 1 });
    await request(server())
      .delete(url)
      .set('Authorization', ana)
      .expect(200, { count: 3 });
    await request(server())
      .delete(url)
      .set('Authorization', ana)
      .expect(200, { count: 0 });
    expect(store.notifications.map((n) => n.id)).toEqual(['b1']);
  });
});
