import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MealType } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateMealDto {
  @ApiProperty({
    description:
      'Fecha y hora en que se consumió el alimento en formato ISO 8601',
    example: '2026-11-04T08:30:00.000Z',
  })
  @IsNotEmpty({ message: 'eatenAt es obligatorio' })
  @IsDateString({}, { message: 'eatenAt debe ser una fecha ISO 8601 válida' })
  eatenAt!: string;

  @ApiProperty({
    description: 'Tipo de comida (tiempo de alimento)',
    enum: MealType,
    example: MealType.BREAKFAST,
  })
  @IsNotEmpty({ message: 'mealType es obligatorio' })
  @IsEnum(MealType, {
    message:
      'mealType debe ser uno de los siguientes valores: BREAKFAST, LUNCH, DINNER, SNACK',
  })
  mealType!: MealType;

  @ApiPropertyOptional({
    description: 'Notas o comentarios sobre la comida',
    example: 'Tazón de avena con frutas y frutos secos.',
  })
  @IsOptional()
  @IsString({ message: 'notes debe ser una cadena de texto' })
  notes?: string;

  @ApiPropertyOptional({
    description: 'Identificador opcional de la fotografía asociada',
    example: 'photo-12345',
  })
  @IsOptional()
  @IsString({ message: 'photoId debe ser una cadena de texto' })
  photoId?: string;
}
