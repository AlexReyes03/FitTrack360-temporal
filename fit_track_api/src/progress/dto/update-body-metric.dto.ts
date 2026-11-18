import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsPositive,
  Max,
  Min,
} from 'class-validator';
import { IsNotFutureDate } from '../validators/not-future-date.validator';

export class UpdateBodyMetricDto {
  @ApiPropertyOptional({
    description:
      'Fecha y hora de la medición biométrica en formato ISO 8601 (no futura)',
    example: '2026-11-10T07:30:00.000Z',
    format: 'date-time',
  })
  @IsOptional()
  @IsDateString(
    {},
    { message: 'measuredAt debe ser una fecha ISO 8601 válida' },
  )
  @IsNotFutureDate({ message: 'measuredAt no puede ser una fecha futura' })
  measuredAt?: string;

  @ApiPropertyOptional({
    description: 'Peso corporal en kilogramos (estrictamente positivo)',
    example: 73.8,
    minimum: 0,
    exclusiveMinimum: true,
  })
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false },
    { message: 'weightKg debe ser un número válido' },
  )
  @IsPositive({ message: 'weightKg debe ser estrictamente mayor a 0' })
  weightKg?: number;

  @ApiPropertyOptional({
    description: 'Porcentaje de grasa corporal (mayor o igual a 0, máximo 100)',
    example: 17.9,
    minimum: 0,
    maximum: 100,
    nullable: true,
    type: Number,
  })
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false },
    { message: 'bodyFatPercent debe ser un número válido' },
  )
  @Min(0, { message: 'bodyFatPercent debe ser mayor o igual a 0' })
  @Max(100, { message: 'bodyFatPercent no puede exceder 100' })
  bodyFatPercent?: number | null;

  @ApiPropertyOptional({
    description: 'Medida de cintura en centímetros (mayor o igual a 0)',
    example: 80.5,
    minimum: 0,
    nullable: true,
    type: Number,
  })
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false },
    { message: 'waistCm debe ser un número válido' },
  )
  @Min(0, { message: 'waistCm debe ser mayor o igual a 0' })
  waistCm?: number | null;
}
