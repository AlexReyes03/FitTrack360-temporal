import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { configureApp } from '../../src/app.setup';
import { DashboardModule } from '../../src/dashboard/dashboard.module';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { createDashboardStore } from './dashboard.fakes';

const SECRET = 'secreto-de-prueba';

describe('GET /api/v1/dashboard/today (W12-06)', () => {
  let app: INestApplication<App>;
  let anaToken: string;
  let betoToken: string;

  beforeAll(async () => {
    const store = createDashboardStore({
      meals: [
        {
          id: 'm1',
          userId: 'user-ana',
          eatenAt: new Date('2026-11-10T14:00:00Z'),
          mealType: 'LUNCH',
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
          load: [() => ({ JWT_ACCESS_SECRET: SECRET, SMTP_HOST: 'localhost' })],
        }),
        PrismaModule,
        DashboardModule,
      ],
    })
      .overrideProvider(PrismaService)
      .useValue(store)
      .compile();
    app = moduleRef.createNestApplication<INestApplication<App>>();
    configureApp(app);
    await app.init();
    const jwt = new JwtService({ secret: SECRET });
    anaToken = await jwt.signAsync({ sub: 'user-ana' });
    betoToken = await jwt.signAsync({ sub: 'user-beto' });
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
    expect(response.body.session).toMatchObject({ id: 's1', isToday: true });
    expect(response.body.latestMetric).toBeNull();
  });

  it('otro usuario ve un resumen vacío, sin datos ajenos', async () => {
    const response = await request(server())
      .get('/api/v1/dashboard/today?date=2026-11-10')
      .set('Authorization', `Bearer ${betoToken}`)
      .expect(200);

    expect(response.body.nutrition.mealsLogged).toBe(0);
    expect(response.body.session).toBeNull();
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
  });
});
