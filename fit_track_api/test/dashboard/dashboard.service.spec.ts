import { BadRequestException } from '@nestjs/common';
import { DashboardService } from '../../src/dashboard/dashboard.service';
import {
  resolveDay,
  sumMealItems,
  sumNutrition,
} from '../../src/dashboard/domain/day-summary';
import { PrismaService } from '../../src/prisma/prisma.service';
import { DEFAULT_SETTINGS } from '../../src/users/domain/profile-rules';
import { createDashboardStore, type FakeMealItem } from './dashboard.fakes';

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

const meal = (
  id: string,
  userId: string,
  eatenAt: string,
  items: FakeMealItem[] = [],
) => ({
  id,
  userId,
  eatenAt: new Date(eatenAt),
  mealType: 'LUNCH',
  items,
});

const item = (
  kcal: number,
  proteinG: number,
  carbsG: number,
  fatG: number,
): FakeMealItem => ({ kcal, proteinG, carbsG, fatG });

const metric = (
  id: string,
  userId: string,
  measuredAt: string,
  weightKg: number | null = 70,
) => ({
  id,
  userId,
  measuredAt: new Date(measuredAt),
  weightKg,
  bodyFatPercent: null,
  waistCm: null,
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

  it('suma los MealItem congelados de todas las comidas (kcal -> calories)', () => {
    expect(
      sumMealItems([
        { items: [item(300, 20, 30, 10), item(150, 5, 20, 4)] },
        { items: [] },
        { items: [item(450.5, 35, 40, 15.5)] },
      ]),
    ).toEqual({ calories: 900.5, proteinG: 60, carbsG: 90, fatG: 29.5 });
  });

  it('redondea los totales a 2 decimales como los totales de comidas', () => {
    expect(
      sumMealItems([
        { items: [item(0.1, 0.1, 0.1, 0.1), item(0.2, 0.2, 0.2, 0.2)] },
      ]),
    ).toEqual({ calories: 0.3, proteinG: 0.3, carbsG: 0.3, fatG: 0.3 });
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

describe('DashboardService.today: totales reales de comidas (W12-06, M-02)', () => {
  const NOW = new Date('2026-11-10T18:00:00Z');
  const UTC_MINUS_6 = { date: '2026-11-10', utcOffsetMinutes: -360 };

  it('consumed coincide con la suma de los MealItem de las comidas del día', async () => {
    const summary = await serviceWith({
      meals: [
        meal('desayuno', ANA, '2026-11-10T14:00:00Z', [
          item(300, 20, 30, 10),
          item(120.25, 4, 18, 3.5),
        ]),
        meal('cena', ANA, '2026-11-11T02:00:00Z', [item(500, 40, 45, 18)]), // 20:00 del 10 local
        meal('ayer', ANA, '2026-11-09T18:00:00Z', [item(999, 99, 99, 99)]),
        meal('manana', ANA, '2026-11-11T08:00:00Z', [item(777, 77, 77, 77)]),
        meal('ajena', BETO, '2026-11-10T15:00:00Z', [item(888, 88, 88, 88)]),
      ],
    }).today(ANA, UTC_MINUS_6, NOW);

    expect(summary.nutrition.mealsLogged).toBe(2);
    expect(summary.nutrition.consumed).toEqual({
      calories: 920.25,
      proteinG: 64,
      carbsG: 93,
      fatG: 31.5,
    });
    expect(summary.nutrition.remaining).toEqual({
      calories: DEFAULT_SETTINGS.dailyCalorieGoal - 920.25,
      proteinG: DEFAULT_SETTINGS.proteinGoalG - 64,
      carbsG: DEFAULT_SETTINGS.carbsGoalG - 93,
      fatG: DEFAULT_SETTINGS.fatGoalG - 31.5,
    });
  });

  it('respeta los bordes del día local: incluye 00:00 y excluye 24:00', async () => {
    const summary = await serviceWith({
      meals: [
        meal('inicio', ANA, '2026-11-10T06:00:00.000Z', [item(100, 1, 1, 1)]), // 00:00 local
        meal('fin', ANA, '2026-11-11T05:59:59.999Z', [item(10, 1, 1, 1)]), // 23:59:59.999 local
        meal('antes', ANA, '2026-11-10T05:59:59.999Z', [item(1000, 9, 9, 9)]), // 23:59 del 9
        meal('despues', ANA, '2026-11-11T06:00:00.000Z', [item(2000, 9, 9, 9)]), // 00:00 del 11
      ],
    }).today(ANA, UTC_MINUS_6, NOW);

    expect(summary.nutrition.mealsLogged).toBe(2);
    expect(summary.nutrition.consumed).toEqual({
      calories: 110,
      proteinG: 2,
      carbsG: 2,
      fatG: 2,
    });
  });

  it('el desplazamiento horario cambia qué comidas son del día', async () => {
    // 2026-11-11T03:00Z: en UTC ya es el 11; en UTC-6 todavía es el 10.
    const seed = {
      meals: [
        meal('noche', ANA, '2026-11-11T03:00:00Z', [item(400, 30, 20, 10)]),
      ],
    };
    const local = await serviceWith(seed).today(ANA, UTC_MINUS_6, NOW);
    const utc = await serviceWith(seed).today(
      ANA,
      { date: '2026-11-10', utcOffsetMinutes: 0 },
      NOW,
    );

    expect(local.nutrition.consumed.calories).toBe(400);
    expect(utc.nutrition.consumed.calories).toBe(0);
  });

  it('una comida sin alimentos cuenta como registrada pero aporta cero', async () => {
    const summary = await serviceWith({
      meals: [meal('vacia', ANA, '2026-11-10T14:00:00Z')],
    }).today(ANA, { date: '2026-11-10', utcOffsetMinutes: 0 }, NOW);

    expect(summary.nutrition.mealsLogged).toBe(1);
    expect(summary.nutrition.consumed).toEqual({
      calories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
    });
  });

  it('no suma alimentos de otro usuario aunque sean del mismo día', async () => {
    const summary = await serviceWith({
      meals: [
        meal('ajena', BETO, '2026-11-10T14:00:00Z', [item(700, 50, 60, 20)]),
      ],
    }).today(ANA, { date: '2026-11-10', utcOffsetMinutes: 0 }, NOW);

    expect(summary.nutrition.consumed.calories).toBe(0);
  });
});

describe('DashboardService.today: última métrica (W12-06, BodyMetric)', () => {
  const NOW = new Date('2026-11-10T18:00:00Z');
  const DAY = { date: '2026-11-10', utcOffsetMinutes: 0 };

  it('devuelve la última BodyMetric del usuario hasta el fin del día', async () => {
    const summary = await serviceWith({
      metrics: [
        metric('vieja', ANA, '2026-11-01T08:00:00Z', 72.5),
        metric('ultima', ANA, '2026-11-10T07:00:00Z', 71.8),
        metric('futura', ANA, '2026-11-12T07:00:00Z', 70),
        metric('ajena', BETO, '2026-11-10T09:00:00Z', 90),
      ],
    }).today(ANA, DAY, NOW);

    expect(summary.latestMetric).toEqual({
      id: 'ultima',
      measuredAt: '2026-11-10T07:00:00.000Z',
      weightKg: 71.8,
      bodyFatPercent: null,
      waistCm: null,
    });
  });

  it('sin métricas propias es null aunque otro usuario tenga', async () => {
    const summary = await serviceWith({
      metrics: [metric('ajena', BETO, '2026-11-10T09:00:00Z', 90)],
    }).today(ANA, DAY, NOW);

    expect(summary.latestMetric).toBeNull();
  });
});
