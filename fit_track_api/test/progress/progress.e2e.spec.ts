import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { configureApp } from '../../src/app.setup';
import {
  FIREBASE_TOKEN_VERIFIER,
  MockFirebaseTokenVerifier,
} from '../../src/auth/firebase-token.verifier';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { ProgressModule } from '../../src/progress/progress.module';
import { createProgressStore } from './progress.fakes';

describe('ProgressModule · /api/v1/progress (Task W12-03)', () => {
  let app: INestApplication<App>;
  let store: ReturnType<typeof createProgressStore>;
  const anaToken = 'mock:firebase-ana:ana@test.com';
  const betoToken = 'mock:firebase-beto:beto@test.com';

  const daysAgoIso = (days: number, time = '08:00:00.000Z'): string => {
    const d = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    return `${d.toISOString().slice(0, 10)}T${time}`;
  };

  const daysFromNowIso = (days: number): string =>
    new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();

  beforeAll(async () => {
    store = createProgressStore({
      users: [
        { id: 'user-ana', firebaseUid: 'firebase-ana', email: 'ana@test.com' },
        {
          id: 'user-beto',
          firebaseUid: 'firebase-beto',
          email: 'beto@test.com',
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
        ProgressModule,
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

  beforeEach(() => {
    store.metrics.length = 0;
  });

  afterAll(async () => {
    await app.close();
  });

  const server = () => app.getHttpServer();

  describe('1. Autenticación', () => {
    it('rechaza peticiones sin token con 401', async () => {
      await request(server()).get('/api/v1/progress').expect(401);
      await request(server()).get('/api/v1/progress/latest').expect(401);
      await request(server()).get('/api/v1/progress/series').expect(401);
      await request(server())
        .post('/api/v1/progress')
        .send({ measuredAt: daysAgoIso(1), weightKg: 72 })
        .expect(401);
    });
  });

  describe('2. Registro, recuperación en historial y CRUD completo', () => {
    it('registra métricas, las recupera en historial descendente y permite actualizar y eliminar', async () => {
      const olderDate = daysAgoIso(10);
      const newerDate = daysAgoIso(2);

      const firstRes = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({
          measuredAt: olderDate,
          weightKg: 76.4,
          bodyFatPercent: 20.5,
          waistCm: 84,
        })
        .expect(201);

      expect(firstRes.body).toMatchObject({
        userId: 'user-ana',
        measuredAt: olderDate,
        weightKg: 76.4,
        bodyFatPercent: 20.5,
        waistCm: 84,
      });

      const secondRes = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({
          measuredAt: newerDate,
          weightKg: 75.1,
          bodyFatPercent: 0,
          waistCm: 0,
        })
        .expect(201);

      expect(secondRes.body).toMatchObject({
        userId: 'user-ana',
        measuredAt: newerDate,
        weightKg: 75.1,
        bodyFatPercent: 0,
        waistCm: 0,
      });

      const historyRes = await request(server())
        .get('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);

      expect(historyRes.body).toHaveLength(2);
      expect(historyRes.body[0].id).toBe(secondRes.body.id);
      expect(historyRes.body[1].id).toBe(firstRes.body.id);

      const detailRes = await request(server())
        .get(`/api/v1/progress/${firstRes.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);
      expect(detailRes.body.weightKg).toBe(76.4);

      const patchRes = await request(server())
        .patch(`/api/v1/progress/${firstRes.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ weightKg: 76.0, waistCm: null })
        .expect(200);
      expect(patchRes.body.weightKg).toBe(76.0);
      expect(patchRes.body.waistCm).toBeNull();

      await request(server())
        .delete(`/api/v1/progress/${firstRes.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(204);

      await request(server())
        .get(`/api/v1/progress/${firstRes.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(404);
    });
  });

  describe('3. Filtrado por rango de fechas, última métrica y serie cronológica', () => {
    it('filtra historial por from/to, calcula /latest y devuelve /series en orden ascendente', async () => {
      // Estado vacío inicial
      const emptyLatest = await request(server())
        .get('/api/v1/progress/latest')
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);
      expect(emptyLatest.body).toEqual({ metric: null });

      const d1 = daysAgoIso(30, '07:00:00.000Z');
      const d2 = daysAgoIso(15, '07:00:00.000Z');
      const d3 = daysAgoIso(5, '07:00:00.000Z');

      // Insertar fuera de orden cronológico para verificar ordenamiento real
      const m2 = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ measuredAt: d2, weightKg: 74.2, bodyFatPercent: 18.5 })
        .expect(201);

      const m3 = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({
          measuredAt: d3,
          weightKg: 73.4,
          bodyFatPercent: 17.8,
          waistCm: 80.5,
        })
        .expect(201);

      const m1 = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ measuredAt: d1, weightKg: 75.8, waistCm: 83 })
        .expect(201);

      // Última métrica debe ser d3
      const latestRes = await request(server())
        .get('/api/v1/progress/latest')
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);
      expect(latestRes.body.metric).toMatchObject({
        id: m3.body.id,
        measuredAt: d3,
        weightKg: 73.4,
      });

      // Filtrado por rango [d2..d3] en historial (descendente)
      const fromDay = d2.slice(0, 10);
      const toDay = d3.slice(0, 10);

      const rangeHistoryRes = await request(server())
        .get(`/api/v1/progress?from=${fromDay}&to=${toDay}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);

      expect(
        rangeHistoryRes.body.map((item: { id: string }) => item.id),
      ).toEqual([m3.body.id, m2.body.id]);

      // Serie completa ordenada cronológicamente (ascendente) lista para Flutter
      const fullSeriesRes = await request(server())
        .get('/api/v1/progress/series')
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);

      expect(fullSeriesRes.body.count).toBe(3);
      expect(fullSeriesRes.body.from).toBeNull();
      expect(fullSeriesRes.body.to).toBeNull();
      expect(fullSeriesRes.body.latest.id).toBe(m3.body.id);
      expect(
        fullSeriesRes.body.points.map((p: { id: string }) => p.id),
      ).toEqual([m1.body.id, m2.body.id, m3.body.id]);
      expect(fullSeriesRes.body.points[0]).toMatchObject({
        id: m1.body.id,
        date: d1.slice(0, 10),
        measuredAt: d1,
        weightKg: 75.8,
        bodyFatPercent: null,
        waistCm: 83,
      });

      // Serie filtrada por rango
      const rangeSeriesRes = await request(server())
        .get(`/api/v1/progress/series?from=${fromDay}&to=${toDay}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);

      expect(rangeSeriesRes.body.count).toBe(2);
      expect(
        rangeSeriesRes.body.points.map((p: { id: string }) => p.id),
      ).toEqual([m2.body.id, m3.body.id]);
      expect(rangeSeriesRes.body.latest.id).toBe(m3.body.id);
    });

    it('rechaza rangos de fechas inválidos o invertidos (from > to) con 400', async () => {
      const earlier = daysAgoIso(10).slice(0, 10);
      const later = daysAgoIso(2).slice(0, 10);

      await request(server())
        .get(`/api/v1/progress?from=${later}&to=${earlier}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(400);

      await request(server())
        .get(`/api/v1/progress/series?from=${later}&to=${earlier}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(400);

      await request(server())
        .get('/api/v1/progress?from=no-es-fecha')
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(400);
    });
  });

  describe('4. Validaciones biométricas (peso positivo, opcionales >= 0, fecha no futura)', () => {
    it.each([
      ['fecha futura', { measuredAt: daysFromNowIso(2), weightKg: 72 }],
      ['peso cero', { measuredAt: daysAgoIso(1), weightKg: 0 }],
      ['peso negativo', { measuredAt: daysAgoIso(1), weightKg: -5.5 }],
      [
        'bodyFatPercent negativo',
        { measuredAt: daysAgoIso(1), weightKg: 72, bodyFatPercent: -1 },
      ],
      [
        'bodyFatPercent mayor a 100',
        { measuredAt: daysAgoIso(1), weightKg: 72, bodyFatPercent: 101 },
      ],
      [
        'waistCm negativo',
        { measuredAt: daysAgoIso(1), weightKg: 72, waistCm: -10 },
      ],
      [
        'propiedad no permitida (whitelist)',
        { measuredAt: daysAgoIso(1), weightKg: 72, userId: 'user-beto' },
      ],
    ])('rechaza POST con %s devolviendo 400', async (_label, payload) => {
      await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send(payload)
        .expect(400);
    });

    it('rechaza PATCH con fecha futura o valores inválidos devolviendo 400', async () => {
      const created = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ measuredAt: daysAgoIso(3), weightKg: 74 })
        .expect(201);

      await request(server())
        .patch(`/api/v1/progress/${created.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ measuredAt: daysFromNowIso(1) })
        .expect(400);

      await request(server())
        .patch(`/api/v1/progress/${created.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ weightKg: 0 })
        .expect(400);

      await request(server())
        .patch(`/api/v1/progress/${created.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .send({ waistCm: -2 })
        .expect(400);
    });
  });

  describe('5. Aislamiento entre dos usuarios JWT (Regla S4 · 404 Not Found)', () => {
    it('devuelve 404 (nunca 403) al intentar leer, editar o borrar una métrica de otro usuario y aísla historial/latest/series', async () => {
      const anaMetric = await request(server())
        .post('/api/v1/progress')
        .set('Authorization', `Bearer ${anaToken}`)
        .send({
          measuredAt: daysAgoIso(2),
          weightKg: 62.5,
          bodyFatPercent: 21.0,
          waistCm: 70,
        })
        .expect(201);

      // Beto intenta acceder al recurso de Ana por ID -> siempre 404
      await request(server())
        .get(`/api/v1/progress/${anaMetric.body.id}`)
        .set('Authorization', `Bearer ${betoToken}`)
        .expect(404);

      await request(server())
        .patch(`/api/v1/progress/${anaMetric.body.id}`)
        .set('Authorization', `Bearer ${betoToken}`)
        .send({ weightKg: 99 })
        .expect(404);

      await request(server())
        .delete(`/api/v1/progress/${anaMetric.body.id}`)
        .set('Authorization', `Bearer ${betoToken}`)
        .expect(404);

      // Beto no ve datos de Ana en listados ni consultas agregadas
      const betoHistory = await request(server())
        .get('/api/v1/progress')
        .set('Authorization', `Bearer ${betoToken}`)
        .expect(200);
      expect(betoHistory.body).toEqual([]);

      const betoLatest = await request(server())
        .get('/api/v1/progress/latest')
        .set('Authorization', `Bearer ${betoToken}`)
        .expect(200);
      expect(betoLatest.body).toEqual({ metric: null });

      const betoSeries = await request(server())
        .get('/api/v1/progress/series')
        .set('Authorization', `Bearer ${betoToken}`)
        .expect(200);
      expect(betoSeries.body).toMatchObject({
        count: 0,
        latest: null,
        points: [],
      });

      // Confirmar que la métrica de Ana sigue intacta
      const anaStillExists = await request(server())
        .get(`/api/v1/progress/${anaMetric.body.id}`)
        .set('Authorization', `Bearer ${anaToken}`)
        .expect(200);
      expect(anaStillExists.body.weightKg).toBe(62.5);
    });
  });

  describe('6. Contrato OpenAPI / Swagger', () => {
    it('documenta las rutas y esquemas de progress en /api/docs-json', async () => {
      const response = await request(server())
        .get('/api/docs-json')
        .expect(200);

      expect(response.body.paths['/api/v1/progress']?.post?.tags).toContain(
        'progress',
      );
      expect(response.body.paths['/api/v1/progress']?.get?.tags).toContain(
        'progress',
      );
      expect(
        response.body.paths['/api/v1/progress/latest']?.get?.tags,
      ).toContain('progress');
      expect(
        response.body.paths['/api/v1/progress/series']?.get?.tags,
      ).toContain('progress');
      expect(response.body.paths['/api/v1/progress/{id}']?.get?.tags).toContain(
        'progress',
      );
      expect(
        response.body.paths['/api/v1/progress/{id}']?.patch?.tags,
      ).toContain('progress');
      expect(
        response.body.paths['/api/v1/progress/{id}']?.delete?.tags,
      ).toContain('progress');

      const schemas = response.body.components.schemas;
      expect(Object.keys(schemas.CreateBodyMetricDto.properties)).toEqual(
        expect.arrayContaining([
          'measuredAt',
          'weightKg',
          'bodyFatPercent',
          'waistCm',
        ]),
      );
      expect(schemas.ProgressSeriesResponseDto).toBeDefined();
      expect(schemas.LatestBodyMetricResponseDto).toBeDefined();
    });
  });
});
