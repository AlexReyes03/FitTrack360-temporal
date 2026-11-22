export const EXPECTED_EXERCISE_COUNT = 1324;

export interface RawExerciseJson {
  id: string;
  name: string;
  name_es?: string;
  category?: string;
  body_part: string;
  equipment: string;
  target: string;
  muscle_group?: string;
  secondary_muscles?: string[];
  level?: string;
  instructions_es?: string;
  instruction_steps_es?: string[];
  common_errors?: string;
  image: string;
  gif: string;
  media_id?: string;
  attribution: string;
}

export interface ExerciseSeedRecord {
  id: string;
  name: string;
  nameEs: string | null;
  category: string | null;
  bodyPart: string;
  equipment: string;
  target: string;
  muscleGroup: string | null;
  secondaryMuscles: string[];
  level: string | null;
  instructionsEs: string | null;
  instructionStepsEs: string[];
  commonErrors: string | null;
  imageFile: string;
  gifFile: string;
  mediaId: string | null;
  attribution: string;
}

function optionalText(value: string | undefined): string | null {
  if (value == null) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function toExerciseSeedRecord(
  item: RawExerciseJson,
): ExerciseSeedRecord {
  return {
    id: item.id,
    name: item.name,
    nameEs: optionalText(item.name_es),
    category: optionalText(item.category),
    bodyPart: item.body_part,
    equipment: item.equipment,
    target: item.target,
    muscleGroup: optionalText(item.muscle_group),
    secondaryMuscles: item.secondary_muscles ?? [],
    level: optionalText(item.level),
    instructionsEs: optionalText(item.instructions_es),
    instructionStepsEs: item.instruction_steps_es ?? [],
    commonErrors: optionalText(item.common_errors),
    imageFile: item.image,
    gifFile: item.gif,
    mediaId: optionalText(item.media_id),
    attribution: item.attribution,
  };
}

export function exercisesForSeed(all: RawExerciseJson[]): ExerciseSeedRecord[] {
  return all.map(toExerciseSeedRecord);
}

export function assertUniqueExerciseIds(records: { id: string }[]): void {
  const seen = new Set<string>();
  for (const record of records) {
    if (seen.has(record.id)) {
      throw new Error(`ID de ejercicio duplicado en el catálogo: ${record.id}`);
    }
    seen.add(record.id);
  }
}

export function assertExerciseCount(
  actual: number,
  expected: number = EXPECTED_EXERCISE_COUNT,
): void {
  if (actual !== expected) {
    throw new Error(
      `Integridad del catálogo fallida: se esperaban ${expected} ejercicios y hay ${actual}`,
    );
  }
}
