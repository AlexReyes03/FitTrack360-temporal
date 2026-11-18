import sharp from 'sharp';
import request from 'supertest';
import {
  createW12TestingContext,
  type W12IntegrationContext,
} from './w12-test-setup';

describe('W12-BE-07 · Flujo de integración (rutina, sesión, métrica, foto, dashboard, export)', () => {
  let ctx: W12IntegrationContext;

  beforeEach(async () => {
    ctx = await createW12TestingContext();
  });

  afterEach(async () => {
    await ctx.cleanup();
  });

  const server = () => ctx.app.getHttpServer();
  const authA = () => ({ Authorization: `Bearer ${ctx.userA.accessToken}` });

  it('documenta en /api/docs-json el contrato OpenAPI de W12', async () => {
    const response = await request(server()).get('/api/docs-json').expect(200);
    const { paths, components } = response.body;

    expect(paths['/api/v1/routines']?.post?.tags).toContain('routines');
    expect(paths['/api/v1/routines']?.post?.responses?.['201']).toBeDefined();
    expect(paths['/api/v1/routines']?.post?.responses?.['400']).toBeDefined();
    expect(paths['/api/v1/routines']?.post?.responses?.['401']).toBeDefined();
    expect(
      paths['/api/v1/routines/{id}']?.get?.responses?.['404'],
    ).toBeDefined();
    expect(
      paths['/api/v1/routines/{id}/start']?.post?.responses?.['201'],
    ).toBeDefined();

    expect(paths['/api/v1/progress/metrics']?.post?.tags).toContain('progress');
    expect(
      paths['/api/v1/progress/metrics']?.post?.responses?.['201'],
    ).toBeDefined();
    expect(
      paths['/api/v1/progress/metrics/{id}']?.get?.responses?.['404'],
    ).toBeDefined();

    expect(paths['/api/v1/photos']?.post?.tags).toContain('photos');
    expect(paths['/api/v1/photos']?.post?.responses?.['201']).toBeDefined();
    expect(paths['/api/v1/photos/{id}']?.get?.responses?.['404']).toBeDefined();
    expect(
      paths['/api/v1/photos/{id}']?.delete?.responses?.['204'],
    ).toBeDefined();

    expect(paths['/api/v1/dashboard/today']?.get?.tags).toContain('dashboard');
    expect(
      paths['/api/v1/dashboard/today']?.get?.responses?.['200'],
    ).toBeDefined();
    expect(
      paths['/api/v1/dashboard/today']?.get?.responses?.['401'],
    ).toBeDefined();

    expect(paths['/api/v1/users/me']?.get?.responses?.['200']).toBeDefined();
    expect(paths['/api/v1/users/me']?.get?.responses?.['401']).toBeDefined();
    expect(
      paths['/api/v1/users/me/export']?.get?.responses?.['200'],
    ).toBeDefined();

    expect(components.schemas.RoutineResponseDto).toBeDefined();
    expect(components.schemas.MetricResponseDto).toBeDefined();
    expect(components.schemas.PhotoResponseDto).toBeDefined();
    expect(components.schemas.UserExportResponseDto).toBeDefined();
    expect(components.schemas.DashboardTodayDto).toBeDefined();
  });

  it('cubre el flujo rutina → sesión → métrica → foto → dashboard → export', async () => {
    const routineRes = await request(server())
      .post('/api/v1/routines')
      .set(authA())
      .send({
        name: 'Full body W12',
        exercises: [
          {
            exerciseId: '0001',
            position: 1,
            targetSets: 2,
            targetReps: 10,
          },
        ],
      })
      .expect(201);

    expect(routineRes.body.id).toBeDefined();
    expect(routineRes.body.exercises).toHaveLength(1);

    const startRes = await request(server())
      .post(`/api/v1/routines/${routineRes.body.id}/start`)
      .set(authA())
      .send({ startedAt: '2026-11-18T15:00:00.000Z' })
      .expect(201);

    expect(startRes.body.routineId).toBe(routineRes.body.id);
    expect(startRes.body.sets.length).toBe(2);

    const metricRes = await request(server())
      .post('/api/v1/progress/metrics')
      .set(authA())
      .send({
        measuredAt: '2026-11-18T08:00:00.000Z',
        weightKg: 78.5,
        bodyFatPercent: 18,
        waistCm: 82,
      })
      .expect(201);

    expect(metricRes.body.weightKg).toBe(78.5);

    const jpeg = await sharp({
      create: { width: 8, height: 6, channels: 3, background: '#00aa00' },
    })
      .jpeg()
      .toBuffer();

    const photoRes = await request(server())
      .post('/api/v1/photos')
      .set(authA())
      .attach('file', jpeg, {
        filename: 'progreso.jpg',
        contentType: 'image/jpeg',
      })
      .field('metricId', metricRes.body.id)
      .expect(201);

    expect(photoRes.body.metricId).toBe(metricRes.body.id);
    expect(photoRes.body.mimeType).toBe('image/jpeg');

    const dashboardRes = await request(server())
      .get('/api/v1/dashboard/today')
      .query({ date: '2026-11-18', utcOffsetMinutes: 0 })
      .set(authA())
      .expect(200);

    expect(dashboardRes.body.latestMetric).toMatchObject({
      weightKg: 78.5,
      bodyFatPercent: 18,
      waistCm: 82,
    });
    expect(dashboardRes.body.session?.id).toBe(startRes.body.id);

    const exportRes = await request(server())
      .get('/api/v1/users/me/export')
      .set(authA())
      .expect(200);

    expect(exportRes.body.exportedAt).toBeDefined();
    expect(exportRes.body.data.passwordHash).toBeUndefined();
    expect(exportRes.body.data.firebaseUid).toBeUndefined();
    expect(exportRes.body.data.routines).toHaveLength(1);
    expect(exportRes.body.data.bodyMetrics).toHaveLength(1);
    expect(exportRes.body.data.photos).toHaveLength(1);
    expect(exportRes.body.data.workoutSessions.length).toBeGreaterThanOrEqual(
      1,
    );
  });
});
