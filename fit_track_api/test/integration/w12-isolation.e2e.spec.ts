import sharp from 'sharp';
import request from 'supertest';
import {
  createW12TestingContext,
  type W12IntegrationContext,
} from './w12-test-setup';

describe('W12-BE-07 · Aislamiento S4 (rutinas, métricas y fotos)', () => {
  let ctx: W12IntegrationContext;
  let routineAId: string;
  let metricAId: string;
  let photoAId: string;

  beforeEach(async () => {
    ctx = await createW12TestingContext();
    const server = ctx.app.getHttpServer();
    const authA = { Authorization: `Bearer ${ctx.userA.accessToken}` };

    const routine = await request(server)
      .post('/api/v1/routines')
      .set(authA)
      .send({
        name: 'Rutina Alice',
        exercises: [
          {
            exerciseId: '0001',
            position: 1,
            targetSets: 1,
            targetReps: 8,
          },
        ],
      })
      .expect(201);
    routineAId = routine.body.id;

    const metric = await request(server)
      .post('/api/v1/progress/metrics')
      .set(authA)
      .send({
        measuredAt: '2026-11-18T09:00:00.000Z',
        weightKg: 70,
      })
      .expect(201);
    metricAId = metric.body.id;

    const jpeg = await sharp({
      create: { width: 4, height: 4, channels: 3, background: '#112233' },
    })
      .jpeg()
      .toBuffer();

    const photo = await request(server)
      .post('/api/v1/photos')
      .set(authA)
      .attach('file', jpeg, { filename: 'a.jpg', contentType: 'image/jpeg' })
      .field('metricId', metricAId)
      .expect(201);
    photoAId = photo.body.id;
  });

  afterEach(async () => {
    await ctx.cleanup();
  });

  const server = () => ctx.app.getHttpServer();
  const authB = () => ({ Authorization: `Bearer ${ctx.userB.accessToken}` });
  const authA = () => ({ Authorization: `Bearer ${ctx.userA.accessToken}` });

  it('retorna 404 (nunca 403) cuando B accede a la rutina de A', async () => {
    const get = await request(server())
      .get(`/api/v1/routines/${routineAId}`)
      .set(authB());
    expect(get.status).toBe(404);
    expect(get.status).not.toBe(403);

    const patch = await request(server())
      .patch(`/api/v1/routines/${routineAId}`)
      .set(authB())
      .send({ name: 'Hack' });
    expect(patch.status).toBe(404);
    expect(patch.status).not.toBe(403);

    const duplicate = await request(server())
      .post(`/api/v1/routines/${routineAId}/duplicate`)
      .set(authB());
    expect(duplicate.status).toBe(404);
    expect(duplicate.status).not.toBe(403);

    const start = await request(server())
      .post(`/api/v1/routines/${routineAId}/start`)
      .set(authB())
      .send({});
    expect(start.status).toBe(404);
    expect(start.status).not.toBe(403);

    const del = await request(server())
      .delete(`/api/v1/routines/${routineAId}`)
      .set(authB());
    expect(del.status).toBe(404);
    expect(del.status).not.toBe(403);

    const listB = await request(server())
      .get('/api/v1/routines')
      .set(authB())
      .expect(200);
    expect(listB.body).toEqual([]);

    const listA = await request(server())
      .get('/api/v1/routines')
      .set(authA())
      .expect(200);
    expect(listA.body).toHaveLength(1);
  });

  it('retorna 404 (nunca 403) cuando B accede a la métrica de A', async () => {
    const get = await request(server())
      .get(`/api/v1/progress/metrics/${metricAId}`)
      .set(authB());
    expect(get.status).toBe(404);
    expect(get.status).not.toBe(403);

    const patch = await request(server())
      .patch(`/api/v1/progress/metrics/${metricAId}`)
      .set(authB())
      .send({ weightKg: 1 });
    expect(patch.status).toBe(404);
    expect(patch.status).not.toBe(403);

    const del = await request(server())
      .delete(`/api/v1/progress/metrics/${metricAId}`)
      .set(authB());
    expect(del.status).toBe(404);
    expect(del.status).not.toBe(403);

    const listB = await request(server())
      .get('/api/v1/progress/metrics')
      .set(authB())
      .expect(200);
    expect(listB.body).toEqual([]);
  });

  it('retorna 404 (nunca 403) cuando B accede a la foto de A o usa metricId ajeno', async () => {
    const get = await request(server())
      .get(`/api/v1/photos/${photoAId}`)
      .set(authB());
    expect(get.status).toBe(404);
    expect(get.status).not.toBe(403);

    const del = await request(server())
      .delete(`/api/v1/photos/${photoAId}`)
      .set(authB());
    expect(del.status).toBe(404);
    expect(del.status).not.toBe(403);

    const jpeg = await sharp({
      create: { width: 4, height: 4, channels: 3, background: '#abcdef' },
    })
      .jpeg()
      .toBuffer();

    const upload = await request(server())
      .post('/api/v1/photos')
      .set(authB())
      .attach('file', jpeg, { filename: 'b.jpg', contentType: 'image/jpeg' })
      .field('metricId', metricAId);
    expect(upload.status).toBe(404);
    expect(upload.status).not.toBe(403);

    const dashB = await request(server())
      .get('/api/v1/dashboard/today')
      .query({ date: '2026-11-18', utcOffsetMinutes: 0 })
      .set(authB())
      .expect(200);
    expect(dashB.body.latestMetric).toBeNull();

    const privacy = await request(server())
      .get(`/api/v1/privacy/${ctx.userA.id}/export`)
      .set(authB());
    expect(privacy.status).toBe(404);
    expect(privacy.status).not.toBe(403);
  });
});
