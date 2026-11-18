import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { configureApp } from '../../src/app.setup';
import { FIREBASE_TOKEN_VERIFIER } from '../../src/auth/firebase-token.verifier';
import { MockFirebaseTokenVerifier } from '../../src/auth/firebase-token.verifier';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { UsersModule } from '../../src/users/users.module';
import { createUsersStore, mockIdToken, sampleUsers } from './users.fakes';

describe('GET y PATCH /api/v1/users/me (W12-05)', () => {
  let app: INestApplication<App>;
  let store: ReturnType<typeof createUsersStore>;
  let anaToken: string;
  let betoToken: string;

  beforeEach(async () => {
    store = createUsersStore(sampleUsers());
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
        UsersModule,
      ],
    })
      .overrideProvider(PrismaService)
      .useValue(store)
      .overrideProvider(FIREBASE_TOKEN_VERIFIER)
      .useValue(new MockFirebaseTokenVerifier())
      .compile();
    app = moduleRef.createNestApplication<INestApplication<App>>();
    configureApp(app);
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  const server = () => app.getHttpServer();

  it('sin token responde 401', async () => {
    await request(server()).get('/api/v1/users/me').expect(401);
    await request(server()).patch('/api/v1/users/me').send({}).expect(401);
  });

  it('GET conserva los campos que lee Flutter y agrega metas y preferencias', async () => {
    const response = await request(server())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(200);

    expect(response.body).toMatchObject({
      id: 'user-ana',
      email: 'ana@test.com',
      username: 'ana',
      displayName: 'Ana',
      goals: { dailyCalorieGoal: expect.any(Number) },
      preferences: { weightUnit: 'kg', distanceUnit: 'km' },
    });
    expect(response.body).not.toHaveProperty('passwordHash');
  });

  it('PATCH edita perfil, metas y preferencias y GET las devuelve', async () => {
    const patch = await request(server())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({
        displayName: 'Ana P.',
        goals: { dailyCalorieGoal: 2200, fatGoalG: 0 },
        preferences: { weightUnit: 'lb', biometricEnabled: true },
      })
      .expect(200);
    expect(patch.body.displayName).toBe('Ana P.');

    const response = await request(server())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(200);
    expect(response.body.goals).toMatchObject({
      dailyCalorieGoal: 2200,
      fatGoalG: 0,
    });
    expect(response.body.preferences).toMatchObject({
      weightUnit: 'lb',
      biometricEnabled: true,
    });
  });

  it.each([
    ['meta de calorías negativa', { goals: { dailyCalorieGoal: -1 } }],
    ['meta de calorías en cero', { goals: { dailyCalorieGoal: 0 } }],
    ['macro negativo', { goals: { proteinGoalG: -10 } }],
    ['unidad de peso inválida', { preferences: { weightUnit: 'stone' } }],
    ['unidad de distancia inválida', { preferences: { distanceUnit: 'yd' } }],
    ['descanso no entero', { preferences: { restSeconds: 'mucho' } }],
    ['booleano inválido', { preferences: { biometricEnabled: 'si' } }],
    ['displayName vacío', { displayName: '   ' }],
    ['campo no permitido', { passwordHash: 'x' }],
    ['intento de cambiar el id', { id: 'user-beto' }],
    ['campo no permitido en metas', { goals: { userId: 'user-beto' } }],
    [
      'meta de calorías sobre el máximo (W12-16)',
      { displayName: 'Ana X', goals: { dailyCalorieGoal: 20001 } },
    ],
    [
      'proteína sobre el máximo (W12-16)',
      { displayName: 'Ana X', goals: { proteinGoalG: 2001 } },
    ],
  ])('PATCH con %s responde 400 y no guarda nada', async (_caso, body) => {
    await request(server())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .send(body)
      .expect(400);
    expect(store.settings).toHaveLength(0);
    expect(store.users[0].displayName).toBe('Ana');
  });

  it('PATCH parcial con una sola meta no persiste undefined ni pisa defaults (W12-16)', async () => {
    await request(server())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ goals: { proteinGoalG: 175 } })
      .expect(200);

    expect(store.settings).toHaveLength(1);
    const undefinedKeys = Object.entries(store.settings[0])
      .filter(([, value]) => value === undefined)
      .map(([key]) => key);
    expect(undefinedKeys).toEqual([]);

    const response = await request(server())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(200);
    expect(response.body.goals).toEqual({
      dailyCalorieGoal: 2000,
      proteinGoalG: 175,
      carbsGoalG: 250,
      fatGoalG: 65,
    });
    expect(response.body.preferences).toEqual({
      weightUnit: 'kg',
      distanceUnit: 'km',
      restSeconds: 90,
      notificationsEnabled: false,
      biometricEnabled: false,
    });
  });

  it('PATCH que falla al guardar ajustes no deja el nombre cambiado (W12-16)', async () => {
    store.faults.settingsUpsert = new Error('fallo simulado de la base');
    await request(server())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ displayName: 'Ana a medias', goals: { fatGoalG: 70 } })
      .expect(500);
    expect(store.users[0].displayName).toBe('Ana');
    expect(store.settings).toHaveLength(0);
  });

  it('el PATCH de Ana no altera el perfil de Beto', async () => {
    await request(server())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${anaToken}`)
      .send({ displayName: 'Ana X', goals: { dailyCalorieGoal: 1500 } })
      .expect(200);

    const beto = await request(server())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(200);
    expect(beto.body.displayName).toBe('Beto');
    expect(beto.body.goals.dailyCalorieGoal).not.toBe(1500);
  });

  it('documenta GET y PATCH en OpenAPI con su DTO', async () => {
    const response = await request(server()).get('/api/docs-json').expect(200);
    const path = response.body.paths['/api/v1/users/me'];
    expect(path?.get?.responses?.['200']).toBeDefined();
    expect(path?.patch?.responses?.['200']).toBeDefined();
    expect(path?.patch?.tags).toContain('users');
  });
});
