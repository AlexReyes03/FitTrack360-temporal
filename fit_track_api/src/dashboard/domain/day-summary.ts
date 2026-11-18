import { BadRequestException } from '@nestjs/common';

const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
const MINUTE_MS = 60_000;
const DAY_MS = 24 * 60 * MINUTE_MS;

/** Límites del desplazamiento horario respecto de UTC, en minutos. */
export const UTC_OFFSET_MIN = -720;
export const UTC_OFFSET_MAX = 840;

/** Nutrientes de un alimento consumido: kcal y gramos de cada macro. */
export interface Nutrients {
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

export const ZERO_NUTRIENTS: Nutrients = {
  calories: 0,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
};

/**
 * El "día" del deportista es su día calendario local. El cliente manda la
 * fecha (YYYY-MM-DD) y su desplazamiento UTC en minutos (UTC-6 = -360); el día
 * abarca [00:00, 24:00) locales, expresado aquí como un rango UTC semiabierto.
 * Sin fecha se toma "hoy" en ese desplazamiento.
 */
export function resolveDay(
  date: string | undefined,
  utcOffsetMinutes: number,
  now: Date,
): { date: string; start: Date; end: Date } {
  const offsetMs = utcOffsetMinutes * MINUTE_MS;
  const localDate =
    date ?? new Date(now.getTime() + offsetMs).toISOString().slice(0, 10);

  const match = DATE_PATTERN.exec(localDate);
  const midnightUtc = match
    ? Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
    : Number.NaN;
  if (
    Number.isNaN(midnightUtc) ||
    new Date(midnightUtc).toISOString().slice(0, 10) !== localDate
  ) {
    throw new BadRequestException('date debe ser una fecha válida YYYY-MM-DD');
  }

  const start = new Date(midnightUtc - offsetMs);
  return { date: localDate, start, end: new Date(start.getTime() + DAY_MS) };
}

/** Totales del día: suma simple de los nutrientes de cada alimento. */
export function sumNutrition(items: readonly Nutrients[]): Nutrients {
  return items.reduce<Nutrients>(
    (total, item) => ({
      calories: total.calories + item.calories,
      proteinG: total.proteinG + item.proteinG,
      carbsG: total.carbsG + item.carbsG,
      fatG: total.fatG + item.fatG,
    }),
    { ...ZERO_NUTRIENTS },
  );
}

/**
 * Macros de un MealItem tal como se congelaron al registrarlo (decisión M-02):
 * kcal y gramos por porción consumida. No se recalculan contra USDA.
 */
export interface FrozenMealItemMacros {
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

/** Metas diarias contra las que se compara lo consumido. */
export interface DailyGoals {
  dailyCalorieGoal: number;
  proteinGoalG: number;
  carbsGoalG: number;
  fatGoalG: number;
}

/** Mismo redondeo que los totales de una comida (MealResponseDto). */
const round2 = (value: number): number => Math.round(value * 100) / 100;

const roundNutrients = (n: Nutrients): Nutrients => ({
  calories: round2(n.calories),
  proteinG: round2(n.proteinG),
  carbsG: round2(n.carbsG),
  fatG: round2(n.fatG),
});

/**
 * Consumido del día: suma de los MealItem de todas las comidas recibidas.
 * Quien llama decide qué comidas son del día y del usuario; aquí solo se suma.
 * Una comida sin alimentos aporta cero.
 */
export function sumMealItems(
  meals: readonly { items: readonly FrozenMealItemMacros[] }[],
): Nutrients {
  const items = meals.flatMap((meal) => meal.items);
  return roundNutrients(
    sumNutrition(
      items.map((item) => ({
        calories: item.kcal,
        proteinG: item.proteinG,
        carbsG: item.carbsG,
        fatG: item.fatG,
      })),
    ),
  );
}

/** Meta menos consumido; negativo si se excedió la meta. */
export function remainingAgainst(
  goals: DailyGoals,
  consumed: Nutrients,
): Nutrients {
  return roundNutrients({
    calories: goals.dailyCalorieGoal - consumed.calories,
    proteinG: goals.proteinGoalG - consumed.proteinG,
    carbsG: goals.carbsGoalG - consumed.carbsG,
    fatG: goals.fatGoalG - consumed.fatG,
  });
}
