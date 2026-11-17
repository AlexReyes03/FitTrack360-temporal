import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { CreateWorkoutSetDto } from './create-workout-set.dto';

export class CreateWorkoutDto {
  @ApiProperty({
    description: 'Fecha y hora de inicio de la sesión en formato ISO 8601',
    example: '2026-11-04T10:00:00.000Z',
  })
  @IsNotEmpty({ message: 'startedAt es obligatorio' })
  @IsDateString({}, { message: 'startedAt debe ser una fecha ISO 8601 válida' })
  startedAt!: string;

  @ApiPropertyOptional({
    description: 'Fecha y hora de término de la sesión en formato ISO 8601',
    example: '2026-11-04T11:15:00.000Z',
  })
  @IsOptional()
  @IsDateString({}, { message: 'endedAt debe ser una fecha ISO 8601 válida' })
  endedAt?: string;

  @ApiPropertyOptional({
    description:
      'Ubicación aproximada o zona escrita por la persona. No exige GPS.',
    example: 'Gimnasio del campus',
    maxLength: 120,
  })
  @IsOptional()
  @IsString({ message: 'location debe ser una cadena de texto' })
  @MaxLength(120, { message: 'location no puede exceder 120 caracteres' })
  location?: string;

  @ApiPropertyOptional({
    description:
      'Notas u observaciones personales sobre la sesión de entrenamiento',
    example: 'Buen progreso en sentadillas, descanso de 90s entre series.',
  })
  @IsOptional()
  @IsString({ message: 'notes debe ser una cadena de texto' })
  notes?: string;

  @ApiPropertyOptional({
    description: 'Series de la sesión, en el orden en que se ejecutaron',
    type: [CreateWorkoutSetDto],
  })
  @IsOptional()
  @IsArray({ message: 'sets debe ser un arreglo de series' })
  @ValidateNested({ each: true })
  @Type(() => CreateWorkoutSetDto)
  sets?: CreateWorkoutSetDto[];
}
