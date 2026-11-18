// Seed idempotente del catálogo completo (Task W11-02).
// nameEs, level y commonErrors se copian solo cuando el JSON los trae (W11-BE-02.4).

import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';
import {
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

  if (records.length === 0) {
    throw new Error('El catálogo de ejercicios está vacío');
  }

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

/**
 * Confirma cuántas filas quedaron en la base. No vuelca el catálogo completo.
 */
export async function verifyExercises(): Promise<number> {
  const total = await prisma.exercise.count();
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
