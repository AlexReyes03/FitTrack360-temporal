import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { MealType, Prisma, type Exercise, type MealLog } from '@prisma/client';
import { App } from 'supertest/types';
import { APP_HTTP_OPTIONS, configureApp } from '../../src/app.setup';
import { AuthModule } from '../../src/auth/auth.module';
import {
  FIREBASE_TOKEN_VERIFIER,
  MOCK_ID_TOKEN_PREFIX,
  MockFirebaseTokenVerifier,
} from '../../src/auth/firebase-token.verifier';
import { ExercisesModule } from '../../src/exercises/exercises.module';
import { FoodItemDto } from '../../src/foods/dto/food-item.dto';
import { FoodsModule } from '../../src/foods/foods.module';
import {
  UsdaHttpClient,
  type UsdaHttpResponse,
} from '../../src/foods/usda-http.client';
import type { MealItemEntity } from '../../src/meals/dto/meal-response.dto';
import { MealsModule } from '../../src/meals/meals.module';
import type { FrozenMealItemSnapshot } from '../../src/meals/meals.service';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { WorkoutsModule } from '../../src/workouts/workouts.module';
import type { NormalizedWorkoutSetInput } from '../../src/workouts/workouts.service';

export interface SeededTestUser {
  id: string;
  firebaseUid: string;
  email: string;
  username: string;
  displayName: string;
  accessToken: string;
}

export interface StoredMealRecord extends MealLog {
  items: MealItemEntity[];
}

export interface StoredWorkoutSetRecord extends NormalizedWorkoutSetInput {
  id: string;
  sessionId: string;
  exercise: { id: string; name: string } | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface StoredWorkoutSessionRecord {
  id: string;
  userId: string;
  routineId: string | null;
  startedAt: Date;
  endedAt: Date | null;
  location: string | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
  sets: StoredWorkoutSetRecord[];
}

export const SEEDED_EXERCISES: Exercise[] = [
  {
    id: '0001',
    name: '3/4 sit-up',
    nameEs: 'Abdominal 3/4',
    category: 'strength',
    bodyPart: 'waist',
    equipment: 'body weight',
    target: 'abs',
    muscleGroup: 'abdominals',
    secondaryMuscles: ['hip flexors', 'lower back'],
    level: 'beginner',
    instructionsEs: 'Túmbate de espaldas en el suelo y flexiona las rodillas.',
    instructionStepsEs: [
      'Túmbate de espaldas en el suelo.',
      'Eleva el torso hasta 3/4 del recorrido.',
    ],
    commonErrors: 'Tirar del cuello con las manos.',
    imageFile: '0001.jpg',
    gifFile: '0001.gif',
    mediaId: '0001',
    attribution: '© Gym visual - https://gymvisual.com/',
  },
  {
    id: '0025',
    name: 'barbell bench press',
    nameEs: 'Press de banca con barra',
    category: 'strength',
    bodyPart: 'chest',
    equipment: 'barbell',
    target: 'pectorals',
    muscleGroup: 'chest',
    secondaryMuscles: ['triceps', 'anterior deltoid'],
    level: 'intermediate',
    instructionsEs:
      'Acuéstate en el banco plano y baja la barra de forma controlada al pecho.',
    instructionStepsEs: [
      'Retrae las escápulas sobre el banco.',
      'Desciende la barra al esternón y empuja.',
    ],
    commonErrors: 'Rebotar la barra en el pecho.',
    imageFile: '0025.jpg',
    gifFile: '0025.gif',
    mediaId: '0025',
    attribution: '© Gym visual - https://gymvisual.com/',
  },
];

export const MOCK_USDA_CATALOG: FoodItemDto[] = [
  {
    fdcId: 171077,
    description:
      'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
    name: 'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
    servingG: 100,
    kcal: 165,
    proteinG: 31,
    carbsG: 0,
    fatG: 3.6,
  },
  {
    fdcId: 168878,
    description: 'Rice, white, long-grain, regular, cooked',
    name: 'Rice, white, long-grain, regular, cooked',
    servingG: 100,
    kcal: 130,
    proteinG: 2.7,
    carbsG: 28.2,
    fatG: 0.3,
  },
  {
    fdcId: 173944,
    description: 'Bananas, raw',
    name: 'Bananas, raw',
    servingG: 100,
    kcal: 89,
    proteinG: 1.09,
    carbsG: 22.84,
    fatG: 0.33,
  },
];

/**
 * Doble determinista de UsdaHttpClient para garantizar que UsdaFoodService
 * normalice los datos reales del contrato USDA sin depender de la red externa.
 */
export class MockUsdaHttpClient extends UsdaHttpClient {
  readonly calls: string[] = [];
  readonly urls: URL[] = [];

