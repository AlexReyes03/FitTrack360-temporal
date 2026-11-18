import { INestApplication } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { App } from 'supertest/types';
import { configureApp } from '../../src/app.setup';
import { AuthModule } from '../../src/auth/auth.module';
import {
  FIREBASE_TOKEN_VERIFIER,
  MOCK_ID_TOKEN_PREFIX,
  MockFirebaseTokenVerifier,
} from '../../src/auth/firebase-token.verifier';
import { DashboardModule } from '../../src/dashboard/dashboard.module';
import { PhotosModule } from '../../src/photos/photos.module';
import { PrivacyModule } from '../../src/privacy/privacy.module';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { ProgressModule } from '../../src/progress/progress.module';
import { RoutinesModule } from '../../src/routines/routines.module';
import { StorageService } from '../../src/storage/storage.service';
import { UsersModule } from '../../src/users/users.module';
import { WorkoutsModule } from '../../src/workouts/workouts.module';
import type { NormalizedWorkoutSetInput } from '../../src/workouts/workouts.service';
import {
  SEEDED_EXERCISES,
  type SeededTestUser,
  type StoredWorkoutSessionRecord,
  type StoredWorkoutSetRecord,
} from './w11-test-setup';

type DateRange = { gte?: Date; lt?: Date; lte?: Date };

interface StoredRoutineExercise {
  id: string;
  routineId: string;
  exerciseId: string;
  position: number;
  targetSets: number;
  targetReps: number;
}

interface StoredRoutine {
  id: string;
  userId: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
  exercises: StoredRoutineExercise[];
}

interface StoredMetric {
  id: string;
  userId: string;
  measuredAt: Date;
  weightKg: number | null;
  bodyFatPercent: number | null;
  waistCm: number | null;
}

interface StoredPhoto {
  id: string;
  userId: string;
  storageKey: string;
  mimeType: string;
  sizeBytes: number;
  width: number;
  height: number;
  mealId: string | null;
  metricId: string | null;
  createdAt: Date;
}

function inRange(value: Date, range?: DateRange): boolean {
  if (!range) return true;
  if (range.gte && value < range.gte) return false;
  if (range.lt && value >= range.lt) return false;
  if (range.lte && value > range.lte) return false;
  return true;
}

function withSets(
  session: StoredWorkoutSessionRecord,
  include?: { sets?: { include?: { exercise?: unknown } } },
) {
  if (!include?.sets) return { ...session };
  return {
    ...session,
    sets: session.sets.map((set) => ({
      ...set,
      exercise: set.exercise
        ? { id: set.exercise.id, name: set.exercise.name }
        : null,
    })),
  };
}

