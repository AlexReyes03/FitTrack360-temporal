import { BadRequestException } from '@nestjs/common';
import { DashboardService } from '../../src/dashboard/dashboard.service';
import {
  resolveDay,
  sumNutrition,
} from '../../src/dashboard/domain/day-summary';
import { PrismaService } from '../../src/prisma/prisma.service';
import { DEFAULT_SETTINGS } from '../../src/users/domain/profile-rules';
import { createDashboardStore } from './dashboard.fakes';

const ANA = 'user-ana';
const BETO = 'user-beto';

function serviceWith(seed: Parameters<typeof createDashboardStore>[0]) {
  return new DashboardService(
    createDashboardStore(seed) as unknown as PrismaService,
  );
}

const session = (
  id: string,
  userId: string,
  startedAt: string,
  endedAt: string | null = null,
) => ({
  id,
  userId,
  startedAt: new Date(startedAt),
  endedAt: endedAt ? new Date(endedAt) : null,
  notes: null,
});

const meal = (id: string, userId: string, eatenAt: string) => ({
  id,
  userId,
  eatenAt: new Date(eatenAt),
  mealType: 'LUNCH',
});

describe('Dominio del resumen del día (W12-06)', () => {
  it('resuelve el día local con desplazamiento UTC', () => {
    const day = resolveDay('2026-11-10', -360, new Date());
    expect(day.date).toBe('2026-11-10');
    expect(day.start.toISOString()).toBe('2026-11-10T06:00:00.000Z');
    expect(day.end.toISOString()).toBe('2026-11-11T06:00:00.000Z');
  });

  it('sin fecha usa el día actual en la zona del cliente', () => {
    // 2026-11-11 03:00 UTC son todavía las 21:00 del 10 en UTC-6.
    const day = resolveDay(undefined, -360, new Date('2026-11-11T03:00:00Z'));
    expect(day.date).toBe('2026-11-10');
  });

  it.each(['2026-02-30', '10-11-2026', 'hoy'])(
    'rechaza la fecha inválida %s',
    (date) => {
      expect(() => resolveDay(date, 0, new Date())).toThrow(
        BadRequestException,
      );
    },
  );

  it('suma calorías y macros de los alimentos del día', () => {
    expect(
      sumNutrition([
        { calories: 300, proteinG: 20, carbsG: 30, fatG: 10 },
        { calories: 450.5, proteinG: 35, carbsG: 40, fatG: 15.5 },
      ]),
    ).toEqual({ calories: 750.5, proteinG: 55, carbsG: 70, fatG: 25.5 });
  });
});

describe('DashboardService.today (W12-06)', () => {
  const NOW = new Date('2026-11-10T18:00:00Z');

  it('un usuario sin datos recibe un resumen vacío válido', async () => {
    const summary = await serviceWith({}).today(
      ANA,
      { date: '2026-11-10', utcOffsetMinutes: 0 },
      NOW,
    );

    expect(summary).toEqual({
      date: '2026-11-10',
      utcOffsetMinutes: 0,
      nutrition: {
        mealsLogged: 0,
        consumed: { calories: 0, proteinG: 0, carbsG: 0, fatG: 0 },
        goals: {
          dailyCalorieGoal: DEFAULT_SETTINGS.dailyCalorieGoal,
          proteinGoalG: DEFAULT_SETTINGS.proteinGoalG,
          carbsGoalG: DEFAULT_SETTINGS.carbsGoalG,
          fatGoalG: DEFAULT_SETTINGS.fatGoalG,
        },
        remaining: {
          calories: DEFAULT_SETTINGS.dailyCalorieGoal,
          proteinG: DEFAULT_SETTINGS.proteinGoalG,
          carbsG: DEFAULT_SETTINGS.carbsGoalG,
          fatG: DEFAULT_SETTINGS.fatGoalG,
        },
      },
      session: null,
      latestMetric: null,
    });
  });

  it('cuenta solo las comidas del día y usa las metas guardadas del usuario', async () => {
    const summary = await serviceWith({
      meals: [
        meal('m1', ANA, '2026-11-10T14:00:00Z'),
        meal('m2', ANA, '2026-11-11T02:00:00Z'), // 20:00 del 10 en UTC-6
        meal('m3', ANA, '2026-11-11T07:00:00Z'), // ya es día 11 local
        meal('m4', ANA, '2026-11-10T05:00:00Z'), // aún día 9 local
      ],
      settings: [
        {
          userId: ANA,
          dailyCalorieGoal: 1800,
          proteinGoalG: 120,
          carbsGoalG: 200,
          fatGoalG: 60,
        },
      ],
    }).today(ANA, { date: '2026-11-10', utcOffsetMinutes: -360 }, NOW);

    expect(summary.nutrition.mealsLogged).toBe(2);
    expect(summary.nutrition.goals.dailyCalorieGoal).toBe(1800);
    expect(summary.nutrition.remaining.calories).toBe(1800);
  });

  it('devuelve la sesión de hoy con isToday true', async () => {
    const summary = await serviceWith({
      sessions: [
        session('ayer', ANA, '2026-11-09T15:00:00Z', '2026-11-09T16:00:00Z'),
        session('hoy', ANA, '2026-11-10T13:00:00Z', '2026-11-10T14:00:00Z'),
      ],
    }).today(ANA, { date: '2026-11-10', utcOffsetMinutes: 0 }, NOW);

    expect(summary.session).toEqual({
      id: 'hoy',
      startedAt: '2026-11-10T13:00:00.000Z',
      endedAt: '2026-11-10T14:00:00.000Z',
      notes: null,
      isToday: true,
    });
  });

  it('sin sesión hoy no inventa rutina: devuelve la última con isToday false', async () => {
    const summary = await serviceWith({
      sessions: [
        session('vieja', ANA, '2026-11-01T15:00:00Z'),
        session('ultima', ANA, '2026-11-08T15:00:00Z'),
        session('futura', ANA, '2026-11-12T15:00:00Z'),
      ],
    }).today(ANA, { date: '2026-11-10', utcOffsetMinutes: 0 }, NOW);

    expect(summary.session?.id).toBe('ultima');
    expect(summary.session?.isToday).toBe(false);
  });

  it('no mezcla comidas, sesiones ni metas de otro usuario', async () => {
    const summary = await serviceWith({
      meals: [meal('mb', BETO, '2026-11-10T12:00:00Z')],
      sessions: [session('sb', BETO, '2026-11-10T12:00:00Z')],
      settings: [
        {
          userId: BETO,
          dailyCalorieGoal: 3000,
          proteinGoalG: 1,
          carbsGoalG: 1,
          fatGoalG: 1,
        },
      ],
    }).today(ANA, { date: '2026-11-10', utcOffsetMinutes: 0 }, NOW);

    expect(summary.nutrition.mealsLogged).toBe(0);
    expect(summary.session).toBeNull();
    expect(summary.nutrition.goals.dailyCalorieGoal).toBe(
      DEFAULT_SETTINGS.dailyCalorieGoal,
    );
  });
});