  get(url: URL, _options: { signal: AbortSignal }): Promise<UsdaHttpResponse> {
    this.urls.push(url);
    const query = (url.searchParams.get('query') ?? '').trim().toLowerCase();
    this.calls.push(query);

    const matches = MOCK_USDA_CATALOG.filter(
      (food) =>
        food.description.toLowerCase().includes(query) ||
        String(food.fdcId) === query,
    );

    const payload = {
      foods: matches.map((food) => ({
        fdcId: food.fdcId,
        description: food.description,
        brandOwner: food.brandOwner ?? undefined,
        foodNutrients: [
          { nutrientId: 1008, nutrientNumber: '208', value: food.kcal },
          { nutrientId: 1003, nutrientNumber: '203', value: food.proteinG },
          { nutrientId: 1005, nutrientNumber: '205', value: food.carbsG },
          { nutrientId: 1004, nutrientNumber: '204', value: food.fatG },
        ],
      })),
    };

    return Promise.resolve({
      ok: true,
      status: 200,
      json: () => Promise.resolve(payload),
    });
  }
}

function matchesStringFilter(value: string | null, filter: unknown): boolean {
  if (filter == null) return true;
  if (typeof filter === 'string') return value === filter;
  if (typeof filter === 'object') {
    const obj = filter as {
      equals?: string;
      contains?: string;
      in?: string[];
      mode?: 'default' | 'insensitive';
    };
    const insensitive = obj.mode === 'insensitive';
    const current = value ?? '';
    if (Array.isArray(obj.in)) {
      return obj.in.includes(current);
    }
    if (typeof obj.equals === 'string') {
      return insensitive
        ? current.toLowerCase() === obj.equals.toLowerCase()
        : current === obj.equals;
    }
    if (typeof obj.contains === 'string') {
      return insensitive
        ? current.toLowerCase().includes(obj.contains.toLowerCase())
        : current.includes(obj.contains);
    }
  }
  return true;
}

function matchesExerciseWhere(
  row: Exercise,
  where?: Prisma.ExerciseWhereInput,
): boolean {
  if (!where) return true;
  if (where.id && !matchesStringFilter(row.id, where.id)) return false;
  if (where.bodyPart && !matchesStringFilter(row.bodyPart, where.bodyPart)) {
    return false;
  }
  if (where.equipment && !matchesStringFilter(row.equipment, where.equipment)) {
    return false;
  }
  if (where.target && !matchesStringFilter(row.target, where.target)) {
    return false;
  }
  if (Array.isArray(where.OR) && where.OR.length > 0) {
    const anyMatch = where.OR.some((clause) => {
      if ('name' in clause && clause.name) {
        return matchesStringFilter(row.name, clause.name);
      }
      if ('nameEs' in clause && clause.nameEs) {
        return matchesStringFilter(row.nameEs, clause.nameEs);
      }
      return false;
    });
    if (!anyMatch) return false;
  }
  return true;
}

function sortExercises(
  rows: Exercise[],
  orderBy?: Prisma.ExerciseOrderByWithRelationInput,
): Exercise[] {
  const copy = [...rows];
  if (!orderBy) return copy;
  const field = orderBy.name ? 'name' : 'id';
  const dir = (orderBy.name ?? orderBy.id) === 'desc' ? -1 : 1;
  return copy.sort((a, b) => a[field].localeCompare(b[field]) * dir);
}

export function createInMemoryIntegrationStore() {
  const users = [
    {
      id: '11111111-1111-4111-8111-111111111111',
      firebaseUid: 'firebase-alice-w11',
      email: 'alice.w11@fittrack360.local',
      username: 'alice_w11',
      displayName: 'Alice Deportista',
      passwordHash: null,
      privacyConsentAt: new Date('2026-11-01T00:00:00.000Z'),
      privacyNoticeVersion: '1.0',
      createdAt: new Date('2026-11-01T00:00:00.000Z'),
      updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    },
    {
      id: '22222222-2222-4222-8222-222222222222',
      firebaseUid: 'firebase-bob-w11',
      email: 'bob.w11@fittrack360.local',
      username: 'bob_w11',
      displayName: 'Bob Atleta',
      passwordHash: null,
      privacyConsentAt: new Date('2026-11-01T00:00:00.000Z'),
      privacyNoticeVersion: '1.0',
      createdAt: new Date('2026-11-01T00:00:00.000Z'),
      updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    },
  ];

  const exercises: Exercise[] = SEEDED_EXERCISES.map((ex) => ({ ...ex }));
  const workoutSessions: StoredWorkoutSessionRecord[] = [];
  const meals: StoredMealRecord[] = [];

  let sessionSeq = 1;
  let setSeq = 1;
  let mealSeq = 1;
  let mealItemSeq = 1;

  return {
    users,
    exercises,
    workoutSessions,
    meals,
    user: {
      findUnique: ({
        where,
      }: {
        where: {
          id?: string;
          firebaseUid?: string;
          email?: string;
          username?: string;
        };
      }) => {
        const found =
          users.find(
            (u) =>
              (where.id !== undefined && u.id === where.id) ||
              (where.firebaseUid !== undefined &&
                u.firebaseUid === where.firebaseUid) ||
              (where.email !== undefined && u.email === where.email) ||
              (where.username !== undefined && u.username === where.username),
          ) ?? null;
        return Promise.resolve(found ? { ...found } : null);
      },
    },
    exercise: {
      findMany: (args?: {
        where?: Prisma.ExerciseWhereInput;
        skip?: number;
        take?: number;
        orderBy?: Prisma.ExerciseOrderByWithRelationInput;
      }): Promise<Exercise[]> => {
        const filtered = exercises.filter((ex) =>
          matchesExerciseWhere(ex, args?.where),
        );
        const ordered = sortExercises(filtered, args?.orderBy);
        const skip = args?.skip ?? 0;
        const sliced =
          args?.take !== undefined
            ? ordered.slice(skip, skip + args.take)
            : ordered.slice(skip);
        return Promise.resolve(sliced.map((ex) => ({ ...ex })));
      },
      count: (args?: {
        where?: Prisma.ExerciseWhereInput;
      }): Promise<number> => {
        const filtered = exercises.filter((ex) =>
          matchesExerciseWhere(ex, args?.where),
        );
        return Promise.resolve(filtered.length);
      },
      findUnique: ({
        where,
      }: {
        where: { id: string };
      }): Promise<Exercise | null> => {
        const found = exercises.find((ex) => ex.id === where.id) ?? null;
        return Promise.resolve(found ? { ...found } : null);
      },
    },
    routine: {
      findFirst: (): Promise<{ id: string } | null> => Promise.resolve(null),
    },
    workoutSession: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          routineId?: string | null;
          startedAt: Date;
          endedAt: Date | null;
          location: string | null;
          notes: string | null;
          sets?: { create: NormalizedWorkoutSetInput[] };
        };
      }): Promise<StoredWorkoutSessionRecord> => {
        const now = new Date('2026-11-14T10:00:00.000Z');
        const sessionId = `session-${sessionSeq++}`;
        const createdSets: StoredWorkoutSetRecord[] = (
          data.sets?.create ?? []
        ).map((set) => {
          const matchedEx = exercises.find((ex) => ex.id === set.exerciseId);
          return {
            id: `set-${setSeq++}`,
            sessionId,
            exerciseId: set.exerciseId,
            exercise: matchedEx
              ? { id: matchedEx.id, name: matchedEx.name }
              : null,
            order: set.order,
            weight: set.weight,
            reps: set.reps,
            rpe: set.rpe,
            rir: set.rir,
            createdAt: now,
            updatedAt: now,
          };
        });

        const record: StoredWorkoutSessionRecord = {
          id: sessionId,
          userId: data.userId,
          routineId: data.routineId ?? null,
          startedAt: data.startedAt,
          endedAt: data.endedAt,
          location: data.location,
          notes: data.notes,
          createdAt: now,
          updatedAt: now,
          sets: createdSets,
        };
        workoutSessions.push(record);
        return Promise.resolve(record);
      },
      findMany: ({
        where,
        orderBy,
      }: {
        where: { userId: string };
        orderBy?: { startedAt: 'asc' | 'desc' };
      }): Promise<StoredWorkoutSessionRecord[]> => {
        const filtered = workoutSessions.filter(
          (s) => s.userId === where.userId,
        );
        const dir = orderBy?.startedAt === 'asc' ? 1 : -1;
        const sorted = [...filtered].sort(
          (a, b) => (a.startedAt.getTime() - b.startedAt.getTime()) * dir,
        );
        return Promise.resolve(sorted);
      },
      findFirst: ({
        where,
      }: {
        where: { id: string; userId: string };
      }): Promise<StoredWorkoutSessionRecord | null> => {
        const found =
          workoutSessions.find(
            (s) => s.id === where.id && s.userId === where.userId,
          ) ?? null;
        return Promise.resolve(found);
      },
      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: {
          startedAt?: Date;
          endedAt?: Date | null;
          location?: string | null;
          notes?: string | null;
          sets?: {
            deleteMany: Record<string, never>;
            create: NormalizedWorkoutSetInput[];
          };
        };
      }): Promise<StoredWorkoutSessionRecord> => {
        const record = workoutSessions.find((s) => s.id === where.id);
        if (!record) {
          throw new Error('WorkoutSession not found');
        }
        const now = new Date('2026-11-14T11:00:00.000Z');
        if (data.startedAt !== undefined) record.startedAt = data.startedAt;
        if (data.endedAt !== undefined) record.endedAt = data.endedAt;
        if (data.location !== undefined) record.location = data.location;
        if (data.notes !== undefined) record.notes = data.notes;
        if (data.sets !== undefined) {
          record.sets = data.sets.create.map((set) => {
            const matchedEx = exercises.find((ex) => ex.id === set.exerciseId);
            return {
              id: `set-${setSeq++}`,
              sessionId: record.id,
              exerciseId: set.exerciseId,
              exercise: matchedEx
                ? { id: matchedEx.id, name: matchedEx.name }
                : null,
              order: set.order,
              weight: set.weight,
              reps: set.reps,
              rpe: set.rpe,
              rir: set.rir,
              createdAt: now,
              updatedAt: now,
            };
          });
        }
        record.updatedAt = now;
        return Promise.resolve(record);
      },
      delete: ({
        where,
      }: {
        where: { id: string };
      }): Promise<StoredWorkoutSessionRecord> => {
        const idx = workoutSessions.findIndex((s) => s.id === where.id);
        if (idx === -1) {
          throw new Error('WorkoutSession not found');
        }
        const [removed] = workoutSessions.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
    mealLog: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          eatenAt: Date;
          mealType: MealType;
          notes: string | null;
          photoId: string | null;
          items?: { create: FrozenMealItemSnapshot[] };
        };
      }): Promise<StoredMealRecord> => {
        const now = new Date('2026-11-14T12:00:00.000Z');
        const mealId = `meal-${mealSeq++}`;
        const createdItems: MealItemEntity[] = (data.items?.create ?? []).map(
          (item) => ({
            id: `meal-item-${mealItemSeq++}`,
            mealLogId: mealId,
            fdcId: item.fdcId,
            name: item.name,
            servingG: item.servingG,
            kcal: item.kcal,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
            createdAt: now,
            updatedAt: now,
          }),
        );

        const record: StoredMealRecord = {
          id: mealId,
          userId: data.userId,
          eatenAt: data.eatenAt,
          mealType: data.mealType,
          notes: data.notes,
          photoId: data.photoId,
          createdAt: now,
          updatedAt: now,
          items: createdItems,
        };
        meals.push(record);
        return Promise.resolve(record);
      },
      findMany: ({
        where,
      }: {
        where?: {
          userId?: string;
          eatenAt?: { gte?: Date; lte?: Date };
        };
      }): Promise<StoredMealRecord[]> => {
        const filtered = meals.filter((m) => {
          if (where?.userId && m.userId !== where.userId) return false;
          if (where?.eatenAt?.gte && m.eatenAt < where.eatenAt.gte) {
            return false;
          }
          if (where?.eatenAt?.lte && m.eatenAt > where.eatenAt.lte) {
            return false;
          }
          return true;
        });
        return Promise.resolve(filtered);
      },
      findFirst: ({
        where,
      }: {
        where: { id: string; userId: string };
      }): Promise<StoredMealRecord | null> => {
        const found =
          meals.find((m) => m.id === where.id && m.userId === where.userId) ??
          null;
        return Promise.resolve(found);
      },
      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: {
          eatenAt?: Date;
          mealType?: MealType;
          notes?: string | null;
          photoId?: string | null;
          items?: {
            deleteMany: Record<string, never>;
            create: NormalizedWorkoutSetInput[] | FrozenMealItemSnapshot[];
          };
        };
      }): Promise<StoredMealRecord> => {
        const record = meals.find((m) => m.id === where.id);
        if (!record) {
          throw new Error('MealLog not found');
        }
        const now = new Date('2026-11-14T13:00:00.000Z');
        if (data.eatenAt !== undefined) record.eatenAt = data.eatenAt;
        if (data.mealType !== undefined) record.mealType = data.mealType;
        if (data.notes !== undefined) record.notes = data.notes;
        if (data.photoId !== undefined) record.photoId = data.photoId;
        if (data.items !== undefined) {
          record.items = (data.items.create as FrozenMealItemSnapshot[]).map(
            (item) => ({
              id: `meal-item-${mealItemSeq++}`,
              mealLogId: record.id,
              fdcId: item.fdcId,
              name: item.name,
              servingG: item.servingG,
              kcal: item.kcal,
              proteinG: item.proteinG,
              carbsG: item.carbsG,
              fatG: item.fatG,
              createdAt: now,
              updatedAt: now,
            }),
          );
        }
        record.updatedAt = now;
        return Promise.resolve(record);
      },
      delete: ({
        where,
      }: {
        where: { id: string };
      }): Promise<StoredMealRecord> => {
        const idx = meals.findIndex((m) => m.id === where.id);
        if (idx === -1) {
          throw new Error('MealLog not found');
        }
        const [removed] = meals.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
  };
}