export function createInMemoryW12Store() {
  const users = [
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      firebaseUid: 'firebase-alice-w12',
      email: 'alice.w12@fittrack360.local',
      username: 'alice_w12',
      displayName: 'Alice W12',
      passwordHash: null as string | null,
      privacyConsentAt: new Date('2026-11-01T00:00:00.000Z'),
      privacyNoticeVersion: '2',
      createdAt: new Date('2026-11-01T00:00:00.000Z'),
      updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    },
    {
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      firebaseUid: 'firebase-bob-w12',
      email: 'bob.w12@fittrack360.local',
      username: 'bob_w12',
      displayName: 'Bob W12',
      passwordHash: null as string | null,
      privacyConsentAt: new Date('2026-11-01T00:00:00.000Z'),
      privacyNoticeVersion: '2',
      createdAt: new Date('2026-11-01T00:00:00.000Z'),
      updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    },
  ];

  const exercises = SEEDED_EXERCISES.map((ex) => ({ ...ex }));
  const routines: StoredRoutine[] = [];
  const workoutSessions: StoredWorkoutSessionRecord[] = [];
  const metrics: StoredMetric[] = [];
  const photos: StoredPhoto[] = [];
  const settings: Array<{
    userId: string;
    dailyCalorieGoal: number;
    proteinGoalG: number;
    carbsGoalG: number;
    fatGoalG: number;
  }> = [];

  const mapSets = (
    sessionId: string,
    created: NormalizedWorkoutSetInput[],
    now: Date,
  ): StoredWorkoutSetRecord[] =>
    created.map((set) => {
      const matched = exercises.find((ex) => ex.id === set.exerciseId);
      return {
        id: randomUUID(),
        sessionId,
        exerciseId: set.exerciseId,
        exercise: matched ? { id: matched.id, name: matched.name } : null,
        order: set.order,
        weight: set.weight,
        reps: set.reps,
        rpe: set.rpe,
        rir: set.rir,
        createdAt: now,
        updatedAt: now,
      };
    });

  const store = {
    users,
    routines,
    workoutSessions,
    metrics,
    photos,
    user: {
      findUnique: ({
        where,
        select,
      }: {
        where: {
          id?: string;
          firebaseUid?: string;
          email?: string;
          username?: string;
        };
        select?: Record<string, unknown>;
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
        if (!found) return Promise.resolve(null);
        if (!select) return Promise.resolve({ ...found });

        const result: Record<string, unknown> = {};
        for (const key of Object.keys(select)) {
          if (key === 'settings') {
            result.settings =
              settings.find((s) => s.userId === found.id) ?? null;
          } else if (key === 'workoutSessions') {
            result.workoutSessions = workoutSessions
              .filter((s) => s.userId === found.id)
              .map((s) => ({
                ...s,
                sets: [...s.sets].sort((a, b) => a.order - b.order),
              }));
          } else if (key === 'routines') {
            result.routines = routines
              .filter((r) => r.userId === found.id)
              .map((r) => ({
                ...r,
                exercises: [...r.exercises].sort(
                  (a, b) => a.position - b.position,
                ),
              }));
          } else if (key === 'mealLogs') {
            result.mealLogs = [];
          } else if (key === 'bodyMetrics') {
            result.bodyMetrics = metrics
              .filter((m) => m.userId === found.id)
              .sort((a, b) => a.measuredAt.getTime() - b.measuredAt.getTime());
          } else if (key === 'photos') {
            result.photos = photos
              .filter((p) => p.userId === found.id)
              .map(
                ({
                  id,
                  mimeType,
                  sizeBytes,
                  width,
                  height,
                  mealId,
                  metricId,
                  createdAt,
                }) => ({
                  id,
                  mimeType,
                  sizeBytes,
                  width,
                  height,
                  mealId,
                  metricId,
                  createdAt,
                }),
              );
          } else if (key in found) {
            result[key] = (found as Record<string, unknown>)[key];
          }
        }
        return Promise.resolve(result);
      },
    },
    userSettings: {
      findUnique: ({ where }: { where: { userId: string } }) =>
        Promise.resolve(
          settings.find((s) => s.userId === where.userId) ?? null,
        ),
    },
    exercise: {
      findMany: ({ where }: { where?: { id?: { in?: string[] } } }) => {
        const ids = where?.id?.in;
        const rows = ids
          ? exercises.filter((ex) => ids.includes(ex.id))
          : exercises;
        return Promise.resolve(rows.map((ex) => ({ id: ex.id, ...ex })));
      },
      findUnique: ({ where }: { where: { id: string } }) => {
        const found = exercises.find((ex) => ex.id === where.id) ?? null;
        return Promise.resolve(found ? { ...found } : null);
      },
    },
    routine: {
      create: ({
        data,
        include,
      }: {
        data: {
          userId: string;
          name: string;
          exercises?: {
            create: Array<{
              exerciseId: string;
              position: number;
              targetSets: number;
              targetReps: number;
            }>;
          };
        };
        include?: { exercises?: { orderBy?: { position: 'asc' | 'desc' } } };
      }) => {
        const now = new Date('2026-11-18T10:00:00.000Z');
        const id = randomUUID();
        const createdExercises = (data.exercises?.create ?? []).map((item) => ({
          id: randomUUID(),
          routineId: id,
          exerciseId: item.exerciseId,
          position: item.position,
          targetSets: item.targetSets,
          targetReps: item.targetReps,
        }));
        const record: StoredRoutine = {
          id,
          userId: data.userId,
          name: data.name,
          createdAt: now,
          updatedAt: now,
          exercises: createdExercises,
        };
        routines.push(record);
        const exercisesOut = include?.exercises
          ? [...record.exercises].sort((a, b) => a.position - b.position)
          : record.exercises;
        return Promise.resolve({ ...record, exercises: exercisesOut });
      },
      findMany: ({
        where,
        include,
      }: {
        where: { userId: string };
        include?: { exercises?: unknown };
        orderBy?: unknown;
      }) => {
        const rows = routines.filter((r) => r.userId === where.userId);
        return Promise.resolve(
          rows.map((r) => ({
            ...r,
            exercises: include?.exercises
              ? [...r.exercises].sort((a, b) => a.position - b.position)
              : r.exercises,
          })),
        );
      },
      findFirst: ({
        where,
        include,
        select,
      }: {
        where: { id: string; userId: string };
        include?: { exercises?: unknown };
        select?: { id?: boolean };
      }) => {
        const found =
          routines.find(
            (r) => r.id === where.id && r.userId === where.userId,
          ) ?? null;
        if (!found) return Promise.resolve(null);
        if (select?.id) return Promise.resolve({ id: found.id });
        return Promise.resolve({
          ...found,
          exercises: include?.exercises
            ? [...found.exercises].sort((a, b) => a.position - b.position)
            : found.exercises,
        });
      },
      update: ({
        where,
        data,
        include,
      }: {
        where: { id: string };
        data: {
          name?: string;
          exercises?: {
            deleteMany: Record<string, never>;
            create: Array<{
              exerciseId: string;
              position: number;
              targetSets: number;
              targetReps: number;
            }>;
          };
        };
        include?: { exercises?: unknown };
      }) => {
        const record = routines.find((r) => r.id === where.id);
        if (!record) throw new Error('Routine not found');
        if (data.name !== undefined) record.name = data.name;
        if (data.exercises) {
          record.exercises = data.exercises.create.map((item) => ({
            id: randomUUID(),
            routineId: record.id,
            exerciseId: item.exerciseId,
            position: item.position,
            targetSets: item.targetSets,
            targetReps: item.targetReps,
          }));
        }
        record.updatedAt = new Date('2026-11-18T11:00:00.000Z');
        return Promise.resolve({
          ...record,
          exercises: include?.exercises
            ? [...record.exercises].sort((a, b) => a.position - b.position)
            : record.exercises,
        });
      },
      delete: ({ where }: { where: { id: string } }) => {
        const idx = routines.findIndex((r) => r.id === where.id);
        if (idx === -1) throw new Error('Routine not found');
        const [removed] = routines.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
    workoutSession: {
      create: ({
        data,
        include,
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
        include?: { sets?: { include?: { exercise?: unknown } } };
      }) => {
        const now = new Date('2026-11-18T12:00:00.000Z');
        const sessionId = randomUUID();
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
          sets: mapSets(sessionId, data.sets?.create ?? [], now),
        };
        workoutSessions.push(record);
        return Promise.resolve(withSets(record, include));
      },
      findMany: ({
        where,
        include,
        orderBy,
      }: {
        where: { userId: string };
        include?: { sets?: { include?: { exercise?: unknown } } };
        orderBy?: { startedAt: 'asc' | 'desc' };
      }) => {
        const filtered = workoutSessions.filter(
          (s) => s.userId === where.userId,
        );
        const dir = orderBy?.startedAt === 'asc' ? 1 : -1;
        const sorted = [...filtered].sort(
          (a, b) => (a.startedAt.getTime() - b.startedAt.getTime()) * dir,
        );
        return Promise.resolve(sorted.map((s) => withSets(s, include)));
      },
      findFirst: ({
        where,
        include,
        orderBy,
      }: {
        where: {
          id?: string;
          userId?: string;
          startedAt?: DateRange;
        };
        include?: { sets?: { include?: { exercise?: unknown } } };
        orderBy?: { startedAt: 'asc' | 'desc' };
      }) => {
        const found = workoutSessions
          .filter((s) => {
            if (where.id && s.id !== where.id) return false;
            if (where.userId && s.userId !== where.userId) return false;
            if (!inRange(s.startedAt, where.startedAt)) return false;
            return true;
          })
          .sort((a, b) =>
            orderBy?.startedAt === 'asc'
              ? a.startedAt.getTime() - b.startedAt.getTime()
              : b.startedAt.getTime() - a.startedAt.getTime(),
          );
        const first = found[0] ?? null;
        return Promise.resolve(first ? withSets(first, include) : null);
      },
      count: ({ where }: { where: { userId: string } }) =>
        Promise.resolve(
          workoutSessions.filter((s) => s.userId === where.userId).length,
        ),
      update: ({
        where,
        data,
        include,
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
        include?: { sets?: { include?: { exercise?: unknown } } };
      }) => {
        const record = workoutSessions.find((s) => s.id === where.id);
        if (!record) throw new Error('WorkoutSession not found');
        const now = new Date('2026-11-18T13:00:00.000Z');
        if (data.startedAt !== undefined) record.startedAt = data.startedAt;
        if (data.endedAt !== undefined) record.endedAt = data.endedAt;
        if (data.location !== undefined) record.location = data.location;
        if (data.notes !== undefined) record.notes = data.notes;
        if (data.sets) {
          record.sets = mapSets(record.id, data.sets.create, now);
        }
        record.updatedAt = now;
        return Promise.resolve(withSets(record, include));
      },
      delete: ({ where }: { where: { id: string } }) => {
        const idx = workoutSessions.findIndex((s) => s.id === where.id);
        if (idx === -1) throw new Error('WorkoutSession not found');
        const [removed] = workoutSessions.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
    bodyMetric: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          measuredAt: Date;
          weightKg: number | null;
          bodyFatPercent: number | null;
          waistCm: number | null;
        };
      }) => {
        const row: StoredMetric = {
          id: randomUUID(),
          ...data,
        };
        metrics.push(row);
        return Promise.resolve({ ...row });
      },
      findMany: ({
        where,
        orderBy,
      }: {
        where: { userId: string };
        orderBy?: { measuredAt: 'asc' | 'desc' };
      }) => {
        const rows = metrics.filter((m) => m.userId === where.userId);
        const sorted = [...rows].sort((a, b) =>
          orderBy?.measuredAt === 'asc'
            ? a.measuredAt.getTime() - b.measuredAt.getTime()
            : b.measuredAt.getTime() - a.measuredAt.getTime(),
        );
        return Promise.resolve(sorted.map((m) => ({ ...m })));
      },
      findFirst: ({
        where,
        orderBy,
      }: {
        where: { id?: string; userId?: string; measuredAt?: DateRange };
        orderBy?: { measuredAt: 'asc' | 'desc' };
      }) => {
        const found = metrics
          .filter((m) => {
            if (where.id && m.id !== where.id) return false;
            if (where.userId && m.userId !== where.userId) return false;
            if (!inRange(m.measuredAt, where.measuredAt)) return false;
            return true;
          })
          .sort((a, b) =>
            orderBy?.measuredAt === 'asc'
              ? a.measuredAt.getTime() - b.measuredAt.getTime()
              : b.measuredAt.getTime() - a.measuredAt.getTime(),
          );
        return Promise.resolve(found[0] ? { ...found[0] } : null);
      },
      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: Partial<StoredMetric>;
      }) => {
        const row = metrics.find((m) => m.id === where.id);
        if (!row) throw new Error('BodyMetric not found');
        Object.assign(row, data);
        return Promise.resolve({ ...row });
      },
      delete: ({ where }: { where: { id: string } }) => {
        const idx = metrics.findIndex((m) => m.id === where.id);
        if (idx === -1) throw new Error('BodyMetric not found');
        const [removed] = metrics.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
    photo: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          storageKey: string;
          mimeType: string;
          sizeBytes: number;
          width: number;
          height: number;
          mealId?: string | null;
          metricId?: string | null;
        };
      }) => {
        const row: StoredPhoto = {
          id: randomUUID(),
          userId: data.userId,
          storageKey: data.storageKey,
          mimeType: data.mimeType,
          sizeBytes: data.sizeBytes,
          width: data.width,
          height: data.height,
          mealId: data.mealId ?? null,
          metricId: data.metricId ?? null,
          createdAt: new Date('2026-11-18T14:00:00.000Z'),
        };
        photos.push(row);
        return Promise.resolve({ ...row });
      },
      findFirst: ({ where }: { where: { id: string; userId: string } }) => {
        const found =
          photos.find((p) => p.id === where.id && p.userId === where.userId) ??
          null;
        return Promise.resolve(found ? { ...found } : null);
      },
      delete: ({ where }: { where: { id: string } }) => {
        const idx = photos.findIndex((p) => p.id === where.id);
        if (idx === -1) throw new Error('Photo not found');
        const [removed] = photos.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
    mealLog: {
      findMany: () => Promise.resolve([]),
      findFirst: () => Promise.resolve(null),
    },
    $transaction: async <T>(fn: (tx: typeof store) => Promise<T>): Promise<T> =>
      fn(store),
  };

  return store;
}

