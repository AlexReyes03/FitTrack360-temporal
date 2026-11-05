// NOTA: Seed de validación con 5 ejercicios (Task W9-12).
// La carga de los 1324 registros completos está fuera del alcance de este PR y se ejecutará posteriormente.

import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

interface RawExerciseJson {
  id: string;
  name: string;
  category: string;
  body_part: string;
  equipment: string;
  target: string;
  muscle_group?: string;
  secondary_muscles?: string[];
  instructions_es?: string;
  instruction_steps_es?: string[];
  image: string;
  gif: string;
  media_id?: string;
  attribution: string;
}

const prisma = new PrismaClient();

async function main() {
  const seedFilePath = path.resolve(__dirname, '../seed/exercises.es.json');

  if (!fs.existsSync(seedFilePath)) {
    throw new Error(`El archivo de catálogo no existe en: ${seedFilePath}`);
  }

  const fileData = fs.readFileSync(seedFilePath, 'utf-8');
  const allExercises: RawExerciseJson[] = JSON.parse(fileData);

  // Extraer únicamente los primeros 5 registros según el alcance de Task W9-12
  const sample = allExercises.slice(0, 5);

  console.log(`Iniciando seed idempotente de ${sample.length} ejercicios...`);

  for (const item of sample) {
    const exerciseData = {
      id: item.id,
      name: item.name,
      imageFile: item.image,
      gifFile: item.gif,
      attribution: item.attribution,
      bodyPart: item.body_part,
      equipment: item.equipment,
      target: item.target,
    };

    // Operación idempotente: upsert actualiza si ya existe o inserta si no existe
    await prisma.exercise.upsert({
      where: { id: exerciseData.id },
      update: {
        name: exerciseData.name,
        imageFile: exerciseData.imageFile,
        gifFile: exerciseData.gifFile,
        attribution: exerciseData.attribution,
        bodyPart: exerciseData.bodyPart,
        equipment: exerciseData.equipment,
        target: exerciseData.target,
      },
      create: exerciseData,
    });
  }

  console.log(`Seed finalizado correctamente.`);

  // Script / bloque de verificación con findMany() para confirmar que las filas existen en la DB
  await verifyExercises();
}

/**
 * Script de verificación para consultar y mostrar las filas en la base de datos mediante findMany().
 */
export async function verifyExercises() {
  const loadedExercises = await prisma.exercise.findMany();

  console.log('\n=== Verificación de ejercicios en DB (findMany) ===');
  console.log(`Total de filas encontradas: ${loadedExercises.length}`);
  console.log('Detalle de registros:');

  for (const ex of loadedExercises) {
    console.log(
      `- [ID: ${ex.id}] ${ex.name} | bodyPart: ${ex.bodyPart} | equipment: ${ex.equipment} | target: ${ex.target} | imageFile: ${ex.imageFile} | gifFile: ${ex.gifFile}`,
    );
  }

  return loadedExercises;
}

// Ejecutar el script solo si es llamado directamente
if (require.main === module) {
  main()
    .catch((error) => {
      console.error('Error durante la ejecución del seed:', error);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
