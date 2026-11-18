import { BadRequestException } from '@nestjs/common';
import { DistanceUnit, WeightUnit } from '@prisma/client';

/** Catálogo de unidades de peso que acepta el perfil. */
export const WEIGHT_UNITS = Object.values(WeightUnit);
/** Catálogo de unidades de distancia que acepta el perfil. */
export const DISTANCE_UNITS = Object.values(DistanceUnit);

/** Límites del descanso entre series, en segundos. */
export const REST_SECONDS_MIN = 1;
export const REST_SECONDS_MAX = 3600;

/**
 * Topes de las metas diarias: kcal y gramos por macro. El DTO de PATCH usa
 * los mismos valores en sus `@Max`; el dominio los aplica por su cuenta para
 * que la regla no dependa del ValidationPipe.
 */
export const GOAL_LIMITS = {
  dailyCalorieGoalMax: 20000,
  macroGoalMax: 2000,
} as const;

/**
 * Metas y preferencias por defecto del deportista. Coinciden con los
 * `@default` de `UserSettings` en schema.prisma; se usan mientras el usuario
 * no haya guardado ajustes propios.
 */
export const DEFAULT_SETTINGS = {
  dailyCalorieGoal: 2000,
  proteinGoalG: 150,
  carbsGoalG: 250,
  fatGoalG: 65,
  weightUnit: WeightUnit.kg,
  distanceUnit: DistanceUnit.km,
  restSeconds: 90,
  notificationsEnabled: false,
  biometricEnabled: false,
} as const;

export interface GoalsInput {
  dailyCalorieGoal?: number;
  proteinGoalG?: number;
  carbsGoalG?: number;
  fatGoalG?: number;
}

export interface PreferencesInput {
  weightUnit?: WeightUnit;
  distanceUnit?: DistanceUnit;
  restSeconds?: number;
  notificationsEnabled?: boolean;
  biometricEnabled?: boolean;
}

const isInteger = (value: number) => Number.isInteger(value);

/**
 * Reglas de negocio de las metas: la meta calórica diaria es un entero entre
 * 1 y `GOAL_LIMITS.dailyCalorieGoalMax`, y cada macro (proteína,
 * carbohidratos, grasa) es un entero entre 0 y `GOAL_LIMITS.macroGoalMax`.
 * Se valida aquí además del DTO para que la regla no dependa de la capa HTTP.
 */
export function assertValidGoals(goals: GoalsInput | undefined): void {
  if (!goals) return;
  const { dailyCalorieGoal, ...macros } = goals;
  if (
    dailyCalorieGoal !== undefined &&
    (!isInteger(dailyCalorieGoal) ||
      dailyCalorieGoal <= 0 ||
      dailyCalorieGoal > GOAL_LIMITS.dailyCalorieGoalMax)
  ) {
    throw new BadRequestException(
      `dailyCalorieGoal debe ser un entero entre 1 y ${GOAL_LIMITS.dailyCalorieGoalMax}`,
    );
  }
  for (const [name, value] of Object.entries(macros)) {
    if (
      value !== undefined &&
      (!isInteger(value) || value < 0 || value > GOAL_LIMITS.macroGoalMax)
    ) {
      throw new BadRequestException(
        `${name} debe ser un entero entre 0 y ${GOAL_LIMITS.macroGoalMax}`,
      );
    }
  }
}

/**
 * Cambios de ajustes de un PATCH parcial: une metas y preferencias y descarta
 * las claves con valor `undefined`. Los DTO de clase (campos ES2023) declaran
 * todas sus claves aunque el cliente no las envíe; sin este filtro, un spread
 * sobre `DEFAULT_SETTINGS` o sobre la fila guardada las pisaría con
 * `undefined`.
 */
export function settingsChanges(
  goals: GoalsInput | undefined,
  preferences: PreferencesInput | undefined,
): Partial<GoalsInput & PreferencesInput> {
  return Object.fromEntries(
    Object.entries({ ...goals, ...preferences }).filter(
      ([, value]) => value !== undefined,
    ),
  );
}

/** Reglas de las preferencias: unidades del catálogo y descanso acotado. */
export function assertValidPreferences(
  preferences: PreferencesInput | undefined,
): void {
  if (!preferences) return;
  const { weightUnit, distanceUnit, restSeconds } = preferences;
  if (weightUnit !== undefined && !WEIGHT_UNITS.includes(weightUnit)) {
    throw new BadRequestException(
      `weightUnit debe ser uno de: ${WEIGHT_UNITS.join(', ')}`,
    );
  }
  if (distanceUnit !== undefined && !DISTANCE_UNITS.includes(distanceUnit)) {
    throw new BadRequestException(
      `distanceUnit debe ser uno de: ${DISTANCE_UNITS.join(', ')}`,
    );
  }
  if (
    restSeconds !== undefined &&
    (!isInteger(restSeconds) ||
      restSeconds < REST_SECONDS_MIN ||
      restSeconds > REST_SECONDS_MAX)
  ) {
    throw new BadRequestException(
      `restSeconds debe ser un entero entre ${REST_SECONDS_MIN} y ${REST_SECONDS_MAX}`,
    );
  }
}