export interface W11IntegrationContext {
  app: INestApplication<App>;
  store: ReturnType<typeof createInMemoryIntegrationStore>;
  usdaMock: MockUsdaHttpClient;
  userA: SeededTestUser;
  userB: SeededTestUser;
}

export async function createW11TestingContext(): Promise<W11IntegrationContext> {
  const store = createInMemoryIntegrationStore();
  const usdaMock = new MockUsdaHttpClient();

  const moduleRef = await Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({
        isGlobal: true,
        ignoreEnvFile: true,
        load: [
          () => ({
            FIREBASE_AUTH_MODE: 'mock',
            USDA_FDC_API_KEY: 'test-usda-api-key-not-used-in-network',
            SMTP_HOST: 'localhost',
          }),
        ],
      }),
      PrismaModule,
      AuthModule,
      ExercisesModule,
      WorkoutsModule,
      MealsModule,
      FoodsModule,
    ],
  })
    .overrideProvider(PrismaService)
    .useValue(store)
    .overrideProvider(FIREBASE_TOKEN_VERIFIER)
    .useValue(new MockFirebaseTokenVerifier())
    .overrideProvider(UsdaHttpClient)
    .useValue(usdaMock)
    .compile();

  const app =
    moduleRef.createNestApplication<INestApplication<App>>(APP_HTTP_OPTIONS);
  configureApp(app);
  await app.init();

  const [rawUserA, rawUserB] = store.users;
  const tokenA = `${MOCK_ID_TOKEN_PREFIX}${rawUserA.firebaseUid}:${rawUserA.email}`;
  const tokenB = `${MOCK_ID_TOKEN_PREFIX}${rawUserB.firebaseUid}:${rawUserB.email}`;

  return {
    app,
    store,
    usdaMock,
    userA: {
      id: rawUserA.id,
      firebaseUid: rawUserA.firebaseUid,
      email: rawUserA.email,
      username: rawUserA.username,
      displayName: rawUserA.displayName,
      accessToken: tokenA,
    },
    userB: {
      id: rawUserB.id,
      firebaseUid: rawUserB.firebaseUid,
      email: rawUserB.email,
      username: rawUserB.username,
      displayName: rawUserB.displayName,
      accessToken: tokenB,
    },
  };
}