export interface W12IntegrationContext {
  app: INestApplication<App>;
  store: ReturnType<typeof createInMemoryW12Store>;
  uploadDir: string;
  userA: SeededTestUser;
  userB: SeededTestUser;
  cleanup: () => Promise<void>;
}

export async function createW12TestingContext(): Promise<W12IntegrationContext> {
  const store = createInMemoryW12Store();
  const uploadDir = await mkdtemp(join(tmpdir(), 'fittrack-w12-'));
  const storage = new StorageService(
    new ConfigService({ UPLOAD_DIR: uploadDir }),
  );

  const moduleRef = await Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({
        isGlobal: true,
        ignoreEnvFile: true,
        load: [
          () => ({
            FIREBASE_AUTH_MODE: 'mock',
            UPLOAD_DIR: uploadDir,
            SMTP_HOST: 'localhost',
          }),
        ],
      }),
      PrismaModule,
      AuthModule,
      UsersModule,
      WorkoutsModule,
      RoutinesModule,
      ProgressModule,
      PhotosModule,
      PrivacyModule,
      DashboardModule,
    ],
  })
    .overrideProvider(PrismaService)
    .useValue(store)
    .overrideProvider(FIREBASE_TOKEN_VERIFIER)
    .useValue(new MockFirebaseTokenVerifier())
    .overrideProvider(StorageService)
    .useValue(storage)
    .compile();

  const app = moduleRef.createNestApplication<INestApplication<App>>();
  configureApp(app);
  await app.init();

  const [rawUserA, rawUserB] = store.users;
  const tokenA = `${MOCK_ID_TOKEN_PREFIX}${rawUserA.firebaseUid}:${rawUserA.email}`;
  const tokenB = `${MOCK_ID_TOKEN_PREFIX}${rawUserB.firebaseUid}:${rawUserB.email}`;

  return {
    app,
    store,
    uploadDir,
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
    cleanup: async () => {
      await app.close();
      await rm(uploadDir, { recursive: true, force: true });
    },
  };
}
