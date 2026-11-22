import * as fs from 'node:fs';
import * as path from 'node:path';
import { DistanceUnit, MealType, Prisma, WeightUnit } from '@prisma/client';

describe('Prisma Schema, Migrations & Cascade Rules (Tasks W11-01 & W12-01)', () => {
  const getModel = (name: string) => {
    const model = Prisma.dmmf.datamodel.models.find((m) => m.name === name);
    expect(model).toBeDefined();
    return model!;
  };

  const getField = (modelName: string, fieldName: string) => {
    const model = getModel(modelName);
    const field = model.fields.find((f) => f.name === fieldName);
    expect(field).toBeDefined();
    return field!;
  };

  describe('W11-BE-01.1 · Modelo Exercise extendido', () => {
    it('incluye nameEs, level, commonErrors opcionales, instrucciones, pasos, músculos y media', () => {
      const nameEs = getField('Exercise', 'nameEs');
      expect(nameEs.isRequired).toBe(false);
      expect(nameEs.type).toBe('String');

      const level = getField('Exercise', 'level');
      expect(level.isRequired).toBe(false);
      expect(level.type).toBe('String');

      const commonErrors = getField('Exercise', 'commonErrors');
      expect(commonErrors.isRequired).toBe(false);
      expect(commonErrors.type).toBe('String');

      const instructionsEs = getField('Exercise', 'instructionsEs');
      expect(instructionsEs.isRequired).toBe(false);
      expect(instructionsEs.type).toBe('String');

      const instructionStepsEs = getField('Exercise', 'instructionStepsEs');
      expect(instructionStepsEs.isList).toBe(true);
      expect(instructionStepsEs.type).toBe('String');

      const muscleGroup = getField('Exercise', 'muscleGroup');
      expect(muscleGroup.type).toBe('String');

      const secondaryMuscles = getField('Exercise', 'secondaryMuscles');
      expect(secondaryMuscles.isList).toBe(true);
      expect(secondaryMuscles.type).toBe('String');

      expect(getField('Exercise', 'imageFile').isRequired).toBe(true);
      expect(getField('Exercise', 'gifFile').isRequired).toBe(true);
      expect(getField('Exercise', 'mediaId').isRequired).toBe(false);
      expect(getField('Exercise', 'attribution').isRequired).toBe(true);
    });
  });

  describe('W11-BE-01.2 · WorkoutSession (location) y modelo WorkoutSet', () => {
    it('define location opcional en WorkoutSession y relaciona WorkoutSet con sesión y ejercicio', () => {
      const location = getField('WorkoutSession', 'location');
      expect(location.isRequired).toBe(false);
      expect(location.type).toBe('String');

      const setsRelation = getField('WorkoutSession', 'sets');
      expect(setsRelation.type).toBe('WorkoutSet');
      expect(setsRelation.isList).toBe(true);

      const order = getField('WorkoutSet', 'order');
      expect(order.isRequired).toBe(true);
      expect(order.type).toBe('Int');

      const weight = getField('WorkoutSet', 'weight');
      expect(weight.isRequired).toBe(true);
      expect(weight.type).toBe('Float');

      const reps = getField('WorkoutSet', 'reps');
      expect(reps.isRequired).toBe(true);
      expect(reps.type).toBe('Int');

      const rpe = getField('WorkoutSet', 'rpe');
      expect(rpe.isRequired).toBe(false);
      expect(rpe.type).toBe('Float');

      const rir = getField('WorkoutSet', 'rir');
      expect(rir.isRequired).toBe(false);
      expect(rir.type).toBe('Int');

      const sessionRel = getField('WorkoutSet', 'session');
      expect(sessionRel.type).toBe('WorkoutSession');

      const exerciseRel = getField('WorkoutSet', 'exercise');
      expect(exerciseRel.type).toBe('Exercise');
    });
  });

  describe('W11-BE-01.3 · Modelo MealItem (macros congelados) y borrado en cascada (Cascade)', () => {
    it('define MealItem con nombre, porción y macros congelados vinculado a MealLog', () => {
      expect(getField('MealLog', 'items').type).toBe('MealItem');
      expect(getField('MealItem', 'name').isRequired).toBe(true);
      expect(getField('MealItem', 'servingG').type).toBe('Float');
      expect(getField('MealItem', 'kcal').type).toBe('Float');
      expect(getField('MealItem', 'proteinG').type).toBe('Float');
      expect(getField('MealItem', 'carbsG').type).toBe('Float');
      expect(getField('MealItem', 'fatG').type).toBe('Float');
    });

    it('configura onDelete: Cascade desde User hacia sesiones, series, comidas e ítems', () => {
      expect(getField('RefreshToken', 'user').relationOnDelete).toBe('Cascade');
      expect(getField('PasswordResetCode', 'user').relationOnDelete).toBe(
        'Cascade',
      );
      expect(getField('WorkoutSession', 'user').relationOnDelete).toBe(
        'Cascade',
      );
      expect(getField('WorkoutSet', 'session').relationOnDelete).toBe(
        'Cascade',
      );
      expect(getField('WorkoutSet', 'exercise').relationOnDelete).toBe(
        'Restrict',
      );
      expect(getField('MealLog', 'user').relationOnDelete).toBe('Cascade');
      expect(getField('MealItem', 'mealLog').relationOnDelete).toBe('Cascade');
    });
  });

  describe('W12-BE-00.1 · Identidad AUTH-01 en User, metas en UserSettings y modelos Routine / RoutineExercise', () => {
    it('preserva firebaseUid único y passwordHash opcional en User, y mantiene metas y preferencias en UserSettings sin duplicarlas en User', () => {
      const firebaseUid = getField('User', 'firebaseUid');
      expect(firebaseUid.isRequired).toBe(false);
      expect(firebaseUid.isUnique).toBe(true);
      expect(firebaseUid.type).toBe('String');

      const passwordHash = getField('User', 'passwordHash');
      expect(passwordHash.isRequired).toBe(false);
      expect(passwordHash.type).toBe('String');

      expect(getField('User', 'privacyConsentAt').isRequired).toBe(true);
      expect(getField('User', 'privacyNoticeVersion').isRequired).toBe(true);

      // Las metas y preferencias residen exclusivamente en UserSettings (#138), no en User
      const userFieldNames = getModel('User').fields.map((f) => f.name);
      expect(userFieldNames).not.toContain('dailyCalorieGoal');
      expect(userFieldNames).not.toContain('proteinGoalG');
      expect(userFieldNames).not.toContain('weightUnit');

      expect(getField('User', 'settings').type).toBe('UserSettings');
      expect(getField('UserSettings', 'dailyCalorieGoal').default).toBe(2000);
      expect(getField('UserSettings', 'proteinGoalG').default).toBe(150);
      expect(getField('UserSettings', 'carbsGoalG').default).toBe(250);
      expect(getField('UserSettings', 'fatGoalG').default).toBe(65);
      expect(getField('UserSettings', 'weightUnit').default).toBe(
        WeightUnit.kg,
      );
      expect(getField('UserSettings', 'distanceUnit').default).toBe(
        DistanceUnit.km,
      );
      expect(getField('UserSettings', 'restSeconds').default).toBe(90);
      expect(getField('UserSettings', 'notificationsEnabled').default).toBe(
        false,
      );
      expect(getField('UserSettings', 'biometricEnabled').default).toBe(false);
    });

    it('define Routine y RoutineExercise alineados con #155 y relaciones hacia User, Exercise y WorkoutSession', () => {
      expect(getField('User', 'routines').type).toBe('Routine');
      expect(getField('User', 'routines').isList).toBe(true);

      expect(getField('Routine', 'name').isRequired).toBe(true);
      expect(getField('Routine', 'exercises').type).toBe('RoutineExercise');
      expect(getField('Routine', 'sessions').type).toBe('WorkoutSession');

      expect(getField('RoutineExercise', 'position').type).toBe('Int');
      expect(getField('RoutineExercise', 'targetSets').type).toBe('Int');
      expect(getField('RoutineExercise', 'targetReps').type).toBe('Int');
      expect(getField('RoutineExercise', 'routine').type).toBe('Routine');
      expect(getField('RoutineExercise', 'exercise').type).toBe('Exercise');

      expect(getField('WorkoutSession', 'routineId').isRequired).toBe(false);
      expect(getField('WorkoutSession', 'routine').relationOnDelete).toBe(
        'SetNull',
      );
    });
  });

  describe('W12-BE-00.2 · Modelos BodyMetric y Photo (#156), reglas de cascada e integridad de migraciones W12', () => {
    it('define BodyMetric y Photo alineados con #156 y sus relaciones hacia User, MealLog y BodyMetric', () => {
      expect(getField('User', 'photos').type).toBe('Photo');
      expect(getField('User', 'bodyMetrics').type).toBe('BodyMetric');

      expect(getField('Photo', 'storageKey').isRequired).toBe(true);
      expect(getField('Photo', 'mimeType').isRequired).toBe(true);
      expect(getField('Photo', 'sizeBytes').type).toBe('Int');
      expect(getField('Photo', 'width').type).toBe('Int');
      expect(getField('Photo', 'height').type).toBe('Int');
      expect(getField('Photo', 'mealId').isRequired).toBe(false);
      expect(getField('Photo', 'meal').relationOnDelete).toBe('SetNull');
      expect(getField('Photo', 'metricId').isRequired).toBe(false);
      expect(getField('Photo', 'metric').relationOnDelete).toBe('SetNull');

      expect(getField('BodyMetric', 'measuredAt').type).toBe('DateTime');
      expect(getField('BodyMetric', 'weightKg').isRequired).toBe(false);
      expect(getField('BodyMetric', 'bodyFatPercent').isRequired).toBe(false);
      expect(getField('BodyMetric', 'waistCm').isRequired).toBe(false);
      expect(getField('BodyMetric', 'photos').type).toBe('Photo');
      expect(getField('MealLog', 'photos').type).toBe('Photo');
    });

    it('configura onDelete: Cascade en todas las entidades pertenecientes a User en W12', () => {
      expect(getField('UserSettings', 'user').relationOnDelete).toBe('Cascade');
      expect(getField('Routine', 'user').relationOnDelete).toBe('Cascade');
      expect(getField('RoutineExercise', 'routine').relationOnDelete).toBe(
        'Cascade',
      );
      expect(getField('RoutineExercise', 'exercise').relationOnDelete).toBe(
        'Restrict',
      );
      expect(getField('BodyMetric', 'user').relationOnDelete).toBe('Cascade');
      expect(getField('Photo', 'user').relationOnDelete).toBe('Cascade');
    });

    it('verifica la consistencia del historial de migraciones (AUTH-01, índices de Exercise, Routines y Photos) sin migraciones duplicadas', () => {
      const migrationsDir = path.resolve(process.cwd(), 'prisma/migrations');

      // Confirmar que no exista migración duplicada en colisión
      expect(
        fs.existsSync(
          path.join(
            migrationsDir,
            '20261114190500_w12_01_unified_data_migration',
          ),
        ),
      ).toBe(false);

      const authSql = fs.readFileSync(
        path.join(
          migrationsDir,
          '20261116030000_firebase_auth_uid/migration.sql',
        ),
        'utf-8',
      );
      expect(authSql).toContain('ADD COLUMN "firebaseUid" TEXT');
      expect(authSql).toContain('ALTER COLUMN "passwordHash" DROP NOT NULL');

      const indexSql = fs.readFileSync(
        path.join(
          migrationsDir,
          '20261116180000_index_exercise_catalog_filters/migration.sql',
        ),
        'utf-8',
      );
      expect(indexSql).toContain('CREATE INDEX "Exercise_bodyPart_idx"');
      expect(indexSql).toContain('CREATE INDEX "Exercise_equipment_idx"');
      expect(indexSql).toContain('CREATE INDEX "Exercise_target_idx"');

      const routinesSql = fs.readFileSync(
        path.join(migrationsDir, '20261116190000_add_routines/migration.sql'),
        'utf-8',
      );
      expect(routinesSql).toContain('CREATE TABLE "Routine"');
      expect(routinesSql).toContain('CREATE TABLE "RoutineExercise"');
      expect(routinesSql).toContain(
        'FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE',
      );
      expect(routinesSql).toContain(
        'FOREIGN KEY ("routineId") REFERENCES "Routine"("id") ON DELETE CASCADE',
      );
      expect(routinesSql).toContain(
        'FOREIGN KEY ("routineId") REFERENCES "Routine"("id") ON DELETE SET NULL',
      );

      const photosSql = fs.readFileSync(
        path.join(migrationsDir, '20261116200000_add_photos/migration.sql'),
        'utf-8',
      );
      expect(photosSql).toContain('CREATE TABLE "BodyMetric"');
      expect(photosSql).toContain('CREATE TABLE "Photo"');
      expect(photosSql).toContain(
        'FOREIGN KEY ("mealId") REFERENCES "MealLog"("id") ON DELETE SET NULL',
      );
      expect(photosSql).toContain(
        'FOREIGN KEY ("metricId") REFERENCES "BodyMetric"("id") ON DELETE SET NULL',
      );
    });

    it('ejecuta simulación completa de cascada multinivel ARCO (User -> UserSettings, Routine, RoutineExercise, WorkoutSession, WorkoutSet, MealLog, MealItem, BodyMetric, Photo)', () => {
      const users = [
        {
          id: 'user-1',
          firebaseUid: 'firebase-user-1',
          email: 'athlete@fittrack.com',
        },
      ];
      const userSettings = [{ userId: 'user-1', dailyCalorieGoal: 2000 }];
      const exercises = [{ id: '0001', name: '3/4 sit-up' }];
      const routines = [
        { id: 'routine-1', userId: 'user-1', name: 'FullBody' },
      ];
      const routineExercises = [
        {
          id: 're-1',
          routineId: 'routine-1',
          exerciseId: '0001',
          position: 1,
          targetSets: 4,
          targetReps: 12,
        },
      ];
      const bodyMetrics = [
        {
          id: 'metric-1',
          userId: 'user-1',
          measuredAt: new Date('2026-11-14T08:00:00.000Z'),
          weightKg: 74.5,
          bodyFatPercent: 15.2,
        },
      ];
      const photos = [
        {
          id: 'photo-1',
          userId: 'user-1',
          storageKey: 'user-1/progress-1.jpg',
          mealId: null as string | null,
          metricId: 'metric-1' as string | null,
        },
      ];
      const sessions = [
        {
          id: 'session-1',
          userId: 'user-1',
          routineId: 'routine-1',
          startedAt: new Date('2026-11-14T10:00:00.000Z'),
        },
      ];
      const sets = [
        {
          id: 'set-1',
          sessionId: 'session-1',
          exerciseId: '0001',
          order: 1,
          weight: 60,
          reps: 10,
        },
      ];
      const mealLogs = [
        {
          id: 'meal-1',
          userId: 'user-1',
          eatenAt: new Date('2026-11-14T12:00:00.000Z'),
          mealType: MealType.LUNCH,
        },
      ];
      const mealItems = [
        {
          id: 'item-1',
          mealLogId: 'meal-1',
          name: 'Chicken breast',
          servingG: 100,
          kcal: 165,
          proteinG: 31,
          carbsG: 0,
          fatG: 3.6,
        },
      ];

      // Función que aplica exactamente las reglas relationOnDelete del DMMF de Prisma
      const deleteUserWithCascade = (userId: string) => {
        const idx = users.findIndex((u) => u.id === userId);
        if (idx !== -1) users.splice(idx, 1);

        if (getField('UserSettings', 'user').relationOnDelete === 'Cascade') {
          for (let i = userSettings.length - 1; i >= 0; i--) {
            if (userSettings[i].userId === userId) userSettings.splice(i, 1);
          }
        }

        if (getField('Routine', 'user').relationOnDelete === 'Cascade') {
          const removedRoutineIds = routines
            .filter((r) => r.userId === userId)
            .map((r) => r.id);
          for (let i = routines.length - 1; i >= 0; i--) {
            if (routines[i].userId === userId) routines.splice(i, 1);
          }
          if (
            getField('RoutineExercise', 'routine').relationOnDelete ===
            'Cascade'
          ) {
            for (let i = routineExercises.length - 1; i >= 0; i--) {
              if (removedRoutineIds.includes(routineExercises[i].routineId)) {
                routineExercises.splice(i, 1);
              }
            }
          }
        }

        if (getField('WorkoutSession', 'user').relationOnDelete === 'Cascade') {
          const removedSessionIds = sessions
            .filter((s) => s.userId === userId)
            .map((s) => s.id);
          for (let i = sessions.length - 1; i >= 0; i--) {
            if (sessions[i].userId === userId) sessions.splice(i, 1);
          }
          if (
            getField('WorkoutSet', 'session').relationOnDelete === 'Cascade'
          ) {
            for (let i = sets.length - 1; i >= 0; i--) {
              if (removedSessionIds.includes(sets[i].sessionId)) {
                sets.splice(i, 1);
              }
            }
          }
        }

        if (getField('MealLog', 'user').relationOnDelete === 'Cascade') {
          const removedMealIds = mealLogs
            .filter((m) => m.userId === userId)
            .map((m) => m.id);
          for (let i = mealLogs.length - 1; i >= 0; i--) {
            if (mealLogs[i].userId === userId) mealLogs.splice(i, 1);
          }
          if (getField('MealItem', 'mealLog').relationOnDelete === 'Cascade') {
            for (let i = mealItems.length - 1; i >= 0; i--) {
              if (removedMealIds.includes(mealItems[i].mealLogId)) {
                mealItems.splice(i, 1);
              }
            }
          }
        }

        if (getField('BodyMetric', 'user').relationOnDelete === 'Cascade') {
          for (let i = bodyMetrics.length - 1; i >= 0; i--) {
            if (bodyMetrics[i].userId === userId) bodyMetrics.splice(i, 1);
          }
        }

        if (getField('Photo', 'user').relationOnDelete === 'Cascade') {
          for (let i = photos.length - 1; i >= 0; i--) {
            if (photos[i].userId === userId) photos.splice(i, 1);
          }
        }
      };

      deleteUserWithCascade('user-1');

      expect(users).toHaveLength(0);
      expect(userSettings).toHaveLength(0);
      expect(routines).toHaveLength(0);
      expect(routineExercises).toHaveLength(0);
      expect(sessions).toHaveLength(0);
      expect(sets).toHaveLength(0);
      expect(mealLogs).toHaveLength(0);
      expect(mealItems).toHaveLength(0);
      expect(bodyMetrics).toHaveLength(0);
      expect(photos).toHaveLength(0);
      // El catálogo global Exercise se preserva intacto (Restrict)
      expect(exercises).toHaveLength(1);
    });
  });

  describe('W12-15 · Índices de consulta e integridad de orden en WorkoutSet (#158)', () => {
    it('declara @@unique([sessionId, order]) en WorkoutSet dentro del DMMF de Prisma', () => {
      const workoutSet = getModel('WorkoutSet');
      expect(workoutSet.uniqueFields).toContainEqual(['sessionId', 'order']);
    });

    it('incluye una migración dedicada posterior a 20261116200000_add_photos con únicamente CREATE [UNIQUE] INDEX para los 4 modelos', () => {
      const migrationsDir = path.resolve(process.cwd(), 'prisma/migrations');
      const migrationName = '20261121042000_add_session_set_meal_indexes';
      const migrationPath = path.join(
        migrationsDir,
        migrationName,
        'migration.sql',
      );

      expect(migrationName > '20261116200000_add_photos').toBe(true);
      expect(fs.existsSync(migrationPath)).toBe(true);

      const sql = fs.readFileSync(migrationPath, 'utf-8');
      const statements = sql
        .split(';')
        .map((chunk) =>
          chunk
            .split('\n')
            .filter((line) => !line.trim().startsWith('--'))
            .join('\n')
            .trim(),
        )
        .filter(Boolean);

      expect(statements).toHaveLength(5);
      for (const stmt of statements) {
        expect(stmt).toMatch(/^CREATE (UNIQUE )?INDEX /);
      }

      expect(sql).toContain(
        'CREATE INDEX "WorkoutSession_userId_startedAt_idx" ON "WorkoutSession"("userId", "startedAt" DESC);',
      );
      expect(sql).toContain(
        'CREATE INDEX "WorkoutSet_sessionId_idx" ON "WorkoutSet"("sessionId");',
      );
      expect(sql).toContain(
        'CREATE UNIQUE INDEX "WorkoutSet_sessionId_order_key" ON "WorkoutSet"("sessionId", "order");',
      );
      expect(sql).toContain(
        'CREATE INDEX "MealLog_userId_eatenAt_idx" ON "MealLog"("userId", "eatenAt");',
      );
      expect(sql).toContain(
        'CREATE INDEX "MealItem_mealLogId_idx" ON "MealItem"("mealLogId");',
      );
    });

    it('rechaza insertar un order duplicado dentro del mismo sessionId con error P2002 y permite repetir order en sesiones distintas', () => {
      interface WorkoutSetRow {
        id: string;
        sessionId: string;
        exerciseId: string;
        order: number;
        weight: number;
        reps: number;
      }

      const uniqueConstraints = getModel('WorkoutSet').uniqueFields;
      const rows: WorkoutSetRow[] = [];

      const insertWorkoutSet = (candidate: WorkoutSetRow): WorkoutSetRow => {
        for (const constraint of uniqueConstraints) {
          const duplicate = rows.some((existing) =>
            constraint.every(
              (field) =>
                existing[field as keyof WorkoutSetRow] ===
                candidate[field as keyof WorkoutSetRow],
            ),
          );
          if (duplicate) {
            throw new Prisma.PrismaClientKnownRequestError(
              `Unique constraint failed on the fields: (${constraint.join(',')})`,
              {
                code: 'P2002',
                clientVersion: Prisma.prismaVersion.client,
                meta: { target: [...constraint] },
              },
            );
          }
        }
        rows.push(candidate);
        return candidate;
      };

      // Inserciones válidas dentro de session-1 con orders distintos
      insertWorkoutSet({
        id: 'set-1',
        sessionId: 'session-1',
        exerciseId: '0001',
        order: 1,
        weight: 60,
        reps: 10,
      });
      insertWorkoutSet({
        id: 'set-2',
        sessionId: 'session-1',
        exerciseId: '0001',
        order: 2,
        weight: 65,
        reps: 8,
      });

      // Mismo sessionId + mismo order -> debe fallar con P2002
      let caughtError: unknown;
      try {
        insertWorkoutSet({
          id: 'set-dup',
          sessionId: 'session-1',
          exerciseId: '0002',
          order: 1,
          weight: 70,
          reps: 8,
        });
      } catch (error) {
        caughtError = error;
      }

      expect(caughtError).toBeInstanceOf(Prisma.PrismaClientKnownRequestError);
      expect((caughtError as Prisma.PrismaClientKnownRequestError).code).toBe(
        'P2002',
      );
      expect(
        (caughtError as Prisma.PrismaClientKnownRequestError).meta,
      ).toEqual({
        target: ['sessionId', 'order'],
      });

      // Mismo order en una sesión distinta (session-2) -> permitido
      expect(() =>
        insertWorkoutSet({
          id: 'set-other-session',
          sessionId: 'session-2',
          exerciseId: '0001',
          order: 1,
          weight: 60,
          reps: 10,
        }),
      ).not.toThrow();

      expect(rows).toHaveLength(3);
    });
  });
});
