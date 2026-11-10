import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../src/prisma/prisma.service';
import { DEFAULT_SETTINGS } from '../../src/users/domain/profile-rules';
import { UsersService } from '../../src/users/users.service';
import { createUsersStore, sampleUsers } from './users.fakes';

function buildService() {
  const store = createUsersStore(sampleUsers());
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
        notificationsEnabled: true,
        biometricEnabled: false,
      },
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
