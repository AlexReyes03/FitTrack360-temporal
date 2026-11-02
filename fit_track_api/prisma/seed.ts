// NOTA: Seed de validación con 5 ejercicios (W8-04). El seed completo de 1324 ejercicios se ejecutará la semana siguiente.

import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

interface ExerciseJson {
  id: string;
  name: string;
  category: string;
  body_part: string;
  equipment: string;
  target: string;
  muscle_group: string;
  secondary_muscles: string[];
  instructions_es: string;
  instruction_steps_es: string[];
  image: string;
  gif: string;
  media_id?: string;
  attribution: string;
}

const prisma = new PrismaClient();

async function main() {
  const seedFilePath = path.resolve(__dirname, '../seed/exercises.es.json');
  const fileData = fs.readFileSync(seedFilePath, 'utf-8');
  const allExercises: ExerciseJson[] = JSON.parse(fileData);

  const sample = allExercises.slice(0, 5);

  console.log(`Iniciando seed de ${sample.length} ejercicios de validación...`);

  for (const item of sample) {
    await prisma.exercise.upsert({
      where: { id: item.id },
      update: {
        name: item.name,
        bodyPart: item.body_part,
        equipment: item.equipment,
        target: item.target,
        muscleGroup: item.muscle_group,
        secondaryMuscles: item.secondary_muscles,
        instructionsEs: item.instructions_es,
        instructionStepsEs: item.instruction_steps_es,
        imageFile: item.image,
        gifFile: item.gif,
        attribution: item.attribution,
      },
      create: {
        id: item.id,
        name: item.name,
        bodyPart: item.body_part,
        equipment: item.equipment,
        target: item.target,
        muscleGroup: item.muscle_group,
        secondaryMuscles: item.secondary_muscles,
        instructionsEs: item.instructions_es,
        instructionStepsEs: item.instruction_steps_es,
        imageFile: item.image,
        gifFile: item.gif,
        attribution: item.attribution,
      },
    });
  }

  const loadedExercises = await prisma.exercise.findMany();
  console.log(
    `Total de ejercicios cargados en la base de datos: ${loadedExercises.length}`,
  );
  console.log('Detalle de ejercicios cargados:');
  for (const ex of loadedExercises) {
    console.log(
      `- ID: ${ex.id} | imageFile: ${ex.imageFile} | gifFile: ${ex.gifFile}`,
    );
  }
}

main()
  .catch((e) => {
    console.error('Error ejecutando seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
