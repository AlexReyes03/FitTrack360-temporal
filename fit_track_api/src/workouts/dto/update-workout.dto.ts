import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional, IsString } from 'class-validator';

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
    description: 'Notas u observaciones actualizadas de la sesión',
    example: 'Se añadió serie de aproximación adicional.',
  })
  @IsOptional()
  @IsString({ message: 'notes debe ser una cadena de texto' })
  notes?: string;
}
