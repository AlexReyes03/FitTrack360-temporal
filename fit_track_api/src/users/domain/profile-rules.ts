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
  notificationsEnabled: true,
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
 * Reglas de negocio de las metas: la meta calórica diaria es un entero
 * positivo y cada macro (proteína, carbohidratos, grasa) es un entero no
 * negativo. Se valida aquí además del DTO para que la regla no dependa de la
 * capa HTTP.
 */
export function assertValidGoals(goals: GoalsInput | undefined): void {
  if (!goals) return;
  const { dailyCalorieGoal, ...macros } = goals;
  if (
    dailyCalorieGoal !== undefined &&
    (!isInteger(dailyCalorieGoal) || dailyCalorieGoal <= 0)
  ) {
    throw new BadRequestException(
      'dailyCalorieGoal debe ser un entero mayor que 0',
    );
  }
  for (const [name, value] of Object.entries(macros)) {
    if (value !== undefined && (!isInteger(value) || value < 0)) {
      throw new BadRequestException(
        `${name} debe ser un entero mayor o igual a 0`,
      );
    }
  }
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
