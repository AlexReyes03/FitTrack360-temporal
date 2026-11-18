import { MealType } from '@prisma/client';
import request from 'supertest';
import {
  createW11TestingContext,
  type W11IntegrationContext,
} from './w11-test-setup';

describe('W11-BE-06 · Pruebas de Aislamiento y Ownership (Regla S4 · 404 Not Found)', () => {
  let ctx: W11IntegrationContext;
  let userAWorkoutId: string;
  let userBWorkoutId: string;
  let userAMealId: string;
  let userBMealId: string;

  beforeEach(async () => {
    ctx = await createW11TestingContext();
    const server = ctx.app.getHttpServer();

    // Crear sesión de entrenamiento de User A (Alice)
    const workoutARes = await request(server)
      .post('/api/v1/workouts')
      .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
      .send({
        startedAt: '2026-11-14T08:00:00.000Z',
        endedAt: '2026-11-14T09:00:00.000Z',
        location: 'Gimnasio Norte',
        notes: 'Sesión privada de Alice',
        sets: [
          {
            exerciseId: '0025',
            order: 1,
            weight: 60,
            reps: 8,
            rpe: 8,
            rir: 2,
          },
        ],
      })
      .expect(201);
    userAWorkoutId = workoutARes.body.id as string;

    // Crear sesión de entrenamiento de User B (Bob)
    const workoutBRes = await request(server)
      .post('/api/v1/workouts')
      .set('Authorization', `Bearer ${ctx.userB.accessToken}`)
      .send({
        startedAt: '2026-11-14T18:00:00.000Z',
        endedAt: '2026-11-14T19:15:00.000Z',
        location: 'Gimnasio Sur',
        notes: 'Sesión privada de Bob',
        sets: [
          {
            exerciseId: '0025',
            order: 1,
            weight: 70,
            reps: 10,
            rpe: 7,
            rir: 3,
          },
        ],
      })
      .expect(201);
    userBWorkoutId = workoutBRes.body.id as string;

    // Crear comida de User A (Alice)
    const mealARes = await request(server)
      .post('/api/v1/meals')
      .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
      .send({
        eatenAt: '2026-11-14T09:30:00.000Z',
        mealType: MealType.BREAKFAST,
        notes: 'Desayuno privado de Alice',
        items: [
          {
            name: 'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
            fdcId: '171077',
            servingG: 150,
            kcal: 247.5,
            proteinG: 46.5,
            carbsG: 0,
            fatG: 5.4,
          },
        ],
      })
      .expect(201);
    userAMealId = mealARes.body.id as string;

    // Crear comida de User B (Bob)
    const mealBRes = await request(server)
      .post('/api/v1/meals')
      .set('Authorization', `Bearer ${ctx.userB.accessToken}`)
      .send({
        eatenAt: '2026-11-14T14:00:00.000Z',
        mealType: MealType.LUNCH,
        notes: 'Almuerzo privado de Bob',
        items: [
          {
            name: 'Rice, white, long-grain, regular, cooked',
            fdcId: '168878',
            servingG: 200,
            kcal: 260,
            proteinG: 5.4,
            carbsG: 56.4,
            fatG: 0.6,
          },
        ],
      })
      .expect(201);
    userBMealId = mealBRes.body.id as string;
  });

  afterEach(async () => {
    await ctx.app.close();
  });

  const server = () => ctx.app.getHttpServer();

  describe('1. Aislamiento en sesiones de entrenamiento (Workouts)', () => {
    it('retorna 404 Not Found (nunca 403) cuando User B intenta hacer GET, PATCH o DELETE sobre la sesión de User A y viceversa, sin filtrar lastMarks ni comparación', async () => {
      // User B intentando acceder/modificar/eliminar recurso de User A
      const getByB = await request(server())
        .get(`/api/v1/workouts/${userAWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`);
      expect(getByB.status).toBe(404);
      expect(getByB.status).not.toBe(403);

      const patchByB = await request(server())
        .patch(`/api/v1/workouts/${userAWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`)
        .send({ notes: 'Sabotaje desde cuenta de Bob' });
      expect(patchByB.status).toBe(404);
      expect(patchByB.status).not.toBe(403);

      const deleteByB = await request(server())
        .delete(`/api/v1/workouts/${userAWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`);
      expect(deleteByB.status).toBe(404);
      expect(deleteByB.status).not.toBe(403);

      // User A intentando acceder/modificar/eliminar recurso de User B
      const getByA = await request(server())
        .get(`/api/v1/workouts/${userBWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`);
      expect(getByA.status).toBe(404);

      const patchByA = await request(server())
        .patch(`/api/v1/workouts/${userBWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
        .send({ notes: 'Intento cruzado de Alice' });
      expect(patchByA.status).toBe(404);

      const deleteByA = await request(server())
        .delete(`/api/v1/workouts/${userBWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`);
      expect(deleteByA.status).toBe(404);

      // Confirmar que los recursos originales permanecen intactos y sin contaminación cruzada en métricas (#154)
      const intactA = await request(server())
        .get(`/api/v1/workouts/${userAWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
        .expect(200);
      expect(intactA.body.notes).toBe('Sesión privada de Alice');
      expect(intactA.body.sets).toHaveLength(1);

      const intactB = await request(server())
        .get(`/api/v1/workouts/${userBWorkoutId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`)
        .expect(200);
      expect(intactB.body.notes).toBe('Sesión privada de Bob');
      expect(intactB.body.lastMarks).toEqual([]);
      expect(intactB.body.comparison).toBeNull();

      const listA = await request(server())
        .get('/api/v1/workouts')
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
        .expect(200);
      expect(listA.body).toHaveLength(1);
      expect(listA.body[0].id).toBe(userAWorkoutId);
    });
  });

  describe('2. Aislamiento en registros de comidas y resúmenes nutricionales (Meals)', () => {
    it('retorna 404 Not Found (nunca 403) cuando User B intenta hacer GET, PATCH o DELETE sobre la comida de User A y viceversa', async () => {
      // User B intentando acceder/modificar/eliminar comida de User A
      const getByB = await request(server())
        .get(`/api/v1/meals/${userAMealId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`);
      expect(getByB.status).toBe(404);
      expect(getByB.status).not.toBe(403);

      const patchByB = await request(server())
        .patch(`/api/v1/meals/${userAMealId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`)
        .send({ notes: 'Intento de alteración nutricional por Bob' });
      expect(patchByB.status).toBe(404);
      expect(patchByB.status).not.toBe(403);

      const deleteByB = await request(server())
        .delete(`/api/v1/meals/${userAMealId}`)
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`);
      expect(deleteByB.status).toBe(404);
      expect(deleteByB.status).not.toBe(403);

      // User A intentando acceder/modificar/eliminar comida de User B
      const getByA = await request(server())
        .get(`/api/v1/meals/${userBMealId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`);
      expect(getByA.status).toBe(404);

      const patchByA = await request(server())
        .patch(`/api/v1/meals/${userBMealId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
        .send({ notes: 'Intento cruzado de Alice' });
      expect(patchByA.status).toBe(404);

      const deleteByA = await request(server())
        .delete(`/api/v1/meals/${userBMealId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`);
      expect(deleteByA.status).toBe(404);

      // Confirmar integridad e independencia de listados y resúmenes diarios
      const intactMealA = await request(server())
        .get(`/api/v1/meals/${userAMealId}`)
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
        .expect(200);
      expect(intactMealA.body.notes).toBe('Desayuno privado de Alice');
      expect(intactMealA.body.totals.kcal).toBe(247.5);

      const summaryA = await request(server())
        .get('/api/v1/meals/summary')
        .query({ date: '2026-11-14' })
        .set('Authorization', `Bearer ${ctx.userA.accessToken}`)
        .expect(200);
      expect(summaryA.body.totals.kcal).toBe(247.5);

      const summaryB = await request(server())
        .get('/api/v1/meals/summary')
        .query({ date: '2026-11-14' })
        .set('Authorization', `Bearer ${ctx.userB.accessToken}`)
        .expect(200);
      expect(summaryB.body.totals.kcal).toBe(260);
    });
  });
});
