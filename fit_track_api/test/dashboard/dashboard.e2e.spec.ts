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
import { DashboardModule } from '../../src/dashboard/dashboard.module';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { createDashboardStore } from './dashboard.fakes';

describe('GET /api/v1/dashboard/today (W12-06)', () => {
  let app: INestApplication<App>;
  let anaToken: string;
  let betoToken: string;

  beforeAll(async () => {
    const store = createDashboardStore({
      users: [
        { id: 'user-ana', firebaseUid: 'firebase-ana', email: 'ana@test.com' },
        {
          id: 'user-beto',
          firebaseUid: 'firebase-beto',
          email: 'beto@test.com',
        },
      ],
      meals: [
        {
          id: 'm1',
          userId: 'user-ana',
          eatenAt: new Date('2026-11-10T14:00:00Z'),
          mealType: 'LUNCH',
          items: [
            { kcal: 247.5, proteinG: 46.5, carbsG: 0, fatG: 5.4 },
            { kcal: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3 },
          ],
        },
        {
          id: 'm-ayer',
          userId: 'user-ana',
          eatenAt: new Date('2026-11-09T14:00:00Z'),
          mealType: 'DINNER',
          items: [{ kcal: 900, proteinG: 50, carbsG: 80, fatG: 40 }],
        },
      ],
      sessions: [
        {
          id: 's1',
          userId: 'user-ana',
          startedAt: new Date('2026-11-10T13:00:00Z'),
          endedAt: null,
          notes: 'Pierna',
        },
      ],
    });
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
        DashboardModule,
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
    anaToken = 'mock:firebase-ana:ana@test.com';
    betoToken = 'mock:firebase-beto:beto@test.com';
  });

  afterAll(async () => {
    await app.close();
  });

  const server = () => app.getHttpServer();

  it('sin token responde 401', async () => {
    await request(server()).get('/api/v1/dashboard/today').expect(401);
  });

  it('devuelve las comidas y la sesión del día del usuario', async () => {
    const response = await request(server())
      .get('/api/v1/dashboard/today?date=2026-11-10&utcOffsetMinutes=0')
      .set('Authorization', `Bearer ${anaToken}`)
      .expect(200);

    expect(response.body.date).toBe('2026-11-10');
    expect(response.body.nutrition.mealsLogged).toBe(1);
    expect(response.body.nutrition.consumed).toEqual({
      calories: 377.5,
      proteinG: 49.2,
      carbsG: 28,
      fatG: 5.7,
    });
    expect(response.body.session).toMatchObject({ id: 's1', isToday: true });
    expect(response.body.latestMetric).toBeNull();
  });

  it('otro usuario ve un resumen vacío, sin datos ajenos', async () => {
    const response = await request(server())
      .get('/api/v1/dashboard/today?date=2026-11-10')
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(200);

    expect(response.body.nutrition.mealsLogged).toBe(0);
    expect(response.body.nutrition.consumed).toEqual({
      calories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
    });
    expect(response.body.session).toBeNull();
    expect(response.body.latestMetric).toBeNull();
  });

  it.each([
    'date=2026-13-01',
    'date=ayer',
    'utcOffsetMinutes=9999',
    'utcOffsetMinutes=abc',
    'userId=user-ana',
  ])('con query inválida %s responde 400', async (query) => {
    await request(server())
      .get(`/api/v1/dashboard/today?${query}`)
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(400);
  });

  it('documenta el endpoint en OpenAPI', async () => {
    const response = await request(server()).get('/api/docs-json').expect(200);
    const operation = response.body.paths['/api/v1/dashboard/today']?.get;
    expect(operation?.tags).toContain('dashboard');
    expect(operation?.responses?.['200']).toBeDefined();
    const schemas = response.body.components.schemas;
    expect(Object.keys(schemas.LatestMetricDto.properties)).toEqual(
      expect.arrayContaining(['id', 'measuredAt', 'weightKg']),
    );
  });
});
