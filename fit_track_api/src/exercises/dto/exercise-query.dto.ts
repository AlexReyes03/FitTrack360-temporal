import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export const EXERCISE_SORT_FIELDS = ['id', 'name'] as const;
export const EXERCISE_SORT_ORDERS = ['asc', 'desc'] as const;

export type ExerciseSortField = (typeof EXERCISE_SORT_FIELDS)[number];
export type ExerciseSortOrder = (typeof EXERCISE_SORT_ORDERS)[number];

export class ExerciseQueryDto {
  @ApiPropertyOptional({
    description:
      'Texto libre. Coincide con el nombre en inglés o en español si existe',
    example: 'press',
  })
  @IsOptional()
  @IsString({ message: 'q debe ser una cadena de texto' })
  q?: string;

  @ApiPropertyOptional({
    description: 'Filtro exacto por parte del cuerpo (ej. chest, waist, back)',
    example: 'chest',
  })
  @IsOptional()
  @IsString({ message: 'bodyPart debe ser una cadena de texto' })
  bodyPart?: string;

  @ApiPropertyOptional({
    description:
      'Filtro exacto por equipamiento (ej. barbell, dumbbell, body weight)',
    example: 'barbell',
  })
  @IsOptional()
  @IsString({ message: 'equipment debe ser una cadena de texto' })
  equipment?: string;

  @ApiPropertyOptional({
    description: 'Filtro exacto por músculo objetivo (ej. pectorals, abs)',
    example: 'pectorals',
  })
  @IsOptional()
  @IsString({ message: 'target debe ser una cadena de texto' })
  target?: string;

  @ApiPropertyOptional({
    description: 'Número de página (empieza en 1)',
    example: 1,
    default: 1,
    minimum: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'page debe ser un número entero' })
  @Min(1, { message: 'page debe ser mayor o igual a 1' })
  page?: number;

  @ApiPropertyOptional({
    description: 'Cantidad de registros por página',
    example: 20,
    default: 20,
    minimum: 1,
    maximum: 100,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'pageSize debe ser un número entero' })
  @Min(1, { message: 'pageSize debe ser mayor o igual a 1' })
  @Max(100, { message: 'pageSize no puede exceder 100' })
  pageSize?: number;

  @ApiPropertyOptional({
    description: 'Campo de orden. Por defecto id, que es estable entre páginas',
    enum: EXERCISE_SORT_FIELDS,
    default: 'id',
  })
  @IsOptional()
  @IsIn(EXERCISE_SORT_FIELDS, {
    message: 'sort debe ser id o name',
  })
  sort?: ExerciseSortField;

  @ApiPropertyOptional({
    description: 'Dirección del orden',
    enum: EXERCISE_SORT_ORDERS,
    default: 'asc',
  })
  @IsOptional()
  @IsIn(EXERCISE_SORT_ORDERS, {
    message: 'order debe ser asc o desc',
  })
  order?: ExerciseSortOrder;
}
