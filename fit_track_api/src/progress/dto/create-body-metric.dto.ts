import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  Max,
  Min,
} from 'class-validator';
import { IsNotFutureDate } from '../validators/not-future-date.validator';

export class CreateBodyMetricDto {
  @ApiProperty({
    description:
      'Fecha y hora de la medición biométrica en formato ISO 8601 (no se permiten fechas futuras)',
    example: '2026-11-10T07:30:00.000Z',
    format: 'date-time',
  })
  @IsNotEmpty({ message: 'measuredAt es obligatorio' })
  @IsDateString(
    { strict: true },
    { message: 'measuredAt debe ser una fecha ISO 8601 válida' },
  )
  @IsNotFutureDate({ message: 'measuredAt no puede ser una fecha futura' })
  measuredAt!: string;

  @ApiProperty({
    description: 'Peso corporal en kilogramos (estrictamente positivo)',
    example: 74.5,
    minimum: 0,
    exclusiveMinimum: true,
  })
  @IsNumber(
    { allowNaN: false, allowInfinity: false },
    { message: 'weightKg debe ser un número válido' },
  )
  @IsPositive({ message: 'weightKg debe ser estrictamente mayor a 0' })
  weightKg!: number;

  @ApiPropertyOptional({
    description: 'Porcentaje de grasa corporal (mayor o igual a 0, máximo 100)',
    example: 18.2,
    minimum: 0,
    maximum: 100,
  })
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false },
    { message: 'bodyFatPercent debe ser un número válido' },
  )
  @Min(0, { message: 'bodyFatPercent debe ser mayor o igual a 0' })
  @Max(100, { message: 'bodyFatPercent no puede exceder 100' })
  bodyFatPercent?: number;

  @ApiPropertyOptional({
    description: 'Medida de cintura en centímetros (mayor o igual a 0)',
    example: 81.5,
    minimum: 0,
  })
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false },
    { message: 'waistCm debe ser un número válido' },
  )
  @Min(0, { message: 'waistCm debe ser mayor o igual a 0' })
  waistCm?: number;
}
