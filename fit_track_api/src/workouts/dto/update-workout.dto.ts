import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { CreateWorkoutSetDto } from './create-workout-set.dto';

export class UpdateWorkoutDto {
  @ApiPropertyOptional({
    description: 'Fecha y hora de inicio de la sesión en formato ISO 8601',
    example: '2026-11-04T10:00:00.000Z',
  })
  @IsOptional()
  @IsDateString({}, { message: 'startedAt debe ser una fecha ISO 8601 válida' })
  startedAt?: string;

  @ApiPropertyOptional({
    description: 'Fecha y hora de término de la sesión en formato ISO 8601',
    example: '2026-11-04T11:30:00.000Z',
  })
  @IsOptional()
  @IsDateString({}, { message: 'endedAt debe ser una fecha ISO 8601 válida' })
  endedAt?: string;

  @ApiPropertyOptional({
    description:
      'Ubicación aproximada o zona escrita por la persona. Cadena vacía la borra.',
    example: 'Gimnasio del campus',
    maxLength: 120,
  })
  @IsOptional()
  @IsString({ message: 'location debe ser una cadena de texto' })
  @MaxLength(120, { message: 'location no puede exceder 120 caracteres' })
  location?: string;

  @ApiPropertyOptional({
    description: 'Notas u observaciones actualizadas de la sesión',
    example: 'Se añadió serie de aproximación adicional.',
  })
  @IsOptional()
  @IsString({ message: 'notes debe ser una cadena de texto' })
  notes?: string;

  @ApiPropertyOptional({
    description:
      'Series que reemplazan a las anteriores. Un arreglo vacío las elimina.',
    type: [CreateWorkoutSetDto],
  })
  @IsOptional()
  @IsArray({ message: 'sets debe ser un arreglo de series' })
  @ValidateNested({ each: true })
  @Type(() => CreateWorkoutSetDto)
  sets?: CreateWorkoutSetDto[];
}
