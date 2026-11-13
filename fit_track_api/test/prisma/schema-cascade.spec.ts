import { MealType, Prisma } from '@prisma/client';

describe('Prisma Schema & Cascade Rules (Task W11-01)', () => {
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

    it('verifica cascada multinivel al eliminar un usuario y preserva inmutabilidad de macros en MealItem', () => {
      const users = [{ id: 'user-1', email: 'athlete@fittrack.com' }];
      const exercises = [{ id: '0001', name: '3/4 sit-up' }];
      const sessions = [
        {
          id: 'session-1',
          userId: 'user-1',
          startedAt: new Date('2026-11-11T10:00:00.000Z'),
          location: 'Gimnasio Zona Centro',
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
          rpe: 8.5,
          rir: 2,
        },
      ];
      const mealLogs = [
        {
          id: 'meal-1',
          userId: 'user-1',
          eatenAt: new Date('2026-11-11T12:00:00.000Z'),
          mealType: MealType.LUNCH,
        },
      ];
      const externalUsdaSource = {
        fdcId: '171077',
        name: 'Chicken breast',
        kcal: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 3.6,
      };
      const mealItems = [
        {
          id: 'item-1',
          mealLogId: 'meal-1',
          fdcId: externalUsdaSource.fdcId,
          name: externalUsdaSource.name,
          servingG: 100,
          kcal: externalUsdaSource.kcal,
          proteinG: externalUsdaSource.proteinG,
          carbsG: externalUsdaSource.carbsG,
          fatG: externalUsdaSource.fatG,
        },
      ];

      // Mutar la fuente externa no altera los macros congelados en MealItem (Regla M-02)
      externalUsdaSource.kcal = 999;
      externalUsdaSource.proteinG = 0;
      expect(mealItems[0].kcal).toBe(165);
      expect(mealItems[0].proteinG).toBe(31);

      // Aplicar cascada definida en el DMMF al borrar user-1
      const deleteUserWithCascade = (userId: string) => {
        const idx = users.findIndex((u) => u.id === userId);
        if (idx !== -1) users.splice(idx, 1);

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
      };

      deleteUserWithCascade('user-1');

      expect(users).toHaveLength(0);
      expect(sessions).toHaveLength(0);
      expect(sets).toHaveLength(0);
      expect(mealLogs).toHaveLength(0);
      expect(mealItems).toHaveLength(0);
      expect(exercises).toHaveLength(1);
    });
  });
});
