import { MealType } from '@prisma/client';
import request from 'supertest';
import {
  createW11TestingContext,
  type W11IntegrationContext,
} from './w11-test-setup';

describe('W11-BE-06.2 · Flujo de integración E2E (Exercises, Workouts, Meals, USDA & Swagger)', () => {
  let ctx: W11IntegrationContext;

  beforeEach(async () => {
    ctx = await createW11TestingContext();
  });

  afterEach(async () => {
    await ctx.app.close();
  });

  const server = () => ctx.app.getHttpServer();

  it('expone en /api/docs-json el contrato OpenAPI completo con esquemas y códigos de error para exercises, workouts, meals y foods', async () => {
    const response = await request(server()).get('/api/docs-json').expect(200);
    const { paths, components } = response.body;

    // 1. Verificar rutas de exercises (#152)
    expect(paths['/api/v1/exercises']?.get?.tags).toContain('exercises');
    expect(paths['/api/v1/exercises']?.get?.responses?.['200']).toBeDefined();
    expect(paths['/api/v1/exercises']?.get?.responses?.['400']).toBeDefined();
    expect(paths['/api/v1/exercises']?.get?.responses?.['401']).toBeDefined();

    expect(paths['/api/v1/exercises/{id}']?.get?.tags).toContain('exercises');
    expect(
      paths['/api/v1/exercises/{id}']?.get?.responses?.['200'],
    ).toBeDefined();
    expect(
      paths['/api/v1/exercises/{id}']?.get?.responses?.['401'],
    ).toBeDefined();
    expect(
      paths['/api/v1/exercises/{id}']?.get?.responses?.['404'],
    ).toBeDefined();

    // 2. Verificar rutas de workouts (#154)
    expect(paths['/api/v1/workouts']?.post?.tags).toContain('workouts');
    expect(paths['/api/v1/workouts']?.post?.responses?.['201']).toBeDefined();
    expect(paths['/api/v1/workouts']?.post?.responses?.['400']).toBeDefined();
    expect(paths['/api/v1/workouts']?.post?.responses?.['401']).toBeDefined();

    expect(
      paths['/api/v1/workouts/{id}']?.get?.responses?.['200'],
    ).toBeDefined();
    expect(
      paths['/api/v1/workouts/{id}']?.get?.responses?.['401'],
    ).toBeDefined();
    expect(
      paths['/api/v1/workouts/{id}']?.get?.responses?.['404'],
    ).toBeDefined();
    expect(
      paths['/api/v1/workouts/{id}']?.patch?.responses?.['400'],
    ).toBeDefined();
    expect(
      paths['/api/v1/workouts/{id}']?.patch?.responses?.['404'],
    ).toBeDefined();
    expect(
      paths['/api/v1/workouts/{id}']?.delete?.responses?.['204'],
    ).toBeDefined();
    expect(
      paths['/api/v1/workouts/{id}']?.delete?.responses?.['404'],
    ).toBeDefined();

    // 3. Verificar rutas de meals (#146)
    expect(paths['/api/v1/meals']?.post?.tags).toContain('meals');
    expect(paths['/api/v1/meals']?.post?.responses?.['201']).toBeDefined();
    expect(paths['/api/v1/meals']?.post?.responses?.['400']).toBeDefined();
    expect(paths['/api/v1/meals']?.post?.responses?.['401']).toBeDefined();

    expect(
      paths['/api/v1/meals/summary']?.get?.responses?.['200'],
    ).toBeDefined();
    expect(
      paths['/api/v1/meals/summary']?.get?.responses?.['400'],
    ).toBeDefined();
    expect(
      paths['/api/v1/meals/summary']?.get?.responses?.['401'],
    ).toBeDefined();

    expect(paths['/api/v1/meals/{id}']?.get?.responses?.['404']).toBeDefined();
    expect(
      paths['/api/v1/meals/{id}']?.patch?.responses?.['400'],
    ).toBeDefined();
    expect(
      paths['/api/v1/meals/{id}']?.patch?.responses?.['404'],
    ).toBeDefined();
    expect(
      paths['/api/v1/meals/{id}']?.delete?.responses?.['204'],
    ).toBeDefined();
    expect(
      paths['/api/v1/meals/{id}']?.delete?.responses?.['404'],
    ).toBeDefined();

    // 4. Verificar rutas de foods (proxy USDA FDC #153)
    expect(paths['/api/v1/foods/search']?.get?.tags).toContain('foods');
    expect(
      paths['/api/v1/foods/search']?.get?.responses?.['200'],
    ).toBeDefined();
    expect(
      paths['/api/v1/foods/search']?.get?.responses?.['400'],
    ).toBeDefined();
    expect(
      paths['/api/v1/foods/search']?.get?.responses?.['401'],
    ).toBeDefined();
    expect(
      paths['/api/v1/foods/search']?.get?.responses?.['503'],
    ).toBeDefined();
    expect(paths['/api/v1/foods/{fdcId}']).toBeUndefined();

    // 5. Verificar esquemas DTO documentados
    expect(components?.schemas?.ExerciseResponseDto).toBeDefined();
    expect(components?.schemas?.ExercisePageResponseDto).toBeDefined();
    expect(components?.schemas?.CreateWorkoutDto).toBeDefined();
    expect(components?.schemas?.CreateWorkoutSetDto).toBeDefined();
    expect(components?.schemas?.WorkoutResponseDto).toBeDefined();
    expect(components?.schemas?.LastMarkResponseDto).toBeDefined();
    expect(components?.schemas?.WorkoutComparisonResponseDto).toBeDefined();
    expect(components?.schemas?.CreateMealDto).toBeDefined();
    expect(components?.schemas?.CreateMealItemDto).toBeDefined();
    expect(components?.schemas?.MealResponseDto).toBeDefined();
    expect(components?.schemas?.DailyNutritionSummaryDto).toBeDefined();
    expect(components?.schemas?.FoodItemDto).toBeDefined();
    expect(components?.schemas?.UsdaUnavailableDto).toBeDefined();
  });

  it('ejecuta el flujo feliz completo: catálogo de ejercicios -> sesiones con métricas y comparación -> búsqueda USDA -> comida con macros congelados y resumen', async () => {
    const authHeader = `Bearer ${ctx.userA.accessToken}`;

    // =========================================================================
    // PASO 1: Consultar catálogo de ejercicios y detalle de un ejercicio
    // =========================================================================
    const catalogRes = await request(server())
      .get('/api/v1/exercises')
      .query({ bodyPart: 'chest', page: 1, pageSize: 10 })
      .set('Authorization', authHeader)
      .expect(200);

    expect(catalogRes.body).toMatchObject({
      total: 1,
      page: 1,
      pageSize: 10,
      items: [
        expect.objectContaining({
          id: '0025',
          name: 'barbell bench press',
          bodyPart: 'chest',
          equipment: 'barbell',
          target: 'pectorals',
          attribution: '© Gym visual - https://gymvisual.com/',
        }),
      ],
    });

    const selectedExerciseId = catalogRes.body.items[0].id as string;

    const exerciseDetailRes = await request(server())
      .get(`/api/v1/exercises/${selectedExerciseId}`)
      .set('Authorization', authHeader)
      .expect(200);

    expect(exerciseDetailRes.body).toMatchObject({
      id: '0025',
      name: 'barbell bench press',
      imageFile: '0025.jpg',
      gifFile: '0025.gif',
    });

    // =========================================================================
    // PASO 2: Crear sesiones de entrenamiento y verificar métricas, lastMarks y comparación (#154)
    // =========================================================================
    const createWorkoutRes = await request(server())
      .post('/api/v1/workouts')
      .set('Authorization', authHeader)
      .send({
        startedAt: '2026-11-14T09:00:00.000Z',
        endedAt: '2026-11-14T10:10:00.000Z',
        location: 'Gimnasio Universitario UTEZ',
        notes: 'Sesión de fuerza en pecho y core',
        sets: [
          {
            exerciseId: selectedExerciseId,
            order: 1,
            weight: 80,
            reps: 10,
            rpe: 8,
            rir: 2,
          },
          {
            exerciseId: '0001',
            order: 2,
            weight: 0,
            reps: 20,
            rpe: 7.5,
            rir: 3,
          },
        ],
      })
      .expect(201);

    expect(createWorkoutRes.body).toMatchObject({
      id: expect.any(String),
      userId: ctx.userA.id,
      startedAt: '2026-11-14T09:00:00.000Z',
      endedAt: '2026-11-14T10:10:00.000Z',
      location: 'Gimnasio Universitario UTEZ',
      notes: 'Sesión de fuerza en pecho y core',
      volume: 800,
      durationSeconds: 4200,
      lastMarks: [],
      comparison: null,
      sets: [
        expect.objectContaining({
          exerciseId: '0025',
          exerciseName: 'barbell bench press',
          order: 1,
          weight: 80,
          weightKg: 80,
          reps: 10,
          volume: 800,
          rpe: 8,
          rir: 2,
        }),
        expect.objectContaining({
          exerciseId: '0001',
          exerciseName: '3/4 sit-up',
          order: 2,
          weight: 0,
          weightKg: 0,
          reps: 20,
          volume: 0,
          rpe: 7.5,
          rir: 3,
        }),
      ],
    });

    const workoutId = createWorkoutRes.body.id as string;

    const secondWorkoutRes = await request(server())
      .post('/api/v1/workouts')
      .set('Authorization', authHeader)
      .send({
        startedAt: '2026-11-15T09:00:00.000Z',
        endedAt: '2026-11-15T10:00:00.000Z',
        location: 'Gimnasio Universitario UTEZ',
        notes: 'Segunda sesión con sobrecarga progresiva',
        sets: [
          {
            exerciseId: selectedExerciseId,
            order: 1,
            weight: 85,
            reps: 10,
            rpe: 8.5,
            rir: 1,
          },
        ],
      })
      .expect(201);

    expect(secondWorkoutRes.body).toMatchObject({
      volume: 850,
      durationSeconds: 3600,
      lastMarks: [
        expect.objectContaining({
          exerciseId: '0025',
          sessionId: workoutId,
          weight: 80,
          reps: 10,
          volume: 800,
        }),
      ],
      comparison: expect.objectContaining({
        previousSessionId: workoutId,
        volume: 850,
        previousVolume: 800,
        volumeDelta: 50,
        durationSeconds: 3600,
        previousDurationSeconds: 4200,
        durationDeltaSeconds: -600,
        setCount: 1,
        previousSetCount: 2,
        setCountDelta: -1,
      }),
    });

    const getWorkoutRes = await request(server())
      .get(`/api/v1/workouts/${workoutId}`)
      .set('Authorization', authHeader)
      .expect(200);

    expect(getWorkoutRes.body.id).toBe(workoutId);
    expect(getWorkoutRes.body.sets).toHaveLength(2);

    // =========================================================================
    // PASO 3: Consultar el servicio proxy de USDA FDC mediante UsdaHttpClient
    // =========================================================================
    const usdaSearchRes = await request(server())
      .get('/api/v1/foods/search')
      .query({ q: 'chicken' })
      .set('Authorization', authHeader)
      .expect(200);

    expect(ctx.usdaMock.calls).toContain('chicken');
    expect(usdaSearchRes.body).toEqual([
      expect.objectContaining({
        fdcId: 171077,
        name: 'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
        servingG: 100,
        kcal: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 3.6,
      }),
    ]);

    const searchedChicken = usdaSearchRes.body[0];

    // Escalar a una porción de 200g (2x la base de 100g)
    const portionFactor = 2;

    // =========================================================================
    // PASO 4: Crear una comida con alimentos de USDA y verificar congelamiento y resumen diario
    // =========================================================================
    const createMealRes = await request(server())
      .post('/api/v1/meals')
      .set('Authorization', authHeader)
      .send({
        eatenAt: '2026-11-14T13:30:00.000Z',
        mealType: MealType.LUNCH,
        notes: 'Comida post-entrenamiento con pollo de USDA y arroz',
        items: [
          {
            name: searchedChicken.name,
            fdcId: String(searchedChicken.fdcId),
            servingG: 200,
            kcal: searchedChicken.kcal * portionFactor,
            proteinG: searchedChicken.proteinG * portionFactor,
            carbsG: searchedChicken.carbsG * portionFactor,
            fatG: searchedChicken.fatG * portionFactor,
          },
          {
            name: 'Rice, white, long-grain, regular, cooked',
            fdcId: '168878',
            servingG: 100,
            kcal: 130,
            proteinG: 2.7,
            carbsG: 28.2,
            fatG: 0.3,
          },
        ],
      })
      .expect(201);

    expect(createMealRes.body).toMatchObject({
      id: expect.any(String),
      userId: ctx.userA.id,
      mealType: MealType.LUNCH,
      notes: 'Comida post-entrenamiento con pollo de USDA y arroz',
      totals: {
        kcal: 460,
        proteinG: 64.7,
        carbsG: 28.2,
        fatG: 7.5,
      },
    });
    expect(createMealRes.body.items).toHaveLength(2);

    const mealId = createMealRes.body.id as string;

    // Verificar consulta individual y resumen diario de nutrición
    const getMealRes = await request(server())
      .get(`/api/v1/meals/${mealId}`)
      .set('Authorization', authHeader)
      .expect(200);

    expect(getMealRes.body.id).toBe(mealId);
    expect(getMealRes.body.totals.kcal).toBe(460);

    const summaryRes = await request(server())
      .get('/api/v1/meals/summary')
      .query({ date: '2026-11-14' })
      .set('Authorization', authHeader)
      .expect(200);

    expect(summaryRes.body).toMatchObject({
      date: '2026-11-14',
      totals: {
        kcal: 460,
        proteinG: 64.7,
        carbsG: 28.2,
        fatG: 7.5,
      },
    });
    expect(summaryRes.body.byMealType[MealType.LUNCH].mealsCount).toBe(1);
    expect(summaryRes.body.byMealType[MealType.LUNCH].itemsCount).toBe(2);
  });

  it('valida los contratos de error 400 Bad Request, 401 Unauthorized y 404 Not Found', async () => {
    const authHeader = `Bearer ${ctx.userA.accessToken}`;

    // 401 sin token
    await request(server()).get('/api/v1/exercises').expect(401);
    await request(server()).post('/api/v1/workouts').send({}).expect(401);
    await request(server()).post('/api/v1/meals').send({}).expect(401);
    await request(server()).get('/api/v1/foods/search?q=apple').expect(401);

    // 400 con payloads inválidos
    await request(server())
      .get('/api/v1/exercises')
      .query({ page: 0 })
      .set('Authorization', authHeader)
      .expect(400);

    await request(server())
      .post('/api/v1/workouts')
      .set('Authorization', authHeader)
      .send({
        startedAt: 'fecha-invalida',
        sets: [{ exerciseId: '0001', order: 0, weight: -10, reps: 0 }],
      })
      .expect(400);

    await request(server())
      .post('/api/v1/meals')
      .set('Authorization', authHeader)
      .send({
        eatenAt: '2026-11-14T12:00:00.000Z',
        mealType: MealType.BREAKFAST,
        items: [
          {
            name: 'Alimento negativo',
            servingG: -50,
            kcal: -100,
            proteinG: 10,
            carbsG: 10,
            fatG: 5,
          },
        ],
      })
      .expect(400);

    await request(server())
      .get('/api/v1/foods/search')
      .query({ q: '' })
      .set('Authorization', authHeader)
      .expect(400);

    // 404 en recursos inexistentes
    await request(server())
      .get('/api/v1/exercises/9999')
      .set('Authorization', authHeader)
      .expect(404);

    await request(server())
      .get('/api/v1/workouts/non-existent-session')
      .set('Authorization', authHeader)
      .expect(404);

    await request(server())
      .get('/api/v1/meals/non-existent-meal')
      .set('Authorization', authHeader)
      .expect(404);
  });
});
