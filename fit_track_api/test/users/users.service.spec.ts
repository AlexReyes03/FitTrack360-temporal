import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../src/prisma/prisma.service';
import {
  assertValidGoals,
  DEFAULT_SETTINGS,
  GOAL_LIMITS,
} from '../../src/users/domain/profile-rules';
import { UsersService } from '../../src/users/users.service';
import {
  createUsersStore,
  sampleUsers,
  type StoredWorkoutSession,
} from './users.fakes';

function buildService(workoutSessions: StoredWorkoutSession[] = []) {
  const store = createUsersStore(sampleUsers(), workoutSessions);
  const service = new UsersService(store as unknown as PrismaService);
  return { store, service };
}

describe('UsersService: perfil, metas y preferencias (W12-05)', () => {
  it('GET sin ajustes guardados devuelve el perfil con metas y preferencias por defecto', async () => {
    const { service } = buildService();

    const profile = await service.findMe('user-ana');

    expect(profile).toEqual({
      id: 'user-ana',
      email: 'ana@test.com',
      username: 'ana',
      displayName: 'Ana',
      goals: {
        dailyCalorieGoal: DEFAULT_SETTINGS.dailyCalorieGoal,
        proteinGoalG: DEFAULT_SETTINGS.proteinGoalG,
        carbsGoalG: DEFAULT_SETTINGS.carbsGoalG,
        fatGoalG: DEFAULT_SETTINGS.fatGoalG,
      },
      preferences: {
        weightUnit: 'kg',
        distanceUnit: 'km',
        restSeconds: DEFAULT_SETTINGS.restSeconds,
        // P3: el recordatorio no está activo hasta que el usuario lo enciende
        // y concede el permiso (docs/permisos.md).
        notificationsEnabled: false,
        biometricEnabled: false,
      },
      workoutCount: 0,
    });
    expect(profile).not.toHaveProperty('passwordHash');
  });

  it('GET de un usuario inexistente responde 401 como antes', async () => {
    const { service } = buildService();
    await expect(service.findMe('nadie')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('PATCH actualiza displayName y metas, y GET las recupera', async () => {
    const { service } = buildService();

    await service.updateMe('user-ana', {
      displayName: 'Ana Pérez',
      goals: { dailyCalorieGoal: 1800, proteinGoalG: 120 },
    });
    const profile = await service.findMe('user-ana');

    expect(profile.displayName).toBe('Ana Pérez');
    expect(profile.goals).toEqual({
      dailyCalorieGoal: 1800,
      proteinGoalG: 120,
      carbsGoalG: DEFAULT_SETTINGS.carbsGoalG,
      fatGoalG: DEFAULT_SETTINGS.fatGoalG,
    });
  });

  it('PATCH guarda preferencias y un segundo PATCH parcial conserva las demás', async () => {
    const { service } = buildService();

    await service.updateMe('user-ana', {
      preferences: {
        weightUnit: 'lb',
        distanceUnit: 'mi',
        restSeconds: 120,
        notificationsEnabled: false,
        biometricEnabled: true,
      },
    });
    await service.updateMe('user-ana', { preferences: { restSeconds: 60 } });
    const profile = await service.findMe('user-ana');

    expect(profile.preferences).toEqual({
      weightUnit: 'lb',
      distanceUnit: 'mi',
      restSeconds: 60,
      notificationsEnabled: false,
      biometricEnabled: true,
    });
  });

  it('acepta macros en cero (no negativos)', async () => {
    const { service } = buildService();
    const profile = await service.updateMe('user-ana', {
      goals: { proteinGoalG: 0, carbsGoalG: 0, fatGoalG: 0 },
    });
    expect(profile.goals.fatGoalG).toBe(0);
  });

  it.each([
    [{ goals: { dailyCalorieGoal: 0 } }],
    [{ goals: { dailyCalorieGoal: -100 } }],
    [{ goals: { proteinGoalG: -1 } }],
    [{ goals: { carbsGoalG: -5 } }],
    [{ goals: { fatGoalG: -0.5 } }],
    [{ preferences: { restSeconds: 0 } }],
  ])('rechaza la regla de negocio violada en %j', async (dto) => {
    const { service, store } = buildService();
    await expect(service.updateMe('user-ana', dto)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(store.settings).toHaveLength(0);
  });

  it('rechaza una unidad fuera del catálogo aunque no pase por el DTO', async () => {
    const { service } = buildService();
    await expect(
      service.updateMe('user-ana', {
        preferences: { weightUnit: 'stone' as never },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('el PATCH de un usuario no modifica el perfil ni las metas de otro', async () => {
    const { service } = buildService();

    await service.updateMe('user-ana', {
      displayName: 'Ana cambiada',
      goals: { dailyCalorieGoal: 1500 },
    });
    const beto = await service.findMe('user-beto');

    expect(beto.displayName).toBe('Beto');
    expect(beto.goals.dailyCalorieGoal).toBe(DEFAULT_SETTINGS.dailyCalorieGoal);
  });
});

describe('UsersService: atomicidad del perfil y topes de metas (W12-16)', () => {
  const undefinedKeys = (row: Record<string, unknown>) =>
    Object.entries(row)
      .filter(([, value]) => value === undefined)
      .map(([key]) => key);

  describe('criterio 1: un PATCH parcial no persiste undefined sobre los defaults', () => {
    it('al crear los ajustes, las claves undefined del DTO no pisan los defaults', async () => {
      const { service, store } = buildService();

      // Así llegan los DTO de clase (campos ES2023): las claves no enviadas
      // existen con valor undefined.
      const profile = await service.updateMe('user-ana', {
        goals: {
          dailyCalorieGoal: 1800,
          proteinGoalG: undefined,
          carbsGoalG: undefined,
          fatGoalG: undefined,
        },
        preferences: {
          weightUnit: undefined,
          distanceUnit: undefined,
          restSeconds: undefined,
          notificationsEnabled: undefined,
          biometricEnabled: undefined,
        },
      });

      expect(store.settings).toHaveLength(1);
      expect(undefinedKeys(store.settings[0])).toEqual([]);
      expect(store.settings[0]).toEqual({
        ...DEFAULT_SETTINGS,
        dailyCalorieGoal: 1800,
        userId: 'user-ana',
      });
      expect(profile.goals).toEqual({
        dailyCalorieGoal: 1800,
        proteinGoalG: DEFAULT_SETTINGS.proteinGoalG,
        carbsGoalG: DEFAULT_SETTINGS.carbsGoalG,
        fatGoalG: DEFAULT_SETTINGS.fatGoalG,
      });
    });

    it('al actualizar ajustes existentes, las claves undefined no borran los valores guardados', async () => {
      const { service, store } = buildService();
      await service.updateMe('user-ana', {
        goals: { dailyCalorieGoal: 2500, proteinGoalG: 180 },
        preferences: { weightUnit: 'lb', restSeconds: 120 },
      });

      await service.updateMe('user-ana', {
        goals: {
          dailyCalorieGoal: undefined,
          proteinGoalG: 190,
          carbsGoalG: undefined,
          fatGoalG: undefined,
        },
        preferences: { weightUnit: undefined, restSeconds: undefined },
      });
      const profile = await service.findMe('user-ana');

      expect(undefinedKeys(store.settings[0])).toEqual([]);
      expect(profile.goals).toEqual({
        dailyCalorieGoal: 2500,
        proteinGoalG: 190,
        carbsGoalG: DEFAULT_SETTINGS.carbsGoalG,
        fatGoalG: DEFAULT_SETTINGS.fatGoalG,
      });
      expect(profile.preferences.weightUnit).toBe('lb');
      expect(profile.preferences.restSeconds).toBe(120);
    });

    it('un PATCH solo con claves undefined no crea ni modifica ajustes', async () => {
      const { service, store } = buildService();

      const profile = await service.updateMe('user-ana', {
        goals: { dailyCalorieGoal: undefined },
        preferences: { restSeconds: undefined },
      });

      expect(store.settings).toHaveLength(0);
      expect(profile.goals.dailyCalorieGoal).toBe(
        DEFAULT_SETTINGS.dailyCalorieGoal,
      );
    });
  });

  describe('criterio 2: User y UserSettings se actualizan en la misma transacción', () => {
    it('si falla el upsert de ajustes, el displayName no queda actualizado', async () => {
      const { service, store } = buildService();
      store.faults.settingsUpsert = new Error('fallo simulado de la base');

      await expect(
        service.updateMe('user-ana', {
          displayName: 'Ana a medias',
          goals: { dailyCalorieGoal: 1700 },
        }),
      ).rejects.toThrow('fallo simulado de la base');

      expect(store.transactions.rolledBack).toBe(1);
      expect(store.users[0].displayName).toBe('Ana');
      expect(store.settings).toHaveLength(0);
      expect((await service.findMe('user-ana')).displayName).toBe('Ana');
    });

    it('si falla el upsert sobre ajustes existentes, nombre y ajustes previos se conservan', async () => {
      const { service, store } = buildService();
      await service.updateMe('user-ana', { goals: { dailyCalorieGoal: 2100 } });
      store.faults.settingsUpsert = new Error('fallo simulado de la base');

      await expect(
        service.updateMe('user-ana', {
          displayName: 'Ana a medias',
          goals: { dailyCalorieGoal: 1600 },
        }),
      ).rejects.toThrow('fallo simulado de la base');

      const profile = await service.findMe('user-ana');
      expect(profile.displayName).toBe('Ana');
      expect(profile.goals.dailyCalorieGoal).toBe(2100);
    });

    it('nombre y ajustes se escriben dentro de una única transacción', async () => {
      const { service, store } = buildService();

      await service.updateMe('user-ana', {
        displayName: 'Ana Pérez',
        preferences: { biometricEnabled: true },
      });

      expect(store.transactions).toEqual({ started: 1, rolledBack: 0 });
      expect(store.users[0].displayName).toBe('Ana Pérez');
      expect(store.settings[0].biometricEnabled).toBe(true);
    });

    it('mantiene el 401 si el userId del token no existe', async () => {
      const { service, store } = buildService();
      await expect(
        service.updateMe('nadie', { goals: { dailyCalorieGoal: 1800 } }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(store.settings).toHaveLength(0);
    });
  });

  describe('criterio 3: metas fuera de máximo responden 400 desde el dominio', () => {
    it.each([
      [{ dailyCalorieGoal: 20001 }],
      [{ proteinGoalG: 2001 }],
      [{ carbsGoalG: 2001 }],
      [{ fatGoalG: 2001 }],
    ])(
      'el service rechaza %j sin pasar por el ValidationPipe',
      async (goals) => {
        const { service, store } = buildService();
        await expect(
          service.updateMe('user-ana', { displayName: 'Ana X', goals }),
        ).rejects.toBeInstanceOf(BadRequestException);
        expect(store.settings).toHaveLength(0);
        expect(store.users[0].displayName).toBe('Ana');
      },
    );

    it('los topes del dominio son 20000 kcal y 2000 g por macro', () => {
      expect(GOAL_LIMITS).toEqual({
        dailyCalorieGoalMax: 20000,
        macroGoalMax: 2000,
      });
    });

    it('acepta exactamente los máximos', async () => {
      const { service } = buildService();
      const profile = await service.updateMe('user-ana', {
        goals: {
          dailyCalorieGoal: 20000,
          proteinGoalG: 2000,
          carbsGoalG: 2000,
          fatGoalG: 2000,
        },
      });
      expect(profile.goals).toEqual({
        dailyCalorieGoal: 20000,
        proteinGoalG: 2000,
        carbsGoalG: 2000,
        fatGoalG: 2000,
      });
    });

    it('assertValidGoals rechaza los excesos por sí sola', () => {
      expect(() => assertValidGoals({ dailyCalorieGoal: 20001 })).toThrow(
        BadRequestException,
      );
      expect(() => assertValidGoals({ proteinGoalG: 2001 })).toThrow(
        BadRequestException,
      );
      expect(() => assertValidGoals({ fatGoalG: undefined })).not.toThrow();
    });
  });
});

describe('UsersService: resumen de entrenamientos en el perfil (W12-20)', () => {
  const sessions: StoredWorkoutSession[] = [
    { id: 'w1', userId: 'user-ana' },
    { id: 'w2', userId: 'user-ana' },
    { id: 'w3', userId: 'user-beto' },
  ];

  it('workoutCount cuenta solo las sesiones del usuario del token (S4)', async () => {
    const { service } = buildService(sessions);

    expect((await service.findMe('user-ana')).workoutCount).toBe(2);
    expect((await service.findMe('user-beto')).workoutCount).toBe(1);
  });

  it('un usuario sin sesiones ve 0 aunque otros tengan', async () => {
    const { service, store } = buildService(sessions);
    store.users.push({
      id: 'user-caro',
      firebaseUid: 'firebase-caro',
      email: 'caro@test.com',
      username: 'caro',
      displayName: 'Caro',
      passwordHash: null,
    });

    expect((await service.findMe('user-caro')).workoutCount).toBe(0);
  });

  it('obtiene el entero con count filtrado por userId, sin listar sesiones', async () => {
    const { service, store } = buildService(sessions);

    await service.findMe('user-ana');

    expect(store.countCalls).toEqual([{ where: { userId: 'user-ana' } }]);
  });
});
