import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { Exercise } from '@prisma/client';
import {
  EXERCISE_IMAGES_ROUTE,
  EXERCISE_VIDEOS_ROUTE,
} from '../../static/exercise-media.module';

function definedText(value: string | null): string | undefined {
  if (value == null || value.trim() === '') return undefined;
  return value;
}

export class ExerciseResponseDto {
  @ApiProperty({
    description: 'Identificador del ejercicio en el catálogo',
    example: '0001',
  })
  id!: string;

  @ApiProperty({
    description: 'Nombre del ejercicio en inglés',
    example: '3/4 sit-up',
  })
  name!: string;

  @ApiPropertyOptional({
    description: 'Nombre en español. Se omite cuando no existe',
    example: 'Abdominal 3/4',
  })
  nameEs?: string;

  @ApiPropertyOptional({
    description: 'Categoría de entrenamiento',
    example: 'strength',
    nullable: true,
  })
  category!: string | null;

  @ApiProperty({
    description: 'Parte del cuerpo',
    example: 'waist',
  })
  bodyPart!: string;

  @ApiProperty({
    description: 'Equipamiento',
    example: 'body weight',
  })
  equipment!: string;

  @ApiProperty({
    description: 'Músculo objetivo',
    example: 'abs',
  })
  target!: string;

  @ApiPropertyOptional({
    description: 'Grupo muscular',
    example: 'abdominals',
    nullable: true,
  })
  muscleGroup!: string | null;

  @ApiProperty({
    description: 'Músculos secundarios',
    type: [String],
    example: ['hip flexors'],
  })
  secondaryMuscles!: string[];

  @ApiPropertyOptional({
    description: 'Nivel de dificultad. Se omite cuando no existe',
    example: 'beginner',
  })
  level?: string;

  @ApiPropertyOptional({
    description: 'Instrucciones en español',
    nullable: true,
  })
  instructionsEs!: string | null;

  @ApiProperty({
    description: 'Pasos de ejecución en español',
    type: [String],
  })
  instructionStepsEs!: string[];

  @ApiPropertyOptional({
    description: 'Errores comunes. Se omite cuando no existe',
    example: 'Tirar del cuello con las manos.',
  })
  commonErrors?: string;

  @ApiProperty({
    description: `Archivo de miniatura servido en ${EXERCISE_IMAGES_ROUTE}`,
    example: '0001-2gPfomN.jpg',
  })
  imageFile!: string;

  @ApiProperty({
    description: `Archivo animado servido en ${EXERCISE_VIDEOS_ROUTE}`,
    example: '0001-2gPfomN.gif',
  })
  gifFile!: string;

  @ApiPropertyOptional({
    description: 'Identificador de la pieza de media',
    example: '2gPfomN',
    nullable: true,
  })
  mediaId!: string | null;

  @ApiProperty({
    description: 'Atribución de licencia de Gym Visual',
    example: '© Gym visual — https://gymvisual.com/',
  })
  attribution!: string;

  static fromEntity(exercise: Exercise): ExerciseResponseDto {
    const dto = new ExerciseResponseDto();
    dto.id = exercise.id;
    dto.name = exercise.name;
    const nameEs = definedText(exercise.nameEs);
    if (nameEs !== undefined) dto.nameEs = nameEs;
    dto.category = exercise.category;
    dto.bodyPart = exercise.bodyPart;
    dto.equipment = exercise.equipment;
    dto.target = exercise.target;
    dto.muscleGroup = exercise.muscleGroup;
    dto.secondaryMuscles = exercise.secondaryMuscles ?? [];
    const level = definedText(exercise.level);
    if (level !== undefined) dto.level = level;
    dto.instructionsEs = exercise.instructionsEs;
    dto.instructionStepsEs = exercise.instructionStepsEs ?? [];
    const commonErrors = definedText(exercise.commonErrors);
    if (commonErrors !== undefined) dto.commonErrors = commonErrors;
    dto.imageFile = exercise.imageFile;
    dto.gifFile = exercise.gifFile;
    dto.mediaId = exercise.mediaId;
    dto.attribution = exercise.attribution;
    return dto;
  }
}

export class ExercisePageResponseDto {
  @ApiProperty({
    description: 'Ejercicios de la página solicitada',
    type: [ExerciseResponseDto],
  })
  items!: ExerciseResponseDto[];

  @ApiProperty({
    description: 'Total que coincide con los filtros, no solo esta página',
    example: 1324,
  })
  total!: number;

  @ApiProperty({
    description: 'Página actual (empieza en 1)',
    example: 1,
  })
  page!: number;

  @ApiProperty({
    description: 'Tamaño de página aplicado',
    example: 20,
  })
  pageSize!: number;
}
