import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';
import {
  EXPECTED_EXERCISE_COUNT,
  assertExerciseCount,
  assertUniqueExerciseIds,
  exercisesForSeed,
  type ExerciseSeedRecord,
  type RawExerciseJson,
} from './exercise-catalog';

const prisma = new PrismaClient();
const UPSERT_BATCH_SIZE = 100;

async function main() {
  const seedFilePath = path.resolve(__dirname, '../seed/exercises.es.json');

  if (!fs.existsSync(seedFilePath)) {
    throw new Error(`El archivo de catálogo no existe en: ${seedFilePath}`);
  }

  const fileData = fs.readFileSync(seedFilePath, 'utf-8');
  const allExercises: RawExerciseJson[] = JSON.parse(fileData);
  const records = exercisesForSeed(allExercises);

  assertUniqueExerciseIds(records);
  assertExerciseCount(records.length);

  console.log(`Iniciando seed idempotente de ${records.length} ejercicios...`);

  for (let offset = 0; offset < records.length; offset += UPSERT_BATCH_SIZE) {
    const batch = records.slice(offset, offset + UPSERT_BATCH_SIZE);
    await prisma.$transaction(batch.map((record) => upsertExercise(record)));
  }

  console.log('Seed finalizado correctamente.');
  await verifyExercises();
}

function upsertExercise(record: ExerciseSeedRecord) {
  const { id, ...data } = record;
  return prisma.exercise.upsert({
    where: { id },
    update: data,
    create: record,
  });
}

export async function verifyExercises(
  expected: number = EXPECTED_EXERCISE_COUNT,
): Promise<number> {
  const total = await prisma.exercise.count();
  assertExerciseCount(total, expected);
  console.log('\n=== Verificación de ejercicios en DB ===');
  console.log(`Total de filas encontradas: ${total}`);
  return total;
}

if (require.main === module) {
  main()
    .catch((error: unknown) => {
      console.error('Error durante la ejecución del seed:', error);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
