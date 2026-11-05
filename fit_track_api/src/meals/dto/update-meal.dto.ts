import { ApiPropertyOptional } from '@nestjs/swagger';
import { MealType } from '@prisma/client';
import { IsDateString, IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateMealDto {
  @ApiPropertyOptional({
    description:
      'Fecha y hora en que se consumió el alimento en formato ISO 8601',
    example: '2026-11-04T09:00:00.000Z',
  })
  @IsOptional()
  @IsDateString({}, { message: 'eatenAt debe ser una fecha ISO 8601 válida' })
  eatenAt?: string;

  @ApiPropertyOptional({
    description: 'Tipo de comida (tiempo de alimento)',
    enum: MealType,
    example: MealType.LUNCH,
  })
  @IsOptional()
  @IsEnum(MealType, {
    message:
      'mealType debe ser uno de los siguientes valores: BREAKFAST, LUNCH, DINNER, SNACK',
  })
  mealType?: MealType;

  @ApiPropertyOptional({
    description: 'Notas o comentarios sobre la comida',
    example: 'Se añadió proteína en polvo al tazón.',
  })
  @IsOptional()
  @IsString({ message: 'notes debe ser una cadena de texto' })
  notes?: string;

  @ApiPropertyOptional({
    description: 'Identificador opcional de la fotografía asociada',
    example: 'photo-67890',
  })
  @IsOptional()
  @IsString({ message: 'photoId debe ser una cadena de texto' })
  photoId?: string;
}
